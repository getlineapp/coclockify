import Foundation

enum L10n {
    // MARK: - Top bar
    static let settings = NSLocalizedString("settings", bundle: .localized, comment: "Settings button label")

    // MARK: - Connection
    static let statusConnected = NSLocalizedString("status.connected", bundle: .localized, comment: "Connection status: connected")
    static let statusNeedsConnection = NSLocalizedString("status.needsConnection", bundle: .localized, comment: "Connection status: needs connection")
    static let statusNotConfigured = NSLocalizedString("status.notConfigured", bundle: .localized, comment: "Connection status: not configured")

    // MARK: - Timer
    static let timerActive = NSLocalizedString("timer.active", bundle: .localized, comment: "Active timer heading")
    static let timerNew = NSLocalizedString("timer.new", bundle: .localized, comment: "New timer heading")
    static let timerPlaceholder = NSLocalizedString("timer.placeholder", bundle: .localized, comment: "Timer description placeholder")
    static let configureConnection = NSLocalizedString("timer.configureConnection", bundle: .localized, comment: "Prompt to configure connection")

    // MARK: - Sections
    static let quickStart = NSLocalizedString("section.quickStart", bundle: .localized, comment: "Quick start section title")
    static let quickStartEmpty = NSLocalizedString("section.quickStart.empty", bundle: .localized, comment: "Quick start section empty hint")
    static let recentLog = NSLocalizedString("section.recentLog", bundle: .localized, comment: "Recent time log section title")
    static let recentLogEmpty = NSLocalizedString("section.recentLog.empty", bundle: .localized, comment: "Recent time log empty hint")
    static let today = NSLocalizedString("day.today", bundle: .localized, comment: "Today label")
    static let yesterday = NSLocalizedString("day.yesterday", bundle: .localized, comment: "Yesterday label")

    // MARK: - Entry details
    static let noDescription = NSLocalizedString("entry.noDescription", bundle: .localized, comment: "Placeholder for entries without description")
    static let inProgress = NSLocalizedString("entry.inProgress", bundle: .localized, comment: "Label for entry still in progress")
    static let edit = NSLocalizedString("entry.edit", bundle: .localized, comment: "Edit menu item")
    static let editLastEntry = NSLocalizedString("entry.editLast", bundle: .localized, comment: "Context menu: edit last entry")
    static let editRunningEntry = NSLocalizedString("entry.editRunning", bundle: .localized, comment: "Hint/label for editing the running entry")

    // MARK: - Status bar
    static let statusReady = NSLocalizedString("status.ready", bundle: .localized, comment: "Ready status label")
    static let autoRefresh = NSLocalizedString("status.autoRefresh", bundle: .localized, comment: "Auto refresh label")

    // MARK: - Settings sheet
    static let settingsTitle = NSLocalizedString("settings.title", bundle: .localized, comment: "Settings sheet title")
    static let settingsSubtitle = NSLocalizedString("settings.subtitle", bundle: .localized, comment: "Settings sheet subtitle")
    static let settingsWorkspaceHint = NSLocalizedString("settings.workspaceHint", bundle: .localized, comment: "Workspace ID field placeholder")
    static let settingsClose = NSLocalizedString("settings.close", bundle: .localized, comment: "Close button")
    static let settingsSaveConnect = NSLocalizedString("settings.saveConnect", bundle: .localized, comment: "Save and connect button")

    // MARK: - Entry edit sheet
    static let editEntryTitle = NSLocalizedString("editEntry.title", bundle: .localized, comment: "Edit entry sheet title")
    static let editEntryDescription = NSLocalizedString("editEntry.description", bundle: .localized, comment: "Description field label")
    static let editEntryHasEnd = NSLocalizedString("editEntry.hasEnd", bundle: .localized, comment: "Toggle for end time")
    static let editEntryEnd = NSLocalizedString("editEntry.end", bundle: .localized, comment: "End date label")
    static let editEntryCancel = NSLocalizedString("editEntry.cancel", bundle: .localized, comment: "Cancel button")
    static let editEntrySave = NSLocalizedString("editEntry.save", bundle: .localized, comment: "Save button")

