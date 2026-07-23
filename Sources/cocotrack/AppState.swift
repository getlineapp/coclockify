import Foundation

enum TimerValidation {
    static func shouldBlockStart(forceProjects: Bool, projectId: String?) -> Bool {
        forceProjects && projectId == nil
    }

    static func shouldWarnProjectOnStop(forceProjects: Bool, runningProjectId: String?) -> Bool {
        forceProjects && runningProjectId == nil
    }
}

struct QuickStartTemplate: Identifiable {
    let description: String
    let lastUsed: Date
    let projectId: String?

    var id: String { description }
}

struct QuickStartItem: Identifiable {
    let description: String
    let lastUsed: Date
    let projectId: String?
    let isFavorite: Bool

    var id: String { description }
}

struct DayGroup: Identifiable {
    let date: Date
    let label: String
    let entries: [ClockifyTimeEntry]
    let totalSeconds: Int

    var id: Date { date }
}

@MainActor
final class AppState: ObservableObject {
    @Published var apiKey: String
    @Published var baseURL: String
    @Published var workspaceOverride: String
    @Published private(set) var baseURLConfirmed: Bool

    @Published var userName: String = ""
    @Published var userId: String = ""
    @Published var workspaceId: String = ""

    @Published var recentEntries: [ClockifyTimeEntry] = [] {
        didSet { recomputeDerived() }
    }
    @Published var runningEntry: ClockifyTimeEntry?
    @Published var projects: [ClockifyProject] = []
    @Published var timerDraftDescription: String = ""
    @Published var timerDraftProjectId: String?
    @Published var forceProjects: Bool = false
    @Published var statusMessage: String = ""
    @Published var isLoading: Bool = false
    /// True when the Keychain refused to store the API key. The key still works
    /// for this session but will not survive a relaunch, so the UI must say so
    /// rather than silently reporting success.
    @Published private(set) var keychainUnavailable: Bool = false
    @Published private(set) var favoriteDescriptions: Set<String> {
        didSet { recomputeDerived() }
    }

    @Published private(set) var quickStartItems: [QuickStartItem] = []
    @Published private(set) var recentEntryGroups: [DayGroup] = []

    @Published private(set) var elapsedText: String = "00:00:00"

    private var elapsedTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?
    private var lastProjectsFetch: Date?
    private static let projectsRefreshInterval: TimeInterval = 300

    init() {
        let defaults = UserDefaults.standard

        let resolved = APIKeyMigration.resolve(
            keychainKey: APIKeyStore.load(),
            legacyKey: defaults.string(forKey: Keys.apiKey),
            saveToKeychain: { APIKeyStore.save($0) }
        )
        self.apiKey = resolved.apiKey
        if resolved.removeLegacyKey {
            defaults.removeObject(forKey: Keys.apiKey)
        }
        self.keychainUnavailable = resolved.keychainWriteFailed

        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? ClockifyAPIClient.defaultBaseURL
        self.workspaceOverride = defaults.string(forKey: Keys.workspaceOverride) ?? ""
        self.favoriteDescriptions = Set(defaults.stringArray(forKey: Keys.favoriteDescriptions) ?? [])
        self.baseURLConfirmed = AppState.computeBaseURLConfirmed(
            baseURL: defaults.string(forKey: Keys.baseURL) ?? ClockifyAPIClient.defaultBaseURL,
            stored: defaults.string(forKey: Keys.baseURLConfirmed)
        )

        if !apiKey.isEmpty && baseURLConfirmed {
            Task {
                await connectAndRefresh()
            }
        }
    }

