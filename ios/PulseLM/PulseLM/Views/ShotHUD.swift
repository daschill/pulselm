import SwiftUI

struct ShotHUD: View {
    var shot: ShotResult?
    var compact: Bool = false

    var body: some View {
        if compact {
            compactRow
        } else {
            fullHUD
        }
    }

    private var compactRow: some View {
        HStack(spacing: 8) {
            compactChip("MPH", ShotMapping.speedString(shot?.ball_speed_mph))
            compactChip("VLA", ShotMapping.vlaString(shot?.vla_deg))
            compactChip("CARRY", ShotMapping.carryString(shot?.carry_yd_est))
            compactChip("HLA", ShotMapping.metricString(shot?.hla_deg, decimals: 1))
        }
    }

    private func compactChip(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.65))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(title == "MPH" ? Color(red: 0.24, green: 1.0, blue: 0.60) : .white)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.07, green: 0.09, blue: 0.12))
        )
    }

    private var fullHUD: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Ball speed")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.65))
                Text(ShotMapping.speedString(shot?.ball_speed_mph))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .foregroundStyle(Color(red: 0.24, green: 1.0, blue: 0.60))
                    .monospacedDigit()
                Text("MPH")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.09, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            HStack(spacing: 8) {
                hudChip(title: "VLA", value: ShotMapping.vlaString(shot?.vla_deg), unit: "°")
                hudChip(title: "Carry", value: ShotMapping.carryString(shot?.carry_yd_est), unit: "yd")
                hudChip(title: "Shot", value: shot?.shot_id ?? ShotMapping.missing, unit: nil)
            }

            HStack(spacing: 8) {
                hudChip(title: "HLA", value: ShotMapping.metricString(shot?.hla_deg, decimals: 1), unit: "°")
                hudChip(title: "Spin", value: ShotMapping.metricString(shot?.spin_rpm, decimals: 0), unit: "rpm")
                hudChip(title: "Club", value: ShotMapping.metricString(shot?.club_speed_mph, decimals: 1), unit: "mph")
            }
        }
    }

    private func hudChip(title: String, value: String, unit: String?) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.65))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospacedDigit()
            if let unit {
                Text(unit)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.65))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.07, green: 0.09, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ShotHUD(shot: .sample)
        .padding()
        .background(Color(red: 0.027, green: 0.035, blue: 0.051))
}
