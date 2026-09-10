import SwiftUI

/// Full driving range. Landings come from RangeLanding.from(carry:hla:) on shot JSON.
struct RangeView: View {
    var shot: ShotResult?
    var session: [ShotResult] = []
    var practice: PracticePayload?
    var holeMap: CourseHoleMap? = nil
    var pinOverride: Double? = nil
    @Binding var selectedClub: String
    @Binding var gameMode: String
    @State private var pinYards: Double = 250

    init(
        shot: ShotResult?,
        session: [ShotResult] = [],
        practice: PracticePayload? = nil,
        holeMap: CourseHoleMap? = nil,
        pinOverride: Double? = nil,
        selectedClub: Binding<String> = .constant("Dr"),
        gameMode: Binding<String> = .constant("practice")
    ) {
        self.shot = shot
        self.session = session
        self.practice = practice
        self.holeMap = holeMap
        self.pinOverride = pinOverride
        self._selectedClub = selectedClub
        self._gameMode = gameMode
    }

    private var landing: RangeLanding {
        RangeLanding.from(carry: shot?.carry_yd_est, hla: shot?.hla_deg)
    }

    var body: some View {
        VStack(spacing: 0) {
            clubAndGame
            pinPicker
            dataTiles
            canvas
            gamesStrip
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
        .onAppear {
            if let pinOverride { pinYards = pinOverride }
        }
        .onChange(of: pinOverride) { _, new in
            if let new { pinYards = new }
        }
    }

    private var clubAndGame: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(practice?.clubs ?? ["Dr", "7i", "PW", "SW"], id: \.self) { c in
                    Button(c) { selectedClub = c }
                }
            } label: {
                Text(selectedClub)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
            ForEach(["practice", "closest", "longest", "random"], id: \.self) { g in
                Button {
                    gameMode = g
                    if g == "random" {
                        pinYards = [150, 200, 250, 300, 400].randomElement() ?? 250
                    }
                } label: {
                    Text(g.prefix(1).uppercased() + g.dropFirst())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(gameMode == g ? Color.black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(gameMode == g ? Color(red: 0.24, green: 1.0, blue: 0.60) : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private var dataTiles: some View {
        let t = practice?.tiles
        let smash = t?.smash.map { String(format: "%.2f", $0) } ?? "—"
        let apex = t?.apex_yd.map { String(format: "%.0f", $0) } ?? "—"
        let hang = t?.hang_time_s.map { String(format: "%.1fs", $0) } ?? "—"
        let land = t?.land_angle_deg.map { String(format: "%.0f°", $0) } ?? "—"
        let total = t?.total_yd_est.map { String(format: "%.0f", $0) } ?? "—"
        let curve = t?.curve_yd.map { String(format: "%.1f", $0) } ?? "—"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                miniTile("Smash", smash)
                miniTile("Apex", apex)
                miniTile("Hang", hang)
                miniTile("Land", land)
                miniTile("Total", total)
                miniTile("Curve", curve)
            }
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 4)
    }

    private func miniTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var gamesStrip: some View {
        HStack {
            if gameMode == "closest", let d = practice?.tiles?.dist_to_pin_yd {
                Text(String(format: "CTP  %.1f yd to pin", d))
            } else if gameMode == "longest" {
                let best = session.compactMap(\.carry_yd_est).max()
                Text(best.map { String(format: "Longest  %.0f yd", $0) } ?? "Longest  —")
            } else if gameMode == "random" {
                Text(String(format: "Random pin  %.0f yd", pinYards))
            } else {
                Text("Practice")
            }
            Spacer()
            Text("Tour 8 yd · 15hcp 22 yd")
                .foregroundStyle(.white.opacity(0.4))
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.24, green: 1.0, blue: 0.60))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var pinPicker: some View {
        HStack(spacing: 6) {
            Text("PIN")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            ForEach([150.0, 200.0, 250.0, 300.0, 400.0, 500.0], id: \.self) { yd in
                Button {
                    pinYards = yd
                } label: {
                    Text("\(Int(yd))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(pinYards == yd ? Color.black : .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
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
                        if let holeMap {
                            OsmHoleLayer(map: holeMap)
                        }
                        sessionDots(size: geo.size)
                        dispersionRings(size: geo.size)
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
    private func dispersionRings(size: CGSize) -> some View {
        let lands = session.compactMap { s -> CGPoint? in
            let land = RangeLanding.from(shot: s)
            guard let along = land.alongYd else { return nil }
            return RangeLayout.point(along: along, offline: land.offlineYd ?? 0, size: size)
        }
        if lands.count >= 2 {
            let mx = lands.map(\.x).reduce(0, +) / CGFloat(lands.count)
            let my = lands.map(\.y).reduce(0, +) / CGFloat(lands.count)
            let p = RangeLayout.point(along: 250, offline: 0, size: size)
            let scale = max(6.0, abs(p.y - RangeLayout.point(along: 250 + 8, offline: 0, size: size).y))
            Circle()
                .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                .frame(width: scale * 2, height: scale * 1.1)
                .position(x: mx, y: my)
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: scale * 5.5, height: scale * 3)
                .position(x: mx, y: my)
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

private struct OsmHoleLayer: View {
    var map: CourseHoleMap

    var body: some View {
        Canvas { context, size in
            fillRings(map.rough, Color(red: 0.12, green: 0.32, blue: 0.12), context: &context, size: size)
            fillRings(map.fairways, Color(red: 0.34, green: 0.70, blue: 0.30), context: &context, size: size)
            fillRings(map.water, Color(red: 0.20, green: 0.45, blue: 0.75), context: &context, size: size)
            fillRings(map.bunkers, Color(red: 0.83, green: 0.72, blue: 0.42), context: &context, size: size)
            fillRings(map.greens, Color(red: 0.18, green: 0.55, blue: 0.22), context: &context, size: size)
            if let line = map.hole_line, line.count >= 2 {
                var path = Path()
                for (i, pt) in line.enumerated() {
                    guard pt.count >= 2 else { continue }
                    let p = RangeLayout.point(along: pt[1], offline: pt[0], size: size)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                context.stroke(path, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            for t in map.trees ?? [] where t.count >= 2 {
                let p = RangeLayout.point(along: t[1], offline: t[0], size: size)
                var canopy = Path()
                canopy.addEllipse(in: CGRect(x: p.x - 4, y: p.y - 10, width: 8, height: 10))
                context.fill(canopy, with: .color(Color(red: 0.07, green: 0.28, blue: 0.10)))
            }
        }
        .allowsHitTesting(false)
    }

    private func fillRings(_ rings: [[[Double]]]?, _ color: Color, context: inout GraphicsContext, size: CGSize) {
        for ring in rings ?? [] where ring.count >= 3 {
            var path = Path()
            for (i, pt) in ring.enumerated() where pt.count >= 2 {
                let p = RangeLayout.point(along: pt[1], offline: pt[0], size: size)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.fill(path, with: .color(color.opacity(0.92)))
        }
    }
}

enum RangeLayout {
    static let maxAlongYd: Double = 500
    static let maxOfflineYd: Double = 55
    static let markers: [Double] = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500]
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
        let rFarL = RangeLayout.point(along: 500, offline: -48, size: size)
        let rFarR = RangeLayout.point(along: 500, offline: 48, size: size)
        rough.move(to: CGPoint(x: 0, y: size.height))
        rough.addLine(to: CGPoint(x: size.width, y: size.height))
        rough.addLine(to: rFarR)
        rough.addLine(to: rFarL)
        rough.closeSubpath()
        context.fill(rough, with: .color(Color(red: 0.13, green: 0.34, blue: 0.14)))

        var fairway = Path()
        let teeHalf = RangeLayout.fairwayHalfWidth(along: 0, size: size)
        let farHalf = RangeLayout.fairwayHalfWidth(along: 500, size: size)
        let bottom = RangeLayout.point(along: 0, offline: 0, size: size).y
        let top = RangeLayout.point(along: 500, offline: 0, size: size).y
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
            (185, 16, 18, 7),
            (260, -12, 16, 6),
            (340, 20, 14, 5),
            (420, -14, 12, 4),
        ]
        for (along, off, w, h) in spots {
            let p = RangeLayout.point(along: along, offline: off, size: size)
            let scale = 0.45 + 0.55 * (1 - RangeLayout.depth(along))
            let rect = CGRect(x: p.x - w * scale, y: p.y - h * scale * 0.4, width: w * 2 * scale, height: h * 2 * scale)
            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.83, green: 0.72, blue: 0.42)))
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        for yd in stride(from: 25.0, through: 500.0, by: 25.0) {
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
        let far = RangeLayout.point(along: 500, offline: 0, size: size)
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
        for yd in [150.0, 200.0, 250.0, 300.0, 400.0, 500.0] {
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
            (40, -42, 18), (90, 44, 16), (140, -46, 20), (190, 48, 14),
            (250, -44, 16), (320, 42, 12), (390, -46, 14), (460, 40, 11),
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
