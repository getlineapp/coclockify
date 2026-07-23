import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    @State private var editingEntry: ClockifyTimeEntry?
    @State private var showSettings: Bool = false
    @State private var showCreateProject: Bool = false
    @State private var customDescription: String = ""
    @State private var selectedProjectId: String?

    var body: some View {
        ZStack {
            DS.Palette.bg
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    toolbar
                        .padding(.horizontal, DS.Metric.sectionPaddingH)
                        .padding(.top, DS.Metric.topPadding)
                        .padding(.bottom, 12)

                    timerCard
                        .padding(.horizontal, DS.Metric.sectionPaddingH)

                    DSDivider()
                        .padding(.vertical, DS.Metric.dividerVMargin)
                        .padding(.horizontal, DS.Metric.sectionPaddingH)

                    quickStartSection
                        .padding(.horizontal, DS.Metric.sectionPaddingH)

                    if !appState.recentEntryGroups.isEmpty {
                        DSDivider()
                            .padding(.vertical, DS.Metric.dividerVMargin)
                            .padding(.horizontal, DS.Metric.sectionPaddingH)

                        RecentTimeLogSection(onEditEntry: { entry in
                            editingEntry = entry
                        })
                        .padding(.horizontal, DS.Metric.sectionPaddingH)
                    }

                    Spacer(minLength: 12)

                    statusBar
                        .padding(.horizontal, DS.Metric.sectionPaddingH)
                        .padding(.bottom, DS.Metric.bottomPadding)
                }
                .frame(maxWidth: DS.Metric.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 400)
        .background(DS.Palette.bg)
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry) { description, start, end, projectId in
                await appState.saveEntryEdits(
                    entryId: entry.id,
                    description: description,
                    start: start,
                    end: end,
                    projectId: projectId
                )
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 8) {
            StatusDot(kind: appState.isConnected ? .ok : (appState.isConfigured ? .warn : .off))

            Text("Cocotrack")
                .font(DS.Font.appName)
                .foregroundStyle(DS.Palette.ink)

            if !appState.userName.isEmpty {
                Text("· \(appState.userName)")
                    .font(DS.Font.appSub)
                    .foregroundStyle(DS.Palette.ink3)
            }

            Spacer()

            Button {
                Task { await appState.refreshEntries() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.dsStandardIcon)
            .disabled(appState.isLoading || !appState.isConnected)
            .accessibilityLabel(L10n.refresh)
            .help(L10n.refresh)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.dsStandardIcon)
            .accessibilityLabel(L10n.settings)
            .help(L10n.settings)
        }
    }

    // MARK: - Timer card

    private var timerCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: 10) {
                if !appState.isConnected {
                    timerCardUnconfigured
                } else if appState.isTracking {
                    timerCardActive
                } else {
                    timerCardEmpty
                }
            }
        }
    }

    @ViewBuilder
    private var timerCardUnconfigured: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.Palette.card2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(DS.Palette.line, lineWidth: 0.5)
                    )
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DS.Palette.ink3)
            }
            .frame(width: 44, height: 44)

            Text(L10n.configureConnection)
                .font(DS.Font.configHeadline)
                .foregroundStyle(DS.Palette.ink)
                .multilineTextAlignment(.center)

            Text(L10n.settingsSubtitle)
                .font(DS.Font.configSub)
                .foregroundStyle(DS.Palette.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .lineSpacing(2)

            Button(L10n.settings) {
                showSettings = true
            }
            .buttonStyle(.dsStandard)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var timerCardActive: some View {
        if let entry = appState.runningEntry {
            HStack(spacing: 6) {
                LiveDot(size: 6)
                SectionLabel(text: L10n.timerActive)
            }
            .padding(.bottom, 2)

            Text(appState.runningDescription)
                .font(DS.Font.runningDesc)
                .foregroundStyle(DS.Palette.ink)
                .lineLimit(2)
                .padding(.bottom, 2)

            HStack(spacing: 8) {
                ProjectPickerMenu(
                    projects: appState.projects,
                    selectedProjectId: entry.projectId,
                    strong: true,
                    onSelect: { newId in
                        Task { await appState.changeEntryProject(entryId: entry.id, projectId: newId) }
                    }
                )

                if appState.forceProjects && entry.projectId == nil {
                    Text(L10n.projectRequiredForStop)
                        .font(DS.Font.warnText)
                        .foregroundStyle(DS.Palette.bad)
                }
            }
            .padding(.bottom, 6)

            HStack(alignment: .bottom) {
                // Was a bare `.onTapGesture`, which is unreachable by keyboard
                // and invisible to VoiceOver — editing the running entry was
                // mouse-only. A plain-styled Button keeps the visuals identical.
                Button {
                    editingEntry = entry
                } label: {
                    ElapsedText(text: appState.elapsedText, font: DS.Font.elapsedHero)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.editRunningEntry)
                .accessibilityValue(appState.elapsedText)
                .help(L10n.editRunningEntry)

                Spacer()

                Button {
                    Task { await appState.stopTimer() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.dsDanger)
                .disabled(!appState.canStopTimer)
            }
        }
    }

    @ViewBuilder
    private var timerCardEmpty: some View {
        SectionLabel(text: L10n.timerNew)
            .padding(.bottom, 2)

        HStack(spacing: 8) {
            TextField(L10n.timerPlaceholder, text: $customDescription)
                .textFieldStyle(.ds)
                .onSubmit {
                    triggerStart()
                }

            Button {
                triggerStart()
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(.dsProminent)
            .disabled(!appState.canStartTimer || (appState.forceProjects && selectedProjectId == nil))
        }

        HStack(spacing: 8) {
            ProjectPickerMenu(
                projects: appState.projects,
                selectedProjectId: selectedProjectId,
                onSelect: { selectedProjectId = $0 }
            )

            if appState.forceProjects && selectedProjectId == nil {
                Text(L10n.projectRequiredHint)
                    .font(DS.Font.warnText)
                    .foregroundStyle(DS.Palette.warn)
            }

            Spacer()

            Button {
                showCreateProject = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13, weight: .regular))
            }
            .buttonStyle(.dsGhostIcon)
            .accessibilityLabel(L10n.createProjectTitle)
            .help(L10n.createProjectTitle)
        }
    }

    private func triggerStart() {
        guard appState.canStartTimer else { return }
        Task {
            let started = await appState.startTimer(using: customDescription, projectId: selectedProjectId)
            if started {
                customDescription = ""
                selectedProjectId = nil
            }
        }
    }

    // MARK: - Quick start

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: L10n.quickStart)

            if appState.quickStartItems.isEmpty {
                Text(L10n.quickStartEmpty)
                    .font(.system(size: 12.5))
                    .foregroundStyle(DS.Palette.ink3)
                    .lineSpacing(2)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 1) {
                    ForEach(appState.quickStartItems) { item in
                        QuickStartRow(
                            item: item,
                            projectName: appState.projectName(for: item.projectId),
                            projectColorHex: appState.projectColorHex(for: item.projectId),
                            onToggleFavorite: {
                                appState.toggleFavorite(description: item.description)
                            },
                            onStart: {
                                Task { await appState.startTimer(using: item.description, projectId: item.projectId) }
                            },
                            onEditLastEntry: {
                                // A favourite can outlive every entry that produced it
                                // (or be pinned before any exists). Previously this
                                // menu item just did nothing, with no explanation.
                                if let entry = appState.recentEntries.first(where: {
                                    ($0.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == item.description
                                }) {
                                    editingEntry = entry
                                } else {
                                    appState.statusMessage = L10n.entryNotFound
                                }
                            },
                            isStartDisabled: !appState.canStartTimer || (appState.forceProjects && item.projectId == nil)
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        VStack(spacing: 0) {
            DSDivider()
                .padding(.bottom, 8)

            HStack(spacing: 8) {
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .frame(width: 12, height: 12)
                }

                Text(appState.statusMessage.isEmpty ? L10n.statusReady : appState.statusMessage)
                    .font(DS.Font.statusBar)
                    .foregroundStyle(DS.Palette.ink3)
                    .lineLimit(2)

                Spacer()

                Text(L10n.autoRefresh)
                    .font(DS.Font.statusBarRight)
                    .foregroundStyle(DS.Palette.ink4)
            }
        }
    }
}

// MARK: - Quick start row

private struct QuickStartRow: View {
    let item: QuickStartItem
    let projectName: String?
    let projectColorHex: String?
    let onToggleFavorite: () -> Void
    let onStart: () -> Void
    let onEditLastEntry: () -> Void
    let isStartDisabled: Bool

    @State private var isHovered = false
    @State private var isStartHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(item.isFavorite ? Color(red: 0.75, green: 0.51, blue: 0.10) : DS.Palette.ink4)
                    .frame(width: DS.Metric.starWidth, alignment: .center)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isFavorite ? L10n.a11yFavoriteRemove : L10n.a11yFavoriteAdd)
            .help(item.isFavorite ? L10n.a11yFavoriteRemove : L10n.a11yFavoriteAdd)

            Text(item.description)
                .font(DS.Font.qsDesc)
                .foregroundStyle(DS.Palette.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if let projectName {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: projectColorHex ?? "") ?? DS.Palette.ink4)
                        .frame(width: 6, height: 6)
                    Text(projectName)
                        .font(DS.Font.qsProj)
                        .foregroundStyle(DS.Palette.ink3)
                        .lineLimit(1)
                }
                .frame(maxWidth: 180, alignment: .trailing)
            }

            Button {
                onStart()
            } label: {
                Text("Start")
                    .font(DS.Font.qsStart)
                    .foregroundStyle(isStartDisabled ? DS.Palette.ink4 : DS.Palette.accentInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isStartHovered && !isStartDisabled ? DS.Palette.accentBg : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isStartDisabled)
            .onHover { isStartHovered = $0 }
            .accessibilityLabel(L10n.a11yStartEntry(item.description))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DS.Metric.rowRadius, style: .continuous)
                .fill(isHovered ? DS.Palette.card2 : .clear)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(L10n.editLastEntry) {
                onEditLastEntry()
            }
        }
    }
}

