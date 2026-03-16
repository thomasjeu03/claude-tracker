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
                    .scaledToFit()
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
        let maxTokens = (vm.dashboardData?.periods[.thirtyDays]?.totals.input  ?? 0)
                      + (vm.dashboardData?.periods[.thirtyDays]?.totals.output ?? 0)

        return VStack(spacing: 8) {
            PeriodRow(
                label:    "Today",
                input:    vm.dashboardData?.periods[.today]?.totals.input  ?? 0,
                output:   vm.dashboardData?.periods[.today]?.totals.output ?? 0,
                maxTokens: maxTokens,
                cost:     vm.dashboardData?.periods[.today]?.costCents ?? 0,
                accent:   true
            )
            PeriodRow(
                label:    "7 Days",
                input:    vm.dashboardData?.periods[.sevenDays]?.totals.input  ?? 0,
                output:   vm.dashboardData?.periods[.sevenDays]?.totals.output ?? 0,
                maxTokens: maxTokens,
                cost:     vm.dashboardData?.periods[.sevenDays]?.costCents ?? 0
            )
            PeriodRow(
                label:    "30 Days",
                input:    vm.dashboardData?.periods[.thirtyDays]?.totals.input  ?? 0,
                output:   vm.dashboardData?.periods[.thirtyDays]?.totals.output ?? 0,
                maxTokens: maxTokens,
                cost:     vm.dashboardData?.periods[.thirtyDays]?.costCents ?? 0
            )
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
// MARK: – PERIOD ROW WITH PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

struct PeriodRow: View {
    let label:     String
    let input:     Int
    let output:    Int
    let maxTokens: Int
    let cost:      Int
    var accent:    Bool = false

    private var total: Int { input + output }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Label + total + cost
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                Text(TokenFormatter.format(total))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(accent ? .claudeOrange : .primary)
                if cost > 0 {
                    Text(CostFormatter.format(cents: cost))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            TokenProgressBar(input: input, output: output, maxTokens: maxTokens)

            // Legend
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.claudeOrange)
                        .frame(width: 8, height: 8)
                    Text("\(TokenFormatter.format(input)) in")
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.indigo.opacity(0.7))
                        .frame(width: 8, height: 8)
                    Text("\(TokenFormatter.format(output)) out")
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accent ? Color.claudeOrange.opacity(0.07) : Color.primary.opacity(0.04))
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – TOKEN PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

struct TokenProgressBar: View {
    let input:     Int
    let output:    Int
    let maxTokens: Int

    private var total: Int { input + output }
    private var fillFraction: Double {
        guard maxTokens > 0 else { return 0 }
        return min(Double(total) / Double(maxTokens), 1.0)
    }
    private var inputFraction: Double {
        guard total > 0 else { return 0.5 }
        return Double(input) / Double(total)
    }

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width * fillFraction
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
                // Fill (input | output)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.claudeOrange)
                        .frame(width: barWidth * inputFraction)
                    Rectangle()
                        .fill(Color.indigo.opacity(0.7))
                        .frame(width: barWidth * (1 - inputFraction))
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(height: 7)
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


