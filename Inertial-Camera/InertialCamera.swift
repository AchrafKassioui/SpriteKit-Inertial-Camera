/**
 
 # The Inertial Camera class
 
 This is a custom camera that allows you to freely navigate around the scene in an infinite canvas fashion.
 You use pan, pinch, and rotate gestures to control the camera.
 The camera includes inertia: at the end of each gesture, the velocity of the change is maintained then slowed down over time.
 
 Tested on iOS. Not adapted for macOS yet.
 
 
 ## Setup
 
 Include this file in your project, then create an instance of InertialCamera and set it as the scene camera.
 
 ```
 override func didMove(to view: SKView) {
    size = view.bounds.size
    let inertialCamera = InertialCameraNode(scene: self)
    camera = inertialCamera
    addChild(inertialCamera)
 }
 
 ```
 
 
 ## Inertia
 
 You enable inertial panning, zooming, and rotating by calling `updateInertia()` inside the SKScene update loop.
 
 ```
 override func update(_ currentTime: TimeInterval) {
     if let inertialCamera = camera as? InertialCamera {
        inertialCamera.updateInertia()
     }
 }
 ```
 
 You can also selectively toggle inertia on each of pan, pinch, and rotate in the camera settings. For example:
 
 ```
 inertialCamera.enableRotationInertia = false
 
 ```
 
 
 ## Adaptive filtering
 
 ```
 let objectsLayer = SKNode()
 inertialCamera.setAdaptiveFiltering(forChildrenOf: objectsLayer, to: true)
 
 ```
 
 
 ## Challenges
 
 Implementing simulataneous pan and rotation has been a challenge. See: https://gist.github.com/AchrafKassioui/bd835b99a78e9ce29b08ce406896c59b
 The solution is to not rely on cumulative states stored when gesture has began. Instead, continuously reset the gesture value inside the changed state.
 
 
 ## Author
 
 Achraf Kassioui
 Created: 8 April 2024
 Updated: 10 June 2024
 
 */

import SpriteKit

protocol InertialCameraDelegate: AnyObject {
    func cameraWillScale(to scale: (x: CGFloat, y: CGFloat))
    func cameraDidScale(to scale: (x: CGFloat, y: CGFloat))
    func cameraDidMove(to position: CGPoint)
}

/// We subclass SKCameraNode, and add a delegate for UIKit gesture recognizers
class InertialCamera: SKCameraNode, UIGestureRecognizerDelegate {
    
    // MARK: - Settings
    
    /// toggle panning inertia
    var enablePanInertia = true
    /// toggle scale inertia
    var enableScaleInertia = true
    /// toggle rotation inertia
    var enableRotationInertia = true
    
    /**
     
     Inertia settings.
     Values between 0 and 1. Lower values = higher friction.
     A value of 1 will perpetuate the motion indefinitely.
     Values more than 1 will accelerate exponentially. Negative values are unstable.
     
     */
    /// Velocity is multiplied by this factor every frame. Default is 0.95
    var positionInertia: CGFloat = 0.95
    /// Scale is multiplied by this factor every frame. Default is 0.75
    var scaleInertia: CGFloat = 0.75
    /// Rotation is multiplied by this factor every frame. Default is 0.85
    var rotationInertia: CGFloat = 0.85
    
    /**
     
     Inertia state.
     You can control the camera programmatically by passing a value to these variables
     
     */
    var positionVelocity: (x: CGFloat, y: CGFloat) = (0, 0)
    var scaleVelocity: (x: CGFloat, y: CGFloat) = (0, 0)
    var rotationVelocity: CGFloat = 0
    
    /// Convenience method. Called to stop all ongoing inertia.
    func stopInertia() {
        positionVelocity = (0.0, 0.0)
        scaleVelocity = (0.0, 0.0)
        rotationVelocity = 0
    }
    
    /**
     
     Camera zoom settings.
     
     */
    /// Maximum camera scale. Default is 10, which is a 10% zoom.
    var maxScale: CGFloat = 10
    /// Minimum camera scale. Default is 0.25, which is a 400% zoom.
    var minScale: CGFloat = 0.25
    
