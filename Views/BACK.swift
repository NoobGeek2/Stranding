import SwiftUI
import RealityKit

struct BbView: View {
    @Environment(\.openImmersiveSpace) var openBack
    @State private var immersionStyle: ImmersionStyle = .progressive

    var body: some View {
        NavigationView {
            VStack {
                Button("BACK") {
                    enterBackScene()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .navigationTitle("主界面")
        }
    }

    private func enterBackScene() {
        guard let backSceneURL = Bundle.main.url(forResource: "Resources/BACK/BACK", withExtension: "usdc") else {
            print("Failed to locate BACK.usdc file.")
            return
        }

        let immersiveSpace = ImmersiveSpace(id: "BACK") {
            RealityView { content in
                loadBackScene(content: content, sceneURL: backSceneURL)
            }
        }
        immersiveSpace.immersionStyle(selection: $immersionStyle, in: .progressive)

        // Use openImmersiveSpace to transition into the immersive scene
        Task {
            await openBack(id: "BACK")
        }
    }

    @MainActor func loadBackScene(content: RealityViewContent, sceneURL: URL) {
        Task {
            do {
                // Load the 3D model and add it to the scene
                let modelEntity = try await ModelEntity.load(contentsOf: sceneURL)
                let rootEntity = Entity()
                rootEntity.addChild(modelEntity)
                content.add(rootEntity)
            } catch {
                print("Error loading BACK.usdc: \(error)")
            }
        }
    }
}
