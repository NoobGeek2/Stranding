import SwiftUI
import UniformTypeIdentifiers
import RealityKit
import QuickLook

struct ModelInfo: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    var modelEntity: ModelEntity?
}

struct DPView: View {
    @Environment(\.dismiss) var dismiss
    @State private var models: [ModelInfo] = []
    @State private var showFilePicker = false
    @State private var selectedModel: ModelInfo?
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 24)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(models.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }) { model in
                        ModelCard(model: model)
                            .onTapGesture {
                                selectedModel = model
                            }
                    }
                }
                .padding(24)
            }
            .navigationTitle("YourDream")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        showFilePicker = true
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search models")
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker { urls in
                Task {
                    await importModels(from: urls)
                }
            }
        }
        .sheet(item: $selectedModel) { model in
            QLPreviewControllerRepresentable(fileURL: model.url)  // ✅ 确保正确的 URL 传递
        }
        .onAppear {
            Task {
                await loadLocalModels()  // ✅ 确保进入视图时加载所有 .usdz 文件
            }
        }
    }
    // 处理导入 .usdz 文件
    private func importModels(from urls: [URL]) async {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        for url in urls {
            do {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                // 确保目标文件不存在，避免覆盖错误
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // 重新加载本地 .usdz 文件
                await loadLocalModels()
                
                print("✅ 成功导入模型: \(destinationURL.lastPathComponent)")
            } catch {
                print("❌ 导入模型失败: \(error)")
            }
        }
    }
    // ✅ 确保 QuickLook 预览时文件路径正确
    private func loadLocalModels() async {
        models.removeAll()
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURLs = (try? FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil))
            ?? []
        
        for url in fileURLs where url.pathExtension == "usdz" {
            do {
                let modelEntity = try await ModelEntity(contentsOf: url)  // ✅ 解决 Swift 6 问题
                let model = ModelInfo(url: url, name: url.deletingPathExtension().lastPathComponent, modelEntity: modelEntity)
                models.append(model)
            } catch {
                print("❌ 加载模型失败: \(error)")
            }
        }
    }
}

struct ModelCard: View {
    let model: ModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ModelPreview(model: model)
                .frame(height: 200)
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("3D Model")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct ModelPreview: View {
    let model: ModelInfo

    var body: some View {
        ZStack {
            if let entity = model.modelEntity {
                RealityView { content in
                    let clonedEntity = entity.clone(recursive: true)
                    clonedEntity.position = SIMD3<Float>(0, 0, -1.5)
                    content.add(clonedEntity)
                }
            } else {
                Color.gray.opacity(0.1)
            }
        }
    }
}



struct QLPreviewControllerRepresentable: UIViewControllerRepresentable {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss  // 允许关闭当前视图

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator

        // 添加一个"返回"按钮
        let closeButton = UIBarButtonItem(title: "Back", style: .plain, target: context.coordinator, action: #selector(context.coordinator.dismissPreview))
        controller.navigationItem.leftBarButtonItem = closeButton

        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, fileURL: fileURL)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        var dismiss: DismissAction  // 用于返回主界面

        init(dismiss: DismissAction, fileURL: URL) {
            self.dismiss = dismiss
            self.fileURL = fileURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }

        @objc func dismissPreview() {
            dismiss()
        }
    }
}
