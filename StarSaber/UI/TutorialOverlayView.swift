//
//  TutorialOverlayView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import SwiftUI

struct TutorialOverlayView: View {
    @Bindable var session: GameSessionModel
    var startAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("ライトセイバー訓練開始")
                .font(.largeTitle)
                .fontWeight(.bold)
            VStack(alignment: .leading, spacing: 8) {
                Label("右手を構えてライトセイバーを掴もう", systemImage: "hand.draw")
                Label("敵のテレグラフに合わせてパリィ", systemImage: "shield.righthalf.filled")
                Label("ピンチでフォースプッシュ発動", systemImage: "sparkles")
            }
            .labelStyle(.titleAndIcon)
            .font(.headline)

            Button(action: startAction) {
                Text("ウェーブ開始")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(radius: 24)
    }
}