    // MARK: - AppState status messages
    static let timerStarted = NSLocalizedString("appState.timerStarted", bundle: .localized, comment: "Status after starting timer")
    static let timerStopped = NSLocalizedString("appState.timerStopped", bundle: .localized, comment: "Status after stopping timer")
    static let dataRefreshed = NSLocalizedString("appState.dataRefreshed", bundle: .localized, comment: "Status after refreshing data")
    static let entryUpdated = NSLocalizedString("appState.entryUpdated", bundle: .localized, comment: "Status after updating entry")
    static let connectFirst = NSLocalizedString("appState.connectFirst", bundle: .localized, comment: "Error: not connected yet")
    static let fillApiKey = NSLocalizedString("appState.fillApiKey", bundle: .localized, comment: "Error: API key missing")
    static let workspaceError = NSLocalizedString("appState.workspaceError", bundle: .localized, comment: "Error: workspace ID not determined")
    static let operationInProgress = NSLocalizedString("appState.operationInProgress", bundle: .localized, comment: "Operation already in progress")
    static let timerAlreadyRunning = NSLocalizedString("appState.timerAlreadyRunning", bundle: .localized, comment: "Error: timer already running")
    static let noRunningTimer = NSLocalizedString("appState.noRunningTimer", bundle: .localized, comment: "Error: no running timer")
    static let endBeforeStart = NSLocalizedString("appState.endBeforeStart", bundle: .localized, comment: "Error: entry end is before start")
    static let projectNotFound = NSLocalizedString("appState.projectNotFound", bundle: .localized, comment: "Error: selected project is missing")
    static let projectNameRequired = NSLocalizedString("appState.projectNameRequired", bundle: .localized, comment: "Error: project name required")
    static let baseURLNeedsConfirmation = NSLocalizedString("appState.baseURLNeedsConfirmation", bundle: .localized, comment: "Error: non-default base URL requires confirmation")
    static let baseURLConfirmTitle = NSLocalizedString("settings.baseURL.confirm.title", bundle: .localized, comment: "Title of confirmation sheet for non-default base URL")
    static let baseURLConfirmBody = NSLocalizedString("settings.baseURL.confirm.body", bundle: .localized, comment: "Body of confirmation sheet for non-default base URL")
    static let baseURLConfirmAction = NSLocalizedString("settings.baseURL.confirm.action", bundle: .localized, comment: "Confirm action button for non-default base URL")
    static let baseURLResetAction = NSLocalizedString("settings.baseURL.reset.action", bundle: .localized, comment: "Reset to default action")
    static let baseURLBadge = NSLocalizedString("settings.baseURL.custom.badge", bundle: .localized, comment: "Badge shown when using a non-default base URL")

    // MARK: - Menu bar
    static let menuTimerActive = NSLocalizedString("menu.timerActive", bundle: .localized, comment: "Menu bar: timer active")
    static let menuTimerStopped = NSLocalizedString("menu.timerStopped", bundle: .localized, comment: "Menu bar: timer stopped")
    static let refresh = NSLocalizedString("menu.refresh", bundle: .localized, comment: "Refresh button")
    static let openApp = NSLocalizedString("menu.openApp", bundle: .localized, comment: "Open app button")
    static let quit = NSLocalizedString("menu.quit", bundle: .localized, comment: "Quit button")

    // MARK: - Force projects
    static let projectRequired = NSLocalizedString("appState.projectRequired", bundle: .localized, comment: "Error: workspace requires a project")
    static let projectRequiredForStop = NSLocalizedString("appState.projectRequiredForStop", bundle: .localized, comment: "Error: assign project before stopping")
    static let projectRequiredHint = NSLocalizedString("project.requiredHint", bundle: .localized, comment: "Hint: workspace requires project selection")

    // MARK: - Projects
    static let noProject = NSLocalizedString("project.none", bundle: .localized, comment: "No project label")
    static let projectLabel = NSLocalizedString("project.label", bundle: .localized, comment: "Project picker label")
    static let createProjectTitle = NSLocalizedString("project.create.title", bundle: .localized, comment: "Create project sheet title")
    static let createProjectName = NSLocalizedString("project.create.name", bundle: .localized, comment: "Project name field placeholder")
    static let createProjectColor = NSLocalizedString("project.create.color", bundle: .localized, comment: "Color picker label")
    static let createProjectButton = NSLocalizedString("project.create.button", bundle: .localized, comment: "Create project button")
    static let projectUpdated = NSLocalizedString("appState.projectUpdated", bundle: .localized, comment: "Status after updating project")
    static let projectCreated = NSLocalizedString("appState.projectCreated", bundle: .localized, comment: "Status after creating project")

