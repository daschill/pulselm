import SceneKit
import SwiftUI
import UIKit

/// SceneKit hole: fairway, green, bunkers, water, trees. Yards: X offline, Z along, Y up.
struct Course3DView: View {
    var map: CourseHoleMap?
    var shot: ShotResult?
    var remainingYd: Double?

    var body: some View {
        SceneView(
            scene: CourseSceneBuilder.scene(map: map, shot: shot, remainingYd: remainingYd),
            options: [.allowsCameraControl, .autoenablesDefaultLighting]
        )
        .frame(minHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel("3D course")
    }
}

enum CourseSceneBuilder {
    static func scene(map: CourseHoleMap?, shot: ShotResult?, remainingYd: Double?) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.45, green: 0.70, blue: 0.92, alpha: 1)
        scene.fogStartDistance = 180
        scene.fogEndDistance = 520
        scene.fogColor = UIColor(red: 0.55, green: 0.72, blue: 0.88, alpha: 1)

        let root = scene.rootNode
        addLights(to: root)
        addGround(to: root)

        let fairways = map?.fairways ?? Self.synthetic.fairways
        let greens = map?.greens ?? Self.synthetic.greens
        let bunkers = map?.bunkers ?? Self.synthetic.bunkers
        let water = map?.water ?? []
        let trees = map?.trees ?? Self.synthetic.trees
        let pin = remainingYd ?? map?.max_along_yd ?? 380

