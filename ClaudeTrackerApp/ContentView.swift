//
//  ContentView.swift
//  ClaudeTrackerApp
//
//  Created by Thomas Jeu on 16/03/2026.
//

import SwiftUI

// ─── Root dispatcher ─────────────────────────────────────────────────────────

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack {
            if vm.isLoggedIn {
                DashboardView()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isLoggedIn)
    }
}

// ─── Brand color ─────────────────────────────────────────────────────────────

extension Color {
    static let claudeOrange = Color(red: 0.851, green: 0.467, blue: 0.341) // #D97757
    static let claudeOrangeDark = Color(red: 0.784, green: 0.400, blue: 0.290) // #C8664A

    // Tier colors
    static let tierOpus   = Color.orange
    static let tierSonnet = Color.indigo
    static let tierHaiku  = Color.green
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – LOGIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

struct LoginView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var keyInput  = ""
    @State private var showKey   = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // drag region at top
            Color.clear.frame(height: 20)

            VStack(spacing: 22) {

                // ── Logo
                Image("claude-color")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .claudeOrange.opacity(0.35), radius: 12, y: 5)

                // ── Title
                VStack(spacing: 5) {
                    Text("Claude Token Tracker")
                        .font(.system(size: 18, weight: .bold))

                    Text("Monitor your org's API usage\nfrom your menu bar.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // ── Key input
                VStack(alignment: .leading, spacing: 7) {
                    Text("Admin API Key")
                        .font(.system(size: 11, weight: .semibold))

                    HStack(spacing: 6) {
                        Group {
                            if showKey {
                                TextField("sk-ant-admin01-…", text: $keyInput)
                                    .focused($fieldFocused)
                            } else {
                                SecureField("sk-ant-admin01-…", text: $keyInput)
                                    .focused($fieldFocused)
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await vm.connect(key: keyInput) } }

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showKey ? "Hide key" : "Show key")
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                fieldFocused ? Color.claudeOrange : Color(nsColor: .separatorColor),
                                lineWidth: fieldFocused ? 1.5 : 1
                            )
                    )

                    // Error
                    if let err = vm.errorMessage {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text(err)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                // ── Connect button
                Button {
                    Task { await vm.connect(key: keyInput) }
                } label: {
                    Group {
                        if vm.isLoading {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.75)
                                Text("Verifying…")
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("Connect")
                                .fontWeight(.semibold)
                                .foregroundColor(vm.isLoading || keyInput.isEmpty ? .gray : .white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
                .cornerRadius(.infinity)
                .tint(.claudeOrange)
                .disabled(vm.isLoading || keyInput.isEmpty)
                .padding(.horizontal, 32)

                // ── Help
                VStack(spacing: 4) {
                    Text("Requires an **Admin API key** (org admin role).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Button("Get it from Claude Console →") {
                        NSWorkspace.shared.open(
                            URL(string: "https://console.anthropic.com/settings/admin-keys")!
                        )
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.claudeOrange)
                }
            }
            .padding(.bottom, 28)
        }
        .onAppear { fieldFocused = true }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – DASHBOARD VIEW
// ─────────────────────────────────────────────────────────────────────────────

struct DashboardView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            DashboardHeader()

            Group {
                if vm.isLoading && vm.dashboardData == nil {
                    loadingView
                } else if let err = vm.errorMessage, vm.dashboardData == nil {
                    errorView(err)
                } else {
                    usageContent
                }
            }

            DashboardFooter()
        }
    }

    // MARK: – Usage content

    private var usageContent: some View {
        VStack(spacing: 10) {
            // Today — large card
            let todayTotal = vm.dashboardData?.periods[.today]?.totals.total ?? 0
            let todayIn    = vm.dashboardData?.periods[.today]?.totals.input ?? 0
            let todayOut   = vm.dashboardData?.periods[.today]?.totals.output ?? 0

            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Text(TokenFormatter.format(todayTotal))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.claudeOrange)

                HStack(spacing: 12) {
                    Label(TokenFormatter.format(todayIn),  systemImage: "arrow.down")
                    Label(TokenFormatter.format(todayOut), systemImage: "arrow.up")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.claudeOrange.opacity(0.08)))

            // 7-day and 30-day mini cards
            HStack(spacing: 8) {
                PeriodMiniCard(
                    label: "7 Days",
                    tokens: vm.dashboardData?.periods[.sevenDays]?.totals.total ?? 0,
                    cost:   vm.dashboardData?.periods[.sevenDays]?.costCents ?? 0
                )
                PeriodMiniCard(
                    label: "30 Days",
                    tokens: vm.dashboardData?.periods[.thirtyDays]?.totals.total ?? 0,
                    cost:   vm.dashboardData?.periods[.thirtyDays]?.costCents ?? 0
                )
            }
        }
        .padding(12)
    }

    // MARK: – States

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Loading usage data…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            Text("Could not load data")
                .font(.system(size: 14, weight: .semibold))
            Text(msg)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button("Try Again") { Task { await vm.refresh() } }
                .buttonStyle(.borderedProminent)
                .tint(.claudeOrange)
                .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – HEADER
// ─────────────────────────────────────────────────────────────────────────────

struct DashboardHeader: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.claudeOrange)
                .frame(width: 7, height: 7)

            Text("Claude Usage")
                .font(.system(size: 14, weight: .bold))

            Spacer()

            if vm.isLoading {
                ProgressView().scaleEffect(0.65)
            }

            // Refresh
            Button {
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Refresh data")

            // Disconnect
            Button {
                vm.disconnect()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Disconnect")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(Divider(), alignment: .bottom)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – PERIOD MINI CARD
// ─────────────────────────────────────────────────────────────────────────────

struct PeriodMiniCard: View {
    let label:  String
    let tokens: Int
    let cost:   Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)

            Text(TokenFormatter.format(tokens))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(CostFormatter.format(cents: cost))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – FOOTER
// ─────────────────────────────────────────────────────────────────────────────

struct DashboardFooter: View {
    @EnvironmentObject var vm: AppViewModel

    private var todayCost: Int {
        vm.dashboardData?.periods[.today]?.costCents ?? 0
    }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(CostFormatter.format(cents: todayCost))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))

                Text("today's cost")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Text("Quit")
                        .font(.system(size: 11))
                    Text("⌘Q")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Quit app (⌘Q)")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(Divider(), alignment: .top)
    }
}


