//
//  DebugLogPanelView.swift
//  StarSaber
//
//  Created by tamakou on 2025/10/18.
//

import SwiftUI

struct DebugLogPanelView: View {
    @Bindable var session: GameSessionModel

    private var events: [GameSessionModel.CombatLogEntry] {
        Array(session.combatLog.suffix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEBUG LOG")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            ForEach(events, id: \.self) { entry in
                Text(description(for: entry))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func description(for entry: GameSessionModel.CombatLogEntry) -> String {
        switch entry {
            case .waveStarted(let index):
                return "Wave \(index) started"
            case .enemySpawned(let id):
                return "Enemy spawned \(id.uuidString.prefix(4))"
            case .enemyDefeated(let id):
                return "Enemy down \(id.uuidString.prefix(4))"
            case .playerTookDamage(let amount):
                return "Player hit -\(Int(amount))"
            case .playerDefeated:
                return "Player defeated"
            case .forcePushTriggered:
                return "Force push"
            case .parrySuccess(let id):
                return "Parry success \(id.uuidString.prefix(4))"
            case .waveCleared(let index):
                return "Wave \(index) cleared"
        }
    }
}
