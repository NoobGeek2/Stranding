import SwiftUI
import AVKit

struct ImportedAudio: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
}

struct ImportAudioView: View {
    @Environment(\.dismiss) var dismiss
    @State private var importedAudio: [ImportedAudio] = []
    @State private var showDocumentPicker = false
    @State private var searchText = ""
    @State private var currentAudioURL: URL?
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?

    private let fileManager = FileManager.default
    private let audioFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Audio")
    
    var body: some View {
        NavigationStack {
            VStack {
                if importedAudio.isEmpty {
                    Text("No audio imported. Tap the Import button to add audio files.")
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(importedAudio) { audio in
                            VStack(alignment: .leading) {
                                Text(audio.name)
                                    .font(.headline)
                                Text(audio.url.lastPathComponent)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .onTapGesture {
                                playAudio(audio.url)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search audio")
            .navigationTitle("Your Audio")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import Audio") {
                        showDocumentPicker = true
                    }
                }
            }
            .onAppear {
                createAudioFolderIfNeeded()
                Task {
                    await scanLocalAudio()
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                AudioDocumentPicker { urls in
                    Task {
                        await handleImportedAudio(urls)
                    }
                }
            }
            
            // Audio Player Controls
            if let currentAudioURL = currentAudioURL {
                VStack {
                    Text("Now Playing: \(currentAudioURL.lastPathComponent)")
                        .font(.headline)
                    HStack {
                        Button(action: {
                            if isPlaying {
                                audioPlayer?.pause()
                            } else {
                                audioPlayer?.play()
                            }
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                        Button(action: {
                            audioPlayer?.stop()
                            isPlaying = false
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding()
            }
        }
    }

    /// 创建 Audio 文件夹（如果不存在）
    private func createAudioFolderIfNeeded() {
        if !fileManager.fileExists(atPath: audioFolder.path) {
            do {
                try fileManager.createDirectory(at: audioFolder, withIntermediateDirectories: true, attributes: nil)
                print("Audio 文件夹创建成功")
            } catch {
                print("无法创建 Audio 文件夹: \(error.localizedDescription)")
            }
        }
    }

    /// 扫描 App 文件夹中的音频文件
    private func scanLocalAudio() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: audioFolder, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { ["mp3", "wav", "m4a"].contains($0.pathExtension.lowercased()) }

            var newImportedAudio: [ImportedAudio] = []
            for fileURL in audioFiles {
                let fileName = fileURL.lastPathComponent
                newImportedAudio.append(ImportedAudio(name: fileName, url: fileURL))
            }
            
            DispatchQueue.main.async {
                importedAudio = newImportedAudio
            }
        } catch {
            print("Failed to scan audio files: \(error.localizedDescription)")
        }
    }

    /// 处理用户导入的音频文件
    private func handleImportedAudio(_ urls: [URL]) async {
        for url in urls {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    print("无法访问文件: \(url)")
                    continue
                }
                
                let localURL = audioFolder.appendingPathComponent(url.lastPathComponent)
                
                if fileManager.fileExists(atPath: localURL.path) {
                    print("文件已存在，跳过: \(localURL)")
                } else {
                    try fileManager.copyItem(at: url, to: localURL)
                    print("成功拷贝文件至: \(localURL)")
                }

                url.stopAccessingSecurityScopedResource()

                DispatchQueue.main.async {
                    importedAudio.append(ImportedAudio(name: localURL.lastPathComponent, url: localURL))
                }
            } catch {
                print("文件导入失败: \(error.localizedDescription)")
            }
        }
    }

    /// 播放音频文件
    private func playAudio(_ url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
            currentAudioURL = url
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
}

/// 文件选择器（导入音频）
struct AudioDocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void
        
        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
