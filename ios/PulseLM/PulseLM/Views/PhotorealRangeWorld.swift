import SceneKit
import UIKit

enum RangeCameraMode: String, CaseIterable, Identifiable {
    case auto, tee, follow, landing, high, top

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .tee: return "Tee"
        case .follow: return "Follow"
        case .landing: return "Land"
        case .high: return "High"
        case .top: return "Top"
        }
    }
}

/// 1 SceneKit unit = 1 yard. Origin at the tee, +Z down the range, +Y up, +X right.
enum PhotorealRangeWorld {
    static let length: Float = 520
    static let halfWidth: Float = 78

    struct Handle {
        let scene: SCNScene
        let cameraNode: SCNNode
        let ballNode: SCNNode
        let tracerNode: SCNNode
        let pinRoot: SCNNode
        let sessionRoot: SCNNode
        let landingRing: SCNNode
        let carryLabel: SCNNode
        let greens: [(along: Float, offline: Float, radius: Float)]
    }

    static func build() -> Handle {
        let scene = SCNScene()
        scene.fogStartDistance = 520
        scene.fogEndDistance = 980
        scene.fogColor = UIColor(red: 0.78, green: 0.86, blue: 0.93, alpha: 1)
        scene.background.contents = UIImage(named: "RangeSkyWide") ?? UIImage(named: "RangeSky") ?? UIColor(red: 0.40, green: 0.68, blue: 0.90, alpha: 1)
        scene.lightingEnvironment.contents = UIImage(named: "RangeSkyWide") ?? UIImage(named: "RangeSkyGolf")
        scene.lightingEnvironment.intensity = 1.45

        let root = scene.rootNode
        addSky(to: root)
        addBackdrop(to: root)
        addLights(to: root)
        addTerrain(to: root)
        addFairway(to: root)
        let greens = addGreensAndBunkers(to: root)
        addWater(to: root)
        addTrees(to: root)
        addMarkers(to: root)
        addAimLine(to: root)

        let pinRoot = SCNNode()
        pinRoot.name = "pinRoot"
        root.addChildNode(pinRoot)

        let tracerNode = SCNNode()
        tracerNode.name = "tracer"
        root.addChildNode(tracerNode)

        let sessionRoot = SCNNode()
        sessionRoot.name = "session"
        root.addChildNode(sessionRoot)

        let landingRing = makeLandingRing()
        landingRing.isHidden = true
        root.addChildNode(landingRing)

        let carryLabel = makeCarryLabel()
        carryLabel.isHidden = true
        root.addChildNode(carryLabel)

        let ball = makeBall()
        ball.position = teeBallPosition
        root.addChildNode(ball)

        let camera = makeCamera()
        root.addChildNode(camera)
        applyCamera(.auto, camera: camera, along: 250, offline: 0, ball: ball.position)

        return Handle(
            scene: scene,
            cameraNode: camera,
            ballNode: ball,
            tracerNode: tracerNode,
            pinRoot: pinRoot,
            sessionRoot: sessionRoot,
            landingRing: landingRing,
            carryLabel: carryLabel,
            greens: greens
        )
    }

    static func fairwayHalf(_ z: Float) -> Float {
        let t = min(max(z / 500, 0), 1)
        return 11.5 + 18.0 * t
    }

    static func groundY(_ x: Float, _ z: Float) -> Float {
        var y = 0.28 * sinf(x * 0.032) * cosf(z * 0.017)
        y += 0.14 * sinf(x * 0.07 + 1.4) * sinf(z * 0.033)
        let berm = max(0, abs(x) - 34)
        y += berm * 0.04
        if z > 495 {
            y += (z - 495) * 0.11
        }
        if z < 0 {
            y += 0.04
        }
        return y
    }

    static func applyCamera(
        _ mode: RangeCameraMode,
        camera: SCNNode,
        along: Float,
        offline: Float,
        ball: SCNVector3
    ) {
        switch mode {
        case .auto, .tee:
            camera.position = SCNVector3(0, 1.82, -8.4)
            camera.look(at: SCNVector3(0, 0.92, 68))
        case .follow:
            applyFlightCamera(camera: camera, ball: ball, progress: 0.55)
        case .landing:
            camera.position = SCNVector3(offline + 16, 8.5, along - 22)
            camera.look(at: SCNVector3(offline, 1.2, along))
        case .high:
            camera.position = SCNVector3(0, 28, -22)
            camera.look(at: SCNVector3(0, 0, 140))
        case .top:
            camera.position = SCNVector3(0, 210, 220)
            camera.look(at: SCNVector3(0, 0, 230))
        }
    }

