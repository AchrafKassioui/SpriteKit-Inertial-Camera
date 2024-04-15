/**
 
 # A demo scene to try out the inertial camera
 
 Achraf Kassioui
 Created: 9 April 2024
 Updated: 15 April 2024
 
 */

import SwiftUI
import SpriteKit

// MARK: - Live preview

struct CameraDemoView: View {
    var myScene = CameraDemoScene()
    
    var body: some View {
        SpriteView(
            scene: myScene,
            preferredFramesPerSecond: 120,
            options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            //debugOptions: [.showsNodeCount, .showsDrawCount, .showsFPS]
        )
        .ignoresSafeArea()
    }
}

#Preview {
    CameraDemoView()
}

// MARK: - Demo scene

class CameraDemoScene: SKScene {
        
    override func didMove(to view: SKView) {
        /// configure view
        size = view.bounds.size
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.89, green: 0.89, blue: 0.84, alpha: 1)
        
        /// setup scene physics
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.speed = 1
        let physicsBoundaries = CGRect(
            x: -view.frame.width / 2,
            y: -view.frame.height / 2,
            width: view.frame.width,
            height: view.frame.height
        )
        physicsBody = SKPhysicsBody(edgeLoopFrom: physicsBoundaries)
        physicsBody?.restitution = 1
        
        /// create background
        if let gridTexture = generateGridTexture(cellSize: 60, rows: 30, cols: 30, color: SKColor(white: 0, alpha: 0.15)) {
            let gridbackground = SKSpriteNode(texture: gridTexture)
            gridbackground.zPosition = -1
            addChild(gridbackground)
        }
        
        let yAxis = SKShapeNode(rectOf: CGSize(width: 1, height: 10000))
        yAxis.strokeColor = SKColor(white: 0, alpha: 0.2)
        addChild(yAxis)
        
        let xAxis = SKShapeNode(rectOf: CGSize(width: 10000, height: 1))
        xAxis.isAntialiased = false
        xAxis.strokeColor = SKColor(white: 0, alpha: 0.2)
        addChild(xAxis)
        
        /// create view frame
        let viewFrame = SKShapeNode(rectOf: CGSize(width: view.frame.width, height: view.frame.height))
        viewFrame.lineWidth = 3
        viewFrame.strokeColor = SKColor(white: 0, alpha: 0.9)
        viewFrame.lineJoin = .round
        addChild(viewFrame)
        
