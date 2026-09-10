import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var client: MonitorClient
    @State private var showHostEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    ShotHUD(shot: client.latest)
                    RangeView(shot: client.latest)
                    armButton
                    statusLine
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(Color(red: 0.027, green: 0.035, blue: 0.051).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PULSELM")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHostEditor.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Monitor address")
                }
            }
            .sheet(isPresented: $showHostEditor) {
                hostSheet
            }
            .task {
                await client.refresh()
            }
            .refreshable {
                await client.refresh()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Indoor dual-strobe")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("iPhone display only")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            healthBadge
        }
        .padding(.top, 8)
    }

    private var healthBadge: some View {
        let ok = client.health?.ok == true
        return HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color(red: 0.24, green: 1.0, blue: 0.60) : Color.orange)
                .frame(width: 8, height: 8)
            Text(ok ? (client.health?.demo == true ? "demo" : "live") : "offline")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var armButton: some View {
        Button {
            Task { await arm() }
        } label: {
            HStack {
                if client.isBusy {
                    ProgressView()
                        .tint(Color(red: 0.02, green: 0.13, blue: 0.08))
                }
                Text(client.isBusy ? "Arming…" : "Arm")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.08))
            .background(Color(red: 0.24, green: 1.0, blue: 0.60), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(client.isBusy)
        .accessibilityLabel("Arm")
        .accessibilityHint("Posts arm and updates HUD and range landing from the JSON payload")
    }

    private var statusLine: some View {
        VStack(spacing: 4) {
            if let err = client.lastError {
                Text(err)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            Text(footer)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var footer: String {
        let gap = client.latest?.pulse_gap_s ?? client.health?.pulse_gap_s ?? 0.002
        let ok = client.latest.map { $0.ok ? "ok" : ($0.error ?? "error") } ?? "no shot"
        return "\(ok) · pulse_gap_s \(gap) · HLA / spin / club from JSON"
    }

    private var hostSheet: some View {
        NavigationStack {
            Form {
                Section("Pi monitor") {
                    TextField("Base URL", text: $client.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Default \(MonitorClient.defaultBaseURLString). HTTP on the LAN is allowed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showHostEditor = false
                        Task { await client.refresh() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func arm() async {
        do {
            _ = try await client.arm()
            _ = try? await client.fetchShots()
        } catch {
            client.lastError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MonitorClient())
}
