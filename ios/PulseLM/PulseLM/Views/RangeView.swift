import SwiftUI

/// Full driving range. Landings come from RangeLanding.from(carry:hla:) on shot JSON.
struct RangeView: View {
    var shot: ShotResult?
    var session: [ShotResult] = []
    @State private var pinYards: Double = 150

    private var landing: RangeLanding {
        RangeLanding.from(carry: shot?.carry_yd_est, hla: shot?.hla_deg)
    }

    var body: some View {
        VStack(spacing: 0) {
            pinPicker
            canvas
            callout
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Driving range")
        .accessibilityValue(accessibilityLanding)
    }

    private var pinPicker: some View {
        HStack(spacing: 6) {
            Text("PIN")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            ForEach([100.0, 150.0, 200.0, 250.0], id: \.self) { yd in
                Button {
                    pinYards = yd
                } label: {
                    Text("\(Int(yd))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(pinYards == yd ? Color.black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(pinYards == yd ? Color(red: 0.24, green: 1.0, blue: 0.60) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if let miss = missCall {
                Text(miss)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.24, green: 1.0, blue: 0.60))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.35))
    }

    private var missCall: String? {
        guard let along = landing.alongYd else { return nil }
        let off = landing.offlineYd ?? 0
        let dAlong = along - pinYards
        let dist = (dAlong * dAlong + off * off).squareRoot()
        if abs(off) < 0.5 {
            return String(format: "%.0f yd to pin", dist)
        }
        let lr = off >= 0 ? "R" : "L"
        return String(format: "%.0f yd · %@%.0f", dist, lr, abs(off))
    }

    private var canvas: some View {
        Color.clear
            .aspectRatio(0.55, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 440)
            .overlay {
                GeometryReader { geo in
                    ZStack {
                        RangeScenery(pinYards: pinYards)
                        sessionDots(size: geo.size)
                        tracerAndBall(size: geo.size)
                    }
                }
            }
    }

    @ViewBuilder
    private func sessionDots(size: CGSize) -> some View {
        let prior = session.filter { $0.shot_id != shot?.shot_id && $0.ok && $0.carry_yd_est != nil }
        ForEach(prior.suffix(24), id: \.shot_id) { s in
            let land = RangeLanding.from(shot: s)
            if let along = land.alongYd {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .position(RangeLayout.point(along: along, offline: land.offlineYd ?? 0, size: size))
            }
        }
    }

    @ViewBuilder
    private func tracerAndBall(size: CGSize) -> some View {
        if let along = landing.alongYd {
            let offline = landing.offlineYd ?? 0
            let landPt = RangeLayout.point(along: along, offline: offline, size: size)
            let tee = RangeLayout.point(along: 0, offline: 0, size: size)
            ShotTracer(
                tee: tee,
                land: landPt,
                vla: shot?.vla_deg ?? 12
            )
            LandingMarker(
                onLine: landing.onLine,
                carry: shot?.carry_yd_est,
                offline: landing.offlineYd
            )
            .position(landPt)
            .animation(.easeOut(duration: 0.45), value: along)
            .animation(.easeOut(duration: 0.45), value: offline)
        }
    }

    private var callout: some View {
        HStack {
            Text("RANGE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            if let along = landing.alongYd {
                Text(String(format: "%.0f yd carry", along))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if !landing.onLine, let off = landing.offlineYd {
                    Text(String(format: "· %.1f yd off", off))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("Waiting for shot")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
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
    static let maxAlongYd: Double = 320
    static let maxOfflineYd: Double = 50
    static let markers: [Double] = [50, 100, 150, 200, 250, 300]
    static let topInset: CGFloat = 36
    static let bottomInset: CGFloat = 28

    static func depth(_ along: Double) -> CGFloat {
        let t = min(max(along / maxAlongYd, 0), 1.12)
        return CGFloat(pow(t, 0.82))
    }

    static func point(along: Double, offline: Double, size: CGSize) -> CGPoint {
        let top = topInset
        let bottom = size.height - bottomInset
        let y = bottom - depth(along) * (bottom - top)
        let scale = 0.22 + 0.78 * (1 - depth(along))
        let x = size.width / 2 + CGFloat(offline / maxOfflineYd) * (size.width * 0.46) * scale
        return CGPoint(x: x, y: y)
    }

    static func fairwayHalfWidth(along: Double, size: CGSize) -> CGFloat {
        let tee: CGFloat = size.width * 0.13
        let far: CGFloat = size.width * 0.48
        return tee + (far - tee) * depth(along)
    }
}

private struct ShotTracer: View {
    var tee: CGPoint
    var land: CGPoint
    var vla: Double

    var body: some View {
        Canvas { context, _ in
            let peak = min(90.0, 18.0 + max(vla, 0) * 2.4)
            let ctrl = CGPoint(
                x: (tee.x + land.x) / 2,
                y: min(tee.y, land.y) - peak
            )
            var path = Path()
            path.move(to: tee)
            path.addQuadCurve(to: land, control: ctrl)
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.24, green: 1.0, blue: 0.60).opacity(0.15),
                        Color(red: 0.24, green: 1.0, blue: 0.60),
                    ]),
                    startPoint: tee,
                    endPoint: land
                ),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
            )
        }
        .allowsHitTesting(false)
    }
}