        /// create sprite
        let sprite = SKSpriteNode(color: .systemRed, size: CGSize(width: 60, height: 60))
        sprite.name = "sprite"
        sprite.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 60))
        sprite.physicsBody?.restitution = 1
        sprite.physicsBody?.linearDamping = 0
        sprite.physicsBody?.angularDamping = 0
        sprite.zPosition = 10
        sprite.position.y = 300
        sprite.zRotation = .pi * 0.2
        addChild(sprite)
        
        /// create camera
        let inertialCamera = InertialCamera(scene: self)
        inertialCamera.zPosition = 100
        camera = inertialCamera
        addChild(inertialCamera)
        
        /// create visualization
        let gestureVisualizer = GestureVisualizer(scene: self)
        addChild(gestureVisualizer)
        
        /// create UI
        createCameraResetButton(view: view)
        createCameraLockButton(view: view)
        createResetSpriteButton(view: view)
    }
    
    // MARK: UI
    
    let spacing: CGFloat = 20
    let buttonSize = CGSize(width: 160, height: 50)
    
    /// reset sprite
    func createResetSpriteButton(view: SKView) {
        let button = ButtonWithLabel(
            size: buttonSize,
            textContent: "Reset Sprite",
            onTouch: resetSprite
        )
        
        button.position = CGPoint(
            x: 0,
            y: view.frame.height/2 - view.safeAreaInsets.bottom - buttonSize.height/2 - spacing
        )
        
        camera?.addChild(button)
    }
    
    /// lock camera
    func createCameraLockButton(view: SKView) {
        let button = ButtonWithLabel(
            size: buttonSize,
            textContent: "Lock Camera",
            onTouch: toggleCameraLock
        )
        
        button.name = "button-camera-lock"
        button.position = CGPoint(
            x: -90,
            y: -view.frame.height/2 + view.safeAreaInsets.bottom + buttonSize.height/2 + spacing
        )
        
        camera?.addChild(button)
    }
    
    /// reset camera
    func createCameraResetButton(view: SKView) {
        let button = ButtonWithLabel(
            size: buttonSize,
            textContent: "Reset Camera",
            onTouch: resetCamera
        )
        
        button.position = CGPoint(
            x: 90,
            y: -view.frame.height/2 + view.safeAreaInsets.bottom + buttonSize.height/2 + spacing
        )
        
        camera?.addChild(button)
    }
    
    // MARK: Methods
    
    func resetSprite() {
        if let sprite = childNode(withName: "//sprite") as? SKSpriteNode {
            sprite.position = CGPoint(x: 0, y: 300)
            sprite.zRotation = .pi * 0.2
            sprite.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            sprite.physicsBody?.angularVelocity = 0.0
        }
    }
    
    func toggleCameraLock() {
        if let myCamera = self.camera as? InertialCamera {
            myCamera.lock.toggle()
            if myCamera.lock { myCamera.stopInertia() }
            if let button = scene?.childNode(withName: "//button-camera-lock") as? ButtonWithLabel {
                button.labelNode.text = button.isActive ? "Unlock Camera" : button.textContent
                button.labelNode.fontColor = button.isActive ? .white : button.textColor
                button.fillColor = button.isActive ? SKColor(red: 0.9, green: 0, blue: 0, alpha: 0.8) : button.backgroundColor
            }
        }
    }
    
    func resetCamera(){
        if let inertialCamera = self.camera as? InertialCamera {
            /// only reset if the camera is unlocked
            if inertialCamera.lock { return }
            
            inertialCamera.stopInertia()
            inertialCamera.setCameraTo(
                position: .zero,
                xScale: 1,
                yScale: 1,
                rotation: 0
            )
        }
    }
    
    /// unused in this demo
    /// shows an example of a method that toggles camera rotation ON and OFF
    func toggleCameraRotation() {
        if let myCamera = self.camera as? InertialCamera {
            myCamera.lockRotation.toggle()
        }
    }
    
    // MARK: Update loop
    
    override func update(_ currentTime: TimeInterval) {
        /// enable camera inertia
        if let inertialCamera = camera as? InertialCamera {
            inertialCamera.updateInertia()
        }
    }
    
    // MARK: Touch events
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for _ in touches {            
            if let inertialCamera = camera as? InertialCamera {
                inertialCamera.stopInertia()
            }
        }
    }
    
}

// MARK: - UI buttons
/**
 
 A convenience class to create UI buttons in SpriteKit.
 
 Parameters:
 - Parameter size: the rectangular size of the button
 - Parameter textContent: the button label
 - Parameter onTouch: the function to execute whenever the button is touched. A touch toggles the `isActive` property
 
 */

class ButtonWithLabel: SKShapeNode {
    
    /// properties
    var isActive = false
    let labelNode: SKLabelNode
    let textColor = SKColor(white: 0, alpha: 0.8)
    let borderColor = SKColor(white: 0, alpha: 1)
    let backgroundColor = SKColor(white: 1, alpha: 0.4)
    
    let textContent: String
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    /// a function to be called when the button is touched
    let onTouch: () -> Void
    
    /// initialization
    init(size: CGSize, textContent: String, onTouch: @escaping () -> Void) {
        self.labelNode = SKLabelNode(text: textContent)
        self.textContent = textContent
        self.onTouch = onTouch
        
        /// button shape
        super.init()
        self.path = UIBezierPath(
            roundedRect: CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2),size: size),
            cornerRadius: 12
        ).cgPath
        strokeColor = borderColor
        fillColor = backgroundColor
        isUserInteractionEnabled = true
        
        /// button label
        self.labelNode.fontName = "GillSans-SemiBold"
        self.labelNode.fontColor = textColor
        self.labelNode.fontSize = 18
        self.labelNode.verticalAlignmentMode = .center
        self.labelNode.isUserInteractionEnabled = false
        self.addChild(labelNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var pulseAnimation = SKAction.sequence([
        SKAction.scale(to: 1.2, duration: 0.05),
        SKAction.scale(to: 0.95, duration: 0.05),
        SKAction.scale(to: 1, duration: 0.02)
    ])
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.isActive.toggle()
        self.run(pulseAnimation)
        hapticFeedback.impactOccurred()
        onTouch()
    }
    
}

