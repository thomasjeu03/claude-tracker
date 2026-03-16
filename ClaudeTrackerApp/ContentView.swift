//
//  ContentView.swift
//  ClaudeTrackerApp
//
//  Created by Thomas Jeu on 16/03/2026.
//

import SwiftUI
import Charts

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
            Color.clear.frame(height: 10)

            VStack(spacing: 22) {

                // ── Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [.claudeOrange, .claudeOrangeDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: .claudeOrange.opacity(0.35), radius: 12, y: 5)

                    Image(systemName: "c.circle.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }

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
                            }
                        } else {
                            Text("Connect")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
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
            TabPicker()

            Group {
                if vm.isLoading && vm.dashboardData == nil {
                    loadingView
                } else if let err = vm.errorMessage, vm.dashboardData == nil {
                    errorView(err)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        dashboardContent
                            .padding(12)
                    }
                }
            }

            DashboardFooter()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var dashboardContent: some View {
        let pd = vm.dashboardData?.periods[vm.selectedPeriod]

        VStack(spacing: 10) {
            // Token totals
            if let t = pd?.totals {
                StatsRow(totals: t)
                CacheRow(totals: t)
            }

            // Bar chart (not shown for "Today")
            if vm.selectedPeriod != .today,
               let daily = vm.dashboardData?.dailyData {
                BarChartSection(data: daily, period: vm.selectedPeriod)
            }

            // Model table
            if let models = pd?.models, !models.isEmpty {
                ModelTable(models: Array(models.prefix(6)))
            }

            // Empty state
            if pd?.totals.total == 0 {
                emptyState
            }
        }
    }

    // MARK: States

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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No usage for this period")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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
// MARK: – TAB PICKER
// ─────────────────────────────────────────────────────────────────────────────

struct TabPicker: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Period.allCases) { period in
                Button(period.rawValue) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.selectedPeriod = period
                    }
                }
                .buttonStyle(PillButtonStyle(active: vm.selectedPeriod == period))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

struct PillButtonStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(active ? Color.claudeOrange : Color.clear)
            )
            .foregroundColor(active ? .white : .secondary)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – STAT CARDS
// ─────────────────────────────────────────────────────────────────────────────

struct StatsRow: View {
    let totals: TokenTotals
    var body: some View {
        HStack(spacing: 7) {
            StatCard(label: "Total",  value: TokenFormatter.format(totals.total),  accent: true)
            StatCard(label: "Input",  value: TokenFormatter.format(totals.input))
            StatCard(label: "Output", value: TokenFormatter.format(totals.output))
        }
    }
}

struct CacheRow: View {
    let totals: TokenTotals
    var body: some View {
        HStack(spacing: 7) {
            CacheCard(label: "Cache Read",  value: TokenFormatter.format(totals.cacheRead),   sub: "tokens saved")
            CacheCard(label: "Cache Write", value: TokenFormatter.format(totals.cacheCreate), sub: "tokens written")
        }
    }
}

struct StatCard: View {
    let label:  String
    let value:  String
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(accent ? .claudeOrange : .primary)

            Text("tokens")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

struct CacheCard: View {
    let label: String
    let value: String
    let sub:   String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.indigo)
                .textCase(.uppercase)
                .tracking(0.4)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.indigo)

            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.indigo.opacity(0.07))
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – BAR CHART
// ─────────────────────────────────────────────────────────────────────────────

struct BarChartSection: View {
    let data:   [DayData]
    let period: Period

    private var chartDays: [DayData] {
        let count = period == .thirtyDays ? 30 : 7
        return Array(data.suffix(count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Daily Tokens")

            Chart(chartDays) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Tokens", day.total)
                )
                .foregroundStyle(
                    day.isToday
                        ? Color.claudeOrange
                        : Color.claudeOrange.opacity(0.28)
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                let stride = period == .sevenDays ? 1 : 5
                AxisMarks(values: .stride(by: .day, count: stride)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(
                                period == .sevenDays
                                    ? date.formatted(.dateTime.weekday(.narrow))
                                    : "\(Calendar.current.component(.day, from: date))"
                            )
                            .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis(.automatic)
            .frame(height: 64)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – MODEL TABLE
// ─────────────────────────────────────────────────────────────────────────────

struct ModelTable: View {
    let models: [ModelUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("By Model")

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("MODEL")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("INPUT")
                        .frame(width: 55, alignment: .trailing)
                    Text("OUTPUT")
                        .frame(width: 55, alignment: .trailing)
                }
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.4)
                .padding(.bottom, 5)

                // Data rows
                ForEach(models) { m in
                    Divider()
                    HStack {
                        HStack(spacing: 6) {
                            Text(m.displayName)
                                .font(.system(size: 11.5, weight: .semibold))

                            Text(m.tier.label)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(tierColor(m.tier))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    Capsule()
                                        .fill(tierColor(m.tier).opacity(0.12))
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(TokenFormatter.format(m.input))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)

                        Text(TokenFormatter.format(m.output))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private func tierColor(_ tier: ModelTier) -> Color {
        switch tier.color {
        case .orange: return .tierOpus
        case .indigo: return .tierSonnet
        case .green:  return .tierHaiku
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – FOOTER
// ─────────────────────────────────────────────────────────────────────────────

struct DashboardFooter: View {
    @EnvironmentObject var vm: AppViewModel

    private var costCents: Int {
        vm.dashboardData?.periods[vm.selectedPeriod]?.costCents ?? 0
    }

    private var periodLabel: String {
        switch vm.selectedPeriod {
        case .today:      return "today"
        case .sevenDays:  return "7-day"
        case .thirtyDays: return "30-day"
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(CostFormatter.format(cents: costCents))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))

                Text("\(periodLabel) cost")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(Divider(), alignment: .top)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – REUSABLE COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

