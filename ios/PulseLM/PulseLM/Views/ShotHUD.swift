import SwiftUI

struct ShotHUD: View {
    var shot: ShotResult?

    var body: some View {
        VStack(spacing: 12) {
            Text("Ball speed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(ShotMapping.speedString(shot?.ball_speed_mph))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(Color.green)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text("MPH")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                metric("VLA", ShotMapping.vlaString(shot?.vla_deg))
                metric("Carry", ShotMapping.carryString(shot?.carry_yd_est))
                metric("HLA", ShotMapping.optionalMetric(shot?.hla_deg))
            }
            HStack(spacing: 16) {
                metric("Spin", ShotMapping.optionalMetric(shot?.spin_rpm))
                metric("Club", ShotMapping.optionalMetric(shot?.club_speed_mph))
                metric("Shot", shot?.shot_id ?? "—")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
