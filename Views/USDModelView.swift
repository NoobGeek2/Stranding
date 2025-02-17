//
//  USDModelView.swift
//  RealityKit-UIPortal
//
//  Created by YangyiSun on 12/5/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI
import RealityKit

struct USDModelView: View {
    var body: some View {
        RealityView { content in
            do {
                // Load the USD file
                if let modelURL = Bundle.main.url(forResource: "BR", withExtension: "usda") {
                    let modelEntity = try await ModelEntity.load(contentsOf: modelURL)
                    
                    // 添加实体到内容
                    content.add(modelEntity)
                } else {
                    print("Failed to locate BR.usda file.")
                }
            } catch {
                print("Error loading model: \(error)")
            }
        }
    }
}
