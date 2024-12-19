/**
 
 # SpriteKit Inertial Camera
 
 This is a custom SpriteKit camera that allows you to freely navigate around the scene using multi-touch gestures.
 You use pan, pinch, and rotate gestures to control the camera.
 The camera includes inertia: at the end of each gesture, the velocity of the change is maintained then slowed down over time.
 
 Tested on iOS. Not adapted for macOS yet.
 
 ## Setup
 
 - Include this file in your project.
 - Create an instance of InertialCamera.
 - Set the view that will receive gesture recognition. It could be the SKView or a parent UIView.
 - Set this camera as the scene camera.
 - Add the camera to the scene.
 
 ```
 override func didMove(to view: SKView) {
    let inertialCamera = InertialCamera()
    inertialCamera.gesturesView = view
    self.camera = inertialCamera
    addChild(inertialCamera)
 }
 ```
 
 
 ## Inertia
 
 You enable inertial panning, zooming, and rotating by calling the camera `update()` function from the update function of SKScene.
 
 ```
 override func update(_ currentTime: TimeInterval) {
    if let inertialCamera = camera as? InertialCamera {
        inertialCamera.update()
    }
 }
 ```
 
 ## Challenges
 
 Implementing simulataneous pan and rotation has been a challenge. See: https://gist.github.com/AchrafKassioui/bd835b99a78e9ce29b08ce406896c59b
 The solution is to not rely on cumulative states stored when gesture has began. Instead, continuously reset the gesture value inside the changed state.
 
 
 ## Author
 
 Achraf Kassioui
 Created: 8 April 2024
 Updated: 19 December 2024
 
 */

import SpriteKit

// MARK: Protocol

protocol InertialCameraDelegate: AnyObject {
    func cameraWillScale(to scale: (x: CGFloat, y: CGFloat))
    func cameraDidScale(to scale: (x: CGFloat, y: CGFloat))
    func cameraDidMove(to position: CGPoint)
    func cameraDidRotate(to angle: CGFloat)
}

/// Subclass SKCameraNode, and add the protocol that allows simulatenous gesture recognition
class InertialCamera: SKCameraNode, UIGestureRecognizerDelegate {
    
    // MARK: Settings
    
    /// Maximum zoom out. Default is 10, which is a 10% zoom.
    var maxScale: CGFloat = 10
    /// Maximum zoom in. Default is 0.25, which is a 400% zoom.
    var minScale: CGFloat = 0.25
    
    /// Toggle position inertia.
    var enablePanInertia = true
    /// Toggle scale inertia.
    var enableScaleInertia = true
    /// Toggle rotation inertia.
    var enableRotationInertia = true
    
    /// Lock camera pan.
    var lockPan = false
    /// Lock camera scale.
    var lockScale = false
    /// Lock camera rotation.
    var lockRotation = false
    /// Lock the camera by stoping the gesture recogniziers from responding.
    var lock = false
    
    /// Toggle double tap to reset position, scale, and rotation.
    var doubleTapToReset = false
    
    /**
     
     # Inertia
     
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
    
    /// Gesture changes that take longer than this duration in seconds will not trigger inertia.
    private var thresholdDurationForInertia: Double = 0.02
    
    // MARK: API
    /**
     
     You can control the camera programmatically by setting these values manually.
     
     */
    /// The state of position velocity.
    var positionVelocity = CGVector(dx: 0, dy: 0)
    /// The state of scale velocity.
    var scaleVelocity = CGVector(dx: 0, dy: 0)
    /// The state of rotation velocity.
    var rotationVelocity: CGFloat = 0
    
    /// Stop all ongoing inertia and internal actions.
    func stop() {
        self.removeAction(forKey: actionName)
        
        positionVelocity = .zero
        scaleVelocity = .zero
        rotationVelocity = 0
    }
    
    // MARK: Initialization
    /**
     
     Creating the camera requires to pass in the view on which the gesture recognizers will be setup.
     That view can be the SKView presenting the scene, or any UIView in the parent hierarchy of SKView.
     
     */
    /// The view on which the camera gesture recognizers are setup.
    weak var gesturesView: UIView? {
        didSet {
            if let view = gesturesView {
                setupGestureRecognizers(gesturesView: view)
            }
        }
    }
    
    // MARK: Property Observers
    /**
     
     The notifications for the camera protocol methods are made here.
     
     */
    weak var delegate: InertialCameraDelegate?
    
