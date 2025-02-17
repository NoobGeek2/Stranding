/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's immersive view.
*/

import SwiftUI
import RealityKit
import ARKit

/// An immersive view that contains the box environment.
struct AImmersiveView: View {
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @State private var showExitAlert = false
    
    var body: some View {
        RealityView { content in
            // Create the box environment on the root entity.
            let root = Entity()
            do {
                try await createEnvironment(on: root)
            } catch {
                print("Failed to load environment: \(error.localizedDescription)")
            }

            content.add(root)
        }
        .gesture(
            // 双击手势
            
            TapGesture(count: 2)
                .onEnded { _ in
                    showExitAlert = true
                }
        )
        .alert("退出环境", isPresented: $showExitAlert) {
            Button("确定") {
                Task {
                    await dismissImmersiveSpace()
                }
            }
            Button("取消", role: .cancel) {
                showExitAlert = false
            }
        } message: {
            Text("确定要退出当前环境吗？")
        }
    }
}

/// Creates the box environment and applies image-based lighting.
@MainActor func createEnvironment(on root: Entity) async throws {
    do {
        /// The root entity for the box environment.
        let assetRoot = try await Entity(named: "CornellBox.usda")

        // Convert the image-based lighting file into a URL, and load it as an environment resource.
        guard let iblURL = Bundle.main.url(forResource: "TeapotIBL", withExtension: "exr") else {
            fatalError("Failed to load the Image-Based Lighting file.")
        }
        let iblEnv = try await EnvironmentResource(fromImage: iblURL)

        /// The entity to perform image-based lighting on the environment.
        let iblEntity = Entity()

        /// The image-based lighting component that contains background and lighting information.
        var iblComp = ImageBasedLightComponent(source: .single(iblEnv))
        iblComp.inheritsRotation = true

        // Add the image-based lighting component to the entity.
        iblEntity.components.set(iblComp)

        // Set up image-based lighting for the box environment.
        assetRoot.components.set(ImageBasedLightReceiverComponent(imageBasedLight: iblEntity))

        // Add the image-based lighting entity to the box environment.
        assetRoot.addChild(iblEntity)

        // Add the box environment to `root`.
        root.addChild(assetRoot)
    } catch {
        assertionFailure("\(error)")
    }
}
