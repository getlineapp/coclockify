import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appState.isTracking {
                activeContent
            } else {
                stoppedContent
            }

            DSDivider()
                .padding(.top, 4)

            HStack(spacing: 6) {
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

                Button(L10n.openApp) {
                    openWindow(id: "main")
                }
                .buttonStyle(.dsStandard)

                Spacer()

                Button(L10n.quit) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.dsGhost)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(minWidth: 320)
        .background(DS.Palette.bg)
    }

    @ViewBuilder
    private var activeContent: some View {
        if let entry = appState.runningEntry {
            HStack(spacing: 6) {
                LiveDot(size: 6)
                Text(L10n.menuTimerActive)
                    .font(DS.Font.popHead)
                    .foregroundStyle(DS.Palette.ink)
            }

            Text(appState.runningDescription)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Palette.ink)
                .lineLimit(2)

            HStack {
                ProjectPickerMenu(
                    projects: appState.projects,
                    selectedProjectId: entry.projectId,
                    strong: true,
                    onSelect: { newId in
                        Task { await appState.changeEntryProject(entryId: entry.id, projectId: newId) }
                    }
                )
                Spacer()
            }

            if appState.forceProjects && entry.projectId == nil {
                Text(L10n.projectRequiredForStop)
                    .font(DS.Font.warnText)
                    .foregroundStyle(DS.Palette.warn)
            }

            ElapsedText(text: appState.elapsedText, font: DS.Font.elapsedPopover)
                .padding(.top, 2)

            Button {
                Task { await appState.stopTimer() }
            } label: {
                HStack {
                    Spacer()
                    Label("Stop", systemImage: "stop.fill")
                    Spacer()
                }
            }
            .buttonStyle(.dsDanger)
            .disabled(!appState.canStopTimer)
        }
    }

    @ViewBuilder
    private var stoppedContent: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DS.Palette.ink4)
                .frame(width: 6, height: 6)
            Text(L10n.menuTimerStopped)
                .font(DS.Font.popHead)
                .foregroundStyle(DS.Palette.ink2)
        }

        TextField(L10n.editEntryDescription, text: $appState.timerDraftDescription)
            .textFieldStyle(.ds)
            .onSubmit {
                triggerStart()
            }

        HStack {
            ProjectPickerMenu(
                projects: appState.projects,
                selectedProjectId: appState.timerDraftProjectId,
                strong: true,
                onSelect: { appState.timerDraftProjectId = $0 }
            )

            if appState.forceProjects && appState.timerDraftProjectId == nil {
                Text(L10n.projectRequiredHint)
                    .font(DS.Font.warnText)
                    .foregroundStyle(DS.Palette.warn)
            }
            Spacer()
        }

        Button {
            triggerStart()
        } label: {
            HStack {
                Spacer()
                Label("Start", systemImage: "play.fill")
                Spacer()
            }
        }
        .buttonStyle(.dsProminent)
        .disabled(!appState.canStartTimer || (appState.forceProjects && appState.timerDraftProjectId == nil))
    }

    private func triggerStart() {
        guard appState.canStartTimer,
              !(appState.forceProjects && appState.timerDraftProjectId == nil) else { return }
        Task { await appState.startTimer() }
    }
}
