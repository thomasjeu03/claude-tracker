//
//  ClaudeTrackerAppApp.swift
//  ClaudeTrackerApp
//
//  Created by Thomas Jeu on 16/03/2026.
//

import SwiftUI

@main
struct ClaudeTrackerApp: App {

    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        // MenuBarExtra creates the status-bar icon + popup window.
        // Requires macOS 13 (Ventura)+
        MenuBarExtra {
            ContentView()
                .environmentObject(vm)
                .frame(width: 380)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "c.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                // Show today's token count right in the menu bar
                if let title = vm.trayTitle {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window) // popup window (not a plain menu)
    }
}