    // MARK: - About / disclaimer
    static let aboutDisclaimer = NSLocalizedString("about.disclaimer", bundle: .localized, comment: "Non-affiliation disclaimer shown in Settings")

    // MARK: - Accessibility
    static let a11yFavoriteAdd = NSLocalizedString("a11y.favorite.add", bundle: .localized, comment: "VoiceOver: add favorite")
    static let a11yFavoriteRemove = NSLocalizedString("a11y.favorite.remove", bundle: .localized, comment: "VoiceOver: remove favorite")
    static let a11yConnectionStatus = NSLocalizedString("a11y.connectionStatus", bundle: .localized, comment: "VoiceOver: connection status indicator")
    static let entryNotFound = NSLocalizedString("a11y.entryNotFound", bundle: .localized, comment: "Status: no matching entry to edit")

    static func a11yElapsed(_ value: String) -> String {
        String(format: NSLocalizedString("a11y.elapsed", bundle: .localized, comment: "VoiceOver: elapsed time"), value)
    }

    static func a11yStartEntry(_ description: String) -> String {
        String(format: NSLocalizedString("a11y.startEntry", bundle: .localized, comment: "VoiceOver: start timer for description"), description)
    }

    static func a11yColor(_ value: String) -> String {
        String(format: NSLocalizedString("a11y.color", bundle: .localized, comment: "VoiceOver: color swatch"), value)
    }

    // MARK: - API errors
    static let errorInvalidBaseURL = NSLocalizedString("api.error.invalidBaseURL", bundle: .localized, comment: "Invalid base URL error")
    static let errorKeychainUnavailable = NSLocalizedString("api.error.keychain", bundle: .localized, comment: "Keychain write failure")
    static let errorMissingData = NSLocalizedString("api.error.missingData", bundle: .localized, comment: "Missing data error")
    static let errorInvalidResponse = NSLocalizedString("api.error.invalidResponse", bundle: .localized, comment: "Invalid response error")
    static let errorUnknownApi = NSLocalizedString("api.error.unknown", bundle: .localized, comment: "Unknown API error")
    static let apiDecodingError = NSLocalizedString("api.error.decoding", bundle: .localized, comment: "API decoding error")

    // MARK: - Interpolated strings

    static func connectedAs(_ name: String) -> String {
        String(format: NSLocalizedString("appState.connectedAs", bundle: .localized, comment: "Status: connected as user"), name)
    }

    static func userLabel(_ name: String) -> String {
        String(format: NSLocalizedString("settings.userLabel", bundle: .localized, comment: "User label in settings"), name)
    }

    static func apiError(_ code: Int, _ message: String) -> String {
        String(format: NSLocalizedString("api.error.http", bundle: .localized, comment: "HTTP API error with code and message"), code, message)
    }

    static func apiNetworkError(_ message: String) -> String {
        String(format: NSLocalizedString("api.error.network", bundle: .localized, comment: "Network API error"), message)
    }

    static func sanitizedNetworkErrorMessage(for error: Error) -> String {
        let urlError: URLError
        if let direct = error as? URLError {
            urlError = direct
        } else if let api = error as? ClockifyAPIError, case .networkError = api,
                  let nested = (error as NSError).userInfo[NSUnderlyingErrorKey] as? URLError {
            urlError = nested
        } else {
            return apiNetworkError(networkErrorLabel(for: nil))
        }
        return apiNetworkError(networkErrorLabel(for: urlError.code))
    }

    private static func networkErrorLabel(for code: URLError.Code?) -> String {
        switch code {
        case .some(.notConnectedToInternet), .some(.networkConnectionLost):
            return NSLocalizedString("api.error.network.offline", bundle: .localized, comment: "Network: offline")
        case .some(.timedOut):
            return NSLocalizedString("api.error.network.timeout", bundle: .localized, comment: "Network: timeout")
        case .some(.cannotFindHost), .some(.cannotConnectToHost), .some(.dnsLookupFailed):
            return NSLocalizedString("api.error.network.host", bundle: .localized, comment: "Network: host unreachable")
        case .some(.secureConnectionFailed), .some(.serverCertificateUntrusted), .some(.serverCertificateHasBadDate), .some(.serverCertificateHasUnknownRoot), .some(.serverCertificateNotYetValid):
            return NSLocalizedString("api.error.network.tls", bundle: .localized, comment: "Network: TLS error")
        default:
            return NSLocalizedString("api.error.network.generic", bundle: .localized, comment: "Network: generic error")
        }
    }
}