// MARK: - Gesture visualization
/**
 
 This class is used to visualize gestures.
 It setups its own gesture recognizers, independant from the camera's.
 The visualization provides useful interaction feedback and debug information.
 
 */

class GestureVisualizer: SKNode, UIGestureRecognizerDelegate {
    
    /// variables
    private var gestureVisualizationNodes: [String: SKShapeNode] = [:]
    private let myFontName: String = "GillSans-SemiBold"
    private let myFontColor = SKColor(white: 0, alpha: 0.8)
    private let myStrokeColor = SKColor(white: 1, alpha: 0.8)
    
    /// initialization
    weak var parentScene: SKScene?
    
    init(scene: SKScene) {
        self.parentScene = scene
        super.init()
        
        if let view = scene.view {
            self.setupGestureRecognizers(in: view)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// gesture recognizers setup
    func setupGestureRecognizers(in view: SKView) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(updateGestureVisualization(gesture:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(updateGestureVisualization(gesture:)))
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(updateGestureVisualization(gesture:)))
        
        panGesture.maximumNumberOfTouches = 2
        
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(rotationGesture)
        
        panGesture.delegate = self
        pinchGesture.delegate = self
        rotationGesture.delegate = self
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func updateGestureVisualization(gesture: UIGestureRecognizer) {
        if let panGesture = gesture as? UIPanGestureRecognizer {
            visualizePanGesture(panGesture)
        }
        
        if let pinchGesture = gesture as? UIPinchGestureRecognizer {
            visualizePinchGesture(pinchGesture)
        }
        
        if let rotationGesture = gesture as? UIRotationGestureRecognizer {
            visualizeRotationGesture(rotationGesture)
        }
        
        if gesture.state == .ended || gesture.state == .cancelled {
            clearGestureVisualization(for: gesture)
        }
    }
    
    /// handle gestures
    private func visualizePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let scene = parentScene else { return }
        let panPointInView = gesture.location(in: scene.view)
        let panPointInScene = scene.convertPoint(fromView: panPointInView)
        updateOrCreateAnchorNode(name: "pan", position: panPointInScene, color: .systemBlue)
    }
    
    private func visualizePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let scene = parentScene else { return }
        let pinchCenterInView = gesture.location(in: scene.view)
        let pinchCenterInScene = scene.convertPoint(fromView: pinchCenterInView)
        updateOrCreateAnchorNode(name: "pinch", position: pinchCenterInScene, color: .systemBlue)
        
        if gesture.numberOfTouches == 2 {
            for i in 0..<2 {
                let touchLocationInView = gesture.location(ofTouch: i, in: scene.view)
                let touchLocationInScene = scene.convertPoint(fromView: touchLocationInView)
                updateOrCreateTouchNode(name: "pinch-touch-\(i)", position: touchLocationInScene, color: .systemBlue)
            }
        }
    }
    
    private func visualizeRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        guard let scene = parentScene else { return }
        let rotationCenterInView = gesture.location(in: scene.view)
        let rotationCenterInScene = scene.convertPoint(fromView: rotationCenterInView)
        updateOrCreateAnchorNode(name: "rotation", position: rotationCenterInScene, color: .systemBlue)
        
