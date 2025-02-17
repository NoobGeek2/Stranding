import SwiftUI
import RealityKit
import QuickLook
import AVKit
import QuickLookThumbnailing
import Combine
import ARKit
import UniformTypeIdentifiers

struct UIPortalView: View {
    /// The environment value to get the `OpenImmersiveSpaceAction` instance.
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    /// The environment value to get the `dismissImmersiveSpace` instance.
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    /// A Boolean value that indicates whether the app shows the immersive space.
    @State var immersive: Bool = false

    /// A Boolean value that indicates whether the video player sheet is presented.
    @State var isAVideoPlayerPresented: Bool = false
    
    @State private var showImportUSDView: Bool = false
    @State private var showDPView: Bool = false
    @State private var BACK: Bool = false

    /// The root entity for other entities within the scene.
    private let root = Entity()

    /// A plane entity representing a portal.
    private let portalPlane = ModelEntity(
        mesh: .generatePlane(width: 1.0, height: 1.0),
        materials: [PortalMaterial()]
    )
    
    var body: some View {
        if !immersive {
                            // 左侧的 TabView
                            TabView {
                                portalView
                                    .tabItem {
                                        Label("Scene", systemImage: "house")
                                    }
                                ImportPhotoView()
                                    .tabItem {
                                        Label("Photo", systemImage: "photo")
                                    }
                                ImportMediaView()
                                    .tabItem {
                                        Label("Media", systemImage: "film")
                                    }
                                ImportUSD()
                                    .tabItem {
                                        Label("Model", systemImage: "cube")
                                    }
                                ImportAudioView()
                                    .tabItem {
                                        Label("Audio", systemImage: "music.note")
                                    }
                                Text(createHyperlinkedText())
                                    .tabItem {
                                        Label("Copyright", systemImage: "info")
                                    }
                            }
                            //.frame(width: 200) // 设置 TabView 的宽度
                            //.background(Color.gray.opacity(0.1)) // 添加背景色

                            // 右侧的 portalView
    
        } else {
            TabView {
                EnterView
                    .tabItem {
                        Label("Scene", systemImage: "house")
                    }
                ImmersiveImportMediaView()
                    .tabItem {
                        Label("Media", systemImage: "film")
                    }
                ImportAudioView()
                    .tabItem {
                        Label("Audio", systemImage: "music.note")
                    }
            }
                    }
    }
    func createHyperlinkedText() -> AttributedString {
            var attributedString = AttributedString("Developed by NoobGeek")
            
            if let range = attributedString.range(of: "NoobGeek") {
                attributedString[range].link = URL(string: "https://space.bilibili.com/480601179?spm_id_from=333.1007.0.0") // 你的链接
                attributedString[range].foregroundColor = .blue  // 让链接变蓝
                attributedString[range].underlineStyle = .single // 添加下划线
            }
            
            return attributedString
        }
    
    var EnterView: some View {
        VStack {
            Button("Exit Dream Core") {
                immersive = false
                Task {
                    await dismissImmersiveSpace()
                }
            }
            .padding()

            // Add a button for video playback using AVPlayerViewController
            /*Button("Play Video (AVPlayerViewController)") {
                isAVideoPlayerPresented = true
            }
            .padding()*/
        }
        .fullScreenCover(isPresented: $isAVideoPlayerPresented) {
            BAVPlayerViewControllerRepresentable(videoURL: Bundle.main.url(forResource: "MH", withExtension: "mov"), isPresented: $isAVideoPlayerPresented)
        }

    }
    var portalView: some View {
        ZStack {
            GeometryReader3D { geometry in
                RealityView { content in
                    await createPortal()
                    content.add(root)
                } update: { content in
                    // Resize the scene based on the size of the reality view content.
                    let size = content.convert(geometry.size, from: .local, to: .scene)
                    updatePortalSize(width: size.x, height: size.y)
                }.frame(depth: 0.4)
            }.frame(depth: 0.4)

            VStack {
                Text("Tap the button to enter the immersive environment.")

                /// A button that opens the immersive space when someone taps it.
                Button("EnterDreamCore") {
                    immersive = true
                    Task {
                        if Bool.random() {
                            await openImmersiveSpace(id: "JRView")
                        } else {
                            await openImmersiveSpace(id: "UIPortal")
                        }
                    }
                }
                .padding()
             /*
                Button("BackRoom") {
                    immersive = true
                    Task {
                        await openImmersiveSpace(id: "A2")
                    }
                }
                .padding()

                // Add a single button for video playback using PreviewApplication
                Button("Play Video (QuickLook)") {
                    playWithPreviewAPI(autoImmersive: false)
                }
                .padding()*/


                Button("Room") {
                    immersive = true
                    Task {
                        await openImmersiveSpace(id: "RoomView")
                    }
                }
                .padding()
                
                Button("CrazyRoom") {
                    immersive = true
                    Task {
                        await openImmersiveSpace(id: "CrazyView")
                    }
                }
                .padding()
              
                
                Button("Classroom") {
                                    immersive = true
                                    Task {
                                        await openImmersiveSpace(id: "ScaningView")
                                    }
                                }
                                .padding()
                                
            }
        }
    }
    struct ModelView: View {
        @State private var models: [URL] = [] // 存储本地文件夹中的模型文件 URL
        @State private var isImporting: Bool = false // 控制文件选择器的显示

