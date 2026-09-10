import SwiftUI

/// Driving range. Landing marker is computed from carry_yd_est + hla_deg, never scenery constants.
struct RangeView: View {
    var landing: RangeLanding
    private let maxYd: CGFloat = 300
    private let halfOfflineYd: CGFloat = 50

    var body: some View {
        Canvas { context, size in
            let fairway = Path { p in
                p.move(to: CGPoint(x: size.width * 0.32, y: size.height))
                p.addLine(to: CGPoint(x: size.width * 0.68, y: size.height))
                p.addLine(to: CGPoint(x: size.width * 0.58, y: 8))
                p.addLine(to: CGPoint(x: size.width * 0.42, y: 8))
                p.closeSubpath()
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.08, green: 0.14, blue: 0.08)))
            context.fill(fairway, with: .color(Color(red: 0.18, green: 0.42, blue: 0.22)))
            var target = Path()
            target.move(to: CGPoint(x: size.width / 2, y: size.height - 4))
            target.addLine(to: CGPoint(x: size.width / 2, y: 8))
            context.stroke(target, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            for yd in [50, 100, 150, 200, 250] {
                let y = size.height - (CGFloat(yd) / maxYd) * (size.height - 16)
                var tick = Path()
                tick.move(to: CGPoint(x: 16, y: y))
                tick.addLine(to: CGPoint(x: size.width - 16, y: y))
                context.stroke(tick, with: .color(.white.opacity(0.25)), lineWidth: 1)
                context.draw(
                    Text("\(yd)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7)),
                    at: CGPoint(x: 20, y: y - 6),
                    anchor: .topLeading
                )
            }
            if let along = landing.along_yd {
                let offline = landing.offline_yd ?? 0
                let y = size.height - (CGFloat(along) / maxYd) * (size.height - 16)
                let x = size.width / 2 + CGFloat(offline) / halfOfflineYd * (size.width * 0.35)
                let ball = Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
                context.fill(ball, with: .color(.white))
            }
        }
        .accessibilityLabel("Driving range")
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(minHeight: 280)
    }
}
