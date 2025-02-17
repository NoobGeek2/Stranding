/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's main entry point.
*/

import SwiftUI
import ARKit


@main
struct EntryPoint: App {
    @State var session = ARKitSession()
    @State private var immersionStyle: ImmersionStyle = .progressive
    var body: some Scene {
        WindowGroup {
            UIPortalView()
        }
        

        // Defines an immersive space as a part of the scene.
        ImmersiveSpace(id: "UIPortal") {
            AImmersiveView()
                .task {
                    let handPoseProvider = HandTrackingProvider()

                    if HandTrackingProvider.isSupported {
                        do {
                            // 启动手部姿态检测
                            try await session.run([handPoseProvider])
                            
                            // 持续监听手部姿态更新
                            for await handPose in handPoseProvider.anchorUpdates {
                                // 更新应用状态，处理手部姿态数据
                                print("Detected hand pose: \(handPose)")
                            }
                        } catch {
                            // 错误处理
                            print("Error in hand pose session: \(error)")
                        }
                    } else {
                        print("HandPoseProvider is not supported on this device.")
                    }
                }
              
                 
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        
        ImmersiveSpace(id: "A2") {
            USDModelView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        ImmersiveSpace(id: "BACK") {
            BbView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        ImmersiveSpace(id: "ScaningView") {
            ImmersiveView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        ImmersiveSpace(id: "RoomView") {
            RoomView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        ImmersiveSpace(id: "AudioView") {
            ImportAudioView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        ImmersiveSpace(id: "CrazyView") {
            CrazyView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
        ImmersiveSpace(id: "JRView") {
            JRView()
        }.immersionStyle(selection: $immersionStyle, in: .progressive)
    }
}