        addPolygons(fairways, color: UIColor(red: 0.28, green: 0.62, blue: 0.24, alpha: 1), height: 0.4, to: root)
        addPolygons(water, color: UIColor(red: 0.18, green: 0.42, blue: 0.72, alpha: 1), height: 0.2, to: root)
        addPolygons(bunkers, color: UIColor(red: 0.82, green: 0.70, blue: 0.40, alpha: 1), height: 0.35, to: root)
        addPolygons(greens, color: UIColor(red: 0.16, green: 0.52, blue: 0.20, alpha: 1), height: 0.55, to: root)
        addTrees(trees, to: root)
        addFlag(along: pin, to: root)
        addTee(to: root)
        addBall(shot: shot, to: root)
        addCamera(along: pin, to: root)
        return scene
    }

    private static var synthetic: CourseHoleMap {
        let pin = 380.0
        var green: [[Double]] = []
        for i in 0..<16 {
            let a = Double(i) / 16.0 * 2 * Double.pi
            green.append([12 * cos(a), pin + 8 * sin(a)])
        }
        green.append(green[0])
        var trees: [[Double]] = []
        stride(from: 20.0, through: pin, by: 22.0).forEach { t in
            trees.append([-42, t])
            trees.append([44, t + 10])
        }
        return CourseHoleMap(
            ok: true,
            source: "synthetic",
            hole: 1,
            par: 4,
            fairways: [[[-20, 8], [20, 8], [28, pin * 0.9], [14, pin + 10], [-14, pin + 10], [-28, pin * 0.9], [-20, 8]]],
            greens: [green],
            bunkers: [
                [[-24, pin - 14], [-8, pin - 18], [-6, pin - 4], [-22, pin], [-24, pin - 14]],
                [[12, pin - 10], [26, pin - 16], [28, pin], [14, pin + 4], [12, pin - 10]],
            ],
            water: nil,
            rough: nil,
            trees: trees,
            hole_line: [[0, 0], [0, pin]],
            max_along_yd: pin + 30
        )
    }

    private static func addLights(to root: SCNNode) {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 900
        sun.castsShadow = true
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.9, 0.4, 0)
        root.addChildNode(sunNode)
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 350
        amb.color = UIColor(white: 0.85, alpha: 1)
        let ambNode = SCNNode()
        ambNode.light = amb
        root.addChildNode(ambNode)
    }

    private static func addGround(to root: SCNNode) {
        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.14, green: 0.32, blue: 0.12, alpha: 1)
        let node = SCNNode(geometry: floor)
        root.addChildNode(node)
    }

    private static func addPolygons(_ rings: [[[Double]]]?, color: UIColor, height: CGFloat, to root: SCNNode) {
        for ring in rings ?? [] where ring.count >= 3 {
            let path = UIBezierPath()
            for (i, pt) in ring.enumerated() where pt.count >= 2 {
                let x = CGFloat(pt[0])
                let z = CGFloat(pt[1])
                if i == 0 { path.move(to: CGPoint(x: x, y: z)) }
                else { path.addLine(to: CGPoint(x: x, y: z)) }
            }
            path.close()
            path.flatness = 0.5
            let shape = SCNShape(path: path, extrusionDepth: height)
            shape.firstMaterial?.diffuse.contents = color
            shape.firstMaterial?.isDoubleSided = true
            let node = SCNNode(geometry: shape)
            node.eulerAngles.x = .pi / 2
            node.position.y = Float(height / 2)
            root.addChildNode(node)
        }
    }

    private static func addTrees(_ trees: [[Double]]?, to root: SCNNode) {
        for t in (trees ?? []).prefix(80) where t.count >= 2 {
            let trunk = SCNCylinder(radius: 0.4, height: 4)
            trunk.firstMaterial?.diffuse.contents = UIColor(red: 0.32, green: 0.18, blue: 0.08, alpha: 1)
            let canopy = SCNCone(topRadius: 0.2, bottomRadius: 3.2, height: 8)
            canopy.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.32, blue: 0.10, alpha: 1)
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(t[0], 2, t[1])
            let capNode = SCNNode(geometry: canopy)
            capNode.position = SCNVector3(t[0], 7.5, t[1])
            root.addChildNode(trunkNode)
            root.addChildNode(capNode)
        }
    }

    private static func addFlag(along: Double, to root: SCNNode) {
        let pole = SCNCylinder(radius: 0.12, height: 12)
        pole.firstMaterial?.diffuse.contents = UIColor.white
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(0, 6, along)
        let flag = SCNBox(width: 4, height: 2.2, length: 0.08, chamferRadius: 0)
        flag.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.12, blue: 0.15, alpha: 1)
        let flagNode = SCNNode(geometry: flag)
        flagNode.position = SCNVector3(2.1, 11, along)
        let cup = SCNCylinder(radius: 0.6, height: 0.2)
        cup.firstMaterial?.diffuse.contents = UIColor.white
        let cupNode = SCNNode(geometry: cup)
        cupNode.position = SCNVector3(0, 0.7, along)
        root.addChildNode(poleNode)
        root.addChildNode(flagNode)
        root.addChildNode(cupNode)
    }

    private static func addTee(to root: SCNNode) {
        let box = SCNBox(width: 8, height: 0.4, length: 10, chamferRadius: 0.2)
        box.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.2, blue: 0.12, alpha: 1)
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(0, 0.3, 2)
        root.addChildNode(node)
    }

    private static func addBall(shot: ShotResult?, to root: SCNNode) {
        let ball = SCNSphere(radius: 0.7)
        ball.firstMaterial?.diffuse.contents = UIColor.white
        let node = SCNNode(geometry: ball)
        let land = RangeLanding.from(carry: shot?.carry_yd_est, hla: shot?.hla_deg)
        let along = land.alongYd ?? 0
        let off = land.offlineYd ?? 0
        node.position = SCNVector3(off, 0.8, max(2, along))
        node.name = "ball"
        root.addChildNode(node)
        if along > 8 {
            let trail = SCNCylinder(radius: 0.12, height: CGFloat(hypot(along, off)))
            trail.firstMaterial?.diffuse.contents = UIColor(red: 0.24, green: 1.0, blue: 0.60, alpha: 0.45)
            let trailNode = SCNNode(geometry: trail)
            trailNode.position = SCNVector3(off / 2, 8, along / 2)
            let dx = along
            let dy = off
            trailNode.eulerAngles.x = .pi / 2
            trailNode.eulerAngles.y = Float(atan2(dy, dx))
            root.addChildNode(trailNode)
        }
    }

    private static func addCamera(along: Double, to root: SCNNode) {
        let cam = SCNCamera()
        cam.zFar = 800
        cam.zNear = 0.5
        cam.fieldOfView = 58
        let node = SCNNode()
        node.camera = cam
        node.position = SCNVector3(0, 18, -28)
        node.look(at: SCNVector3(0, 2, min(along * 0.45, 180)))
        root.addChildNode(node)
    }
}

#Preview {
    Course3DView(map: nil, shot: .sample, remainingYd: 380)
        .frame(height: 420)
}
