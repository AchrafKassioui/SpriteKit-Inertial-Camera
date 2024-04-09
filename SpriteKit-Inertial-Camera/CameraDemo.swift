/**
 
 # A demo scene to try out the inertial camera
 
 Achraf Kassioui
 Created: 9 April 2024
 Updated: 9 April 2024
 
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
            options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes],
            debugOptions: [.showsNodeCount, .showsDrawCount, .showsFPS]
        )
        .ignoresSafeArea()
    }
}

#Preview {
    CameraDemoView()
}

// MARK: - Demo scene

class CameraDemoScene: SKScene, UIGestureRecognizerDelegate {
    
    let cameraBaseScale: (x: CGFloat, y: CGFloat) = (1, 1)
    var sprite = SKSpriteNode()
    
    override func didMove(to view: SKView) {
        /// configure view
        size = view.bounds.size
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.89, green: 0.89, blue: 0.84, alpha: 1)
        
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
        
        /// create objects
        sprite = SKSpriteNode(color: .systemRed, size: CGSize(width: 60, height: 60))
        sprite.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 60))
        sprite.physicsBody?.restitution = 1.01
        sprite.physicsBody?.linearDamping = 0
        sprite.zPosition = 10
        sprite.position.y = 300
        sprite.zRotation = .pi * 0.2
        addChild(sprite)
        
        if let gridTexture = generateGridTexture(cellSize: 60, rows: 20, cols: 20, color: SKColor(white: 0, alpha: 0.15)) {
            let gridbackground = SKSpriteNode(texture: gridTexture)
            gridbackground.zPosition = -1
            addChild(gridbackground)
        }
        
        let viewFrame = SKShapeNode(rectOf: CGSize(width: view.frame.width, height: view.frame.height))
        viewFrame.lineWidth = 3
        viewFrame.strokeColor = SKColor(white: 0, alpha: 0.9)
        addChild(viewFrame)
        
        let yAxis = SKShapeNode(rectOf: CGSize(width: 1, height: 100000))
        yAxis.strokeColor = SKColor(white: 0, alpha: 0.1)
        addChild(yAxis)
        
        let xAxis = SKShapeNode(rectOf: CGSize(width: 100000, height: 1))
        xAxis.isAntialiased = false
        xAxis.strokeColor = SKColor(white: 0, alpha: 0.1)
        addChild(xAxis)
        
        /// create camera
        let inertialCamera = InertialCamera(view: view, scene: self)
        camera = inertialCamera
        addChild(inertialCamera)
        inertialCamera.zPosition = 99999
        
        /// create visualization
        let gestureVisualizationHelper = GestureVisualizationHelper(view: view, scene: self)
        addChild(gestureVisualizationHelper)
        
        /// create UI
        createResetCameraButton(with: view)
        createCameraLockButton(with: view)
    }
    
    // MARK: UI
    
    let spacing: CGFloat = 20
    let buttonSize = CGSize(width: 140, height: 50)
    
    /// lock camera
    func createCameraLockButton(with view: SKView) {
        let lockCameraButton = ButtonWithIconAndPattern(
            size: buttonSize,
            labelBase: "Lock Camera",
            labelActive: "Unlock Camera",
            onTouch: toggleCameraLock
        )
        
        lockCameraButton.position = CGPoint(
            x: -80,
            y: -view.frame.height/2 + view.safeAreaInsets.bottom + buttonSize.height/2 + spacing
        )
        
        camera?.addChild(lockCameraButton)
    }
    
    /// reset camera and sprite
    func createResetCameraButton(with view: SKView) {
        let resetCameraButton = ButtonWithIconAndPattern(
            size: buttonSize,
            labelBase: "Reset Camera",
            labelActive: "Reset Camera",
            onTouch: resetCameraAndSprite
        )
        
        resetCameraButton.position = CGPoint(
            x: 80,
            y: -view.frame.height/2 + view.safeAreaInsets.bottom + buttonSize.height/2 + spacing
        )
        
        camera?.addChild(resetCameraButton)
    }
    
    // MARK: Methods
    
    func toggleCameraLock() {
        if let myCamera = self.camera as? InertialCamera {
            myCamera.lock.toggle()
        }
    }
    
    func resetCameraAndSprite(){
        if let inertialCamera = self.camera as? InertialCamera {
            inertialCamera.stopInertia()
            inertialCamera.setCameraTo(
                position: .zero,
                xScale: self.cameraBaseScale.x,
                yScale: self.cameraBaseScale.y,
                rotation: 0
            )
        }
    }
    
    func resetSprite() {
        sprite.position = CGPoint(x: 0, y: 300)
        sprite.zRotation = .pi * 0.2
        sprite.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        sprite.physicsBody?.angularVelocity = 0.0
    }
    
    // MARK: Update loop
    
    override func update(_ currentTime: TimeInterval) {
        if let inertialCamera = camera as? InertialCamera {
            inertialCamera.updateInertia()
        }
    }
    
}

// MARK: - UI buttons

class ButtonWithIconAndPattern: SKShapeNode {
    
    /// a call back function to execute
    /// the function to execute is passed as an argument during initialization
    let onTouch: () -> Void
    
    enum ButtonState {
        case base
        case active
    }
    
    private let label: SKLabelNode
    private let labelBase: String
    private let labelActive: String
    private var buttonState: ButtonState = .base
    
    
    /// initialization
    init(
        size: CGSize,
        labelBase: String,
        labelActive: String,
        onTouch: @escaping () -> Void
    ) {
        self.onTouch = onTouch
        self.labelBase = labelBase
        self.labelActive = labelActive
        
        /// button label
        self.label = SKLabelNode(text: labelBase)
        self.label.fontName = "GillSans-SemiBold"
        self.label.fontColor = SKColor(white: 0, alpha: 0.8)
        self.label.fontSize = 18
        self.label.verticalAlignmentMode = .center
        self.label.isUserInteractionEnabled = false
        
        /// button shape
        super.init()
        self.path = UIBezierPath(
            roundedRect: CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2),size: size),
            cornerRadius: 12).cgPath
        
        /// styling
        strokeColor = SKColor(white: 0, alpha: 1)
        fillColor = SKColor(white: 1, alpha: 0.4)
        
        isUserInteractionEnabled = true
        addChild(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// initialization
    private func updateLabel() {
        let labelText = buttonState == .base ? labelBase : labelActive
        self.label.text = labelText
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        buttonState = buttonState == .base ? .active : .base
        updateLabel()
        onTouch()
    }
    
}

// MARK: - Gesture visualization

class GestureVisualizationHelper: SKNode {
    
    private var gestureVisualizationNodes: [String: SKShapeNode] = [:]
    private let circleRadius: CGFloat = 22
    private let myFontName: String = "GillSans-SemiBold"
    private let myFontColor = SKColor(white: 0, alpha: 0.8)
    
    weak var theView: SKView?
    weak var theScene: SKScene?
    
    init(view: SKView, scene: SKScene) {
        self.theView = view
        self.theScene = scene
        super.init()
        self.setupGestureRecognizers(in: view)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupGestureRecognizers(in view: SKView) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(updateGestureVisualization(gesture:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(updateGestureVisualization(gesture:)))
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(updateGestureVisualization(gesture:)))
        
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(rotationGesture)
    }
    
    @objc func updateGestureVisualization(gesture: UIGestureRecognizer) {
        if let pinchGesture = gesture as? UIPinchGestureRecognizer {
            visualizePinchGesture(pinchGesture)
        } else if let panGesture = gesture as? UIPanGestureRecognizer {
            visualizePanGesture(panGesture)
        } else if let rotationGesture = gesture as? UIRotationGestureRecognizer {
            visualizeRotationGesture(rotationGesture)
        }
        
        if gesture.state == .ended || gesture.state == .cancelled {
            clearGestureVisualization()
        }
    }
    
    private func visualizePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let scene = theScene else { return }
        let nodeName = "pinch"
        let pinchCenterInView = gesture.location(in: self.theView)
        let pinchCenterInScene = scene.convertPoint(fromView: pinchCenterInView)
        updateOrCreateVisualizationNode(name: nodeName, position: pinchCenterInScene, color: .systemCyan, showLabel: true)
        
        if gesture.numberOfTouches == 2 {
            for i in 0..<2 {
                let touchLocationInView = gesture.location(ofTouch: i, in: self.theView)
                let touchLocationInScene = scene.convertPoint(fromView: touchLocationInView)
                updateOrCreateVisualizationNode(name: "pinch-touch-\(i)", position: touchLocationInScene, color: .systemGray, showLabel: false)
            }
        }
    }
    
    private func visualizePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let scene = theScene else { return }
        let nodeName = "pan"
        let panPointInView = gesture.location(in: self.theView)
        let panPointInScene = scene.convertPoint(fromView: panPointInView)
        updateOrCreateVisualizationNode(name: nodeName, position: panPointInScene, color: .systemBlue, showLabel: true)
    }
    
    private func visualizeRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        guard let scene = theScene else { return }
        let rotationCenterInView = gesture.location(in: self.theView)
        let rotationCenterInScene = scene.convertPoint(fromView: rotationCenterInView)
        updateOrCreateVisualizationNode(name: "rotation", position: rotationCenterInScene, color: .systemRed, showLabel: true)
        
        if gesture.numberOfTouches == 2 {
            for i in 0..<2 {
                let touchLocationInView = gesture.location(ofTouch: i, in: self.theView)
                let touchLocationInScene = scene.convertPoint(fromView: touchLocationInView)
                updateOrCreateVisualizationNode(name: "rotation-touch-\(i)", position: touchLocationInScene, color: .systemGreen, showLabel: true)
            }
        }
    }
    
    private func updateOrCreateVisualizationNode(name: String, position: CGPoint, color: UIColor, showLabel: Bool) {
        if let node = gestureVisualizationNodes[name] {
            node.position = position
        } else {
            let node = SKShapeNode(circleOfRadius: circleRadius)
            node.fillColor = color
            node.strokeColor = .white
            node.name = name
            node.zPosition = 9999
            node.position = position
            addChild(node)
            
            if showLabel{
                let label = SKLabelNode(text: name)
                label.fontName = myFontName
                label.fontColor = myFontColor
                label.fontSize = 12
                label.preferredMaxLayoutWidth = 60
                label.numberOfLines = 0
                label.verticalAlignmentMode = .center
                node.addChild(label)
            }
            gestureVisualizationNodes[name] = node
        }
    }
    
    func clearGestureVisualization() {
        gestureVisualizationNodes.values.forEach { $0.removeFromParent() }
        gestureVisualizationNodes.removeAll()
    }
}

