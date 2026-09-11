import SceneKit
import SwiftUI
import UIKit

/// Foresight-style photoreal driving range: PBR turf, IBL sky, 500 yd targets, animated tracer.
struct PhotorealRangeView: UIViewRepresentable {
    var shot: ShotResult?
    var session: [ShotResult] = []
    var pinYards: Double = 250
    var cameraMode: RangeCameraMode = .auto
    var apexYd: Double? = nil
    var hangTimeS: Double? = nil
    var totalYd: Double? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let handle = PhotorealRangeWorld.build()
        context.coordinator.handle = handle
        let view = SCNView()
        view.scene = handle.scene
        view.pointOfView = handle.cameraNode
        view.delegate = context.coordinator
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.loops = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = UIColor(red: 0.40, green: 0.68, blue: 0.90, alpha: 1)
        view.contentScaleFactor = UIScreen.main.scale
        context.coordinator.sync(
            shot: shot,
            session: session,
            pinYards: pinYards,
            cameraMode: cameraMode,
            apexYd: apexYd,
            hangTimeS: hangTimeS,
            totalYd: totalYd,
            animateIfNew: false
        )
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.pointOfView = context.coordinator.handle?.cameraNode
        context.coordinator.sync(
            shot: shot,
            session: session,
            pinYards: pinYards,
            cameraMode: cameraMode,
            apexYd: apexYd,
            hangTimeS: hangTimeS,
            totalYd: totalYd,
            animateIfNew: true
        )
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var handle: PhotorealRangeWorld.Handle?
        var lastShotId: String?
        var lastPin: Double = -1
        var lastCamera: RangeCameraMode = .auto
        var cameraMode: RangeCameraMode = .auto
        var flying = false
        var flightPoints: [SCNVector3] = []
        var flightStart: TimeInterval = 0
        var flightDuration: TimeInterval = 4.5
        var landPosition = SCNVector3Zero
        var carryText = ""
        var pendingStart = false
        var landHoldUntil: TimeInterval = 0

