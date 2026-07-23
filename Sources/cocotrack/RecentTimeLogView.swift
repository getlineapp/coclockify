import SwiftUI

struct RecentTimeLogSection: View {
    @EnvironmentObject private var appState: AppState
    let onEditEntry: (ClockifyTimeEntry) -> Void

    var body: some View {
        if appState.recentEntryGroups.isEmpty {
            Text(L10n.recentLogEmpty)
                .font(.system(size: 12.5))
                .foregroundStyle(DS.Palette.ink3)
                .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(appState.recentEntryGroups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        DayGroupHeader(label: group.label, totalSeconds: group.totalSeconds)

                        ForEach(group.entries) { entry in
                            TimeEntryRow(
                                entry: entry,
                                projectName: appState.projectName(for: entry.projectId),
                                projectColorHex: appState.projectColorHex(for: entry.projectId),
                                isRunning: entry.timeInterval.end == nil,
                                onEdit: { onEditEntry(entry) },
                                onStart: {
                                    Task {
                                        await appState.startTimer(
                                            using: entry.description ?? "",
                                            projectId: entry.projectId
                                        )
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day group header

private struct DayGroupHeader: View {
    let label: String
    let totalSeconds: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(DS.Font.dayHead)
                .foregroundStyle(DS.Palette.ink3)

            Rectangle()
                .fill(DS.Palette.lineSoft)
                .frame(height: 0.5)

            Text(totalSeconds.formattedDuration)
                .font(DS.Font.daySum)
                .foregroundStyle(DS.Palette.ink3)
        }
        .padding(.top, 2)
        .padding(.bottom, 3)
    }
}

// MARK: - Time entry row

private struct TimeEntryRow: View {
    let entry: ClockifyTimeEntry
    let projectName: String?
    let projectColorHex: String?
    let isRunning: Bool
    let onEdit: () -> Void
    let onStart: () -> Void

    @State private var isHovered = false

    private var descriptionText: String {
        let raw = entry.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? L10n.noDescription : raw
    }

    var body: some View {
        // Editing an entry used to be reachable only by mouse (tap gesture or
        // right-click). A plain Button keeps the identical look while making the
        // row focusable, keyboard-activatable and visible to VoiceOver.
        Button(action: onEdit) {
            rowContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(descriptionText), \(entry.timeRangeText)")
        .accessibilityHint(L10n.edit)
        .contextMenu {
            Button(L10n.edit) {
                onEdit()
            }
            Button("Start") {
                onStart()
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(hex: projectColorHex ?? "") ?? DS.Palette.ink4)
                .frame(width: DS.Metric.entryBarWidth)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptionText)
                    .font(DS.Font.entryDesc)
                    .foregroundStyle(DS.Palette.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let projectName {
                        Text(projectName)
                            .font(DS.Font.entryMeta)
                            .foregroundStyle(DS.Palette.ink3)
                            .lineLimit(1)

                        Text("·")
                            .font(DS.Font.entryMeta)
                            .foregroundStyle(DS.Palette.ink4)
                    }

                    Text(entry.timeRangeText)
                        .font(DS.Font.entryMeta)
                        .foregroundStyle(DS.Palette.ink3)
                }
            }

            Spacer(minLength: 8)

            if isRunning {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Palette.ok)
                        .frame(width: 6, height: 6)
                    Text(L10n.inProgress)
                        .font(DS.Font.runningBadge)
                        .foregroundStyle(DS.Palette.ok)
                }
            } else if let seconds = entry.durationSeconds {
                Text(seconds.formattedDuration)
                    .font(DS.Font.entryDur)
                    .foregroundStyle(DS.Palette.ink.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: DS.Metric.rowRadius, style: .continuous)
                .fill(isHovered ? DS.Palette.card2 : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Metric.rowRadius))
        .onHover { isHovered = $0 }
    }
}