    /// selectively lock the camera transforms
    var lockPan = false
    var lockScale = false
    var lockRotation = false
    
    /// a full `lock` disables the gesture recognizers
    var lock = false
    
    // MARK: - Property Observers
    
    weak var delegate: InertialCameraDelegate?
    
    override var xScale: CGFloat {
        willSet {
            delegate?.cameraWillScale(to: (x: newValue, y: yScale))
        }
        didSet {
            delegate?.cameraDidScale(to: (x: xScale, y: yScale))
            updateFilteringMode()
        }
    }
    
    override var yScale: CGFloat {
        willSet {
            delegate?.cameraWillScale(to: (x: xScale, y: newValue))
        }
        didSet {
            delegate?.cameraDidScale(to: (x: xScale, y: yScale))
            updateFilteringMode()
        }
    }
    
    override var position: CGPoint {
        didSet {
            delegate?.cameraDidMove(to: position)
        }
    }
    
    // MARK: - Initialization
    /**
     
     We need methods from the `scene` and the `view`.
     We store a weak reference to the scene, which itself has a reference to the view.
     We either pass the scene during init, or we manually assign a scene to the `parentScene` property.
     
     */
    
    /// Assign a scene to the camera, and setup gesture recognizers on the view associated with it.
    weak var parentScene: SKScene? {
        didSet {
            if let scene = parentScene, let view = scene.view {
                self.setupGestureRecognizers(view: view)
            }
        }
    }
    