        var body: some View {
            VStack {
                // 右上角的 Import 按钮
                HStack {
                    Spacer()
                    Button(action: {
                        isImporting = true
                    }) {
                        Label("Import", systemImage: "plus")
                    }
                    .padding()
                }

                // 网格视图
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(models, id: \.self) { modelURL in
                            VStack {
                                // 3D 模型预览
                                RealityView { content in
                                    do {
                                        let modelEntity = try await Entity.load(contentsOf: modelURL)
                                        content.add(modelEntity)
                                    } catch {
                                        print("Failed to load model: \(error)")
                                    }
                                }
                                .frame(width: 150, height: 150)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)

                                // 文件名
                                Text(modelURL.lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType.usdz],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    // 将文件复制到 App 的本地文件夹
                    copyFilesToLocalDirectory(urls: urls)
                    // 重新加载本地文件夹中的文件
                    loadLocalModels()
                case .failure(let error):
                    print("Failed to import file: \(error)")
                }
            }
            .onAppear {
                // 初始化时加载本地文件夹中的文件
                loadLocalModels()
            }
        }

        // 获取 App 的本地文件夹 URL
        private func getLocalDirectoryURL() -> URL {
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let localDirectoryURL = documentsURL.appendingPathComponent("Models")
            return localDirectoryURL
        }

        // 创建本地文件夹（如果不存在）
        private func createLocalDirectoryIfNeeded() {
            let fileManager = FileManager.default
            let localDirectoryURL = getLocalDirectoryURL()

            if !fileManager.fileExists(atPath: localDirectoryURL.path) {
                do {
                    try fileManager.createDirectory(at: localDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create local directory: \(error)")
                }
            }
        }

        // 将文件复制到本地文件夹
        private func copyFilesToLocalDirectory(urls: [URL]) {
            let fileManager = FileManager.default
            let localDirectoryURL = getLocalDirectoryURL()

            for url in urls {
                let destinationURL = localDirectoryURL.appendingPathComponent(url.lastPathComponent)
                do {
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: url, to: destinationURL)
                } catch {
                    print("Failed to copy file: \(error)")
                }
            }
        }

        // 加载本地文件夹中的 .usdz 文件
        private func loadLocalModels() {
            let fileManager = FileManager.default
            let localDirectoryURL = getLocalDirectoryURL()

            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: localDirectoryURL, includingPropertiesForKeys: nil)
                let usdzFiles = fileURLs.filter { $0.pathExtension == "usdz" }
                models = usdzFiles
            } catch {
                print("Failed to load local models: \(error)")
            }
        }
    }

    // MARK: - Reality

    @MainActor func createPortal() async {
        let world = Entity()
        world.scale *= 0.5
        world.position.y -= 0.5
        world.position.z -= 0.5
        world.components.set(WorldComponent())

        do {
            try await createEnvironment(on: world)
            root.addChild(world)
            portalPlane.components.set(PortalComponent(target: world))
            root.addChild(portalPlane)
        } catch {
            fatalError("Failed to create environment: \(error)")
        }
    }

    func updatePortalSize(width: Float, height: Float) {
        portalPlane.model?.mesh = .generatePlane(width: width, height: height, cornerRadius: 0.03)
    }

    func playWithPreviewAPI(autoImmersive: Bool) {
        if let videoURL = Bundle.main.url(forResource: "MH", withExtension: "mov") {
            Task {
                if autoImmersive {
                    immersive = true
                    await openImmersiveSpace(id: "UIPortal")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    PreviewApplication.open(urls: [videoURL])
                }
            }
        } else {
            print("Failed to locate video file.")
        }
    }
}

/// A SwiftUI view that represents an AVPlayerViewController
struct BAVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let videoURL: URL?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        if let url = videoURL {
            let player = AVPlayer(url: url)
            playerViewController.player = player
            playerViewController.showsPlaybackControls = true
            playerViewController.delegate = context.coordinator
            player.play()  // Start playing the video immediately
        }
        return playerViewController
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {}
        
        func playerViewController(_ playerViewController: AVPlayerViewController, didExitFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            isPresented = false
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, playerDidFinishPlaying note: Notification) {
            isPresented = false
        }

        func playerViewController(_ playerViewController: AVPlayerViewController, playerWillPlayToEndTime notification: Notification) {
            isPresented = false
        }

        func observePlayerItemEnd(player: AVPlayer) {
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        }

        @objc func playerItemDidReachEnd(_ notification: Notification) {
            if let player = notification.object as? AVPlayer, let item = player.currentItem {
                item.seek(to: .zero)
                isPresented = false
            }
        }
    }
}
