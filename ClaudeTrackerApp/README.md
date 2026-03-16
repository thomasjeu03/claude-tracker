# Claude Token Tracker — Native macOS Menu Bar App

A pure SwiftUI macOS status-bar app that shows your Anthropic org's API token usage directly in the menu bar. No npm, no Node.js, no Electron.

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 26 beta (or latest) |
| macOS (run target) | **26.0+** |
| Anthropic Admin API key | `sk-ant-admin01-…` |

> Get your Admin API key at: https://console.anthropic.com/settings/admin-keys
> (Requires the **admin** role in your Anthropic org)

---

## Install & Run

```bash
git clone <repo-url>
cd ClaudeTrackerApp
open ClaudeTrackerApp.xcodeproj
```

Then in Xcode:

1. Select the **ClaudeTrackerApp** scheme
2. Choose your **Mac** as the run destination
3. Press **⌘R**

A `C` icon appears in your macOS menu bar. Click it, paste your Admin API key, and hit **Connect**.

---

## Signing

The project uses **automatic signing**. Xcode will ask you to select a development team on first build:

- Target → **Signing & Capabilities** → set **Team** to your Apple developer account

The entitlements file (`ClaudeTrackerApp.entitlements`) already includes the required `com.apple.security.network.client` permission so the app can reach `api.anthropic.com`.

---

## What it shows

| Section | Detail |
|---------|--------|
| **Today** | Total tokens used today, with input / output breakdown |
| **7 Days** | 7-day token total + estimated cost |
| **30 Days** | 30-day token total + estimated cost |
| **Footer** | Today's estimated USD cost |
| **Menu bar** | Today's token count shown inline in the tray |
| **Auto-refresh** | Data refreshes every 2 minutes in the background |

---

## Project structure

```
ClaudeTrackerAppApp.swift   — @main entry, MenuBarExtra setup
ViewModel.swift             — @MainActor ObservableObject, state + refresh timer
APIService.swift            — URLSession async/await, Codable models, data assembly
ContentView.swift           — All SwiftUI views (Login + Dashboard)
ClaudeTrackerApp.entitlements — Sandbox + network-client entitlements
```

The app makes **3 parallel API calls** on each refresh:
- `GET /v1/organizations/usage_report/messages` — raw token usage
- `GET /v1/organizations/usage_report/messages?group_by[]=model` — usage per model
- `GET /v1/organizations/cost_report` — cost data

Results are assembled into a `DashboardData` struct and driven through a single `AppViewModel`.

---

## Notes

- **API key storage**: uses `UserDefaults` (`@AppStorage`). For production, migrate to the macOS **Keychain** via the `Security` framework.
- Cost data has ~5 min latency per Anthropic's docs.
- The app is a **menu bar agent** (`LSUIElement = YES`): it has no Dock icon and no app menu.
