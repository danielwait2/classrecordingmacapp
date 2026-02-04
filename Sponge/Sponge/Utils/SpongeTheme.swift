//
//  SpongeTheme.swift
//  Sponge
//
//  Created on 2/3/26.
//

import SwiftUI

/// Sponge app theme - coral and cream colors with clean geometric design
struct SpongeTheme {
    // MARK: - Colors

    /// Primary coral color - main brand color
    static let coral = Color(red: 255/255, green: 127/255, blue: 102/255)

    /// Light coral - for backgrounds and subtle accents
    static let coralLight = Color(red: 255/255, green: 167/255, blue: 147/255)

    /// Very light coral - for card backgrounds
    static let coralPale = Color(red: 255/255, green: 210/255, blue: 200/255)

    /// Cream color - secondary accent
    static let cream = Color(red: 252/255, green: 241/255, blue: 227/255)

    /// Dark cream - for text on light backgrounds
    static let creamDark = Color(red: 230/255, green: 210/255, blue: 190/255)

    /// Background coral - the main app background color
    static let backgroundCoral = Color(red: 255/255, green: 147/255, blue: 127/255)

    // MARK: - Semantic Colors

    /// Primary action color (buttons, links)
    static let primary = coral

    /// Secondary action color
    static let secondary = cream

    /// Success states
    static let success = Color.green

    /// Error states
    static let error = Color.red

    /// Warning states
    static let warning = Color.orange

    // MARK: - Gradients

    /// Primary gradient - coral to light coral
    static let primaryGradient = LinearGradient(
        colors: [coral, coralLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background gradient - subtle coral variation
    static let backgroundGradient = LinearGradient(
        colors: [backgroundCoral.opacity(0.3), coralPale.opacity(0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Card gradient - cream to pale coral
    static let cardGradient = LinearGradient(
        colors: [cream, coralPale],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radius

    /// Small corner radius - for buttons and small cards
    static let cornerRadiusS: CGFloat = 8

    /// Medium corner radius - for cards
    static let cornerRadiusM: CGFloat = 12

    /// Large corner radius - for main containers
    static let cornerRadiusL: CGFloat = 20

    /// Extra large corner radius - for hero elements
    static let cornerRadiusXL: CGFloat = 28

    // MARK: - Shadows

    /// Subtle shadow for cards
    static let shadowS = Color.black.opacity(0.05)

    /// Medium shadow for elevated elements
    static let shadowM = Color.black.opacity(0.1)

    /// Strong shadow for modals and overlays
    static let shadowL = Color.black.opacity(0.2)
}

// MARK: - View Extensions

extension View {
    /// Applies the primary Sponge button style
    func spongeButtonStyle() -> some View {
        self
            .padding(.horizontal, SpongeTheme.spacingL)
            .padding(.vertical, SpongeTheme.spacingM)
            .background(SpongeTheme.primaryGradient)
            .foregroundColor(.white)
            .cornerRadius(SpongeTheme.cornerRadiusM)
            .shadow(color: SpongeTheme.shadowM, radius: 4, x: 0, y: 2)
    }

    /// Applies the secondary Sponge button style
    func spongeSecondaryButtonStyle() -> some View {
        self
            .padding(.horizontal, SpongeTheme.spacingL)
            .padding(.vertical, SpongeTheme.spacingM)
            .background(SpongeTheme.cream)
            .foregroundColor(SpongeTheme.coral)
            .cornerRadius(SpongeTheme.cornerRadiusM)
            .shadow(color: SpongeTheme.shadowS, radius: 2, x: 0, y: 1)
    }

    /// Applies the Sponge card style
    func spongeCardStyle() -> some View {
        self
            .background(SpongeTheme.cream)
            .cornerRadius(SpongeTheme.cornerRadiusL)
            .shadow(color: SpongeTheme.shadowM, radius: 8, x: 0, y: 4)
    }

    /// Applies the Sponge background gradient
    func spongeBackground() -> some View {
        self
            .background(SpongeTheme.backgroundGradient.ignoresSafeArea())
    }
}

// MARK: - Sponge Icon Pattern View

/// A decorative view that mimics the sponge hole pattern from the app icon
struct SpongePatternView: View {
    let size: CGFloat
    let color: Color
    let spacing: CGFloat

    init(size: CGFloat = 300, color: Color = SpongeTheme.coral.opacity(0.1), spacing: CGFloat = 30) {
        self.size = size
        self.color = color
        self.spacing = spacing
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(geometry.size.width / spacing) + 1
            let rows = Int(geometry.size.height / spacing) + 1

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let circleSize = spacing * 0.4

                        let circle = Circle()
                            .path(in: CGRect(x: x - circleSize/2, y: y - circleSize/2, width: circleSize, height: circleSize))

                        context.fill(circle, with: .color(color))
                    }
                }
            }
        }
    }
}