    private static func computeBaseURLConfirmed(baseURL: String, stored: String?) -> Bool {
        if ClockifyAPIClient.isDefaultBaseURL(baseURL) { return true }
        return stored == baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var requiresBaseURLConfirmation: Bool {
        !ClockifyAPIClient.isDefaultBaseURL(baseURL) &&
            UserDefaults.standard.string(forKey: Keys.baseURLConfirmed) !=
            baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func confirmBaseURL() {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: Keys.baseURLConfirmed)
        baseURLConfirmed = true
    }

    func resetBaseURLToDefault() {
        baseURL = ClockifyAPIClient.defaultBaseURL
        UserDefaults.standard.removeObject(forKey: Keys.baseURLConfirmed)
        baseURLConfirmed = true
    }

    deinit {
        elapsedTask?.cancel()
        autoRefreshTask?.cancel()
    }

    var isTracking: Bool {
        runningEntry != nil
    }

    var canStartTimer: Bool {
        isConnected && !isTracking && !isLoading
    }

    var canStopTimer: Bool {
        isConnected && isTracking && !isLoading
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isConnected: Bool {
        !userId.isEmpty && !workspaceId.isEmpty
    }

    private func recomputeDerived() {
        var lastUsedByDescription: [String: (date: Date, projectId: String?)] = [:]
        var seenForRecent = Set<String>()
        var recentTemplates: [QuickStartItem] = []

        for entry in recentEntries {
            let trimmed = (entry.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let current = lastUsedByDescription[trimmed] {
                if entry.timeInterval.start > current.date {
                    lastUsedByDescription[trimmed] = (entry.timeInterval.start, entry.projectId)
                }
            } else {
                lastUsedByDescription[trimmed] = (entry.timeInterval.start, entry.projectId)
            }

            if recentTemplates.count < 10,
               seenForRecent.insert(trimmed.lowercased()).inserted {
                recentTemplates.append(QuickStartItem(
                    description: trimmed,
                    lastUsed: entry.timeInterval.start,
                    projectId: entry.projectId,
                    isFavorite: false
                ))
            }
        }

        let favItems = favoriteDescriptions
            .map { description -> QuickStartItem in
                let info = lastUsedByDescription[description]
                return QuickStartItem(
                    description: description,
                    lastUsed: info?.date ?? .distantPast,
                    projectId: info?.projectId,
                    isFavorite: true
                )
            }
            .sorted { $0.lastUsed > $1.lastUsed }

        let favDescriptions = Set(favItems.map { $0.description.lowercased() })
        let filteredRecent = recentTemplates.filter { !favDescriptions.contains($0.description.lowercased()) }
        quickStartItems = Array((favItems + filteredRecent).prefix(10))

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentEntries) { entry in
            calendar.startOfDay(for: entry.timeInterval.start)
        }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!

        recentEntryGroups = grouped
            .sorted { $0.key > $1.key }
            .map { (date, entries) in
                let label: String
                if date == todayStart {
                    label = L10n.today
                } else if date == yesterdayStart {
                    label = L10n.yesterday
                } else {
                    label = Self.dayLabelFormatter.string(from: date)
                }

                let totalSeconds = entries
                    .compactMap(\.durationSeconds)
                    .reduce(0, +)

                return DayGroup(date: date, label: label, entries: entries, totalSeconds: totalSeconds)
            }
    }

    var menuBarTitle: String {
        guard isTracking else { return "Cocotrack" }

        let description = runningDescription
        let shortDescription: String
        if description.count > 20 {
            shortDescription = String(description.prefix(20)) + "..."
        } else {
            shortDescription = description
        }

        return "\(shortDescription) [\(elapsedText)]"
    }

    var runningDescription: String {
        let value = runningEntry?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }

        return L10n.noDescription
    }

    func projectName(for id: String?) -> String? {
        guard let id else { return nil }
        return projects.first(where: { $0.id == id })?.name
    }

    func projectColorHex(for id: String?) -> String? {
        guard let id else { return nil }
        return projects.first(where: { $0.id == id })?.color
    }

    private static let dayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        // A hardcoded "EEE, d MMM" forces English field order onto every locale.
        // The template form keeps the same fields but lets the locale decide the
        // arrangement and separators.
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return f
    }()