// MARK: - Project picker menu

struct ProjectPickerMenu: View {
    let projects: [ClockifyProject]
    let selectedProjectId: String?
    var strong: Bool = false
    let onSelect: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                if selectedProjectId == nil {
                    Label(L10n.noProject, systemImage: "checkmark")
                } else {
                    Text(L10n.noProject)
                }
            }
            Divider()
            ForEach(projects) { project in
                Button {
                    onSelect(project.id)
                } label: {
                    if selectedProjectId == project.id {
                        Label(project.name, systemImage: "checkmark")
                    } else {
                        Text(project.name)
                    }
                }
            }
        } label: {
            ProjectCapsuleMenuLabel(selectedProjectId: selectedProjectId, projects: projects, strong: strong)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Settings sheet

private struct SettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showBaseURLConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.settingsTitle)
                .font(DS.Font.sheetTitle)
                .foregroundStyle(DS.Palette.ink)
                .padding(.bottom, 4)

            Text(L10n.settingsSubtitle)
                .font(DS.Font.sheetSub)
                .foregroundStyle(DS.Palette.ink3)
                .lineSpacing(2)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 10) {
                formRow(label: "API key") {
                    SecureField("API key", text: $appState.apiKey)
                        .textFieldStyle(.ds)
                }

                formRow(label: "Base URL") {
                    TextField("Base URL", text: $appState.baseURL)
                        .textFieldStyle(.ds)
                }

                if appState.requiresBaseURLConfirmation {
                    Text(L10n.baseURLBadge)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Palette.warn)
                        .padding(.top, -4)
                }

                // A failed Keychain write is otherwise invisible until the key
                // turns out to be gone on the next launch.
                if appState.keychainUnavailable {
                    Text(L10n.errorKeychainUnavailable)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Palette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }

                formRow(label: L10n.settingsWorkspaceHint) {
                    TextField(L10n.settingsWorkspaceHint, text: $appState.workspaceOverride)
                        .textFieldStyle(.ds)
                }
            }
            .padding(.bottom, 14)

            HStack {
                if !appState.userName.isEmpty {
                    Text(L10n.userLabel(appState.userName))
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Palette.ink3)
                }

                Spacer()

                Button(L10n.settingsClose) {
                    dismiss()
                }
                .buttonStyle(.dsStandard)

                Button(L10n.settingsSaveConnect) {
                    if appState.requiresBaseURLConfirmation {
                        showBaseURLConfirm = true
                    } else {
                        Task {
                            await appState.connectAndRefresh()
                        }
                    }
                }
                .buttonStyle(DSButtonStyle(kind: .prominent))
            }

            Text(L10n.aboutDisclaimer)
                .font(.system(size: 10))
                .foregroundStyle(DS.Palette.ink3)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(width: 460)
        .background(DS.Palette.bg)
        .alert(L10n.baseURLConfirmTitle, isPresented: $showBaseURLConfirm) {
            Button(L10n.baseURLResetAction, role: .cancel) {
                appState.resetBaseURLToDefault()
                Task { await appState.connectAndRefresh() }
            }
            Button(L10n.baseURLConfirmAction, role: .destructive) {
                appState.confirmBaseURL()
                Task { await appState.connectAndRefresh() }
            }
        } message: {
            Text(L10n.baseURLConfirmBody)
        }
    }

    @ViewBuilder
    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(DS.Font.formLabel)
                .tracking(0.8)
                .foregroundStyle(DS.Palette.ink3)
            content()
        }
    }
}

