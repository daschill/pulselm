import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: PlayerSettings
    @EnvironmentObject private var client: MonitorClient
    @ObservedObject private var r10 = R10Bluetooth.shared
    @ObservedObject private var oc = OpenConnectServer.shared
    @State private var step = 0

    private let steps = 7

    var body: some View {
        ZStack {
            PulseTheme.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation { step -= 1 } }
                            .foregroundStyle(PulseTheme.mute)
                    }
                    Spacer()
                    if step < steps - 1 {
                        Button("Skip") { finish() }
                            .foregroundStyle(PulseTheme.mute)
                    }
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $step) {
                    welcome.tag(0)
                    you.tag(1)
                    bag.tag(2)
                    rangeHow.tag(3)
                    monitorHow.tag(4)
                    playHow.tag(5)
                    ready.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: step)

                pageDots
                    .padding(.bottom, 8)

                Button(action: advance) {
                    Text(step == steps - 1 ? "Open range" : "Continue")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(PulseTheme.ink)
                        .background(PulseTheme.lime, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            r10.onShot = { shot in
                Task { @MainActor in
                    _ = PhoneHub.shared.ingest(shot)
                    client.latest = shot
                    client.shots = PhoneHub.shared.shots
                }
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? PulseTheme.lime : Color.white.opacity(0.18))
                    .frame(width: i == step ? 18 : 6, height: 6)
            }
        }
        .padding(.vertical, 12)
    }

    private func advance() {
        if step == 1 {
            if settings.playerName.trimmingCharacters(in: .whitespaces).isEmpty {
                settings.playerName = "Golfer"
            }
        }
        if step == 2 {
            client.selectedClub = settings.defaultClub
        }
        if step >= steps - 1 {
            finish()
        } else {
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        if settings.playerName.trimmingCharacters(in: .whitespaces).isEmpty {
            settings.playerName = "Golfer"
        }
        client.selectedClub = settings.defaultClub
        settings.completedOnboarding = true
    }

    private var welcome: some View {
        stepStack(
            icon: "flag.fill",
            title: "Welcome to PulseLM",
            body: "This iPhone is the launch monitor app. No PC. Hit on the range, pair an R10, or play 18 holes."
        ) {
            EmptyView()
        }
    }

    private var you: some View {
        stepStack(
            icon: "person.fill",
            title: "You",
            body: "Name and units. You can change these later in Connect."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Name")
                TextField("Your name", text: $settings.playerName)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                fieldLabel("Units")
                Picker("Units", selection: $settings.units) {
                    ForEach(UnitSystem.allCases) { u in
                        Text(u.label).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                fieldLabel("Hand")
                Picker("Hand", selection: $settings.handedness) {
                    ForEach(Handedness.allCases) { h in
                        Text(h.label).tag(h)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var bag: some View {
        stepStack(
            icon: "figure.golf",
            title: "Bag",
            body: "Default club and target. HIT uses this club until you change it on the range."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Default club")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PulseTheme.clubs, id: \.self) { c in
                            Button {
                                settings.defaultClub = c
                            } label: {
                                Text(c)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(settings.defaultClub == c ? PulseTheme.ink : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(settings.defaultClub == c ? PulseTheme.lime : Color.white.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                fieldLabel("Default pin")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PulseTheme.pins, id: \.self) { yd in
                            Button {
                                settings.defaultPinYd = yd
                            } label: {
                                Text("\(Int(yd))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(settings.defaultPinYd == yd ? PulseTheme.ink : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(settings.defaultPinYd == yd ? PulseTheme.lime : Color.white.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var rangeHow: some View {
        stepStack(
            icon: "flag.2.crossed.fill",
            title: "The range",
            body: "A 500-yard photoreal range. HIT sends a shot. The camera follows the ball. Numbers land in the dock."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                howRow("circle.fill", "HIT", "Records a practice shot and plays ball flight.")
                howRow("flag.fill", "Pin", "Sets the target green, 100 to 500 yards.")
                howRow("video.fill", "Camera", "Auto follows the shot. Tee / Follow / Land if you want.")
            }
        }
    }

    private var monitorHow: some View {
        stepStack(
            icon: "dot.radiowaves.left.and.right",
            title: "Launch monitor",
            body: "HIT works with no hardware. For a real monitor, pick it here. Almost every sim unit can send GSPro / OpenConnect to this phone."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Monitor", selection: $settings.monitorId) {
                    ForEach(LaunchMonitorKind.all) { m in
                        Text("\(m.brand) \(m.name)").tag(m.id)
                    }
                }
                .pickerStyle(.menu)
                Text(LaunchMonitorKind.all.first { $0.id == settings.monitorId }?.setup ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if settings.monitorId == "garmin_r10" {
                    Button {
                        if r10.connected { r10.stop() } else { r10.scan() }
                    } label: {
                        Text(r10.connected ? "R10 connected" : "Scan & pair R10")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(r10.connected ? PulseTheme.ink : .white)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(r10.connected ? PulseTheme.lime : Color.white.opacity(0.10))
                            )
                    }
                }
                Button {
                    oc.start()
                } label: {
                    Text(oc.listening
                         ? "Listening \(oc.wifiAddress):921"
                         : "Start OpenConnect listener")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }
                Text("Point the monitor at this phone’s Wi-Fi IP, port 921. You can skip and use HIT.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playHow: some View {
        stepStack(
            icon: "map.fill",
            title: "Play 18",
            body: "Play tab searches real courses. Pick one, then HIT each swing on the Range tab."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                howRow("magnifyingglass", "Search", "Bethpage, Torrey, or any OpenGolf course.")
                howRow("list.number", "Scorecard", "18 holes, par, remaining yards.")
            }
        }
    }

    private var ready: some View {
        let name = settings.playerName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Golfer" : settings.playerName
        return stepStack(
            icon: "checkmark.circle.fill",
            title: "You’re set, \(name)",
            body: "\(settings.defaultClub) · \(Int(settings.defaultPinYd)) yd pin · \(settings.units.label). Open the range and HIT."
        ) {
            EmptyView()
        }
    }

    private func stepStack<Content: View>(
        icon: String,
        title: String,
        body: String,
        @ViewBuilder extra: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(PulseTheme.lime)
                    .padding(.top, 12)
                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.mute)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(PulseTheme.mute)
    }

    private func howRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(PulseTheme.lime)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
