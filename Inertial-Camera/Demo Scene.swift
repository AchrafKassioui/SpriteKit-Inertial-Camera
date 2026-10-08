/**
 
 # Inertial Camera Demo Scene
 
 Achraf Kassioui
 Created 19 Dec 2024
 Updated 8 Oct 2026
 
 */
import UIKit
import SwiftUI
import SpriteKit

// MARK: View Controller

class PlaygroundViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    let skView = SKView()
    let scene = DemoScene()
    
    // MARK: Title
    
    func createTitle() {
        let label = UILabel()
        label.textColor = .black
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .left
        label.text = "Drag, Pinch, Rotate"
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18)
        ])
    }
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        /// SKView
        self.view.addSubview(skView)
        skView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            skView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skView.topAnchor.constraint(equalTo: view.topAnchor),
            skView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        skView.presentScene(scene)
        
        /// Title
        createTitle()
    }
    
}

#Preview() {
    PlaygroundViewController()
}

// MARK: Scene

class DemoScene: SKScene, InertialCameraDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    let inertialCamera = InertialCamera()
    let uiLayer = SKNode()
    let contentLayer = SKNode()
    
    let hapticFeedback = UIImpactFeedbackGenerator()
    
    /// Test floating point precision by placing the camera far from the scene origin.
    /// Camera children nodes will jiggle when the camera is far and zoomed in.
    /// See https://www.achrafkassioui.com/blog/spritekit-scene-size/
    var testDistantCamera: Bool = true
    let cameraDistantPosition = CGPoint(x: 10_000_000, y: 10_000_000)
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        view.contentMode = .center
        view.isMultipleTouchEnabled = true
        backgroundColor = .gray
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        setupCamera(view: view)
        setupLayers(withCamera: inertialCamera)
        
        createCameraZoomLabel(parent: uiLayer, view: view)
        createZoomInButton(parent: uiLayer, view: view)
        createZoomOutButton(parent: uiLayer, view: view)
        createCameraPositionLabel(parent: uiLayer, view: view)
        hapticFeedback.prepare()
        
        createBackgroundTiles(parent: contentLayer, at: .zero)
        //createGridOfSprites(parent: contentLayer)
        
        let gestureVisualization = GestureVisualizationLayer(scene: self)
        addChild(gestureVisualization)

        if testDistantCamera {
            createBackgroundTiles(parent: contentLayer, at: cameraDistantPosition)
            let action = SKAction.sequence([
                .wait(forDuration: 0.3),
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.inertialCamera.setTo(position: cameraDistantPosition)
                }
            ])
            
            run(action)
        }
    }
    
    override func willMove(from view: SKView) {
        removeAllChildren()
    }
    
    // MARK: Camera
    
    func setupCamera(view: UIView) {
        inertialCamera.gestureRecognizerDelegate = self
        inertialCamera.delegate = self
        inertialCamera.gesturesView = view
        inertialCamera.lock = false
        inertialCamera.lockPan = false
        inertialCamera.lockScale = false
        inertialCamera.lockRotation = false
        inertialCamera.doubleTapToReset = false
        inertialCamera.maxScale = 10
        inertialCamera.minScale = 0.1
        
        self.camera = inertialCamera
        inertialCamera.zPosition = 1000
        addChild(inertialCamera)
    }
    
    func cameraDidMove(to position: CGPoint) {
        updateCameraPositionLabel()
    }
    
    func cameraDidRotate(to angle: CGFloat) {
        
    }
    
    func cameraDidScale(to scale: CGPoint) {
        updateCameraZoomLabel()
    }
    
    // MARK: didChangeSize
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        if size != oldSize {
            updateCameraPositionLabel()
            relayout()
        }
    }
    
    // MARK: Content
    
    func setupLayers(withCamera camera: SKCameraNode) {
        camera.addChild(uiLayer)
        addChild(contentLayer)
    }
    
    func createGridOfSprites(parent: SKNode, gridSize: Int = 40, spriteSize: CGFloat = 65, spacing: CGFloat = 10) {
        let totalSize = CGFloat(gridSize) * (spriteSize + spacing) - spacing
        let halfGridWidth = totalSize / 2
        let texture = SKTexture(imageNamed: "square_rounded")
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let sprite = SKSpriteNode(texture: texture)
                sprite.colorBlendFactor = 0.4
                sprite.color = SKColor(red: 106/255, green: 106/255, blue: 93/255, alpha: 1)
                
                let x = CGFloat(col) * (spriteSize + spacing) - halfGridWidth + spriteSize / 2
                let y = CGFloat(row) * (spriteSize + spacing) - halfGridWidth + spriteSize / 2
                
                sprite.position = CGPoint(x: x, y: y)
                parent.addChild(sprite)
            }
        }
    }
    
    func createBackgroundTiles(parent: SKNode, at position: CGPoint) {
        let texture = SKTexture(imageNamed: "Kenney_texture_08")
        
        let tileDefinition = SKTileDefinition(texture: texture)
        let tileGroup = SKTileGroup(tileDefinition: tileDefinition)
        let tileSet = SKTileSet(tileGroups: [tileGroup])
        
        let tileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: 50,
            rows: 50,
            tileSize: texture.size()
        )
        
        tileMap.fill(with: tileGroup)
        tileMap.position = position
        
        parent.addChild(tileMap)
    }
    
    // MARK: Create UI
    
    let viewMargin: CGFloat = 10
    let buttonSize = CGSize(width: 80, height: 50)
    let buttonColor = SKColor.darkGray
    
    enum ButtonNames: String {
        case cameraCurrentZoomButton = "cameraCurrentZoomButton"
        case cameraCurrentZoomlabel = "cameraCurrentZoomlabel"
        case cameraZoomInButton = "cameraZoomInButton"
        case cameraZoomInLabel = "cameraZoomInLabel"
        case cameraZoomOutButton = "cameraZoomOutButton"
        case cameraZoomOutLabel = "cameraZoomOutLabel"
        case cameraPositionLabel = "cameraPositionLabel"
    }
    
    func createCameraPositionLabel(parent: SKNode, view: SKView) {
        let label = SKLabelNode()
        label.name = ButtonNames.cameraPositionLabel.rawValue
        label.fontName = "Menlo"
        label.fontSize = 17
        label.fontColor = .black
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        parent.addChild(label)
    }
    
    func createCameraZoomLabel(parent: SKNode, view: SKView) {
        let strokeWidth: CGFloat = 2
        let shape = SKShapeNode(rectOf: CGSize(width: buttonSize.width - strokeWidth, height: buttonSize.height - strokeWidth), cornerRadius: 12)
        shape.lineWidth = strokeWidth
        shape.strokeColor = .black
        shape.fillColor = .white
        shape.alpha = 0.95
        
        let button = SKSpriteNode()
        button.name = ButtonNames.cameraCurrentZoomButton.rawValue
        button.colorBlendFactor = 1
        button.color = buttonColor
        if let texture = view.texture(from: shape) {
            button.texture = texture
            button.size = texture.size()
            parent.addChild(button)
        }
        
        let label = SKLabelNode()
        label.name = ButtonNames.cameraCurrentZoomlabel.rawValue
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        button.addChild(label)
    }
    
    func createZoomInButton(parent: SKNode, view: SKView) {
        let strokeWidth: CGFloat = 2
        let shape = SKShapeNode(rectOf: CGSize(width: buttonSize.width - strokeWidth, height: buttonSize.height - strokeWidth), cornerRadius: 12)
        shape.lineWidth = strokeWidth
        shape.strokeColor = .black
        shape.fillColor = .white
        shape.alpha = 0.95
        
        let button = SKSpriteNode()
        button.name = ButtonNames.cameraZoomInButton.rawValue
        button.colorBlendFactor = 1
        button.color = buttonColor
        if let texture = view.texture(from: shape) {
            button.texture = texture
            button.size = texture.size()
            parent.addChild(button)
        }
        
        let label = SKLabelNode()
        label.name = ButtonNames.cameraZoomInLabel.rawValue
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .light),
            .foregroundColor: SKColor.white,
        ]
        label.attributedText = NSAttributedString(string: "+", attributes: attributes)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        button.addChild(label)
    }
    
    func createZoomOutButton(parent: SKNode, view: SKView) {
        let strokeWidth: CGFloat = 2
        let shape = SKShapeNode(rectOf: CGSize(width: buttonSize.width - strokeWidth, height: buttonSize.height - strokeWidth), cornerRadius: 12)
        shape.lineWidth = strokeWidth
        shape.strokeColor = .black
        shape.fillColor = .white
        shape.alpha = 0.95
        
        let button = SKSpriteNode()
        button.name = ButtonNames.cameraZoomOutButton.rawValue
        button.colorBlendFactor = 1
        button.color = buttonColor
        if let texture = view.texture(from: shape) {
            button.texture = texture
            button.size = texture.size()
            parent.addChild(button)
        }
        
        let label = SKLabelNode()
        label.name = ButtonNames.cameraZoomOutLabel.rawValue
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .light),
            .foregroundColor: SKColor.white,
        ]
        label.attributedText = NSAttributedString(string: "-", attributes: attributes)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        button.addChild(label)
    }
    
    // MARK: Update UI
    
    func updateCameraPositionLabel() {
        if let label = childNode(withName: "//\(ButtonNames.cameraPositionLabel.rawValue)") as? SKLabelNode {
            label.text = "x: \(Int(inertialCamera.position.x)), y: \(Int(inertialCamera.position.y))"
        }
    }
    
    func updateCameraZoomLabel() {
        if let label = childNode(withName: "//\(ButtonNames.cameraCurrentZoomlabel.rawValue)") as? SKLabelNode, let camera = camera {
            let zoomPercentage = 100 / (camera.xScale)
            let text = String(format: "%.0f%%", zoomPercentage)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: SKColor.white,
            ]
            label.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
    }
    
    func relayout() {
        guard let view = view else { return }
        
        let bottomY = -view.bounds.height/2 + max(view.safeAreaInsets.bottom, viewMargin)
        
        if let cameraPositionLabel = childNode(withName: "//\(ButtonNames.cameraPositionLabel.rawValue)")as? SKLabelNode {
            cameraPositionLabel.position = CGPoint(
                x: 0,
                y: bottomY + 70 + cameraPositionLabel.calculateAccumulatedFrame().height / 2
            )
        }
        
        if let cameraCurrentZoomButton = childNode(withName: "//\(ButtonNames.cameraCurrentZoomButton.rawValue)")as? SKSpriteNode {
            cameraCurrentZoomButton.position = CGPoint(
                x: 0,
                y: bottomY + cameraCurrentZoomButton.size.height/2
            )
        }
        
        if let cameraZoomInButton = childNode(withName: "//\(ButtonNames.cameraZoomInButton.rawValue)")as? SKSpriteNode {
            cameraZoomInButton.position = CGPoint(
                x: cameraZoomInButton.size.width + viewMargin,
                y: bottomY + cameraZoomInButton.size.height/2
            )
        }
        
        if let cameraZoomOutButton = childNode(withName: "//\(ButtonNames.cameraZoomOutButton.rawValue)")as? SKSpriteNode {
            cameraZoomOutButton.position = CGPoint(
                x: -cameraZoomOutButton.size.width - viewMargin,
                y: bottomY + cameraZoomOutButton.size.height/2
            )
        }
    }
    
    // MARK: Run Loop
    
    override func update(_ currentTime: TimeInterval) {
        inertialCamera.update()
    }
    
    override func didEvaluateActions() {
        inertialCamera.didEvaluateActions()
    }
    
    // MARK: Gesture Recognizer Delegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: Touch
    
    let buttonAction = SKAction.sequence([
        SKAction.group([
            SKAction.scale(to: 0.9, duration: 0.05),
            SKAction.colorize(with: .systemRed, colorBlendFactor: 1, duration: 0.1)
        ]),
        SKAction.group([
            SKAction.scale(to: 1, duration: 0.05),
            SKAction.colorize(with: SKColor.darkGray, colorBlendFactor: 1, duration: 0.1)
        ])
    ])
    
    func animateButton(button: SKNode) {
        button.removeAction(forKey: "buttonPressed")
        button.run(buttonAction, withKey: "buttonPressed")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchedNodes = nodes(at: touch.location(in: self))
            
            inertialCamera.stop()
            
            if let topNode = touchedNodes.max(by: { $0.zPosition > $1.zPosition }) {
                if topNode.name == ButtonNames.cameraCurrentZoomlabel.rawValue || topNode.name == ButtonNames.cameraCurrentZoomButton.rawValue {
                    animateButton(button: topNode)
                    
                    hapticFeedback.impactOccurred(intensity: 1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.hapticFeedback.impactOccurred(intensity: 1)
                    }
                    
                    inertialCamera.reset()
                }
                
                if topNode.name == ButtonNames.cameraZoomInLabel.rawValue || topNode.name == ButtonNames.cameraZoomInButton.rawValue {
                    animateButton(button: topNode)
                    
                    hapticFeedback.impactOccurred(intensity: 0.5)
                    inertialCamera.scaleVelocity.dx += 0.1
                    inertialCamera.scaleVelocity.dy += 0.1
                }
                
                if topNode.name == ButtonNames.cameraZoomOutLabel.rawValue || topNode.name == ButtonNames.cameraZoomOutButton.rawValue {
                    animateButton(button: topNode)
                    
                    hapticFeedback.impactOccurred(intensity: 0.5)
                    inertialCamera.scaleVelocity.dx -= 0.1
                    inertialCamera.scaleVelocity.dy -= 0.1
                }
            }
        }
    }
    
}