// MARK: - Entry edit sheet

private struct EntryEditSheet: View {
    @EnvironmentObject private var appState: AppState
    let entry: ClockifyTimeEntry
    let onSave: (_ description: String, _ start: Date, _ end: Date?, _ projectId: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var description: String
    @State private var start: Date
    @State private var hasEndDate: Bool
    @State private var end: Date
    @State private var selectedProjectId: String?
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private var isValid: Bool {
        !hasEndDate || end >= start
    }

    init(entry: ClockifyTimeEntry, onSave: @escaping (_ description: String, _ start: Date, _ end: Date?, _ projectId: String?) async -> Bool) {
        self.entry = entry
        self.onSave = onSave
        _description = State(initialValue: entry.description ?? "")
        _start = State(initialValue: entry.timeInterval.start)
        _selectedProjectId = State(initialValue: entry.projectId)

        if let endDate = entry.timeInterval.end {
            _hasEndDate = State(initialValue: true)
            _end = State(initialValue: endDate)
        } else {
            _hasEndDate = State(initialValue: false)
            _end = State(initialValue: Date())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.editEntryTitle)
                .font(DS.Font.sheetTitle)
                .foregroundStyle(DS.Palette.ink)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 10) {
                TextField(L10n.editEntryDescription, text: $description)
                    .textFieldStyle(.ds)

                HStack(spacing: 10) {
                    Text(L10n.projectLabel)
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.Palette.ink2)
                        .frame(width: 90, alignment: .leading)

                    ProjectPickerMenu(
                        projects: appState.projects,
                        selectedProjectId: selectedProjectId,
                        strong: true,
                        onSelect: { selectedProjectId = $0 }
                    )
                    Spacer()
                }

                HStack(spacing: 10) {
                    Text("Start")
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.Palette.ink2)
                        .frame(width: 90, alignment: .leading)

                    DatePicker("", selection: $start)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer()
                }

