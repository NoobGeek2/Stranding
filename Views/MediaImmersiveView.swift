import SwiftUI
import PhotosUI
import QuickLookThumbnailing
import QuickLook
import AVKit

class VideoPlayerViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
}

struct ImportedMediaItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var thumbnail: UIImage?
}

struct ImmersiveImportMediaView: View {
    @Environment(\.dismiss) var dismiss
    @State private var importedMedia: [ImportedMediaItem] = []
    @State private var showDocumentPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var searchText = ""
    @State private var showVideoPlayerSheet = false
    
    @StateObject private var viewModel = VideoPlayerViewModel()

    private let fileManager = FileManager.default
    private let mediaFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Media")
    
    var body: some View {
        NavigationStack {
            VStack {
                if importedMedia.isEmpty {
                    Text("No media imported. Tap the Import button to add your videos.")
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                            ForEach(importedMedia) { media in
                                VStack {
                                    if let thumbnail = media.thumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100, height: 100)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray)
                                            .frame(width: 100, height: 100)
                                    }
                                    Text(media.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .onTapGesture {
                                    print("Tapped media: \(media.name)")
                                    showVideoPlayer(media.url)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search media")
            .navigationTitle("Your Media")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Import File") {
                            showDocumentPicker = true
                        }
                        PhotosPicker("Import Media", selection: $photoPickerItems, matching: .videos, photoLibrary: .shared())
                    }
                }
            }
            .onAppear {
                // 确保 Media 文件夹存在
                createMediaFolderIfNeeded()
                // 扫描本地媒体文件
                Task {
                    await scanLocalMedia()
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                MediaDocumentPickerView { urls in
                    Task {
                        await handleImportedMedia(urls)
                    }
                }
            }
            .onChange(of: photoPickerItems) { newItems in
                Task {
                    await handleImportedPhotos(newItems)
                }
            }
            .sheet(isPresented: $showVideoPlayerSheet) {
                if let videoURL = viewModel.selectedVideoURL {
                    VideoPlayerView(videoURL: videoURL)
                        .onAppear {
                            print("VideoPlayerView appeared with URL: \(videoURL)")
                        }
                } else {
                    Text("Selected video URL is nil")
                        .onAppear {
                            print("VideoPlayerView appeared but selectedVideoURL is nil")
                        }
                }
            }
        }
    }

    /// 创建 Media 文件夹（如果不存在）
    private func createMediaFolderIfNeeded() {
        if !fileManager.fileExists(atPath: mediaFolder.path) {
            do {
                try fileManager.createDirectory(at: mediaFolder, withIntermediateDirectories: true, attributes: nil)
                print("Media 文件夹创建成功")
            } catch {
                print("无法创建 Media 文件夹: \(error.localizedDescription)")
            }
        }
    }

    /// 扫描 App 文件夹中的媒体文件
    private func scanLocalMedia() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: mediaFolder, includingPropertiesForKeys: nil)
            let mediaFiles = files.filter { ["mp4", "mov"].contains($0.pathExtension.lowercased()) }

            var newImportedMedia: [ImportedMediaItem] = []
            for fileURL in mediaFiles {
                let fileName = fileURL.lastPathComponent
                let thumbnail = await generateThumbnail(for: fileURL)
                newImportedMedia.append(ImportedMediaItem(name: fileName, url: fileURL, thumbnail: thumbnail))
            }
            
            DispatchQueue.main.async {
                importedMedia = newImportedMedia
            }
        } catch {
            print("Failed to scan media files: \(error.localizedDescription)")
        }
    }

    /// 处理用户导入的文件（照片/视频）
    private func handleImportedMedia(_ urls: [URL]) async {
        for url in urls {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    print("无法访问文件: \(url)")
                    continue
                }
                
                let localURL = mediaFolder.appendingPathComponent(url.lastPathComponent)
                
                if fileManager.fileExists(atPath: localURL.path) {
                    print("文件已存在，跳过: \(localURL)")
                } else {
                    try fileManager.copyItem(at: url, to: localURL)
                    print("成功拷贝文件至: \(localURL)")
                }

                url.stopAccessingSecurityScopedResource()

                let thumbnail = await generateThumbnail(for: localURL)
                DispatchQueue.main.async {
                    importedMedia.append(ImportedMediaItem(name: localURL.lastPathComponent, url: localURL, thumbnail: thumbnail))
                }
            } catch {
                print("文件导入失败: \(error.localizedDescription)")
            }
        }
    }

    /// 处理从相册导入的照片
    private func handleImportedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            // 检查是否为视频类型
            if let video = try? await item.loadTransferable(type: VideoTransferable.self) {
                // 获取原始文件名
                let originalFilename = video.url.lastPathComponent
                let localURL = mediaFolder.appendingPathComponent(originalFilename)

                do {
                    // 检查文件是否已存在
                    if fileManager.fileExists(atPath: localURL.path) {
                        print("文件已存在，跳过: \(localURL)")
                    } else {
                        // 将视频文件复制到 media 文件夹
                        try FileManager.default.copyItem(at: video.url, to: localURL)
                        print("成功保存视频: \(localURL)")
                    }

                    // 生成缩略图
                    let thumbnail = await generateThumbnail(for: localURL)
                    DispatchQueue.main.async {
                        importedMedia.append(ImportedMediaItem(name: originalFilename, url: localURL, thumbnail: thumbnail))
                    }
                } catch {
                    print("视频保存失败: \(error.localizedDescription)")
                }
            }
        }
    }

    // 定义一个 VideoTransferable 类型来处理视频数据
    struct VideoTransferable: Transferable {
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(contentType: .movie) { video in
                SentTransferredFile(video.url)
            } importing: { received in
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
                try FileManager.default.copyItem(at: received.file, to: tempURL)
                return Self(url: tempURL)
            }
        }
    }

    /// 生成媒体文件的缩略图
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

    /// 显示视频播放器
    private func showVideoPlayer(_ url: URL) {
        print("Attempting to play video at URL: \(url)")
        DispatchQueue.main.async {
            viewModel.selectedVideoURL = url
            guard let videoURL = viewModel.selectedVideoURL else {
                print("selectedVideoURL is nil after setting")
                return
            }
            print("selectedVideoURL is set to: \(videoURL)")
            showVideoPlayerSheet = true
        }
    }
}

/// 文件选择器（导入照片/视频）
struct MediaDocumentPickerView: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie])
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

/// 视频播放器视图
struct VideoPlayerView: UIViewControllerRepresentable {
    var videoURL: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("Creating AVPlayerViewController with URL: \(videoURL)")
        let player = AVPlayer(url: videoURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true
        playerViewController.videoGravity = .resizeAspectFill
        playerViewController.delegate = context.coordinator
        player.play()
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        print("Updating AVPlayerViewController with URL: \(videoURL)")
        if let currentItem = uiViewController.player?.currentItem,
           let currentURL = currentItem.asset as? AVURLAsset,
           currentURL.url != videoURL {
            let player = AVPlayer(url: videoURL)
            uiViewController.player = player
            uiViewController.player?.play()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        func playerViewControllerDidFinishPlaying(_ playerViewController: AVPlayerViewController, willPlayAgain: Bool) {
            // 可以在这里处理视频播放结束后的逻辑
        }
    }
}