    func connectAndRefresh() async {
        await runLoadingTask {
            guard baseURLConfirmed else {
                throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.baseURLNeedsConfirmation)
            }

            try persistSettings()

            let client = try makeClient()
            let user = try await client.fetchCurrentUser()

            let resolvedWorkspace = resolvedWorkspaceId(user: user)
            guard let resolvedWorkspace else {
                throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.workspaceError)
            }

            userId = user.id
            workspaceId = resolvedWorkspace
            userName = user.name ?? user.email ?? user.id

            async let running = client.fetchRunningTimeEntry(workspaceId: resolvedWorkspace, userId: user.id)
            async let recent = client.fetchRecentTimeEntries(workspaceId: resolvedWorkspace, userId: user.id, limit: 50)
            async let projectsList = client.fetchProjects(workspaceId: resolvedWorkspace)
            async let workspaceInfo = client.fetchWorkspace(workspaceId: resolvedWorkspace)

            runningEntry = try await running
            recentEntries = try await recent
            projects = try await projectsList
            lastProjectsFetch = Date()
            forceProjects = (try? await workspaceInfo)?.workspaceSettings.forceProjects ?? false
            statusMessage = L10n.connectedAs(userName)

            restartElapsedTaskIfNeeded()
            restartAutoRefreshIfNeeded()
        }
    }

    func refreshEntries() async {
        await runLoadingTask {
            let context = try contextOrThrow()
            async let running = context.client.fetchRunningTimeEntry(workspaceId: context.workspaceId, userId: context.userId)
            async let recent = context.client.fetchRecentTimeEntries(workspaceId: context.workspaceId, userId: context.userId, limit: 50)
            async let projectsList = context.client.fetchProjects(workspaceId: context.workspaceId)

            runningEntry = try await running
            recentEntries = try await recent
            projects = try await projectsList
            lastProjectsFetch = Date()
            statusMessage = L10n.dataRefreshed

            restartElapsedTaskIfNeeded()
        }
    }

    @discardableResult
    func startTimer() async -> Bool {
        var didStart = false

        await runLoadingTask {
            guard !isTracking else {
                throw ClockifyAPIError.httpError(statusCode: 409, message: L10n.timerAlreadyRunning)
            }

            if TimerValidation.shouldBlockStart(forceProjects: forceProjects, projectId: timerDraftProjectId) {
                throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.projectRequired)
            }

            let context = try contextOrThrow()
            let text = timerDraftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = text.isEmpty ? L10n.noDescription : text

            _ = try await context.client.startTimer(
                workspaceId: context.workspaceId,
                description: description,
                projectId: timerDraftProjectId,
                start: Date()
            )
            didStart = true

            timerDraftDescription = ""
            timerDraftProjectId = nil
            statusMessage = L10n.timerStarted

            await refreshEntriesWithoutSpinner(context: context)
        }

        return didStart
    }

    @discardableResult
    func startTimer(using description: String, projectId: String? = nil) async -> Bool {
        timerDraftDescription = description
        timerDraftProjectId = projectId
        return await startTimer()
    }

    func isFavorite(_ description: String) -> Bool {
        let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return favoriteDescriptions.contains(normalized)
    }

    func toggleFavorite(description: String) {
        let normalized = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        if favoriteDescriptions.contains(normalized) {
            favoriteDescriptions.remove(normalized)
        } else {
            favoriteDescriptions.insert(normalized)
        }

        persistFavorites()
    }

    func stopTimer() async {
        await runLoadingTask {
            guard isTracking else {
                throw ClockifyAPIError.httpError(statusCode: 409, message: L10n.noRunningTimer)
            }

            let context = try contextOrThrow()

            do {
                _ = try await context.client.stopRunningTimer(
                    workspaceId: context.workspaceId,
                    userId: context.userId,
                    end: Date()
                )
            } catch {
                if forceProjects, runningEntry?.projectId == nil {
                    throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.projectRequiredForStop)
                }
                throw error
            }

            statusMessage = L10n.timerStopped
            await refreshEntriesWithoutSpinner(context: context)
        }
    }

    @discardableResult
    func saveEntryEdits(entryId: String, description: String, start: Date, end: Date?, projectId: String?) async -> Bool {
        var didSave = false

        await runLoadingTask {
            if let end, end < start {
                throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.endBeforeStart)
            }

            // The entry must be in hand before updating it: PUT replaces the whole
            // record, so tags and the task assignment have to be echoed back.
            let existing = try knownEntryOrThrow(entryId)

            let context = try contextOrThrow()
            let payload = ClockifyUpdateTimeEntryRequest(
                preserving: existing,
                start: start,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                end: end,
                projectId: projectId
            )

            _ = try await context.client.updateTimeEntry(
                workspaceId: context.workspaceId,
                entryId: entryId,
                payload: payload
            )
            didSave = true

            statusMessage = L10n.entryUpdated
            await refreshEntriesWithoutSpinner(context: context)
        }

        return didSave
    }

    func changeEntryProject(entryId: String, projectId: String?) async {
        await runLoadingTask {
            let entry = try knownEntryOrThrow(entryId)

            if let projectId, !projects.contains(where: { $0.id == projectId }) {
                throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.projectNotFound)
            }

            let context = try contextOrThrow()
            let payload = ClockifyUpdateTimeEntryRequest(
                preserving: entry,
                start: entry.timeInterval.start,
                description: entry.description ?? "",
                end: entry.timeInterval.end,
                projectId: projectId
            )

            _ = try await context.client.updateTimeEntry(
                workspaceId: context.workspaceId,
                entryId: entryId,
                payload: payload
            )

            statusMessage = L10n.projectUpdated
            await refreshEntriesWithoutSpinner(context: context)
        }
    }

    @discardableResult
    func createProject(name: String, color: String?) async -> Bool {
        var didCreate = false

        await runLoadingTask {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.projectNameRequired)
            }

            let context = try contextOrThrow()
            let project = try await context.client.createProject(
                workspaceId: context.workspaceId,
                name: trimmedName,
                color: color
            )
            didCreate = true

            projects.append(project)
            statusMessage = L10n.projectCreated
        }

        return didCreate
    }

    private func runLoadingTask(_ operation: @MainActor () async throws -> Void) async {
        guard !isLoading else {
            statusMessage = L10n.operationInProgress
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
        } catch is CancellationError {
            // Ignore cancellation and keep current status message.
        } catch {
            statusMessage = AppState.sanitizedErrorMessage(error)
        }
    }

    private func refreshEntriesWithoutSpinner(context: Context) async {
        do {
            async let running = context.client.fetchRunningTimeEntry(workspaceId: context.workspaceId, userId: context.userId)
            async let recent = context.client.fetchRecentTimeEntries(workspaceId: context.workspaceId, userId: context.userId, limit: 50)

            let shouldRefreshProjects: Bool = {
                guard let last = lastProjectsFetch else { return true }
                return Date().timeIntervalSince(last) >= Self.projectsRefreshInterval
            }()

            if shouldRefreshProjects {
                async let projectsList = context.client.fetchProjects(workspaceId: context.workspaceId)
                runningEntry = try await running
                recentEntries = try await recent
                projects = try await projectsList
                lastProjectsFetch = Date()
            } else {
                runningEntry = try await running
                recentEntries = try await recent
            }

            restartElapsedTaskIfNeeded()
        } catch {
            statusMessage = AppState.sanitizedErrorMessage(error)
        }
    }

    /// Locates the locally-cached copy of an entry. Refusing to proceed without it
    /// is deliberate: a blind PUT would reset every field the payload omits.
    private func knownEntryOrThrow(_ entryId: String) throws -> ClockifyTimeEntry {
        if let running = runningEntry, running.id == entryId {
            return running
        }
        guard let entry = recentEntries.first(where: { $0.id == entryId }) else {
            throw ClockifyAPIError.httpError(statusCode: 404, message: L10n.entryNotFound)
        }
        return entry
    }

    private func contextOrThrow() throws -> Context {
        guard !userId.isEmpty, !workspaceId.isEmpty else {
            throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.connectFirst)
        }

        let client = try makeClient()
        return Context(client: client, userId: userId, workspaceId: workspaceId)
    }

    private func makeClient() throws -> ClockifyAPIClient {
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedApiKey.isEmpty else {
            throw ClockifyAPIError.httpError(statusCode: 400, message: L10n.fillApiKey)
        }

        return try ClockifyAPIClient(
            baseURLString: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: trimmedApiKey,
            session: .cocotrackShared
        )
    }

    static func sanitizedErrorMessage(_ error: Error) -> String {
        if let api = error as? ClockifyAPIError {
            switch api {
            case .networkError:
                return L10n.sanitizedNetworkErrorMessage(for: error)
            default:
                return api.errorDescription ?? L10n.errorUnknownApi
            }
        }
        if error is URLError {
            return L10n.sanitizedNetworkErrorMessage(for: error)
        }
        return L10n.errorUnknownApi
    }

    private func resolvedWorkspaceId(user: ClockifyUser) -> String? {
        let override = workspaceOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty {
            return override
        }

        if let defaultWorkspace = user.defaultWorkspace, !defaultWorkspace.isEmpty {
            return defaultWorkspace
        }

        if let activeWorkspace = user.activeWorkspace, !activeWorkspace.isEmpty {
            return activeWorkspace
        }

        return nil
    }

    private func persistSettings() throws {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(workspaceOverride, forKey: Keys.workspaceOverride)

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            APIKeyStore.delete()
            defaults.removeObject(forKey: Keys.apiKey)
            keychainUnavailable = false
            return
        }

        // A failed Keychain write used to pass silently: the app reported
        // "connected", then came back unconfigured on the next launch.
        guard APIKeyStore.save(trimmedKey) else {
            keychainUnavailable = true
            throw ClockifyAPIError.keychainUnavailable
        }

        keychainUnavailable = false
        defaults.removeObject(forKey: Keys.apiKey)
    }

    private func persistFavorites() {
        UserDefaults.standard.set(Array(favoriteDescriptions).sorted(), forKey: Keys.favoriteDescriptions)
    }

    private func restartElapsedTaskIfNeeded() {
        elapsedTask?.cancel()
        elapsedTask = nil

        guard runningEntry != nil else {
            elapsedText = "00:00:00"
            return
        }

        updateElapsedText()

        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self?.updateElapsedText()
            }
        }
    }

    private func updateElapsedText() {
        guard let start = runningEntry?.timeInterval.start else {
            elapsedText = "00:00:00"
            return
        }

        let seconds = max(0, Int(Date().timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        elapsedText = String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }

    private func restartAutoRefreshIfNeeded() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        guard isConnected else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))

                if Task.isCancelled {
                    return
                }

                await self?.autoRefreshTick()
            }
        }
    }

    private func autoRefreshTick() async {
        guard !isLoading else { return }

        do {
            let context = try contextOrThrow()
            await refreshEntriesWithoutSpinner(context: context)
        } catch {
            statusMessage = AppState.sanitizedErrorMessage(error)
        }
    }
}

private extension AppState {
    struct Context {
        let client: ClockifyAPIClient
        let userId: String
        let workspaceId: String
    }

    enum Keys {
        static let apiKey = "clockify.apiKey"
        static let baseURL = "clockify.baseURL"
        static let baseURLConfirmed = "clockify.baseURL.confirmed"
        static let workspaceOverride = "clockify.workspaceOverride"
        static let favoriteDescriptions = "clockify.favoriteDescriptions"
    }
}