                Toggle(isOn: $hasEndDate) {
                    Text(L10n.editEntryHasEnd)
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.Palette.ink2)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(DS.Palette.ok)

                if hasEndDate {
                    HStack(spacing: 10) {
                        Text(L10n.editEntryEnd)
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.Palette.ink2)
                            .frame(width: 90, alignment: .leading)

                        DatePicker("", selection: $end)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 14)

            // The sheet used to stay open with no explanation when a save failed —
            // the reason only ever landed in the main window's status bar, which is
            // covered by this sheet.
            if let saveError {
                Text(saveError)
                    .font(DS.Font.warnText)
                    .foregroundStyle(DS.Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
                    .accessibilityAddTraits(.isStaticText)
            }

            HStack {
                Spacer()
                Button(L10n.editEntryCancel) {
                    dismiss()
                }
                .buttonStyle(.dsStandard)
                .disabled(isSaving)

                Button(L10n.editEntrySave) {
                    guard !isSaving else { return }

                    isSaving = true
                    saveError = nil
                    Task {
                        let saved = await onSave(description, start, hasEndDate ? end : nil, selectedProjectId)
                        isSaving = false

                        if saved {
                            dismiss()
                        } else {
                            saveError = appState.statusMessage.isEmpty
                                ? L10n.errorUnknownApi
                                : appState.statusMessage
                        }
                    }
                }
                .buttonStyle(DSButtonStyle(kind: .prominent))
                .disabled(!isValid || isSaving || appState.isLoading)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(width: 440)
        .background(DS.Palette.bg)
    }
}

// MARK: - Create project sheet

private struct CreateProjectSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: String = "#c9724c"
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private let presetColors = [
        "#c9724c", "#7d6eb8", "#c24e7a", "#d08a3c",
        "#4aa572", "#3b9a8c", "#4e8bc9", "#7a4ea8",
        "#c5544a", "#cf9c2e", "#3d9b5e", "#2e8a7a"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.createProjectTitle)
                .font(DS.Font.sheetTitle)
                .foregroundStyle(DS.Palette.ink)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 10) {
                TextField(L10n.createProjectName, text: $name)
                    .textFieldStyle(.ds)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.createProjectColor.uppercased())
                        .font(DS.Font.formLabel)
                        .tracking(0.8)
                        .foregroundStyle(DS.Palette.ink3)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 6), spacing: 8) {
                        ForEach(presetColors, id: \.self) { color in
                            ColorSwatch(hex: color, selected: selectedColor == color) {
                                selectedColor = color
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 14)

            if let saveError {
                Text(saveError)
                    .font(DS.Font.warnText)
                    .foregroundStyle(DS.Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
                    .accessibilityAddTraits(.isStaticText)
            }

            HStack {
                Spacer()
                Button(L10n.editEntryCancel) {
                    dismiss()
                }
                .buttonStyle(.dsStandard)
                .disabled(isSaving)

                Button(L10n.createProjectButton) {
                    guard !isSaving else { return }

                    isSaving = true
                    saveError = nil
                    Task {
                        let created = await appState.createProject(name: name, color: selectedColor)
                        isSaving = false

                        if created {
                            dismiss()
                        } else {
                            saveError = appState.statusMessage.isEmpty
                                ? L10n.errorUnknownApi
                                : appState.statusMessage
                        }
                    }
                }
                .buttonStyle(DSButtonStyle(kind: .prominent))
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || appState.isLoading)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(width: 380)
        .background(DS.Palette.bg)
    }
}

private struct ColorSwatch: View {
    let hex: String
    let selected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex) ?? DS.Palette.ink4)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .strokeBorder(DS.Palette.ink, lineWidth: selected ? 2 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(DS.Palette.bg, lineWidth: selected ? 1 : 0)
                        .padding(2)
                )
                .scaleEffect(hovered ? 1.08 : 1)
                .animation(.easeOut(duration: 0.1), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        // Selection was signalled by a ring alone — colour/shape only, with no
        // name and no state exposed to assistive technology.
        .accessibilityLabel(L10n.a11yColor(hex))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .help(hex)
    }
}