    static func applyFlightCamera(camera: SCNNode, ball: SCNVector3, progress: Float) {
        let back: Float = 14 + 10 * progress
        let height: Float = max(4.5, ball.y + 3.6 + 6 * progress)
        camera.position = SCNVector3(ball.x * 0.2 - 2.5, height, ball.z - back)
        camera.look(at: SCNVector3(ball.x, max(1.2, ball.y + 0.4), ball.z + 18))
    }

    static func lerpFlight(_ points: [SCNVector3], t: Float) -> SCNVector3 {
        guard points.count >= 2 else { return teeBallPosition }
        let u = min(max(t, 0), 0.9999) * Float(points.count - 1)
        let i = Int(u)
        let f = u - Float(i)
        let a = points[i]
        let b = points[min(i + 1, points.count - 1)]
        return SCNVector3(
            a.x + (b.x - a.x) * f,
            a.y + (b.y - a.y) * f,
            a.z + (b.z - a.z) * f
        )
    }

    // MARK: - Lights / sky

    private static func addSky(to root: SCNNode) {
        let sky = SCNSphere(radius: 920)
        sky.segmentCount = 48
        let mat = SCNMaterial()
        mat.diffuse.contents = UIImage(named: "RangeSkyWide") ?? UIImage(named: "RangeSky")
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.cullMode = .front
        mat.writesToDepthBuffer = false
        sky.firstMaterial = mat
        let node = SCNNode(geometry: sky)
        node.name = "sky"
        node.eulerAngles.y = .pi
        root.addChildNode(node)
    }

    private static func addBackdrop(to root: SCNNode) {
        let plane = SCNPlane(width: 920, height: 260)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIImage(named: "RangeSkyWide") ?? UIImage(named: "RangeSky")
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 88, 535)
        node.name = "backdrop"
        root.addChildNode(node)

