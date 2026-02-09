import SwiftUI

/// Detail view for a recording with segmented navigation
struct RecordingDetailView: View {
    let recording: SDRecording
    let className: String

    @State private var selectedTab: DetailTab = .transcript
    @Environment(\.dismiss) private var dismiss

    enum DetailTab: String, CaseIterable, Identifiable {
        case transcript = "Transcript"
        case summaries = "Summaries"
        case recall = "Recall"
        case markers = "Markers"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .transcript:
                return "doc.text"
            case .summaries:
                return "doc.richtext"
            case .recall:
                return "brain.head.profile"
            case .markers:
                return "flag.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Segmented control
            segmentedControl

            Divider()

            // Content
            tabContent
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.headline)

                HStack(spacing: SpongeTheme.spacingS) {
                    Label(recording.formattedDuration, systemImage: "clock")
                    Label(recording.formattedDate, systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(SpongeTheme.coral)
        }
        .padding(SpongeTheme.spacingM)
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: SpongeTheme.spacingS) {
            ForEach(DetailTab.allCases) { tab in
                TabSegmentButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badgeCount: badgeCount(for: tab),
                    onTap: { selectedTab = tab }
                )
            }
        }
        .padding(.horizontal, SpongeTheme.spacingM)
        .padding(.vertical, SpongeTheme.spacingS)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .transcript:
            transcriptView
        case .summaries:
            EnhancedSummaryView(recording: recording)
        case .recall:
            RecallPromptsView(recording: recording)
        case .markers:
            markersView
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
                // Transcript
                if !recording.transcriptText.isEmpty {
                    VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(SpongeTheme.coral)
                            Text("Transcript")
                                .font(.headline)
                            Spacer()
                            Text("\(recording.transcriptText.split(separator: " ").count) words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(recording.transcriptText)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding(SpongeTheme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                            .fill(Color.primaryBackground)
                            .shadow(color: SpongeTheme.shadowS, radius: 4, x: 0, y: 2)
                    )
                } else {
                    emptyState(
                        icon: "waveform",
                        title: "No Transcript",
                        message: "This recording doesn't have a transcript."
                    )
                }

                // User Notes
                if !recording.userNotes.isEmpty {
                    VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(SpongeTheme.coral)
                            Text("Your Notes")
                                .font(.headline)
                        }

                        Text(recording.userNotes)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding(SpongeTheme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                            .fill(Color.primaryBackground)
                            .shadow(color: SpongeTheme.shadowS, radius: 4, x: 0, y: 2)
                    )
                }
            }
            .padding(SpongeTheme.spacingM)
        }
    }

    // MARK: - Markers View

    private var markersView: some View {
        Group {
            if recording.intentMarkers.isEmpty {
                emptyState(
                    icon: "flag",
                    title: "No Markers",
                    message: "You didn't mark any moments during this recording."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: SpongeTheme.spacingS) {
                        // Summary header
                        markersSummary

                        Divider()
                            .padding(.vertical, SpongeTheme.spacingS)

                        // Timeline of markers
                        ForEach(recording.intentMarkers.sorted { $0.timestamp < $1.timestamp }) { marker in
                            MarkerTimelineRow(marker: marker)
                        }
                    }
                    .padding(SpongeTheme.spacingM)
                }
            }
        }
    }

    private var markersSummary: some View {
        HStack(spacing: SpongeTheme.spacingM) {
            ForEach(IntentMarkerType.allCases) { type in
                let count = recording.intentMarkers.filter { $0.type == type }.count
                if count > 0 {
                    MarkerCountBadge(type: type, count: count)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: SpongeTheme.spacingM) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(SpongeTheme.spacingL)
    }

    // MARK: - Badge Count

    private func badgeCount(for tab: DetailTab) -> Int? {
        switch tab {
        case .transcript:
            return nil
        case .summaries:
            var count = 0
            if recording.enhancedSummary?.generalOverview != nil { count += 1 }
            if recording.enhancedSummary?.confusionFocused != nil { count += 1 }
            if recording.enhancedSummary?.examOriented != nil { count += 1 }
            return count > 0 ? count : nil
        case .recall:
            let count = recording.recallPrompts?.questions.count ?? 0
            return count > 0 ? count : nil
        case .markers:
            let count = recording.intentMarkers.count
            return count > 0 ? count : nil
        }
    }
}

// MARK: - Supporting Views

private struct TabSegmentButton: View {
    let tab: RecordingDetailView.DetailTab
    let isSelected: Bool
    let badgeCount: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))

                if let count = badgeCount {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(SpongeTheme.coral))
                }
            }
            .foregroundColor(isSelected ? SpongeTheme.coral : .secondary)
            .padding(.horizontal, SpongeTheme.spacingS)
            .padding(.vertical, SpongeTheme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusS)
                    .fill(isSelected ? SpongeTheme.coral.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MarkerTimelineRow: View {
    let marker: IntentMarker

    var body: some View {
        HStack(alignment: .top, spacing: SpongeTheme.spacingM) {
            // Timestamp
            Text(marker.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)

            // Type indicator
            Circle()
                .fill(markerColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: marker.type.icon)
                        .font(.caption)
                    Text(marker.type.displayName)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(markerColor)

                if let snapshot = marker.transcriptSnapshot {
                    Text("\"...\(snapshot)...\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, SpongeTheme.spacingS)
    }

    private var markerColor: Color {
        switch marker.type {
        case .confused:
            return .orange
        case .important:
            return .red
        case .examRelevant:
            return .yellow
        case .reviewLater:
            return .blue
        }
    }
}

private struct MarkerCountBadge: View {
    let type: IntentMarkerType
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 12))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, SpongeTheme.spacingS)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }

    private var badgeColor: Color {
        switch type {
        case .confused:
            return .orange
        case .important:
            return .red
        case .examRelevant:
            return .yellow
        case .reviewLater:
            return .blue
        }
    }
}

#Preview {
    RecordingDetailView(
        recording: SDRecording(
            classId: UUID(),
            duration: 3600,
            audioFileName: "test.m4a",
            transcriptText: "Today we discussed the fundamentals of algorithms...",
            userNotes: "# Important Notes\n\n- Big O notation\n- Tree structures",
            intentMarkers: [
                IntentMarker(type: .confused, timestamp: 120, transcriptSnapshot: "the time complexity of recursive functions"),
                IntentMarker(type: .important, timestamp: 360, transcriptSnapshot: "this will be on the exam"),
                IntentMarker(type: .examRelevant, timestamp: 600, transcriptSnapshot: "master theorem")
            ],
            enhancedSummary: EnhancedSummary(
                generalOverview: "This lecture covered algorithm analysis...",
                confusionFocused: "Recursion can be confusing because...",
                examOriented: "Key exam topics: Big O, Master Theorem..."
            ),
            recallPrompts: RecallPrompts(questions: [
                RecallQuestion(question: "What is Big O notation?", type: .definition, suggestedAnswer: "Big O describes the upper bound of algorithm time complexity.")
            ])
        ),
        className: "CS 201"
    )
}