    /// Assign a scene now, or do it later with the parentScene property.
    init(scene: SKScene? = nil) {
        super.init()
        self.parentScene = scene
        
        /// If a scene is passed during init, setup gesture recognizers
        /// Init does not trigger didSet, so we do it manually here
        if let scene = scene, let view = scene.view {
            self.setupGestureRecognizers(view: view)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Set camera
    /**
     
     Send the camera to a specific position, scale, and rotation, with an animation.
     
     ## Todo
     
     SpriteKit actions do not trigger property observers like didSet, and therefore, delegate functions won't be called properly.
     We need to observe changes made by SKAction on camera position, rotation, and scale.
     
     */
    func setTo(position: CGPoint, xScale: CGFloat, yScale: CGFloat, rotation: CGFloat) {
        self.stopInertia()
        self.delegate?.cameraWillScale(to: (x: xScale, y: yScale))
        
        /// the minimum and maximum durations for the animation of each transform
        let minDuration: CGFloat = 0.2
        let maxDuration: CGFloat = 3
        /// the maximum points per second traveled by the camera
        let translationSpeed: CGFloat = 10000
        /// the maximum scale factor change per second
        let scaleSpeed: CGFloat = 50
        /// the maximum number of camera revolutions per second
        let rotationSpeed: CGFloat = 4 * .pi
        
        /// calculate the duration of the translation
        let distance = sqrt(pow(position.x - self.position.x, 2) + pow(position.y - self.position.y, 2))
        let translationDuration = min(maxDuration, max(minDuration, Double(distance / translationSpeed)))
        
        /// calculate the duration of the scaling
        let initialScale = max(self.xScale, self.yScale)
        let finalScale = max(xScale, yScale)
        var scaleDelta: CGFloat
        if initialScale >= xScale || initialScale >= yScale {
            scaleDelta = initialScale / finalScale
        } else {
            scaleDelta = finalScale / initialScale
        }
        let scaleDuration = min(maxDuration, max(minDuration, Double(scaleDelta / scaleSpeed)))
        
        /// calculate the duration of the rotation
        let rotationDelta = abs(rotation - self.zRotation)
        let rotationDuration = min(maxDuration, max(minDuration, Double(rotationDelta / rotationSpeed)))
        
        /// choose the longest duration
        /// use this if the animations are grouped instead of sequenced
        //let longestDuration = max(translationDuration, scaleDuration, rotationDuration)
        
        /// create and run animation actions
        let translationAction = SKAction.move(to: position, duration: translationDuration)
        translationAction.timingMode = .easeInEaseOut
        let scaleAction = SKAction.scaleX(to: xScale, y: yScale, duration: scaleDuration)
        scaleAction.timingMode = .easeInEaseOut
        let rotateAction = SKAction.rotate(toAngle: rotation, duration: rotationDuration)
        rotateAction.timingMode = .easeInEaseOut
        
        var finalAnimation: SKAction
        
        if (self.xScale >= xScale || self.yScale >= yScale) {
            finalAnimation = SKAction.sequence([translationAction, rotateAction, scaleAction])
        } else {
            finalAnimation = SKAction.sequence([scaleAction, rotateAction, translationAction])
        }
        finalAnimation.timingMode = .easeInEaseOut
        
        /// SKAction do not trigger property observers
        /// https://developer.apple.com/documentation/spritekit/skaction/detecting_changes_at_each_step_of_an_animation
        /// So after running the animation, we manually set the properties
        self.run(finalAnimation) {
            self.delegate?.cameraDidScale(to: (x: xScale, y: yScale))
        }
    }
    
    // MARK: - Adaptive filtering
    /**
     
     This camera is able to change the filtering mode of SKSpriteNode and SKShapeNode depending on zoom level.
     The adaptive filtering is applied only to sprite and shape nodes that are children of a specific parent node.
     When the scale is 1.0 or above (zoom out) on either x and y, linear filtering and anti-aliasing are enabled (the default renderer behavior).
     When the scale is below 1.0 (zoom in) on either x or y, linear filtering and anti-aliasing are disabled.
     
     This mimicks what bitmap graphical authoring tools do, and allow you to see the pixel grid.
     By default, adaptive filtering is off.
     
     ## Todo
     
     Currently very broken.
     
     */
    
    /// Children of this node will get adaptive texture filtering
    weak var adaptiveFilteringParent: SKNode? {
        didSet {
            if adaptiveFilteringParent != nil { adaptiveFiltering = true}
            else { adaptiveFiltering = false}
        }
    }
    /// Toggle adaptive filtering, if a parent node is defined.
    var adaptiveFiltering = false
    /// Is the camera zoomed in.
    private(set) var isZoomedIn: Bool = false
    
    private func updateFilteringMode() {
        let _isZoomedIn = xScale < 1 || yScale < 1
        
        if adaptiveFiltering, let parent = adaptiveFilteringParent {
            if _isZoomedIn != isZoomedIn {
                setSmoothing(to: !_isZoomedIn, forChildrenOf: parent)
            }
        } else if !adaptiveFiltering, let parent = adaptiveFilteringParent {
            setSmoothing(to: true, forChildrenOf: parent)
        }
        
        isZoomedIn = _isZoomedIn
    }
    
    func setSmoothing(to smoothing: Bool, forChildrenOf parent: SKNode) {
        let filteringMode: SKTextureFilteringMode = smoothing ? .linear : .nearest
        let antialiasing = smoothing
        
        for node in parent.children {
            if let spriteNode = node as? SKSpriteNode {
                spriteNode.texture?.filteringMode = filteringMode
                /// Force the redraw of the texture to apply the new filtering mode
                spriteNode.texture = spriteNode.texture
            } else if let shapeNode = node as? SKShapeNode {
                shapeNode.isAntialiased = antialiasing
                shapeNode.fillTexture?.filteringMode = filteringMode
                /// Force redraw
                shapeNode.fillTexture = shapeNode.fillTexture
            }
        }
    }
    
    // MARK: - Shared gestures state
    
    /// Gesture changes that take longer than this duration in seconds will not trigger inertia.
    private var thresholdDurationForInertia: Double = 0.02
    
    // MARK: Pan
    
    /// pan state
    private var positionBeforePanGesture = CGPoint.zero
    private var lastPanGestureTimestamp: TimeInterval = 0
    
    @objc private func panCamera(gesture: UIPanGestureRecognizer) {
        if lockPan || lock { return }
        
        guard let scene = self.parentScene else { return }
        
        if gesture.state == .began {
            
            /// store the camera's position at the beginning of the pan gesture
            positionBeforePanGesture = self.position
            
        } else if gesture.state == .changed {
            
            /// convert UIKit translation coordinates to SpriteKit's coordinates for mathematical clarity further down
            let uiKitTranslation = gesture.translation(in: scene.view)
            let translation = CGPoint(
                /// UIKit and SpriteKit share the same x-axis direction
                x: uiKitTranslation.x,
                /// invert y because UIKit's y-axis increases downwards, opposite to SpriteKit's
                y: -uiKitTranslation.y
            )
            
            /// transform the translation from the screen coordinate system to the camera's local coordinate system, considering its rotation.
            let angle = self.zRotation
            let dx = translation.x * cos(angle) - translation.y * sin(angle)
            let dy = translation.x * sin(angle) + translation.y * cos(angle)
            
            /// apply the transformed translation to the camera's position, accounting for the current scale.
            /// we moves the camera opposite to the gesture direction (-dx and -dy), building the impression of moving the scene itself.
            /// if we wanted direct manipulation of a node, dx and dy would be added instead of subtracted.
            self.position.x = self.position.x - dx * self.xScale
            self.position.y = self.position.y - dy * self.yScale
            
            /// it is important to implement panning by immediately applying delta translations to the current camera position.
            /// if we used a logic that applies the cumulative translation since the gesture has started, there would be a confilct with other logics that also change camera position repeatedly, such as rotation.
            /// see: https://gist.github.com/AchrafKassioui/bd835b99a78e9ce29b08ce406896c59b
            /// we reset the translation so that after each gesture change, we get a delta, not an accumulation.
            gesture.setTranslation(.zero, in: scene.view)
            
            /// Store the timestamp when the gesture last changed
            lastPanGestureTimestamp = Date().timeIntervalSince1970
            
        } else if gesture.state == .ended {
            
            /// Calculate the delta time between gesture end and last gesture change
            /// If the duration is below a threshold, store velocity
            /// If the duration is above a threshold, reset velocity
            if Date().timeIntervalSince1970 - lastPanGestureTimestamp < thresholdDurationForInertia {
                /// at the end of the gesture, calculate the velocity to pass to the inertia simulation.
                /// we divide by an arbitrary factor for better user experience
                positionVelocity.x = self.xScale * gesture.velocity(in: scene.view).x / 80
                positionVelocity.y = self.yScale * gesture.velocity(in: scene.view).y / 80
            } else {
                positionVelocity = (0, 0)
            }
            
            
        } else if gesture.state == .cancelled {
            
            /// if the gesture is cancelled, revert to the camera's position at the beginning of the gesture
            self.position = positionBeforePanGesture
            
        }
    }
    
    // MARK: Pinch
    
    /// zoom state
    private var scaleBeforePinchGesture: (x: CGFloat, y: CGFloat) = (1, 1)
    private var positionBeforePinchGesture = CGPoint.zero
    private var lastPinchGestureTimestamp: TimeInterval = 0
    
    @objc private func scaleCamera(gesture: UIPinchGestureRecognizer) {
        if lockScale || lock { return }
        
        guard let scene = parentScene else { return }
        
        let scaleCenterInView = gesture.location(in: scene.view)
        let scaleCenterInScene = scene.convertPoint(fromView: scaleCenterInView)
        
        if gesture.state == .began {
            
            scaleBeforePinchGesture.x = self.xScale
            scaleBeforePinchGesture.y = self.yScale
            positionBeforePinchGesture = self.position
            
        } else if gesture.state == .changed {
            
            /// respect the base scaling ratio
            let newXScale = (self.xScale / gesture.scale)
            let newYScale = (self.yScale / gesture.scale)
            
            /// limit the resulting scale within a range
            let clampedXScale = max(min(newXScale, maxScale), minScale)
            let clampedYScale = max(min(newYScale, maxScale), minScale)
            
            /// calculate a factor to move the camera toward the pinch midpoint
            let xTranslationFactor = clampedXScale / self.xScale
            let yTranslationFactor = clampedYScale / self.yScale
            let newCamPosX = scaleCenterInScene.x + (self.position.x - scaleCenterInScene.x) * xTranslationFactor
            let newCamPosY = scaleCenterInScene.y + (self.position.y - scaleCenterInScene.y) * yTranslationFactor
            
            /// update camera scale and position
            self.xScale = clampedXScale
            self.yScale = clampedYScale
            self.position = CGPoint(x: newCamPosX, y: newCamPosY)
            
            /// reset the gesture scale delta
            gesture.scale = 1.0
            
            /// Store the timestamp when the gesture last changed
            lastPinchGestureTimestamp = Date().timeIntervalSince1970
            
        } else if gesture.state == .ended {
            
            if Date().timeIntervalSince1970 - lastPinchGestureTimestamp < thresholdDurationForInertia {
                scaleVelocity.x = self.xScale * gesture.velocity / 100
                scaleVelocity.y = self.xScale * gesture.velocity / 100
            } else {
                scaleVelocity = (0, 0)
            }
            
        } else if gesture.state == .cancelled {
            
            self.xScale = scaleBeforePinchGesture.x
            self.yScale = scaleBeforePinchGesture.y
            self.position = positionBeforePinchGesture
            
        }
    }
    
    // MARK: Rotate
    
    /// rotation state
    private var positionBeforeRotationGesture = CGPoint.zero
    private var rotationBeforeRotationGesture: CGFloat = 0
    private var rotationPivot = CGPoint.zero
    private var lastRotationGestureTimestamp: TimeInterval = 0
    
    @objc private func rotateCamera(gesture: UIRotationGestureRecognizer) {
        if lockRotation || lock { return }
        
        guard let scene = parentScene else { return }
        
        let midpointInView = gesture.location(in: scene.view)
        let midpointInScene = scene.convertPoint(fromView: midpointInView)
        
        if gesture.state == .began {
            
            rotationBeforeRotationGesture = self.zRotation
            positionBeforeRotationGesture = self.position
            rotationPivot = midpointInScene
            
        } else if gesture.state == .changed {
            
            /// store the rotation delta since the last gesture change, and apply it to the camera, then reset the gesture rotation value
            let rotationDelta = gesture.rotation
            self.zRotation += rotationDelta
            gesture.rotation = 0
            
            /// Calculate where the camera should be positioned to simulate a rotation around the gesture midpoint
            let offsetX = self.position.x - rotationPivot.x
            let offsetY = self.position.y - rotationPivot.y
            
            let rotatedOffsetX = cos(rotationDelta) * offsetX - sin(rotationDelta) * offsetY
            let rotatedOffsetY = sin(rotationDelta) * offsetX + cos(rotationDelta) * offsetY
            
            let newCameraPositionX = rotationPivot.x + rotatedOffsetX
            let newCameraPositionY = rotationPivot.y + rotatedOffsetY
            
            self.position.x = newCameraPositionX
            self.position.y = newCameraPositionY
            
            /// Store the timestamp when the gesture last changed
            lastRotationGestureTimestamp = Date().timeIntervalSince1970
            
        } else if gesture.state == .ended {
            
            if Date().timeIntervalSince1970 - lastRotationGestureTimestamp < thresholdDurationForInertia {
                rotationVelocity = self.xScale * gesture.velocity / 100
            } else {
                rotationVelocity = 0
            }
            
        } else if gesture.state == .cancelled {
            
            self.zRotation = rotationBeforeRotationGesture
            self.position = positionBeforeRotationGesture
            
        }
    }
    
    // MARK: Double tap
    
    @objc private func resetCamera(gesture: UITapGestureRecognizer) {
        if lock { return }
        
        self.setTo(position: .zero, xScale: 1, yScale: 1, rotation: 0)
    }
    
    // MARK: Simulate inertia
    /**
     
     Inertia is simulated by getting a velocity from the gesture recognizer, then integrating it over time according to the inertia setting.
     This method should be called by the update loop of the scene that instantiates the camera.
     
     */
    func updateInertia() {
        
        /// reduce the load by checking the current position velocity first
        if (enablePanInertia && (positionVelocity.x != 0 || positionVelocity.y != 0)) {
            /// apply friction to velocity
            positionVelocity.x *= positionInertia
            positionVelocity.y *= positionInertia
            
            /// calculate the rotated velocity to account for camera rotation
            let angle = self.zRotation
            let rotatedVelocityX = positionVelocity.x * cos(angle) + positionVelocity.y * sin(angle)
            let rotatedVelocityY = -positionVelocity.x * sin(angle) + positionVelocity.y * cos(angle)
            
            /// Stop the camera when velocity is near zero to prevent oscillation
            if abs(positionVelocity.x) < 0.01 { positionVelocity.x = 0 }
            if abs(positionVelocity.y) < 0.01 { positionVelocity.y = 0 }
            
            /// Update the camera's position with the rotated velocity
            self.position.x -= rotatedVelocityX
            self.position.y += rotatedVelocityY
        }
        
        /// reduce the load by checking the current scale velocity first
        if (enableScaleInertia && (scaleVelocity.x != 0 || scaleVelocity.y != 0)) {
            /// Apply friction to velocity so the camera slows to a stop when user interaction ends.
            scaleVelocity.x *= scaleInertia
            scaleVelocity.y *= scaleInertia
            
            /// Stop the camera when velocity has approached close enough to zero
            if (abs(scaleVelocity.x) < 0.001) { scaleVelocity.x = 0 }
            if (abs(scaleVelocity.y) < 0.001) { scaleVelocity.y = 0 }
            
            let newXScale = self.xScale - scaleVelocity.x
            let newYScale = self.yScale - scaleVelocity.y
            
            /// prevent the inertial zooming from exceeding the zoom limits
            let clampedXScale = max(min(newXScale, maxScale), minScale)
            let clampedYScale = max(min(newYScale, maxScale), minScale)
            
            self.xScale = clampedXScale
            self.yScale = clampedYScale
        }
        
        /// reduce the load by checking the current scale velocity first
        if (enableRotationInertia && rotationVelocity != 0) {
            /// Apply friction to velocity so the camera slows to a stop when user interaction ends
            rotationVelocity *= rotationInertia
            
            /// Stop the camera when velocity has approached close enough to zero
            if (abs(rotationVelocity) < 0.001) {
                rotationVelocity = 0
            }
            
            self.zRotation += rotationVelocity
        }
    }
    
    // MARK: Gesture recognizers
    
    private func setupGestureRecognizers(view: SKView) {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panCamera(gesture:)))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(scaleCamera(gesture:)))
        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotateCamera(gesture:)))
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(resetCamera(gesture:)))
        
        panRecognizer.delegate = self
        pinchRecognizer.delegate = self
        rotationRecognizer.delegate = self
        tapRecognizer.delegate = self
        
        panRecognizer.maximumNumberOfTouches = 2
        tapRecognizer.numberOfTapsRequired = 2
        
        /// this prevents the recognizer from cancelling touch events once a gesture is recognized
        /// In UIKit, this property is set to true by default
        panRecognizer.cancelsTouchesInView = false
        pinchRecognizer.cancelsTouchesInView = false
        rotationRecognizer.cancelsTouchesInView = false
        tapRecognizer.cancelsTouchesInView = false
        
        /// Allows touches ended event to fire immediately
        tapRecognizer.delaysTouchesEnded = false
        tapRecognizer.delaysTouchesBegan = false
        
        view.addGestureRecognizer(panRecognizer)
        view.addGestureRecognizer(pinchRecognizer)
        view.addGestureRecognizer(rotationRecognizer)
        view.addGestureRecognizer(tapRecognizer)
    }
    
    /// allow multiple gesture recognizers to recognize gestures at the same time
    /// for this function to work, the protocol `UIGestureRecognizerDelegate` must be added to this class
    /// and a delegate must be set on the recognizer that needs to work with others
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /// Use this function to determine if gesture recognizers should be triggered
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        /// here, you can add logic to determine whether the gesture recognizer should fire
        /// for example, if some area is touched, return false to disable the gesture recognition
        /// for this camera, we disable the gestures if the `lock` property is false
        return !lock
    }
}