    /// Some transform changes, such as those made with SKAction, do not trigger property observers.
    /// https://developer.apple.com/documentation/spritekit/skaction/detecting_changes_at_each_step_of_an_animation
    /// This tracking variable is used to manually set the transforms in the appropriate run loop, for example in didEvaluateActions.
    private var manuallyTriggerThePropertyObservers: Bool = false
    
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
    
    override var zRotation: CGFloat {
        didSet {
            delegate?.cameraDidRotate(to: zRotation)
        }
    }
    
    // MARK: Isometric View
    /**
     
     Toggle an isometric view of the 2D scene.
     Unfinished.
     
     */
    private var isIsometric = false
    private let isometricScaleMultiplier = 0.75
    private let isometricRotation = -45 * (CGFloat.pi / 180)
    
    var isometric: Bool {
        get { return isIsometric }
        set {
            if isIsometric != newValue {
                isIsometric = newValue
                
                let targetXScale = isIsometric ? xScale * isometricScaleMultiplier : xScale / isometricScaleMultiplier
                let targetRotation = isIsometric ? isometricRotation : 0
                
                let scaleAction = SKAction.scaleX(to: targetXScale, duration: 0.3)
                let rotateAction = SKAction.rotate(toAngle: targetRotation, duration: 0.3)
                
                run(SKAction.group([scaleAction, rotateAction]))
            }
        }
    }
    
    // MARK: Set Camera
    /**
     
     Animate the camera to a specific position, scale, and rotation.
     
     */
    
    let actionName: String = "InertialCameraSetAction"
    
    func setTo(position: CGPoint? = nil, xScale: CGFloat? = nil, yScale: CGFloat? = nil, rotation: CGFloat? = nil) {
        if position == nil && xScale == nil && yScale == nil && rotation == nil {
            return
        }
        /// Toggle manual transform tracking because we are going to use SKAction
        manuallyTriggerThePropertyObservers = true
        self.stop()
        
        /// Determine final values for animation
        let targetPosition = position ?? self.position
        let targetXScale = max(minScale, min(maxScale, xScale ?? self.xScale))
        let targetYScale = max(minScale, min(maxScale, yScale ?? self.yScale))
        let targetRotation = rotation ?? self.zRotation
        
        /// The minimum and maximum durations for the animation of each transform
        let minDuration: CGFloat = 0.2
        let maxDuration: CGFloat = 3
        /// The maximum points per second traveled by the camera
        let translationSpeed: CGFloat = 10000
        /// The maximum scale factor change per second
        let scaleSpeed: CGFloat = 50
        /// The maximum number of camera revolutions per second
        let rotationSpeed: CGFloat = 4 * .pi
        
        /// Calculate the animation duration of the translation
        let distance = sqrt(pow(targetPosition.x - self.position.x, 2) + pow(targetPosition.y - self.position.y, 2))
        let translationDuration = min(maxDuration, max(minDuration, Double(distance / translationSpeed)))
        
        /// Calculate the animation duration of the scaling
        let initialScale = max(self.xScale, self.yScale)
        let finalScale = max(targetXScale, targetYScale)
        var scaleDelta: CGFloat
        if initialScale >= targetXScale || initialScale >= targetYScale {
            scaleDelta = initialScale / finalScale
        } else {
            scaleDelta = finalScale / initialScale
        }
        let scaleDuration = min(maxDuration, max(minDuration, Double(scaleDelta / scaleSpeed)))
        
        /// Calculate the animation duration of the rotation
        let rotationDelta = abs(targetRotation - self.zRotation)
        let rotationDuration = min(maxDuration, max(minDuration, Double(rotationDelta / rotationSpeed)))
        
        /// Create and run the animation
        let translationAction = SKAction.move(to: targetPosition, duration: translationDuration)
        translationAction.timingMode = .easeInEaseOut
        let scaleAction = SKAction.scaleX(to: targetXScale, y: targetYScale, duration: scaleDuration)
        scaleAction.timingMode = .easeInEaseOut
        let rotateAction = SKAction.rotate(toAngle: targetRotation, duration: rotationDuration)
        rotateAction.timingMode = .easeInEaseOut
        
        var finalAnimation: SKAction
        
        /// The order of the animation depends on whether the camera is zooming in or out
        if (self.xScale >= targetXScale || self.yScale >= targetYScale) {
            finalAnimation = SKAction.sequence([translationAction, rotateAction, scaleAction])
        } else {
            finalAnimation = SKAction.sequence([scaleAction, rotateAction, translationAction])
        }
        finalAnimation.timingMode = .easeInEaseOut
        
        /// After the action ends, stop tracking transforms manually
        let finalAnimationPlusCompletion = SKAction.sequence([
            finalAnimation,
            SKAction.run { [weak self] in
                self?.manuallyTriggerThePropertyObservers = false
            }
        ])
        
        /// Assign the action a key so it can be removed later
        self.run(finalAnimationPlusCompletion, withKey: actionName)
    }
    
