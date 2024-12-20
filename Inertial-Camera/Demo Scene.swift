/**
 
 # Inertial Camera Demo Scene
 
 Achraf Kassioui
 Created 19 December 2024
 Updated 19 December 2024
 
 */

import UIKit
import SpriteKit

// MARK: - UIKit

class PlaygroundViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    let skView = SKView()
    let scene = DemoScene()
    
    // MARK: View
    
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
    }
}

#Preview() {
    PlaygroundViewController()
}

// MARK: - SpriteKit

class DemoScene: SKScene, InertialCameraDelegate {
    
    var inertialCamera: InertialCamera?
    
    let uiLayer = SKNode()
    let contentLayer = SKNode()
    
    var contentCreated: Bool = false
    
    let hapticFeedback = UIImpactFeedbackGenerator()
    
    // MARK: Setup Scene
    
    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        view.contentMode = .center
        view.isMultipleTouchEnabled = true
        backgroundColor = .gray
        
        if !contentCreated {
            setupCamera(view: view)
            setupLayers()
            
            createCameraZoomLabel(parent: uiLayer, view: view)
            createZoomInButton(parent: uiLayer, view: view)
            createZoomOutButton(parent: uiLayer, view: view)
            hapticFeedback.prepare()
            
            createBackgroundTiles(parent: contentLayer)
            createGridOfSprites(parent: contentLayer)
            
            let gestureVisualization = GestureVisualizationLayer(scene: self)
            addChild(gestureVisualization)
            
            contentCreated = true
        }
    }
    
    func setupLayers() {
        guard let camera = camera else { return }
        camera.addChild(uiLayer)
        addChild(contentLayer)
    }
    
    // MARK: Setup Camera
    
    func setupCamera(view: UIView) {
        inertialCamera = InertialCamera()
        inertialCamera?.gesturesView = view
        
        /// The camera delegate is the scene itself
        /// We will use the camera protocol to update the zoom UI
        inertialCamera?.delegate = self
        
        camera = inertialCamera
        if let inertialCamera = inertialCamera { addChild(inertialCamera) }
        inertialCamera?.zPosition = 1000
    }
    
    // MARK: Camera Protocol
    
    func cameraWillScale(to scale: (x: CGFloat, y: CGFloat)) {
        updateCameraZoomLabel()
    }
    
    func cameraDidScale(to scale: (x: CGFloat, y: CGFloat)) {
        updateCameraZoomLabel()
    }
    
    func cameraDidMove(to position: CGPoint) {
        
    }
    
    func cameraDidRotate(to angle: CGFloat) {
        
    }
    
    // MARK: didChangeSize
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        if size != oldSize {
            relayout()
        }
    }
    
    // MARK: Content
    
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
    
    func createBackgroundTiles(parent: SKNode) {
        let texture = SKTexture(imageNamed: "checker_beige")
        
        let tileDefinition = SKTileDefinition(texture: texture)
        let tileGroup = SKTileGroup(tileDefinition: tileDefinition)
        let tileSet = SKTileSet(tileGroups: [tileGroup])
        
        let tileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: 20,
            rows: 20,
            tileSize: texture.size()
        )
        
        tileMap.fill(with: tileGroup)
        tileMap.position = CGPoint(x: -0, y: 0)
        
        parent.addChild(tileMap)
    }
    
    // MARK: UI
    
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
    
    // MARK: UI Layout
    
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
    
    // MARK: Update
    
    override func update(_ currentTime: TimeInterval) {
        inertialCamera?.update()
    }
    
    // MARK: didEvaluateActions
    
    override func didEvaluateActions() {
        inertialCamera?.didEvaluateActions()
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
            
            inertialCamera?.touchesBegan()
            
            if let topNode = touchedNodes.max(by: { $0.zPosition > $1.zPosition }) {
                if topNode.name == ButtonNames.cameraCurrentZoomlabel.rawValue || topNode.name == ButtonNames.cameraCurrentZoomButton.rawValue {
                    animateButton(button: topNode)
                    
                    hapticFeedback.impactOccurred(intensity: 1)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.hapticFeedback.impactOccurred(intensity: 1)
                    }
                    
                    inertialCamera?.setTo(
                        position: inertialCamera?.defaultPosition,
                        xScale: inertialCamera?.defaultXScale,
                        yScale: inertialCamera?.defaultYScale,
                        rotation: inertialCamera?.defaultRotation
                    )
                }
                
                if topNode.name == ButtonNames.cameraZoomInLabel.rawValue || topNode.name == ButtonNames.cameraZoomInButton.rawValue {
                    animateButton(button: topNode)
                    
                    hapticFeedback.impactOccurred(intensity: 0.5)
                    inertialCamera?.scaleVelocity.dx += 0.1
                    inertialCamera?.scaleVelocity.dy += 0.1
                }
                
                if topNode.name == ButtonNames.cameraZoomOutLabel.rawValue || topNode.name == ButtonNames.cameraZoomOutButton.rawValue {
                    animateButton(button: topNode)
                    
                    hapticFeedback.impactOccurred(intensity: 0.5)
                    inertialCamera?.scaleVelocity.dx -= 0.1
                    inertialCamera?.scaleVelocity.dy -= 0.1
                }
            }
        }
    }
}
