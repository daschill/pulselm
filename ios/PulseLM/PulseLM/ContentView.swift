import SwiftUI

struct ContentView: View {
    @State private var shot: ShotResult?
    @State private var status: String = "pulse_gap_s 0.002"
    @State private var busy = false
    private let client = MonitorClient()

    var landing: RangeLanding {
        if let shot {
            return RangeLanding.from(shot: shot)
        }
        return RangeLanding(along_yd: nil, offline_yd: nil, on_line: true, hla_deg: nil, carry_yd_est: nil, shot_id: nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("PulseLM")
                        .font(.headline)
                        .textCase(.uppercase)
                    Spacer()
                    Text("indoor dual-strobe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ShotHUD(shot: shot)
                RangeView(landing: landing)
                Button(action: arm) {
                    Text(busy ? "Arming…" : "Arm")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .task { await refresh() }
    }

    private func arm() {
        busy = true
        Task {
            defer { busy = false }
            do {
                shot = try await client.arm()
                status = (shot?.ok == true ? "ok" : (shot?.error ?? "error"))
                    + " · pulse_gap_s \(shot?.pulse_gap_s ?? 0.002)"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func refresh() async {
        do {
            shot = try await client.latest()
            status = "ok · pulse_gap_s \(shot?.pulse_gap_s ?? 0.002)"
        } catch {
            status = error.localizedDescription
        }
    }
}
