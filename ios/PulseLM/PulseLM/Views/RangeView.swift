import SwiftUI

/// Driving-range canvas. Ball position comes only from `RangeLanding.from(carry:hla:)`.
struct RangeView: View {
    var shot: ShotResult?

    private var landing: RangeLanding {
        RangeLanding.from(carry: shot?.carry_yd_est, hla: shot?.hla_deg)
    }

    var body: some View {
        Color.clear
            .aspectRatio(0.72, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 280)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        RangeScenery()
                        if let along = landing.alongYd {
                            let offline = landing.offlineYd ?? 0
                            let point = RangeLayout.point(along: along, offline: offline, size: geo.size)
                            LandingMarker(
                                onLine: landing.onLine,
                                carry: shot?.carry_yd_est,
                                offline: landing.offlineYd
                            )
                                .position(point)
                                .animation(.easeOut(duration: 0.45), value: along)
                                .animation(.easeOut(duration: 0.45), value: offline)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Driving range")
        .accessibilityValue(accessibilityLanding)
    }

    private var accessibilityLanding: String {
        guard let along = landing.alongYd else { return "no landing" }
        let off = landing.offlineYd ?? 0
        if landing.onLine {
            return String(format: "on target line, %.0f yards", along)
        }
        return String(format: "%.0f yards along, %.1f yards offline", along, off)
    }
}

enum RangeLayout {
    static let maxAlongYd: Double = 300
    static let maxOfflineYd: Double = 45
    static let markers: [Double] = [50, 100, 150, 200, 250]
    static let topInset: CGFloat = 28
    static let bottomInset: CGFloat = 22

    static func point(along: Double, offline: Double, size: CGSize) -> CGPoint {
        let top = topInset
        let bottom = size.height - bottomInset
        let clampedAlong = min(max(along, 0), maxAlongYd)
        let t = CGFloat(clampedAlong / maxAlongYd)
        let y = bottom - t * (bottom - top)
        let x = size.width / 2 + CGFloat(offline / maxOfflineYd) * (size.width * 0.42)
        return CGPoint(x: x, y: y)
    }

    static func fairwayHalfWidth(t: CGFloat, size: CGSize) -> CGFloat {
        let tee = size.width * 0.14
        let far = size.width * 0.46
        return tee + (far - tee) * t
    }
}

private struct RangeScenery: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.62, blue: 0.92),
                    Color(red: 0.55, green: 0.78, blue: 0.95),
                    Color(red: 0.18, green: 0.38, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, canvasSize in
                drawRoughAndFairway(context: &context, size: canvasSize)
                drawTargetLine(context: &context, size: canvasSize)
                drawMarkers(context: &context, size: canvasSize)
                drawTee(context: &context, size: canvasSize)
            }
        }
    }

    private func drawRoughAndFairway(context: inout GraphicsContext, size: CGSize) {
        let bottom = size.height - RangeLayout.bottomInset
        let top = RangeLayout.topInset
        var rough = Path()
        rough.move(to: CGPoint(x: 0, y: size.height))
        rough.addLine(to: CGPoint(x: size.width, y: size.height))
        rough.addLine(to: CGPoint(x: size.width, y: top))
        rough.addLine(to: CGPoint(x: 0, y: top))
        rough.closeSubpath()
        context.fill(rough, with: .color(Color(red: 0.12, green: 0.32, blue: 0.12)))

        var fairway = Path()
        let teeHalf = RangeLayout.fairwayHalfWidth(t: 0, size: size)
        let farHalf = RangeLayout.fairwayHalfWidth(t: 1, size: size)
        let cx = size.width / 2
        fairway.move(to: CGPoint(x: cx - teeHalf, y: bottom))
        fairway.addLine(to: CGPoint(x: cx + teeHalf, y: bottom))
        fairway.addLine(to: CGPoint(x: cx + farHalf, y: top))
        fairway.addLine(to: CGPoint(x: cx - farHalf, y: top))
        fairway.closeSubpath()
        context.fill(fairway, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.28, green: 0.62, blue: 0.28),
                Color(red: 0.42, green: 0.74, blue: 0.34),
            ]),
            startPoint: CGPoint(x: cx, y: bottom),
            endPoint: CGPoint(x: cx, y: top)
        ))
    }

    private func drawTargetLine(context: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        var line = Path()
        line.move(to: CGPoint(x: cx, y: size.height - RangeLayout.bottomInset))
        line.addLine(to: CGPoint(x: cx, y: RangeLayout.topInset))
        context.stroke(
            line,
            with: .color(.white.opacity(0.85)),
            style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
        )
    }

    private func drawMarkers(context: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        for yd in RangeLayout.markers {
            let t = CGFloat(yd / RangeLayout.maxAlongYd)
            let y = RangeLayout.point(along: yd, offline: 0, size: size).y
            let half = RangeLayout.fairwayHalfWidth(t: t, size: size)
            var tick = Path()
            tick.move(to: CGPoint(x: cx - half, y: y))
            tick.addLine(to: CGPoint(x: cx + half, y: y))
            context.stroke(tick, with: .color(.white.opacity(0.28)), lineWidth: 1)

            let label = Text("\(Int(yd)) yd")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            context.draw(label, at: CGPoint(x: cx + half + 4, y: y), anchor: .leading)
        }
    }

    private func drawTee(context: inout GraphicsContext, size: CGSize) {
        let tee = RangeLayout.point(along: 0, offline: 0, size: size)
        let rect = CGRect(x: tee.x - 10, y: tee.y - 5, width: 20, height: 10)
        context.fill(
            RoundedRectangle(cornerRadius: 2).path(in: rect),
            with: .color(Color(red: 0.75, green: 0.55, blue: 0.18))
        )
    }
}

private struct LandingMarker: View {
    var onLine: Bool
    var carry: Double?
    var offline: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 22, height: 10)
                .offset(y: 7)
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color(red: 0.24, green: 1.0, blue: 0.60), lineWidth: 2))
                .shadow(color: Color(red: 0.24, green: 1.0, blue: 0.60).opacity(0.7), radius: 6)
            VStack(spacing: 2) {
                if let carry {
                    Text(ShotMapping.carryString(carry) + " yd")
                }
                if !onLine, let offline {
                    Text(ShotMapping.metricString(offline, decimals: 1) + " yd off")
                }
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.45), in: Capsule())
            .offset(y: 22)
            .opacity((carry == nil && onLine) ? 0 : 1)
        }
        .frame(width: 72, height: 56)
        .accessibilityLabel(onLine ? "Landing on target line" : "Landing offline")
    }
}

#Preview {
    RangeView(shot: .sample)
        .padding()
        .background(Color.black)
}
