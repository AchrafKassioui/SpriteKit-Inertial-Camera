/**
 
 # Gesture Visualization
 
 This class provides interaction feedback for user interaction.
 For each of pan, pinch, and rotate gestures, it draws a circle at the finger position.
 Warning: the class setups its own gesture recognizers, independant from the camera's or any other recognizer in your view.
 
 Achraf Kassioui
 Created: 15 April 2024
 Updated: 16 April 2024
 
 */

import SpriteKit

class GestureVisualization: SKNode, UIGestureRecognizerDelegate {
    
    /// variables
    private var gestureVisualizationNodes: [String: SKNode] = [:]
    private let myFontName: String = "GillSans-SemiBold"
    private let myFontColor = SKColor(white: 0, alpha: 0.8)
    private let myStrokeColor = SKColor(white: 0, alpha: 0.8)
    private let circleRadius: CGFloat = 30
    
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
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(visualizePanGesture(gesture:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(visualizePinchGesture(gesture:)))
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(visualizeRotationGesture(gesture:)))
        
        //panGesture.maximumNumberOfTouches = 2
        
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
    
    /// create visualization
    @objc private func visualizePanGesture(gesture: UIPanGestureRecognizer) {
        guard let scene = parentScene else { return }
        
        if gesture.numberOfTouches == 1 {
            let panPointInView = gesture.location(in: scene.view)
            let panPointInScene = scene.convertPoint(fromView: panPointInView)
            updateOrCreateTouchNode(name: "pan", position: panPointInScene, color: .systemBlue)
        } else {
            clearGestureVisualization(for: gesture)
        }
        
        if gesture.state == .ended || gesture.state == .cancelled {
            clearGestureVisualization(for: gesture)
        }
    }
    
    @objc private func visualizePinchGesture(gesture: UIPinchGestureRecognizer) {
        guard let scene = parentScene else { return }
        
        if gesture.numberOfTouches == 2 {
            for i in 0..<2 {
                let touchLocationInView = gesture.location(ofTouch: i, in: scene.view)
                let touchLocationInScene = scene.convertPoint(fromView: touchLocationInView)
                updateOrCreateTouchNode(name: "pinch-touch-\(i)", position: touchLocationInScene, color: .systemBlue)
            }
        } else {
            clearGestureVisualization(for: gesture)
        }
        
        if gesture.state == .ended || gesture.state == .cancelled {
            clearGestureVisualization(for: gesture)
        }
    }
    
    @objc private func visualizeRotationGesture(gesture: UIRotationGestureRecognizer) {
        guard let scene = parentScene else { return }
        
        if gesture.numberOfTouches == 2 {
            for i in 0..<2 {
                let touchLocationInView = gesture.location(ofTouch: i, in: scene.view)
                let touchLocationInScene = scene.convertPoint(fromView: touchLocationInView)
                updateOrCreateTouchNode(name: "rotation-touch-\(i)", position: touchLocationInScene, color: .systemBlue)
            }
        } else {
            clearGestureVisualization(for: gesture)
        }
        
        if gesture.state == .ended || gesture.state == .cancelled {
            clearGestureVisualization(for: gesture)
        }
    }
    
    private func updateOrCreateTouchNode(name: String, position: CGPoint, color: SKColor) {
        if let node = gestureVisualizationNodes[name] {
            node.position = position
            adjustForCamera(node: node)
        } else {
            let node = SKShapeNode(circleOfRadius: circleRadius)
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
    
    private func adjustForCamera(node: SKNode) {
        if let camera = parentScene?.camera {
            node.xScale = camera.xScale
            node.yScale = camera.yScale
        }
    }
    
    /// clear visualization
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
    
    private func clearAllVisualizationNodes() {
        gestureVisualizationNodes.values.forEach { $0.removeFromParent() }
        gestureVisualizationNodes.removeAll()
    }
}
