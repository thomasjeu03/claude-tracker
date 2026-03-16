# Claude Token Tracker — Native macOS Menu Bar App

A pure SwiftUI macOS status-bar app. No npm, no Node.js, no Electron.

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 14.2+ |
| macOS (run target) | **13 (Ventura)+** |
| Anthropic Admin API key | `sk-ant-admin01-…` |

> Get your Admin API key at: https://console.anthropic.com/settings/admin-keys
> (Requires the admin role in your Anthropic org)

---

## Setup in Xcode — step by step

### 1 — Create project
- Open Xcode → **File → New → Project**
- Choose **macOS → App**
- Settings:
  - Product Name: `ClaudeTokenTracker`
  - Interface: **SwiftUI**
  - Language: **Swift**
  - Uncheck "Include Tests"

### 2 — Add the source files
Delete the auto-generated `ContentView.swift` and `ClaudeTokenTrackerApp.swift`.
Drag **all 4 `.swift` files** from this folder into the Xcode project:
```
ClaudeTrackerApp.swift
ViewModel.swift
APIService.swift
ContentView.swift
```
When prompted, check **"Copy items if needed"** and make sure your target is selected.

### 3 — Configure Info.plist
The app must **hide from the Dock** (menu bar only). In Xcode:
- Select the project target → **Info** tab
- Add key: `Application is agent (UIElement)` → Value: `YES`

Or edit Info.plist XML directly:
```xml
<key>LSUIElement</key>
<true/>
```

### 4 — Set deployment target
- Target → General → **Minimum Deployments → macOS 13.0**

### 5 — Run
Press **⌘R**. A `C` icon appears in the macOS menu bar. Click it to open the popup.

---

## Features

| Feature | Detail |
|---------|--------|
| Login | Admin API key stored in UserDefaults |
| Today tab | Input / Output / Cache tokens for today |
| 7 Days tab | 7-day totals + animated bar chart |
| 30 Days tab | 30-day totals + animated bar chart |
| Model table | Top 6 models with tier badges |
| Cost footer | Estimated USD cost for selected period |
| Tray title | Today's token count shown in menu bar |
| Auto-refresh | Every 2 minutes in the background |

---

## Architecture

```
ClaudeTrackerApp.swift   — @main entry, MenuBarExtra setup
ViewModel.swift          — @MainActor ObservableObject, state + timer
APIService.swift         — URLSession async/await, models, data assembly
ContentView.swift        — All SwiftUI views (Login + Dashboard)
```

The API calls (`/v1/organizations/usage_report/messages` and `/v1/organizations/cost_report`)
are executed in 3 parallel `async let` tasks, then assembled into a `DashboardData` struct.

---

## Notes

- **API key storage**: currently uses `UserDefaults` (`@AppStorage`). For production,
  migrate to the macOS Keychain using the `Security` framework.
- Costs have ~5 min latency per Anthropic's docs.
- Priority Tier costs are tracked via the usage endpoint (not cost endpoint).