        if gesture.numberOfTouches == 2 {
            for i in 0..<2 {
                let touchLocationInView = gesture.location(ofTouch: i, in: scene.view)
                let touchLocationInScene = scene.convertPoint(fromView: touchLocationInView)
                updateOrCreateTouchNode(name: "rotation-touch-\(i)", position: touchLocationInScene, color: .systemBlue)
            }
        }
    }
    
    /// node creation and manipulation
    private func updateOrCreateAnchorNode(name: String, position: CGPoint, color: SKColor) {
        if let node = gestureVisualizationNodes[name] {
            node.position = position
            adjustForCamera(node: node)
        } else {
            let node = SKShapeNode(circleOfRadius: 2)
            
            //node.fillColor = color
            node.strokeColor = .systemBlue
            node.name = name
            node.zPosition = 9999
            node.position = position
            adjustForCamera(node: node)
            
            addChild(node)
            
            let label = SKLabelNode(text: name)
            label.fontName = myFontName
            label.fontColor = myFontColor
            label.fontSize = 16
            
            if (name == "pan") {
                label.verticalAlignmentMode = .baseline
                label.horizontalAlignmentMode = .right
                label.position = CGPoint(x: -20, y: 20)
            }
            if (name == "pinch") {
                label.verticalAlignmentMode = .baseline
                label.horizontalAlignmentMode = .left
                label.position = CGPoint(x: 20, y: 20)
            }
            if (name == "rotation") {
                label.verticalAlignmentMode = .top
                label.horizontalAlignmentMode = .right
                label.position = CGPoint(x: -20, y: -20)
            }
            
            //node.addChild(label)
            
            gestureVisualizationNodes[name] = node
        }
    }
    
    private func updateOrCreateTouchNode(name: String, position: CGPoint, color: SKColor) {
        if let node = gestureVisualizationNodes[name] {
            node.position = position
            adjustForCamera(node: node)
        } else {
            let node = SKShapeNode(circleOfRadius: 22)
            node.name = name
            node.fillColor = color
            node.strokeColor = myStrokeColor
            node.zPosition = 9999
            node.position = position
            adjustForCamera(node: node)
            addChild(node)
            
            gestureVisualizationNodes[name] = node
        }
    }
    
    func clearGestureVisualization(for gesture: UIGestureRecognizer) {
        switch gesture {
            case is UIPanGestureRecognizer:
                clearVisualizationNodes(withName: "pan")
            case is UIPinchGestureRecognizer:
                clearVisualizationNodes(withName: "pinch")
            case is UIRotationGestureRecognizer:
                clearVisualizationNodes(withName: "rotation")
            default:
                break
        }
    }
    
    private func clearVisualizationNodes(withName name: String) {
        let nodesToRemove = gestureVisualizationNodes.filter { $0.key.contains(name) }
        nodesToRemove.forEach { $0.value.removeFromParent() }
        gestureVisualizationNodes = gestureVisualizationNodes.filter { !$0.key.contains(name) }
    }
    
    private func adjustForCamera(node: SKNode) {
        if let camera = parentScene?.camera {
            node.xScale = camera.xScale
            node.yScale = camera.yScale
        }
    }
}

// MARK: -  Grid generator
/**
 
 This function uses Core Graphics to generate a texture that SpriteKit can use, for example to create a sprite node
 
 */

func generateGridTexture(cellSize: CGFloat, rows: Int, cols: Int, color: SKColor) -> SKTexture? {
    
    /// Add 1 to the height and width to ensure the borders are within the sprite
    let size = CGSize(width: CGFloat(cols) * cellSize + 1, height: CGFloat(rows) * cellSize + 1)
    
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
        
        let bezierPath = UIBezierPath()
        let offset: CGFloat = 0.5
        
        /// vertical lines
        for i in 0...cols {
            let x = CGFloat(i) * cellSize + offset
            bezierPath.move(to: CGPoint(x: x, y: 0))
            bezierPath.addLine(to: CGPoint(x: x, y: size.height))
        }
        /// horizontal lines
        for i in 0...rows {
            let y = CGFloat(i) * cellSize + offset
            bezierPath.move(to: CGPoint(x: 0, y: y))
            bezierPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        
        /// stroke style
        color.setStroke()
        bezierPath.lineWidth = 1
        
        /// draw
        bezierPath.stroke()
    }
    
    return SKTexture(image: image)
}

