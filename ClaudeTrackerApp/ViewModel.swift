import SwiftUI
import Combine

// ─── Period ───────────────────────────────────────────────────────────────────

enum Period: String, CaseIterable, Identifiable, Hashable {
    case today     = "Today"
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"

    var id: String { rawValue }

    func dateRange() -> (start: Date, end: Date) {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let tomorrow   = cal.date(byAdding: .day, value: 1, to: todayStart)!
        switch self {
        case .today:
            return (todayStart, tomorrow)
        case .sevenDays:
            return (cal.date(byAdding: .day, value: -6, to: todayStart)!, tomorrow)
        case .thirtyDays:
            return (cal.date(byAdding: .day, value: -29, to: todayStart)!, tomorrow)
        }
    }
}

// ─── View Model ───────────────────────────────────────────────────────────────

@MainActor
final class AppViewModel: ObservableObject {

    // Published UI state
    @Published var isLoggedIn     = false
    @Published var isLoading      = false
    @Published var errorMessage: String?  = nil
    @Published var dashboardData: DashboardData? = nil
    @Published var selectedPeriod: Period = .today
    @Published var trayTitle: String?     = nil

    // API key persisted via UserDefaults (@AppStorage equivalent for classes)
    // NOTE: For production, migrate this to the macOS Keychain.
    @AppStorage("adminApiKey") var storedKey: String = ""

    private var refreshTimer: Timer?
    private var lastFetch: Date? = nil

    init() {
        if !storedKey.isEmpty {
            isLoggedIn = true
            Task { await fetchAll() }
            startAutoRefresh()
        }
    }

    // MARK: – Connect

    func connect(key: String) async {
        guard !key.isEmpty else { return }
        isLoading     = true
        errorMessage  = nil

        do {
            // Validate key against the real API before saving
            let range = Period.today.dateRange()
            _ = try await APIService.shared.fetchUsage(
                apiKey: key, from: range.start, to: range.end
            )
            storedKey  = key
            isLoggedIn = true
            await fetchAll()
            startAutoRefresh()
        } catch let e as APIError {
            errorMessage = e.userMessage
        } catch {
            errorMessage = "Network error — check your connection."
        }

        isLoading = false
    }

    // MARK: – Disconnect

    func disconnect() {
        storedKey     = ""
        isLoggedIn    = false
        dashboardData = nil
        trayTitle     = nil
        errorMessage  = nil
        refreshTimer?.invalidate()
        refreshTimer  = nil
    }

    // MARK: – Refresh

    func refresh() async {
        guard !storedKey.isEmpty else { return }
        // Debounce: skip if we refreshed less than 30 seconds ago
        if let last = lastFetch, Date().timeIntervalSince(last) < 30 { return }
        await fetchAll()
    }

    // MARK: – Private

    private func fetchAll() async {
        isLoading    = true
        errorMessage = nil

        do {
            dashboardData = try await APIService.shared.fetchAll(apiKey: storedKey)
            lastFetch     = Date()
            updateTrayTitle()
        } catch let e as APIError {
            errorMessage = e.userMessage
        } catch {
            errorMessage = "Network error — check your connection."
        }

        isLoading = false
    }

    private func updateTrayTitle() {
        let today = dashboardData?.periods[.today]?.totals.total ?? 0
        trayTitle = today > 0 ? TokenFormatter.format(today) : nil
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        // Refresh every 2 minutes in the background
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }
}