        let sun = SCNSphere(radius: 7.5)
        let sunMat = SCNMaterial()
        sunMat.lightingModel = .constant
        sunMat.diffuse.contents = UIColor(red: 1, green: 0.95, blue: 0.75, alpha: 1)
        sunMat.emission.contents = UIColor(red: 1, green: 0.92, blue: 0.55, alpha: 1)
        sun.firstMaterial = sunMat
        let sunNode = SCNNode(geometry: sun)
        sunNode.position = SCNVector3(95, 168, 480)
        sunNode.renderingOrder = -2
        sunNode.name = "sunDisc"
        root.addChildNode(sunNode)
    }

    private static func addLights(to root: SCNNode) {
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1100
        sun.temperature = 5400
        sun.castsShadow = true
        sun.shadowSampleCount = 8
        sun.shadowRadius = 2.4
        sun.shadowMode = .forward
        sun.shadowColor = UIColor(white: 0, alpha: 0.55)
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.maximumShadowDistance = 240
        sun.orthographicScale = 90
        sun.zNear = 1
        sun.zFar = 420
        if #available(iOS 11.0, *) {
            sun.shadowCascadeCount = 2
            sun.shadowCascadeSplittingFactor = 0.45
        }
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.95, 0.72, 0.08)
        sunNode.name = "sun"
        root.addChildNode(sunNode)

        let bounce = SCNLight()
        bounce.type = .ambient
        bounce.intensity = 280
        bounce.color = UIColor(red: 0.72, green: 0.82, blue: 0.70, alpha: 1)
        bounce.temperature = 6200
        let bounceNode = SCNNode()
        bounceNode.light = bounce
        root.addChildNode(bounceNode)
    }

    // MARK: - Ground

    private static func addTerrain(to root: SCNNode) {
        let geo = meshGrid(
            xCount: 72,
            zCount: 168,
            x0: -halfWidth,
            x1: halfWidth,
            z0: -18,
            z1: length,
            y: { x, z in groundY(x, z) },
            uv: { x, z in SIMD2(x / 9.0, z / 9.0) }
        )
        geo.firstMaterial = pbr(
            diffuse: "GrassRough",
            normal: "GrassRoughN",
            roughness: 0.92,
            metalness: 0,
            normalIntensity: 0.62
        )
        let node = SCNNode(geometry: geo)
        node.name = "rough"
        node.castsShadow = true
        root.addChildNode(node)
    }

    private static func addFairway(to root: SCNNode) {
        let geo = fairwayMesh(xCount: 14, zCount: 150)
        let mat = pbr(
            diffuse: "GrassFairway",
            normal: "GrassFairwayN",
            roughness: 0.86,
            metalness: 0,
            normalIntensity: 0.48
        )
        geo.firstMaterial = mat
        let node = SCNNode(geometry: geo)
        node.name = "fairway"
        node.castsShadow = true
        root.addChildNode(node)

        // First-cut collar between fairway and rough.
        let collar = fairwayMesh(xCount: 8, zCount: 120, widthScale: 1.28, yLift: 0.02)
        let collarMat = pbr(
            diffuse: "GrassGreen",
            normal: "GrassGreenN",
            roughness: 0.9,
            metalness: 0,
            normalIntensity: 0.4
        )
        collarMat.multiply.contents = UIColor(red: 0.72, green: 0.82, blue: 0.55, alpha: 1)
        collar.firstMaterial = collarMat
        let collarNode = SCNNode(geometry: collar)
        collarNode.name = "collar"
        collarNode.renderingOrder = -1
        root.addChildNode(collarNode)
    }

    private static func addGreensAndBunkers(to root: SCNNode) -> [(along: Float, offline: Float, radius: Float)] {
        let greens: [(Float, Float, Float)] = [
            (100, 0, 8.5),
            (150, -7.5, 9.0),
            (200, 6.5, 8.2),
            (250, 0, 10.5),
            (300, 9.0, 8.8),
            (350, -6.0, 8.0),
            (400, 5.0, 9.2),
            (450, -8.0, 7.6),
            (500, 0, 11.0),
        ]
        let greenMat = pbr(
            diffuse: "GrassGreen",
            normal: "GrassGreenN",
            roughness: 0.78,
            metalness: 0,
            normalIntensity: 0.35
        )
        for (along, off, radius) in greens {
            let disc = SCNCylinder(radius: CGFloat(radius), height: 0.16)
            disc.firstMaterial = greenMat
            let node = SCNNode(geometry: disc)
            let y = groundY(off, along) + 0.10
            node.position = SCNVector3(off, y, along)
            node.name = "green-\(Int(along))"
            root.addChildNode(node)
            addFlag(along: along, offline: off, selected: false, to: root)
        }

        let bunkers: [(Float, Float, Float, Float)] = [
            (118, -16, 7.5, 4.8),
            (168, 14, 6.4, 4.2),
            (248, -13, 7.0, 4.4),
            (318, 17, 6.2, 3.8),
            (392, -15, 6.8, 4.0),
            (458, 12, 5.6, 3.4),
        ]
        let sandMat = pbr(
            diffuse: "SandBunker",
            normal: "SandBunkerN",
            roughness: 0.95,
            metalness: 0,
            normalIntensity: 0.4
        )
        for (along, off, rx, rz) in bunkers {
            let sand = SCNSphere(radius: 1)
            sand.segmentCount = 18
            sand.firstMaterial = sandMat
            let node = SCNNode(geometry: sand)
            node.scale = SCNVector3(rx, 0.28, rz)
            node.position = SCNVector3(off, groundY(off, along) + 0.05, along)
            node.name = "bunker"
            root.addChildNode(node)
        }
        return greens.map { (along: $0.0, offline: $0.1, radius: $0.2) }
    }

    private static func addWater(to root: SCNNode) {
        let water = SCNCylinder(radius: 9.5, height: 0.12)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.18, green: 0.42, blue: 0.58, alpha: 1)
        mat.roughness.contents = 0.08
        mat.metalness.contents = 0.22
        mat.reflective.contents = UIImage(named: "RangeSky")
        water.firstMaterial = mat
        let node = SCNNode(geometry: water)
        node.position = SCNVector3(38, groundY(38, 286) + 0.04, 286)
        node.name = "water"
        root.addChildNode(node)
    }

    private static func addTrees(to root: SCNNode) {
        let pineMat = billboardMaterial("TreePine")
        let oakMat = billboardMaterial("TreeOak")
        var rng = LCG(state: 0xC0FFEE)

        func plant(x: Float, z: Float, pine: Bool, scale: Float) {
            let height = (pine ? rng.range(12, 18.5) : rng.range(10, 16)) * scale
            let width = height * (pine ? 0.48 : 0.74)
            let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
            plane.firstMaterial = pine ? pineMat : oakMat
            let node = SCNNode(geometry: plane)
            node.pivot = SCNMatrix4MakeTranslation(0, -height / 2, 0)
            node.position = SCNVector3(x, groundY(x, z), z)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            node.constraints = [billboard]
            node.castsShadow = z < 160
            root.addChildNode(node)
        }

        for side: Float in [-1, 1] {
            var z: Float = 36
            var row = 0
            while z < 512 {
                let inset = row % 2 == 0 ? rng.range(12, 17) : rng.range(22, 32)
                let x = side * (fairwayHalf(z) + inset) + rng.range(-1.8, 1.8)
                plant(x: x, z: z, pine: rng.next() > 0.38, scale: z < 90 ? 1.1 : 1)
                z += rng.range(5.4, 8.6)
                row += 1
            }
        }
        // Forest wall at the far end so the range doesn't drop into empty sky.
        for i in 0..<28 {
            let t = Float(i) / 27
            let x = -62 + 124 * t + rng.range(-2, 2)
            plant(x: x, z: rng.range(508, 528), pine: rng.next() > 0.3, scale: rng.range(1.3, 1.8))
        }
    }

    private static func addMarkers(to root: SCNNode) {
        let posts: [(Float, UIColor)] = [
            (50, UIColor.white),
            (100, UIColor(red: 0.95, green: 0.82, blue: 0.15, alpha: 1)),
            (150, UIColor(red: 0.90, green: 0.16, blue: 0.18, alpha: 1)),
            (200, UIColor.white),
            (250, UIColor(red: 0.15, green: 0.42, blue: 0.90, alpha: 1)),
            (300, UIColor(red: 0.95, green: 0.82, blue: 0.15, alpha: 1)),
            (350, UIColor.white),
            (400, UIColor(red: 0.90, green: 0.16, blue: 0.18, alpha: 1)),
            (450, UIColor.white),
            (500, UIColor(red: 0.15, green: 0.42, blue: 0.90, alpha: 1)),
        ]
        for (along, color) in posts {
            let half = fairwayHalf(along) + 3.2
            for side: Float in [-1, 1] {
                addPost(x: side * half, z: along, color: color, yards: Int(along), to: root)
            }
            if along >= 100 {
                addGroundNumber(Int(along), z: along, x: fairwayHalf(along) + 5.5, to: root)
            }
        }
    }

    private static func addPost(x: Float, z: Float, color: UIColor, yards: Int, to root: SCNNode) {
        let pole = SCNCylinder(radius: 0.13, height: 2.4)
        pole.firstMaterial = constant(color)
        let node = SCNNode(geometry: pole)
        node.position = SCNVector3(x, groundY(x, z) + 1.2, z)
        root.addChildNode(node)
        let cap = SCNBox(width: 0.55, height: 0.55, length: 0.12, chamferRadius: 0.02)
        cap.firstMaterial = constant(color)
        let capNode = SCNNode(geometry: cap)
        capNode.position = SCNVector3(x, groundY(x, z) + 2.45, z)
        root.addChildNode(capNode)
    }

    private static func addGroundNumber(_ yards: Int, z: Float, x: Float, to root: SCNNode) {
        let text = SCNText(string: "\(yards)", extrusionDepth: 0.08)
        text.font = UIFont.systemFont(ofSize: 6.5, weight: .heavy)
        text.flatness = 0.2
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor.white
        mat.emission.contents = UIColor(white: 0.2, alpha: 1)
        mat.isDoubleSided = true
        text.materials = [mat]
        let node = SCNNode(geometry: text)
        let (minB, maxB) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((minB.x + maxB.x) / 2, minB.y, (minB.z + maxB.z) / 2)
        node.eulerAngles.x = -.pi / 2
        node.scale = SCNVector3(0.28, 0.28, 0.28)
        node.position = SCNVector3(x, groundY(x, z) + 0.14, z)
        root.addChildNode(node)
    }

    static var teeBallPosition: SCNVector3 {
        let z: Float = 1.1
        return SCNVector3(0, groundY(0, z) + 0.14, z)
    }

    private static func addAimLine(to root: SCNNode) {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(white: 1, alpha: 0.28)
        mat.writesToDepthBuffer = false
        var z: Float = 8
        while z < 490 {
            let dash = SCNBox(width: 0.10, height: 0.015, length: 2.2, chamferRadius: 0)
            dash.firstMaterial = mat
            let node = SCNNode(geometry: dash)
            node.position = SCNVector3(0, groundY(0, z) + 0.09, z)
            node.name = "aim"
            root.addChildNode(node)
            z += 8
        }
    }

    static func addFlag(along: Float, offline: Float, selected: Bool, to parent: SCNNode) -> SCNNode {
        let group = SCNNode()
        group.position = SCNVector3(offline, groundY(offline, along), along)
        let h: Float = selected ? 5.2 : 3.6
        let pole = SCNCylinder(radius: selected ? 0.055 : 0.04, height: CGFloat(h))
        let poleMat = constant(.white)
        poleMat.isDoubleSided = true
        pole.firstMaterial = poleMat
        let poleNode = SCNNode(geometry: pole)
        poleNode.position.y = h / 2
        group.addChildNode(poleNode)

        let flag = SCNBox(width: selected ? 1.8 : 1.35, height: selected ? 1.05 : 0.78, length: 0.05, chamferRadius: 0)
        let color: UIColor = selected
            ? UIColor(red: 0.92, green: 0.12, blue: 0.16, alpha: 1)
            : UIColor(red: 0.95, green: 0.86, blue: 0.18, alpha: 1)
        let flagMat = constant(color)
        flagMat.isDoubleSided = true
        flag.firstMaterial = flagMat
        let flagNode = SCNNode(geometry: flag)
        flagNode.position = SCNVector3(selected ? 0.92 : 0.7, h - 0.55, 0)
        group.addChildNode(flagNode)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        group.constraints = [billboard]
        parent.addChildNode(group)
        return group
    }

    private static func makeBall() -> SCNNode {
        let ball = SCNSphere(radius: 0.14)
        ball.segmentCount = 24
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor.white
        mat.roughness.contents = 0.22
        mat.metalness.contents = 0.04
        mat.emission.contents = UIColor(white: 0.18, alpha: 1)
        ball.firstMaterial = mat
        let node = SCNNode(geometry: ball)
        node.name = "ball"
        node.castsShadow = true
        let glow = SCNSphere(radius: 0.28)
        let glowMat = SCNMaterial()
        glowMat.lightingModel = .constant
        glowMat.diffuse.contents = UIColor(white: 1, alpha: 0.18)
        glowMat.emission.contents = UIColor.white
        glowMat.blendMode = .add
        glowMat.writesToDepthBuffer = false
        glow.firstMaterial = glowMat
        let glowNode = SCNNode(geometry: glow)
        glowNode.name = "ballGlow"
        glowNode.isHidden = true
        node.addChildNode(glowNode)
        return node
    }

    private static func makeLandingRing() -> SCNNode {
        let tube = SCNTube(innerRadius: 1.35, outerRadius: 1.75, height: 0.08)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 0.24, green: 1.0, blue: 0.60, alpha: 1)
        mat.emission.contents = UIColor(red: 0.18, green: 0.75, blue: 0.42, alpha: 1)
        tube.firstMaterial = mat
        let node = SCNNode(geometry: tube)
        node.name = "landingRing"
        return node
    }

    static func makeCarryLabel() -> SCNNode {
        let plane = SCNPlane(width: 10, height: 2.6)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor.clear
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.name = "carryLabel"
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        node.constraints = [billboard]
        return node
    }

    static func setCarryLabel(_ node: SCNNode, text: String) {
        let bounds = CGSize(width: 520, height: 140)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: bounds, format: format)
        let img = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds))
            let rect = CGRect(origin: .zero, size: bounds).insetBy(dx: 8, dy: 8)
            UIColor(red: 0.02, green: 0.10, blue: 0.06, alpha: 0.82).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 28).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .heavy),
                .foregroundColor: UIColor.white,
            ]
            let str = text as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(
                at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
                withAttributes: attrs
            )
        }
        node.geometry?.firstMaterial?.diffuse.contents = img
        node.geometry?.firstMaterial?.transparencyMode = .aOne
    }

    private static func makeCamera() -> SCNNode {
        let cam = SCNCamera()
        cam.zNear = 0.15
        cam.zFar = 1400
        cam.fieldOfView = 54
        cam.wantsHDR = true
        cam.bloomIntensity = 0.08
        cam.bloomThreshold = 1.15
        cam.bloomBlurRadius = 4
        cam.wantsExposureAdaptation = false
        cam.minimumExposure = -0.4
        cam.maximumExposure = 1.4
        cam.contrast = 0.12
        cam.saturation = 1.08
        cam.vignettingIntensity = 0.35
        cam.vignettingPower = 1.2
        cam.averageGray = 0.18
        let node = SCNNode()
        node.camera = cam
        node.name = "rangeCam"
        return node
    }

    // MARK: - Materials / mesh

    private static func pbr(
        diffuse: String,
        normal: String?,
        roughness: CGFloat,
        metalness: CGFloat,
        normalIntensity: CGFloat
    ) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIImage(named: diffuse) ?? UIColor(red: 0.22, green: 0.48, blue: 0.20, alpha: 1)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.magnificationFilter = .linear
        m.diffuse.minificationFilter = .linear
        m.diffuse.mipFilter = .linear
        m.diffuse.maxAnisotropy = 16
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        if let normal, let nimg = UIImage(named: normal) {
            m.normal.contents = nimg
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.intensity = normalIntensity
        }
        m.locksAmbientWithDiffuse = true
        return m
    }

    private static func constant(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        return m
    }

    private static func billboardMaterial(_ name: String) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIImage(named: name)
        m.diffuse.wrapS = .clamp
        m.diffuse.wrapT = .clamp
        m.roughness.contents = 0.88
        m.metalness.contents = 0
        m.isDoubleSided = true
        m.transparencyMode = .aOne
        m.blendMode = .alpha
        m.writesToDepthBuffer = true
        m.shaderModifiers = [
            .fragment: """
            #pragma transparent
            #pragma body
            if (_output.color.a < 0.18) {
                discard;
            }
            """
        ]
        return m
    }

    private static func fairwayMesh(
        xCount: Int,
        zCount: Int,
        widthScale: Float = 1,
        yLift: Float = 0.06
    ) -> SCNGeometry {
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity((xCount + 1) * (zCount + 1))
        for iz in 0...zCount {
            let z = -12 + Float(iz) / Float(zCount) * 517
            let half = fairwayHalf(max(0, z)) * widthScale
            for ix in 0...xCount {
                let t = Float(ix) / Float(xCount)
                let x = -half + 2 * half * t
                let y = groundY(x, z) + yLift
                positions.append(SCNVector3(x, y, z))
                uvs.append(SIMD2(t, (z + 12) / 8.0))
            }
        }
        normals = computedNormals(positions: positions, xCount: xCount, zCount: zCount)
        let indices = gridIndices(xCount: xCount, zCount: zCount)
        return geometry(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }

    private static func meshGrid(
        xCount: Int,
        zCount: Int,
        x0: Float,
        x1: Float,
        z0: Float,
        z1: Float,
        y: (Float, Float) -> Float,
        uv: (Float, Float) -> SIMD2<Float>
    ) -> SCNGeometry {
        var positions: [SCNVector3] = []
        var uvs: [SIMD2<Float>] = []
        for iz in 0...zCount {
            let zt = Float(iz) / Float(zCount)
            let z = z0 + (z1 - z0) * zt
            for ix in 0...xCount {
                let xt = Float(ix) / Float(xCount)
                let x = x0 + (x1 - x0) * xt
                positions.append(SCNVector3(x, y(x, z), z))
                uvs.append(uv(x, z))
            }
        }
        let normals = computedNormals(positions: positions, xCount: xCount, zCount: zCount)
        let indices = gridIndices(xCount: xCount, zCount: zCount)
        return geometry(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }

    private static func gridIndices(xCount: Int, zCount: Int) -> [UInt32] {
        var indices: [UInt32] = []
        indices.reserveCapacity(xCount * zCount * 6)
        let stride = xCount + 1
        for iz in 0..<zCount {
            for ix in 0..<xCount {
                let a = UInt32(iz * stride + ix)
                let b = a + 1
                let c = UInt32((iz + 1) * stride + ix)
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        return indices
    }

    private static func computedNormals(positions: [SCNVector3], xCount: Int, zCount: Int) -> [SCNVector3] {
        var normals = Array(repeating: SCNVector3(0, 1, 0), count: positions.count)
        let stride = xCount + 1
        for iz in 0...zCount {
            for ix in 0...xCount {
                let i = iz * stride + ix
                let left = ix > 0 ? positions[i - 1] : positions[i]
                let right = ix < xCount ? positions[i + 1] : positions[i]
                let down = iz > 0 ? positions[i - stride] : positions[i]
                let up = iz < zCount ? positions[i + stride] : positions[i]
                let tx = SCNVector3(right.x - left.x, right.y - left.y, right.z - left.z)
                let tz = SCNVector3(up.x - down.x, up.y - down.y, up.z - down.z)
                var n = SCNVector3(
                    tz.y * tx.z - tz.z * tx.y,
                    tz.z * tx.x - tz.x * tx.z,
                    tz.x * tx.y - tz.y * tx.x
                )
                let len = sqrtf(n.x * n.x + n.y * n.y + n.z * n.z)
                if len > 1e-5 {
                    n.x /= len; n.y /= len; n.z /= len
                } else {
                    n = SCNVector3(0, 1, 0)
                }
                normals[i] = n
            }
        }
        return normals
    }

    static func geometry(
        positions: [SCNVector3],
        normals: [SCNVector3],
        uvs: [SIMD2<Float>],
        indices: [UInt32]
    ) -> SCNGeometry {
        let pos = SCNGeometrySource(vertices: positions)
        let nrm = SCNGeometrySource(normals: normals)
        let uvData = uvs.withUnsafeBufferPointer { Data(buffer: $0) }
        let uv = SCNGeometrySource(
            data: uvData,
            semantic: .texcoord,
            vectorCount: uvs.count,
            usesFloatComponents: true,
            componentsPerVector: 2,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD2<Float>>.stride
        )
        let idx = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: idx,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        return SCNGeometry(sources: [pos, nrm, uv], elements: [element])
    }

    static func ribbon(points: [SCNVector3], width: Float = 0.38) -> SCNGeometry {
        guard points.count >= 2 else {
            return SCNGeometry()
        }
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for i in 0..<points.count {
            let p = points[i]
            let next = i + 1 < points.count ? points[i + 1] : points[i]
            let prev = i > 0 ? points[i - 1] : points[i]
            let dx = next.x - prev.x
            let dz = next.z - prev.z
            var sx = -dz
            var sz = dx
            let sl = max(0.0001, sqrtf(sx * sx + sz * sz))
            sx = sx / sl * width * 0.5
            sz = sz / sl * width * 0.5
            let a = SCNVector3(p.x - sx, p.y, p.z - sz)
            let b = SCNVector3(p.x + sx, p.y, p.z + sz)
            positions.append(a)
            positions.append(b)
            normals.append(SCNVector3(0, 1, 0))
            normals.append(SCNVector3(0, 1, 0))
            let v = Float(i) / Float(max(points.count - 1, 1))
            uvs.append(SIMD2(0, v))
            uvs.append(SIMD2(1, v))
            if i > 0 {
                let i0 = UInt32((i - 1) * 2)
                indices.append(contentsOf: [i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2])
            }
        }
        let geo = geometry(positions: positions, normals: normals, uvs: uvs, indices: indices)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 0.24, green: 1.0, blue: 0.60, alpha: 0.92)
        mat.emission.contents = UIColor(red: 0.24, green: 1.0, blue: 0.60, alpha: 1)
        mat.isDoubleSided = true
        mat.blendMode = .alpha
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        geo.firstMaterial = mat
        return geo
    }

    static func flightPoints(
        along: Double,
        offline: Double,
        apex: Double,
        curve: Double = 0,
        samples: Int = 72
    ) -> [SCNVector3] {
        let start = teeBallPosition
        return (0...samples).map { i in
            let t = Double(i) / Double(samples)
            let side = sin(t * Double.pi) * curve
            let x = start.x + Float(offline * t + side)
            let z = start.z + Float((along - Double(start.z)) * t)
            let y = start.y + Float(4 * apex * t * (1 - t))
            return SCNVector3(x, y, z)
        }
    }
}

private struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return Double(state >> 33) / Double(UInt32.max)
    }
    mutating func range(_ a: Float, _ b: Float) -> Float {
        a + Float(next()) * (b - a)
    }
}
