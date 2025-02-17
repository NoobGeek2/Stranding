
//
//  ImmersiveView.swift
//  Im
//
//  Created by YangyiSun on 1/5/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct JRView: View {

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "CornellBox", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)

                // Put skybox here.  See example in World project available at
                // https://developer.apple.com/
            }
        }
    }
}

#Preview(immersionStyle: .progressive) {
    ImmersiveView()
        .environment(AppModel())
}
