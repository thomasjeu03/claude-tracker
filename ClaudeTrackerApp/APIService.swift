import Foundation

// ─── Error types ──────────────────────────────────────────────────────────────

enum APIError: Error {
    case unauthorized
    case forbidden
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Invalid API key — it must start with sk-ant-admin…"
        case .forbidden:
            return "Forbidden — make sure your key has the admin role."
        case .httpError(let code, let msg):
            return "API error \(code)\(msg.isEmpty ? "" : ": \(msg)")"
        case .decodingError:
            return "Failed to parse the API response."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        }
    }
}

// ─── Codable response wrappers ────────────────────────────────────────────────

struct UsageResponse: Decodable {
    let data: [UsageEntry]
}

struct UsageEntry: Decodable {
    let start_time:                    String?
    let end_time:                      String?
    let input_tokens:                  Int?
    let output_tokens:                 Int?
    let cache_read_input_tokens:       Int?
    let cache_creation_input_tokens:   Int?
    let model:                         String?
}

struct CostResponse: Decodable {
    let data: [CostEntry]
}

struct CostEntry: Decodable {
    let start_time: String?
    let end_time:   String?
    let costCents:  Int

    enum CodingKeys: String, CodingKey { case start_time, end_time, cost }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start_time = try c.decodeIfPresent(String.self, forKey: .start_time)
        end_time   = try c.decodeIfPresent(String.self, forKey: .end_time)
        // API may return cost as a decimal-cent String ("1250") or as a Double
        if let s = try? c.decodeIfPresent(String.self, forKey: .cost) {
            costCents = Int(s ?? "0") ?? 0
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .cost) {
            costCents = Int(d)
        } else {
            costCents = 0
        }
    }
}

private struct AnthropicError: Decodable {
    struct Detail: Decodable { let message: String? }
    let error: Detail?
}

// ─── Domain models ────────────────────────────────────────────────────────────

struct TokenTotals {
    var input:       Int = 0
    var output:      Int = 0
    var cacheRead:   Int = 0
    var cacheCreate: Int = 0
    var total: Int { input + output }
}

enum ModelTier {
    case opus, sonnet, haiku

    var label: String {
        switch self { case .opus: return "opus"; case .sonnet: return "sonnet"; case .haiku: return "haiku" }
    }
    var color: BrandColor {
        switch self { case .opus: return .orange; case .sonnet: return .indigo; case .haiku: return .green }
    }
    enum BrandColor { case orange, indigo, green }
}

struct ModelUsage: Identifiable {
    let id       = UUID()
    let modelId:   String
    var input:     Int = 0
    var output:    Int = 0
    var total: Int { input + output }

    var displayName: String {
        let map: [String: String] = [
            "claude-opus-4-6":            "Opus 4.6",
            "claude-sonnet-4-6":          "Sonnet 4.6",
            "claude-haiku-4-5-20251001":  "Haiku 4.5",
            "claude-3-5-sonnet-20241022": "Sonnet 3.5",
            "claude-3-5-haiku-20241022":  "Haiku 3.5",
            "claude-3-opus-20240229":     "Opus 3",
            "claude-3-sonnet-20240229":   "Sonnet 3",
            "claude-3-haiku-20240307":    "Haiku 3",
        ]
        return map[modelId] ?? modelId
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-2024\\d{4}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "-2025\\d{4}", with: "", options: .regularExpression)
    }

    var tier: ModelTier {
        if modelId.contains("opus")  { return .opus }
        if modelId.contains("haiku") { return .haiku }
        return .sonnet
    }
}

struct DayData: Identifiable {
    let id    = UUID()
    let date:   Date
    var total:  Int = 0
    var isToday: Bool { Calendar.current.isDateInToday(date) }
}

struct PeriodData {
    var totals:    TokenTotals    = TokenTotals()
    var models:    [ModelUsage]   = []
    var costCents: Int            = 0
}

struct DashboardData {
    var periods:   [Period: PeriodData] = [:]
    var dailyData: [DayData]            = []  // last 30 days, oldest first
}

// ─── Formatting helpers ───────────────────────────────────────────────────────

enum TokenFormatter {
    static func format(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...:     return "\(n / 1_000)K"
        default:           return "\(n)"
        }
    }
}

enum CostFormatter {
    static func format(cents: Int) -> String {
        let d = Double(cents) / 100.0
        if d == 0   { return "$0.00" }
        if d < 0.01 { return "<$0.01" }
        if d < 1    { return String(format: "$%.3f", d) }
        return String(format: "$%.2f", d)
    }
}

// ─── API Service ──────────────────────────────────────────────────────────────

final class APIService {

    static let shared = APIService()
    private init() {}

    private let base    = URL(string: "https://api.anthropic.com")!
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: – Public