private struct RangeScenery: View {
    var pinYards: Double

    var body: some View {
        Canvas { context, size in
            drawSky(context: &context, size: size)
            drawHills(context: &context, size: size)
            drawRoughAndFairway(context: &context, size: size)
            drawBunkers(context: &context, size: size)
            drawGrid(context: &context, size: size)
            drawTargetLine(context: &context, size: size)
            drawMarkers(context: &context, size: size)
            drawFlags(context: &context, size: size)
            drawTrees(context: &context, size: size)
            drawTee(context: &context, size: size)
        }
    }

    private func drawSky(context: inout GraphicsContext, size: CGSize) {
        let sky = Path(CGRect(origin: .zero, size: size))
        context.fill(sky, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.30, green: 0.58, blue: 0.88),
                Color(red: 0.62, green: 0.82, blue: 0.95),
                Color(red: 0.78, green: 0.90, blue: 0.72),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height * 0.42)
        ))
        let sun = Path(ellipseIn: CGRect(x: size.width * 0.78, y: 10, width: 28, height: 28))
        context.fill(sun, with: .color(Color(red: 1.0, green: 0.92, blue: 0.55).opacity(0.9)))
    }

    private func drawHills(context: inout GraphicsContext, size: CGSize) {
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: RangeLayout.topInset + 18))
        hills.addQuadCurve(
            to: CGPoint(x: size.width, y: RangeLayout.topInset + 22),
            control: CGPoint(x: size.width * 0.5, y: 8)
        )
        hills.addLine(to: CGPoint(x: size.width, y: size.height))
        hills.addLine(to: CGPoint(x: 0, y: size.height))
        hills.closeSubpath()
        context.fill(hills, with: .color(Color(red: 0.10, green: 0.28, blue: 0.12)))
    }

    private func drawRoughAndFairway(context: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        var rough = Path()
        let rL = RangeLayout.point(along: 0, offline: -48, size: size)
        let rR = RangeLayout.point(along: 0, offline: 48, size: size)
        let rFarL = RangeLayout.point(along: 320, offline: -48, size: size)
        let rFarR = RangeLayout.point(along: 320, offline: 48, size: size)
        rough.move(to: CGPoint(x: 0, y: size.height))
        rough.addLine(to: CGPoint(x: size.width, y: size.height))
        rough.addLine(to: rFarR)
        rough.addLine(to: rFarL)
        rough.closeSubpath()
        context.fill(rough, with: .color(Color(red: 0.13, green: 0.34, blue: 0.14)))

        var fairway = Path()
        let teeHalf = RangeLayout.fairwayHalfWidth(along: 0, size: size)
        let farHalf = RangeLayout.fairwayHalfWidth(along: 320, size: size)
        let bottom = RangeLayout.point(along: 0, offline: 0, size: size).y
        let top = RangeLayout.point(along: 320, offline: 0, size: size).y
        fairway.move(to: CGPoint(x: cx - teeHalf, y: bottom))
        fairway.addLine(to: CGPoint(x: cx + teeHalf, y: bottom))
        fairway.addLine(to: CGPoint(x: cx + farHalf, y: top))
        fairway.addLine(to: CGPoint(x: cx - farHalf, y: top))
        fairway.closeSubpath()
        context.fill(fairway, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.32, green: 0.66, blue: 0.28),
                Color(red: 0.48, green: 0.78, blue: 0.36),
            ]),
            startPoint: CGPoint(x: cx, y: bottom),
            endPoint: CGPoint(x: cx, y: top)
        ))
        _ = (rL, rR, rFarL, rFarR)
    }

    private func drawBunkers(context: inout GraphicsContext, size: CGSize) {
        let spots: [(Double, Double, CGFloat, CGFloat)] = [
            (118, -18, 22, 8),
            (162, 16, 18, 7),
            (208, -12, 16, 6),
            (248, 20, 14, 5),
        ]
        for (along, off, w, h) in spots {
            let p = RangeLayout.point(along: along, offline: off, size: size)
            let scale = 0.45 + 0.55 * (1 - RangeLayout.depth(along))
            let rect = CGRect(x: p.x - w * scale, y: p.y - h * scale * 0.4, width: w * 2 * scale, height: h * 2 * scale)
            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.83, green: 0.72, blue: 0.42)))
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        for yd in stride(from: 25.0, through: 300.0, by: 25.0) {
            let y = RangeLayout.point(along: yd, offline: 0, size: size).y
            let half = RangeLayout.fairwayHalfWidth(along: yd, size: size)
            var tick = Path()
            tick.move(to: CGPoint(x: size.width / 2 - half, y: y))
            tick.addLine(to: CGPoint(x: size.width / 2 + half, y: y))
            context.stroke(tick, with: .color(.white.opacity(yd.truncatingRemainder(dividingBy: 50) == 0 ? 0.22 : 0.08)), lineWidth: 0.8)
        }
    }

    private func drawTargetLine(context: inout GraphicsContext, size: CGSize) {
        let tee = RangeLayout.point(along: 0, offline: 0, size: size)
        let far = RangeLayout.point(along: 320, offline: 0, size: size)
        var line = Path()
        line.move(to: tee)
        line.addLine(to: far)
        context.stroke(line, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.4, dash: [7, 6]))
    }

    private func drawMarkers(context: inout GraphicsContext, size: CGSize) {
        for yd in RangeLayout.markers {
            let p = RangeLayout.point(along: yd, offline: 0, size: size)
            let half = RangeLayout.fairwayHalfWidth(along: yd, size: size)
            let label = Text("\(Int(yd))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            context.draw(label, at: CGPoint(x: size.width / 2 + half + 6, y: p.y), anchor: .leading)
        }
    }

    private func drawFlags(context: inout GraphicsContext, size: CGSize) {
        for yd in [100.0, 150.0, 200.0, 250.0] {
            let p = RangeLayout.point(along: yd, offline: 0, size: size)
            let h: CGFloat = yd == pinYards ? 22 : 14
            var pole = Path()
            pole.move(to: p)
            pole.addLine(to: CGPoint(x: p.x, y: p.y - h))
            context.stroke(pole, with: .color(.white.opacity(0.9)), lineWidth: 1.2)
            var flag = Path()
            flag.move(to: CGPoint(x: p.x, y: p.y - h))
            flag.addLine(to: CGPoint(x: p.x + 10, y: p.y - h + 5))
            flag.addLine(to: CGPoint(x: p.x, y: p.y - h + 10))
            flag.closeSubpath()
            let color = yd == pinYards ? Color(red: 0.95, green: 0.2, blue: 0.22) : Color.white.opacity(0.75)
            context.fill(flag, with: .color(color))
        }
        let green = RangeLayout.point(along: pinYards, offline: 0, size: size)
        let gRect = CGRect(x: green.x - 16, y: green.y - 6, width: 32, height: 12)
        context.fill(Path(ellipseIn: gRect), with: .color(Color(red: 0.22, green: 0.55, blue: 0.22).opacity(0.85)))
    }

    private func drawTrees(context: inout GraphicsContext, size: CGSize) {
        let trees: [(Double, Double, CGFloat)] = [
            (40, -42, 18), (90, 44, 16), (140, -46, 20), (190, 48, 14), (240, -44, 16), (280, 42, 12),
        ]
        for (along, off, h) in trees {
            let p = RangeLayout.point(along: along, offline: off, size: size)
            let trunk = Path(CGRect(x: p.x - 1.5, y: p.y - h * 0.25, width: 3, height: h * 0.3))
            context.fill(trunk, with: .color(Color(red: 0.28, green: 0.16, blue: 0.08)))
            var canopy = Path()
            canopy.move(to: CGPoint(x: p.x, y: p.y - h))
            canopy.addLine(to: CGPoint(x: p.x + h * 0.38, y: p.y - h * 0.2))
            canopy.addLine(to: CGPoint(x: p.x - h * 0.38, y: p.y - h * 0.2))
            canopy.closeSubpath()
            context.fill(canopy, with: .color(Color(red: 0.08, green: 0.28, blue: 0.12)))
        }
    }

    private func drawTee(context: inout GraphicsContext, size: CGSize) {
        let tee = RangeLayout.point(along: 0, offline: 0, size: size)
        let mat = CGRect(x: tee.x - 16, y: tee.y - 6, width: 32, height: 12)
        context.fill(RoundedRectangle(cornerRadius: 2).path(in: mat), with: .color(Color(red: 0.22, green: 0.18, blue: 0.12)))
        context.fill(
            Path(ellipseIn: CGRect(x: tee.x - 5, y: tee.y - 5, width: 10, height: 8)),
            with: .color(Color(red: 0.85, green: 0.82, blue: 0.72))
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
    RangeView(shot: .sample, session: [.sample])
        .padding()
        .background(Color.black)
}
