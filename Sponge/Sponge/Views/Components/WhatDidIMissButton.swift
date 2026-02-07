import SwiftUI

/// Floating button for requesting catch-up summaries with popover display
struct WhatDidIMissButton: View {
    @Binding var isLoading: Bool
    let lastSummary: CatchUpSummary?
    let onTap: () -> Void

    @State private var showingPopover = false

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: SpongeTheme.spacingS) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(buttonText)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, SpongeTheme.spacingM)
            .padding(.vertical, SpongeTheme.spacingS)
            .background(
                Capsule()
                    .fill(SpongeTheme.coral)
                    .shadow(color: SpongeTheme.shadowM, radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .popover(isPresented: $showingPopover) {
            CatchUpPopover(
                summary: lastSummary,
                isLoading: isLoading,
                onRequestNew: {
                    showingPopover = false
                    onTap()
                }
            )
        }
    }

    private var buttonText: String {
        if isLoading {
            return "Loading..."
        } else if lastSummary != nil {
            return "Show Summary"
        } else {
            return "What did I miss?"
        }
    }

    private func handleTap() {
        if lastSummary != nil && !isLoading {
            // Show popover with existing summary (can request new from there)
            showingPopover = true
        } else if !isLoading {
            // Request first summary
            onTap()
        }
    }
}

/// Popover view showing the catch-up summary with option to request new one
private struct CatchUpPopover: View {
    let summary: CatchUpSummary?
    let isLoading: Bool
    let onRequestNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpongeTheme.spacingM) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(SpongeTheme.coral)
                Text("Catch-Up Summary")
                    .font(.headline)
                Spacer()

                // New summary button
                Button(action: onRequestNew) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("New")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(SpongeTheme.coral)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            if let summary = summary {
                // Time range
                Text("Covering: \(summary.formattedRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Summary content
                ScrollView {
                    Text(summary.summary)
                        .font(.body)
                        .lineSpacing(4)
                }
                .frame(maxHeight: 300)
            } else {
                Text("No summary available yet. Tap 'New' to generate one.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(SpongeTheme.spacingM)
        .frame(width: 320)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Default state
        WhatDidIMissButton(
            isLoading: .constant(false),
            lastSummary: nil,
            onTap: {}
        )

        // Loading state
        WhatDidIMissButton(
            isLoading: .constant(true),
            lastSummary: nil,
            onTap: {}
        )

        // With summary
        WhatDidIMissButton(
            isLoading: .constant(false),
            lastSummary: CatchUpSummary(
                requestedAt: 300,
                coveringFrom: 150,
                summary: "The professor discussed the key differences between object-oriented and functional programming paradigms. Key points included: immutability in functional programming, the role of side effects, and how both approaches handle state management."
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