    /// Fetch daily usage, optionally grouped by model
    func fetchUsage(
        apiKey: String,
        from: Date,
        to: Date,
        groupBy: [String] = []
    ) async throws -> UsageResponse {
        var items: [URLQueryItem] = [
            .init(name: "starting_at",  value: iso(from)),
            .init(name: "ending_at",    value: iso(to)),
            .init(name: "bucket_width", value: "1d"),
        ]
        groupBy.forEach { items.append(.init(name: "group_by[]", value: $0)) }
        return try await get(
            path: "v1/organizations/usage_report/messages",
            queryItems: items,
            apiKey: apiKey
        )
    }

    /// Fetch cost report grouped by description
    func fetchCosts(apiKey: String, from: Date, to: Date) async throws -> CostResponse {
        let items: [URLQueryItem] = [
            .init(name: "starting_at",  value: iso(from)),
            .init(name: "ending_at",    value: iso(to)),
            .init(name: "group_by[]",   value: "description"),
        ]
        return try await get(
            path: "v1/organizations/cost_report",
            queryItems: items,
            apiKey: apiKey
        )
    }

    /// Fetch everything the dashboard needs in 3 parallel requests
    func fetchAll(apiKey: String) async throws -> DashboardData {
        let cal       = Calendar.current
        let today     = cal.startOfDay(for: Date())
        let tomorrow  = cal.date(byAdding: .day, value:  1, to: today)!
        let thirtyAgo = cal.date(byAdding: .day, value: -29, to: today)!

        async let rawUsage  = fetchUsage(apiKey: apiKey, from: thirtyAgo, to: tomorrow)
        async let rawModels = fetchUsage(apiKey: apiKey, from: thirtyAgo, to: tomorrow, groupBy: ["model"])
        async let rawCosts  = fetchCosts(apiKey: apiKey, from: thirtyAgo, to: tomorrow)

        let (u, m, c) = try await (rawUsage, rawModels, rawCosts)
        return buildDashboard(usage: u, byModel: m, costs: c)
    }

    // MARK: – Generic GET

    private func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        apiKey: String
    ) async throws -> T {
        var components     = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems

        var req = URLRequest(url: components.url!, timeoutInterval: 15)
        req.setValue(apiKey,           forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",     forHTTPHeaderField: "anthropic-version")
        req.setValue("ClaudeTokenTracker/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            do    { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decodingError(error) }
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            let msg = (try? decoder.decode(AnthropicError.self, from: data))?.error?.message ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }
    }

    // MARK: – Data assembly

    private func buildDashboard(
        usage:   UsageResponse,
        byModel: UsageResponse,
        costs:   CostResponse
    ) -> DashboardData {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Build 30-day array (oldest first)
        var daily: [DayData] = (0..<30).reversed().map { offset in
            DayData(date: cal.date(byAdding: .day, value: -offset, to: today)!)
        }

        // Populate daily totals
        for entry in usage.data {
            guard let s = entry.start_time, let d = parseDate(s) else { continue }
            let entryDay = cal.startOfDay(for: d)
            if let idx = daily.firstIndex(where: { cal.isDate($0.date, inSameDayAs: entryDay) }) {
                daily[idx].total += (entry.input_tokens ?? 0) + (entry.output_tokens ?? 0)
            }
        }

        var data = DashboardData(dailyData: daily)

        for period in Period.allCases {
            let range = period.dateRange()
            var pd    = PeriodData()

            // Aggregate overall tokens
            for entry in usage.data {
                guard let s = entry.start_time, let d = parseDate(s), d >= range.start, d < range.end else { continue }
                pd.totals.input       += entry.input_tokens                 ?? 0
                pd.totals.output      += entry.output_tokens                ?? 0
                pd.totals.cacheRead   += entry.cache_read_input_tokens      ?? 0
                pd.totals.cacheCreate += entry.cache_creation_input_tokens  ?? 0
            }

            // Model breakdown
            var modelMap: [String: ModelUsage] = [:]
            for entry in byModel.data {
                guard let s = entry.start_time, let d = parseDate(s), d >= range.start, d < range.end else { continue }
                let key = entry.model ?? "unknown"
                var m   = modelMap[key] ?? ModelUsage(modelId: key)
                m.input  += entry.input_tokens  ?? 0
                m.output += entry.output_tokens ?? 0
                modelMap[key] = m
            }
            pd.models = modelMap.values.sorted { $0.total > $1.total }

            // Costs
            for entry in costs.data {
                guard let s = entry.start_time, let d = parseDate(s), d >= range.start, d < range.end else { continue }
                pd.costCents += entry.costCents
            }

            data.periods[period] = pd
        }

        return data
    }

    // MARK: – Date parsing

    private let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoShort: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseDate(_ s: String) -> Date? {
        isoFull.date(from: s) ?? isoShort.date(from: s)
    }

    private func iso(_ d: Date) -> String {
        isoShort.string(from: d)
    }
}