        func sync(
            shot: ShotResult?,
            session: [ShotResult],
            pinYards: Double,
            cameraMode: RangeCameraMode,
            apexYd: Double?,
            hangTimeS: Double?,
            totalYd: Double?,
            animateIfNew: Bool
        ) {
            guard let handle else { return }
            self.cameraMode = cameraMode
            if lastPin != pinYards {
                lastPin = pinYards
                rebuildPin(pinYards, handle: handle)
            }
            rebuildSession(session, current: shot, handle: handle)
            let shotId = shot?.shot_id
            if shotId != lastShotId {
                lastShotId = shotId
                if animateIfNew, let shot, shot.ok, shot.carry_yd_est != nil {
                    beginFlight(
                        shot: shot,
                        apexYd: apexYd,
                        hangTimeS: hangTimeS,
                        totalYd: totalYd,
                        handle: handle
                    )
                } else {
                    placeBall(shot: shot, handle: handle)
                }
            }
            if lastCamera != cameraMode, !flying {
                lastCamera = cameraMode
                let land = RangeLanding.from(carry: shot?.carry_yd_est, hla: shot?.hla_deg)
                PhotorealRangeWorld.applyCamera(
                    cameraMode,
                    camera: handle.cameraNode,
                    along: Float(land.alongYd ?? pinYards),
                    offline: Float(land.offlineYd ?? 0),
                    ball: handle.ballNode.presentation.position
                )
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let handle else { return }
            if pendingStart {
                flightStart = time
                pendingStart = false
            }
            if flying {
                let raw = flightDuration > 0 ? (time - flightStart) / flightDuration : 1
                let t = Float(min(max(raw, 0), 1))
                let eased = t * t * (3 - 2 * t)
                let pos = PhotorealRangeWorld.lerpFlight(flightPoints, t: eased)
                handle.ballNode.position = pos
                handle.ballNode.scale = SCNVector3(2.4, 2.4, 2.4)
                handle.ballNode.childNode(withName: "ballGlow", recursively: false)?.isHidden = true
                let n = max(2, Int(eased * Float(flightPoints.count)))
                handle.tracerNode.geometry = PhotorealRangeWorld.ribbon(
                    points: Array(flightPoints.prefix(n))
                )
                steerCamera(ball: pos, progress: eased, handle: handle)
                if t >= 1 {
                    finishLanding(at: time, handle: handle)
                }
                return
            }
            if landHoldUntil > 0, time >= landHoldUntil, cameraMode == .auto {
                landHoldUntil = 0
                PhotorealRangeWorld.applyCamera(
                    .tee,
                    camera: handle.cameraNode,
                    along: landPosition.z,
                    offline: landPosition.x,
                    ball: landPosition
                )
            }
        }

        private func steerCamera(ball: SCNVector3, progress: Float, handle: PhotorealRangeWorld.Handle) {
            switch cameraMode {
            case .auto, .follow:
                PhotorealRangeWorld.applyFlightCamera(
                    camera: handle.cameraNode,
                    ball: ball,
                    progress: progress
                )
            case .tee:
                handle.cameraNode.position = SCNVector3(0, 1.82, -8.4)
                handle.cameraNode.look(at: SCNVector3(ball.x, max(1.4, ball.y), ball.z))
            case .high, .top, .landing:
                break
            }
        }

        private func beginFlight(
            shot: ShotResult,
            apexYd: Double?,
            hangTimeS: Double?,
            totalYd: Double?,
            handle: PhotorealRangeWorld.Handle
        ) {
            let land = RangeLanding.from(shot: shot)
            guard let along = land.alongYd else {
                placeBall(shot: shot, handle: handle)
                return
            }
            let offline = land.offlineYd ?? 0
            let vla = shot.vla_deg ?? 13
            let apex = apexYd ?? max(12, min(62, along * 0.14 * max(0.6, vla / 12)))
            let hang = hangTimeS ?? max(3.4, min(6.6, along / 48))
            let curve = (shot.spin_axis_deg ?? 0) * 0.45
            flightPoints = PhotorealRangeWorld.flightPoints(
                along: along,
                offline: offline,
                apex: apex,
                curve: curve
            )
            landPosition = flightPoints.last ?? SCNVector3(Float(offline), 0.16, Float(along))
            let carry = shot.carry_yd_est ?? along
            let total = totalYd ?? shot.total_yd_est
            if let total, abs(total - carry) > 0.5 {
                carryText = String(format: "%.0f yd  ·  tot %.0f", carry, total)
            } else {
                carryText = String(format: "%.0f yd", carry)
            }
            handle.ballNode.removeAllAnimations()
            handle.ballNode.position = PhotorealRangeWorld.teeBallPosition
            handle.ballNode.scale = SCNVector3(1, 1, 1)
            handle.landingRing.isHidden = true
            handle.carryLabel.isHidden = true
            handle.tracerNode.geometry = nil
            flying = true
            pendingStart = true
            landHoldUntil = 0
        }

        private func finishLanding(at time: TimeInterval, handle: PhotorealRangeWorld.Handle) {
            flying = false
            handle.ballNode.position = landPosition
            handle.ballNode.scale = SCNVector3(1.6, 1.6, 1.6)
            handle.ballNode.childNode(withName: "ballGlow", recursively: false)?.isHidden = true
            handle.tracerNode.geometry = PhotorealRangeWorld.ribbon(points: flightPoints)
            handle.landingRing.isHidden = false
            handle.landingRing.position = SCNVector3(
                landPosition.x,
                PhotorealRangeWorld.groundY(landPosition.x, landPosition.z) + 0.1,
                landPosition.z
            )
            handle.carryLabel.isHidden = true
            if cameraMode == .auto || cameraMode == .follow || cameraMode == .landing {
                PhotorealRangeWorld.applyCamera(
                    .landing,
                    camera: handle.cameraNode,
                    along: landPosition.z,
                    offline: landPosition.x,
                    ball: landPosition
                )
            }
            if cameraMode == .auto {
                landHoldUntil = time + 2.4
            }
        }

        private func rebuildPin(_ pinYards: Double, handle: PhotorealRangeWorld.Handle) {
            handle.pinRoot.childNodes.forEach { $0.removeFromParentNode() }
            let pin = Float(pinYards)
            let green = handle.greens.min(by: { abs($0.along - pin) < abs($1.along - pin) })
            let along = green?.along ?? pin
            let off = green?.offline ?? 0
            _ = PhotorealRangeWorld.addFlag(along: along, offline: off, selected: true, to: handle.pinRoot)
            let radius = CGFloat(green?.radius ?? 9) * 0.92
            let tube = SCNTube(innerRadius: max(0.2, radius - 0.22), outerRadius: radius, height: 0.07)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = UIColor(red: 1, green: 0.18, blue: 0.16, alpha: 0.9)
            mat.emission.contents = UIColor(red: 0.7, green: 0.08, blue: 0.08, alpha: 1)
            tube.firstMaterial = mat
            let ring = SCNNode(geometry: tube)
            ring.position = SCNVector3(off, PhotorealRangeWorld.groundY(off, along) + 0.12, along)
            handle.pinRoot.addChildNode(ring)
        }

        private func rebuildSession(_ session: [ShotResult], current: ShotResult?, handle: PhotorealRangeWorld.Handle) {
            handle.sessionRoot.childNodes.forEach { $0.removeFromParentNode() }
            let prior = session.filter { $0.shot_id != current?.shot_id && $0.ok && $0.carry_yd_est != nil }
            for s in prior.suffix(20) {
                let land = RangeLanding.from(shot: s)
                guard let along = land.alongYd else { continue }
                let off = Float(land.offlineYd ?? 0)
                let z = Float(along)
                let mark = SCNSphere(radius: 0.28)
                let m = SCNMaterial()
                m.lightingModel = .constant
                m.diffuse.contents = UIColor.white.withAlphaComponent(0.75)
                mark.firstMaterial = m
                let node = SCNNode(geometry: mark)
                node.position = SCNVector3(off, PhotorealRangeWorld.groundY(off, z) + 0.28, z)
                handle.sessionRoot.addChildNode(node)
            }
        }

        private func placeBall(shot: ShotResult?, handle: PhotorealRangeWorld.Handle) {
            handle.ballNode.removeAllAnimations()
            flying = false
            handle.ballNode.scale = SCNVector3(1, 1, 1)
            handle.ballNode.childNode(withName: "ballGlow", recursively: false)?.isHidden = true
            let land = RangeLanding.from(carry: shot?.carry_yd_est, hla: shot?.hla_deg)
            if let along = land.alongYd {
                let off = Float(land.offlineYd ?? 0)
                let z = Float(along)
                handle.ballNode.position = SCNVector3(off, PhotorealRangeWorld.groundY(off, z) + 0.16, z)
                handle.landingRing.isHidden = false
                handle.landingRing.position = SCNVector3(off, PhotorealRangeWorld.groundY(off, z) + 0.08, z)
                let points = PhotorealRangeWorld.flightPoints(
                    along: along,
                    offline: land.offlineYd ?? 0,
                    apex: 22
                )
                handle.tracerNode.geometry = PhotorealRangeWorld.ribbon(points: points)
                handle.carryLabel.isHidden = true
            } else {
                handle.ballNode.position = PhotorealRangeWorld.teeBallPosition
                handle.landingRing.isHidden = true
                handle.tracerNode.geometry = nil
                handle.carryLabel.isHidden = true
            }
        }
    }
}
