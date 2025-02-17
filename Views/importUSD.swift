import SwiftUI
import QuickLookThumbnailing
import QuickLook

struct ImportedFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var thumbnail: UIImage?
}

struct ImportUSD: View {
    @Environment(\.dismiss) var dismiss
    @State private var importedFiles: [ImportedFile] = []
    @State private var showDocumentPicker = false
    @State private var searchText = ""

    private let fileManager = FileManager.default
    private let appFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    var body: some View {
        NavigationStack {
            VStack {
                if importedFiles.isEmpty {
                    Text("No files imported. Tap the Import button to select .usdz files.")
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                            ForEach(importedFiles) { file in
                                VStack {
                                    if let thumbnail = file.thumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100, height: 100)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray)
                                            .frame(width: 100, height: 100)
                                    }
                                    Text(file.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .onTapGesture {
                                    previewUSDZ(file.url)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }.searchable(text: $searchText, prompt: "Search models")
            .navigationTitle("Your iteme")
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import Model") {
                        showDocumentPicker = true
                    }
                }
            }
            .onAppear {
                Task {
                    await scanLocalFiles()
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                USDDocumentPicker { urls in
                    Task {
                        await handleImportedFiles(urls)
                    }
                }
            }
        }
    }

    /// 扫描 App 文件夹中的 USDZ 文件并更新 UI
    private func scanLocalFiles() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: appFolder, includingPropertiesForKeys: nil)
            let usdzFiles = files.filter { $0.pathExtension == "usdz" }

            var newImportedFiles: [ImportedFile] = []
            for fileURL in usdzFiles {
                let fileName = fileURL.lastPathComponent
                let thumbnail = await generateThumbnail(for: fileURL)
                newImportedFiles.append(ImportedFile(name: fileName, url: fileURL, thumbnail: thumbnail))
            }
            
            DispatchQueue.main.async {
                importedFiles = newImportedFiles
            }
        } catch {
            print("Failed to scan local files: \(error.localizedDescription)")
        }
    }

    /// 处理用户导入的 USDZ 文件
    /// 处理用户导入的 USDZ 文件并拷贝到 App 的 Documents 目录
    private func handleImportedFiles(_ urls: [URL]) async {
        for url in urls {
            do {
                // 解决沙盒访问权限问题
                guard url.startAccessingSecurityScopedResource() else {
                    print("无法访问文件: \(url)")
                    continue
                }
                
                let localURL = appFolder.appendingPathComponent(url.lastPathComponent)
                
                // 确保不会覆盖已存在的文件
                if fileManager.fileExists(atPath: localURL.path) {
                    print("文件已存在，跳过: \(localURL)")
                } else {
                    do {
                        try fileManager.copyItem(at: url, to: localURL)
                        print("成功拷贝文件至: \(localURL)")
                    } catch {
                        print("文件拷贝失败: \(error.localizedDescription)")
                    }
                }

                // 释放沙盒访问权限
                url.stopAccessingSecurityScopedResource()

                // 生成缩略图并更新 UI
                let thumbnail = await generateThumbnail(for: localURL)
                DispatchQueue.main.async {
                    importedFiles.append(ImportedFile(name: localURL.lastPathComponent, url: localURL, thumbnail: thumbnail))
                }
            } catch {
                print("处理导入文件失败: \(error.localizedDescription)")
            }
        }
    }

    /// 生成 USDZ 文件缩略图
    private func generateThumbnail(for url: URL) async -> UIImage? {
        let size = CGSize(width: 100, height: 100)
        let scale = 2.0
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, _, error in
                if let error = error {
                    print("Failed to generate thumbnail: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: thumbnail?.uiImage)
                }
            }
        }
    }

    /// 使用 QuickLook 预览 USDZ 文件
    private func previewUSDZ(_ fileURL: URL) {
        Task {
            do {
                try await PreviewApplication.open(urls: [fileURL])
            } catch {
                print("Failed to preview file: \(error.localizedDescription)")
            }
        }
    }
}

/// USDZ 文件选择器
struct USDDocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.usdz])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
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

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let usdzType = UTType(filenameExtension: "usdz")!
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [usdzType])
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