    // MARK: Adaptive filtering
    /**
     
     This camera is able to change the filtering mode of SKSpriteNode and SKShapeNode depending on zoom level.
     The adaptive filtering is applied only to sprite and shape nodes that are children of a specific parent node.
     When the scale is 1.0 or above (zoom out) on either x and y, linear filtering and anti-aliasing are enabled (the default renderer behavior).
     When the scale is below 1.0 (zoom in) on either x or y, linear filtering and anti-aliasing are disabled.
     
     This mimicks what bitmap graphical authoring tools do, and allow you to see the pixel grid.
     By default, adaptive filtering is off.
     
     ## Todo
     
     Currently broken.
     
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
    
    // MARK: Pan
    
    /// Pan state
    private var positionBeforePanGesture = CGPoint.zero
    private var lastPanGestureTimestamp: TimeInterval = 0
    
    @objc private func panCamera(gesture: UIPanGestureRecognizer) {
        if lockPan || lock { return }
        
        guard let gesturesView = self.gesturesView else { return }
        
        if gesture.state == .began {
            
            /// Store the camera's position at the beginning of the pan gesture
            positionBeforePanGesture = self.position
            
        } else if gesture.state == .changed {
            
            /// Convert UIKit translation coordinates to SpriteKit's coordinates for mathematical clarity further down
            let uiKitTranslation = gesture.translation(in: gesturesView)
            let translation = CGPoint(
                /// UIKit and SpriteKit share the same x-axis direction
                x: uiKitTranslation.x,
                /// Invert y because UIKit's y-axis increases downwards, opposite to SpriteKit's
                y: -uiKitTranslation.y
            )
            
            /// Transform the translation from the screen coordinate system to the camera's local coordinate system, considering its rotation.
            let angle = self.zRotation
            let dx = translation.x * cos(angle) - translation.y * sin(angle)
            let dy = translation.x * sin(angle) + translation.y * cos(angle)
            
            /// Apply the transformed translation to the camera's position, accounting for the current scale.
            /// We moves the camera opposite to the gesture direction (-dx and -dy), building the impression of moving the scene itself.
            /// If we wanted direct manipulation of a node, dx and dy would be added instead of subtracted.
            self.position.x = self.position.x - dx * self.xScale
            self.position.y = self.position.y - dy * self.yScale
            
            /// It is important to implement panning by immediately applying delta translations to the current camera position.
            /// If we used a logic that applies the cumulative translation since the gesture has started, there would be a confilct with other logics that also change camera position repeatedly, such as rotation.
            /// See: https://gist.github.com/AchrafKassioui/bd835b99a78e9ce29b08ce406896c59b
            /// We reset the translation so that after each gesture change, we get a delta, not an accumulation.
            gesture.setTranslation(.zero, in: gesturesView)
            
            /// Store the timestamp when the gesture last changed
            lastPanGestureTimestamp = Date().timeIntervalSince1970
            
        } else if gesture.state == .ended {
            
            /// Calculate the delta time between gesture end and last gesture change
            /// If the duration is below a threshold, store velocity
            /// If the duration is above a threshold, reset velocity
            if Date().timeIntervalSince1970 - lastPanGestureTimestamp < thresholdDurationForInertia {
                /// At the end of the gesture, calculate the velocity to pass to the inertia simulation.
                /// We divide by an arbitrary factor for better user experience.
                positionVelocity.dx = self.xScale * gesture.velocity(in: gesturesView).x / 80
                positionVelocity.dy = self.yScale * gesture.velocity(in: gesturesView).y / 80
            } else {
                positionVelocity = .zero
            }
            
            
        } else if gesture.state == .cancelled {
            
            /// If the gesture is cancelled, revert to the camera's position at the beginning of the gesture
            self.position = positionBeforePanGesture
            
        }
    }
    
    // MARK: Pinch
    
    /// Scale state
    private var scaleBeforePinchGesture: (x: CGFloat, y: CGFloat) = (1, 1)
    private var positionBeforePinchGesture = CGPoint.zero
    private var lastPinchGestureTimestamp: TimeInterval = 0
    
    @objc private func scaleCamera(gesture: UIPinchGestureRecognizer) {
        if lockScale || lock { return }
        
        guard let parentScene = self.scene, let gesturesView = self.gesturesView else { return }
        
        let scaleCenterInView = gesture.location(in: gesturesView)
        let scaleCenterInScene = parentScene.convertPoint(fromView: scaleCenterInView)
        
        if gesture.state == .began {
            
            scaleBeforePinchGesture.x = self.xScale
            scaleBeforePinchGesture.y = self.yScale
            positionBeforePinchGesture = self.position
            
        } else if gesture.state == .changed {
            
            /// Respect the base scaling ratio
            let newXScale = (self.xScale / gesture.scale)
            let newYScale = (self.yScale / gesture.scale)
            
            /// Limit the resulting scale within a range
            let clampedXScale = max(min(newXScale, maxScale), minScale)
            let clampedYScale = max(min(newYScale, maxScale), minScale)
            
            /// Calculate a factor to move the camera toward the pinch midpoint
            let xTranslationFactor = clampedXScale / self.xScale
            let yTranslationFactor = clampedYScale / self.yScale
            let newCamPosX = scaleCenterInScene.x + (self.position.x - scaleCenterInScene.x) * xTranslationFactor
            let newCamPosY = scaleCenterInScene.y + (self.position.y - scaleCenterInScene.y) * yTranslationFactor
            
            /// Update camera scale and position
            self.xScale = clampedXScale
            self.yScale = clampedYScale
            self.position = CGPoint(x: newCamPosX, y: newCamPosY)
            
            /// Reset the gesture scale delta
            gesture.scale = 1.0
            
            /// Store the timestamp when the gesture last changed
            lastPinchGestureTimestamp = Date().timeIntervalSince1970
            
        } else if gesture.state == .ended {
            
            if Date().timeIntervalSince1970 - lastPinchGestureTimestamp < thresholdDurationForInertia {
                scaleVelocity.dx = self.xScale * gesture.velocity / 100
                scaleVelocity.dy = self.xScale * gesture.velocity / 100
            } else {
                scaleVelocity = .zero
            }
            
        } else if gesture.state == .cancelled {
            
            self.xScale = scaleBeforePinchGesture.x
            self.yScale = scaleBeforePinchGesture.y
            self.position = positionBeforePinchGesture
            
        }
    }
    
    // MARK: Rotate
    
    /// Rotation state
    private var positionBeforeRotationGesture = CGPoint.zero
    private var rotationBeforeRotationGesture: CGFloat = 0
    private var rotationPivot = CGPoint.zero
    private var lastRotationGestureTimestamp: TimeInterval = 0
    
    @objc private func rotateCamera(gesture: UIRotationGestureRecognizer) {
        if lockRotation || lock { return }
        
        guard let parentScene = self.scene, let gesturesView = self.gesturesView else { return }
        
        let midpointInView = gesture.location(in: gesturesView)
        let midpointInScene = parentScene.convertPoint(fromView: midpointInView)
        
        if gesture.state == .began {
            
            rotationBeforeRotationGesture = self.zRotation
            positionBeforeRotationGesture = self.position
            rotationPivot = midpointInScene
            
        } else if gesture.state == .changed {
            
            /// Store the rotation delta since the last gesture change, and apply it to the camera, then reset the gesture rotation value
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
    
    @objc private func handleDoubleTap(gesture: UITapGestureRecognizer) {
        if lock || !doubleTapToReset { return }
        
        self.setTo(position: .zero, xScale: 1, yScale: 1, rotation: 0)
    }
    
    // MARK: Update
    /**
     
     Inertia is simulated by getting a velocity after the gesture has ended, then integrating it over time according to inertia settings.
     This method should be called by the update method of the scene that instantiates the camera.
     
     */
    func update() {
        /// Reduce the load by checking the current position velocity first
        if (enablePanInertia && (positionVelocity.dx != 0 || positionVelocity.dy != 0)) {
            /// Apply friction to velocity
            positionVelocity.dx *= positionInertia
            positionVelocity.dy *= positionInertia
            
            /// Calculate the rotated velocity to account for camera rotation
            let angle = self.zRotation
            let rotatedVelocityX = positionVelocity.dx * cos(angle) + positionVelocity.dy * sin(angle)
            let rotatedVelocityY = -positionVelocity.dx * sin(angle) + positionVelocity.dy * cos(angle)
            
            /// Stop the camera when velocity is near zero to prevent oscillation
            if abs(positionVelocity.dx) < 0.01 { positionVelocity.dx = 0 }
            if abs(positionVelocity.dy) < 0.01 { positionVelocity.dy = 0 }
            
            /// Update the camera's position with the rotated velocity
            self.position.x -= rotatedVelocityX
            self.position.y += rotatedVelocityY
        }
        
        /// Reduce the load by checking the current scale velocity first
        if (enableScaleInertia && (scaleVelocity.dx != 0 || scaleVelocity.dy != 0)) {
            /// Apply friction to velocity so the camera slows to a stop when user interaction ends.
            scaleVelocity.dx *= scaleInertia
            scaleVelocity.dy *= scaleInertia
            
            /// Stop the camera when velocity has approached close enough to zero
            if (abs(scaleVelocity.dx) < 0.001) { scaleVelocity.dx = 0 }
            if (abs(scaleVelocity.dy) < 0.001) { scaleVelocity.dy = 0 }
            
            let newXScale = self.xScale - scaleVelocity.dx
            let newYScale = self.yScale - scaleVelocity.dy
            
            /// Prevent the inertial zooming from exceeding the zoom limits
            let clampedXScale = max(min(newXScale, maxScale), minScale)
            let clampedYScale = max(min(newYScale, maxScale), minScale)
            
            self.xScale = clampedXScale
            self.yScale = clampedYScale
        }
        
        /// Reduce the load by checking the current scale velocity first
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
    
    // MARK: didEvaluateActions
    /**
     
     The camera protocol methods require this for proper tracking.
     This method should be called by the didEvaluateActions method of the scene that instantiates the camera.
     
     */
    func didEvaluateActions() {
        /// Manually trigger the property observers
        if manuallyTriggerThePropertyObservers {
            position = position
            xScale = xScale
            yScale = yScale
            zRotation = zRotation
        }
    }
    
    // MARK: Touch
    /**
     
     This method should be called by the touchesBegan event handler of the scene that instantiates the camera.
     
     */
    func touchesBegan() {
        stop()
    }
    
    // MARK: Gesture Recognizers
    
    /// Allow multiple gesture recognizers to recognize gestures at the same time.
    /// For this function to work, the protocol `UIGestureRecognizerDelegate` must be added to this class,
    /// and a delegate must be set on the recognizer that needs to work with others
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func setupGestureRecognizers(gesturesView: UIView) {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panCamera(gesture:)))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(scaleCamera(gesture:)))
        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotateCamera(gesture:)))
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(gesture:)))
        
        /// Delegates are set to allow simultaneous gesture recognition
        panRecognizer.delegate = self
        pinchRecognizer.delegate = self
        rotationRecognizer.delegate = self
        tapRecognizer.delegate = self
        
        panRecognizer.maximumNumberOfTouches = 2
        tapRecognizer.numberOfTapsRequired = 2
        
        /// Prevent the recognizers from cancelling touch events once a gesture is recognized
        /// In UIKit, this property is set to true by default
        panRecognizer.cancelsTouchesInView = false
        pinchRecognizer.cancelsTouchesInView = false
        rotationRecognizer.cancelsTouchesInView = false
        tapRecognizer.cancelsTouchesInView = false
        
        /// Allow touchesEnded events to fire immediately
        tapRecognizer.delaysTouchesEnded = false
        tapRecognizer.delaysTouchesBegan = false
        
        /// Attach the recognizers to the view
        gesturesView.addGestureRecognizer(panRecognizer)
        gesturesView.addGestureRecognizer(pinchRecognizer)
        gesturesView.addGestureRecognizer(rotationRecognizer)
        gesturesView.addGestureRecognizer(tapRecognizer)
    }
    
    /// Use this function to determine if gesture recognizers should be triggered
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        /// here, you can add logic to determine whether the gesture recognizer should fire
        /// for example, if some area is touched, return false to disable the gesture recognition
        /// for this camera, we disable the gestures if the `lock` property is false
        return !lock
    }
}

/**
 
 # Custom Pan Gesture Recognizer
 
 By default, UIKit's pan gesture recognizer starts recognizing a pan after touches have moved across 10 points.
 This sublcass of UIPanGestureRecognizer forces the recognition to happen immediately upon touchesMoved.
 This cutsom class works, but the start up motion is not smooth. Need more work.
 Inertial Camera uses the default UIPanGestureRecognizer.
 
 */
class InstantPanGestureRecognizer: UIPanGestureRecognizer {
    
    /// Override the touchesMoved function to make it trigger immediately
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        /// Force the gesture recognizer to start recognizing the gesture immediately
        if state == .possible {
            state = .began
        }
    }
}
