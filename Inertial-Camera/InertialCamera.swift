/**
 
 # Inertial Camera
 
 A custom SKCameraNode to navigate around the scene with multi-touch gestures.
 Use pan, pinch, and rotate gestures to control the camera.
 
 ## Usage
 
 - Create a scene wide instance of the camera.
 - Optionally attach a camera delegate.
 - Optionally attach a gesture recognizer delegate before attaching a view.
 - Attach the view on which recognizers work, such as SKView in didMove.
 - Call the instance's update() inside SpriteKit's update in order to enable inertia.
 - Call the instance's didEvaluateActions() after SpriteKit has evaluated actions, in order to update the camera delegate.
 - Call the instance's stop() inside SpriteKit touchesBegan to stop the camera on touch.
 
 ## Documentation
 
 https://github.com/AchrafKassioui/SpriteKit-Inertial-Camera
 
 Achraf Kassioui
 Created: 8 April 2024
 Updated: 28 May 2026
 
 */

import SpriteKit

// MARK: Protocol
/**
 
 Conform to this protocol to react to camera changes.
 
 */
protocol InertialCameraDelegate: AnyObject {
    func cameraDidScale(to scale: CGPoint)
    func cameraDidMove(to position: CGPoint)
    func cameraDidRotate(to angle: CGFloat)
}

// MARK: Camera

class InertialCamera: SKCameraNode {
    
    // MARK: Settings
    /**
     
     Scale works the opposite way of zoom. A higher zoom percentage corresponds to a lower value scale.
     
     */
    /// Maximum zoom out. Default is 10, which is a 10% zoom.
    var maxScale: CGFloat = 10
    /// Maximum zoom in. Default is 1/6, which is a 600% zoom.
    var minScale: CGFloat = 1/6
    /// Clamp the position of the camera to this area, relative to the camera's parent coordinates. If nil, no clamping is applied.
    var area: CGSize?
    
    /// Lock camera pan.
    var lockPan = false
    /// Lock camera scale.
    var lockScale = false
    /// Lock camera rotation.
    var lockRotation = false
    /// Lock all camera transforms.
    var lock = false
    
    /// Toggle position inertia.
    var enablePanInertia = true
    /// Toggle scale inertia.
    var enableScaleInertia = true
    /// Toggle rotation inertia.
    var enableRotationInertia = true
    
    /**
     
     Inertia factors for position, scale, and rotation.
     These factors determine how motion decays over time.
     - A value of `1`: no decay; motion continues indefinitely.
     - A value greater than `1`: causes exponential acceleration.
     - A negative value: unstable.
     Lower values = higher friction, resulting in faster decay of motion.
     
     */
    
    /// Velocity is multiplied by this factor every frame. Default is `0.95`.
    var positionInertia: CGFloat = 0.95
    /// Scale is multiplied by this factor every frame. Default is `0.75`.
    var scaleInertia: CGFloat = 0.75
    /// Rotation is multiplied by this factor every frame. Default is `0.85`.
    var rotationInertia: CGFloat = 0.85
    
    /// Double tap the view to reset the camera to its default transforms.
    var doubleTapToReset = false
    
    /// Gesture changes that take longer than this duration in seconds will not trigger inertia.
    private var thresholdDurationForInertia: Double = 0.02
    
    /// A unique name used for animation actions.
    private let actionName: String = UUID().uuidString
    
    // MARK: Init
    
    /// Store a default camera position.
    var defaultPosition: CGPoint
    /// Store a default camera X scale.
    var defaultXScale: CGFloat
    /// Store a default camera Y scale.
    var defaultYScale: CGFloat
    /// Store a default camera rotation.
    var defaultRotation: CGFloat
    
    /// The delegate of the gesture recognizers, to allow simultaneous gestures
    /// Must be assigned before `gesturesView`
    weak var gestureRecognizerDelegate: UIGestureRecognizerDelegate?
    
    /// The view on which the gesture recognizers are setup.
    /// This view can be the SKView presenting the scene, or any UIView in the parent hierarchy of SKView.
    weak var gesturesView: UIView? {
        didSet {
            if let view = gesturesView {
                setupGestureRecognizers(gesturesView: view)
            }
        }
    }
    
    init(gestureRecognizerDelegate: UIGestureRecognizerDelegate? = nil, position: CGPoint = .zero, xScale: CGFloat = 1, yScale: CGFloat = 1, rotation: CGFloat = 0) {
        self.gestureRecognizerDelegate = gestureRecognizerDelegate
        self.defaultPosition = position
        self.defaultXScale = xScale
        self.defaultYScale = yScale
        self.defaultRotation = rotation
        
        super.init()
        
        /// We use the setTo method to assign the camera its default starting state
        /// This will triggers the property observers, and therefore the protocol methods.
        setTo(
            position: defaultPosition,
            xScale: defaultXScale,
            yScale: defaultYScale,
            rotation: defaultRotation,
            withAnimation: false
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("InertialCamera: init(coder:) has not been implemented")
    }
    
    // MARK: Public API
    /**
     
     Set the camera to a specific position, scale, and rotation.
     If withAnimation is true (the default), the transforms are animated in a specific manner.
     
     */
    func setTo(
        position: CGPoint? = nil,
        xScale: CGFloat? = nil,
        yScale: CGFloat? = nil,
        rotation: CGFloat? = nil,
        withAnimation: Bool? = nil
    ) {
        /// Toggle manual transform tracking because we are going to use SKAction
        manuallyTriggerThePropertyObservers = true
        
        /// Stop all ongoing inertia and internal actions before starting a new camera animation.
        self.stop()
        
        /// Determine final values for animation
        var targetPosition = position ?? self.position
        targetPosition = clamp(position: targetPosition, to: area)
        let targetXScale = max(minScale, min(maxScale, xScale ?? self.xScale))
        let targetYScale = max(minScale, min(maxScale, yScale ?? self.yScale))
        let targetRotation = rotation ?? self.zRotation
        let animate = withAnimation ?? true
        
        /// The animation duration, in seconds.
        let duration: TimeInterval = animate ? 0.2 : 0
        
        /// Create and run the animation
        let translationAction = SKAction.move(to: targetPosition, duration: duration)
        translationAction.timingMode = .easeInEaseOut
        
        let scaleAction = SKAction.scaleX(to: targetXScale, y: targetYScale, duration: duration)
        scaleAction.timingMode = .easeInEaseOut
        
        let rotateAction = SKAction.rotate(toAngle: targetRotation, duration: duration)
        rotateAction.timingMode = .easeInEaseOut
        
        /// Run translation, scale, and rotation at the same time.
        let finalAnimation = SKAction.group([
            translationAction,
            scaleAction,
            rotateAction
        ])
        finalAnimation.timingMode = .easeInEaseOut
        
        /// After the action ends, stop tracking transforms manually
        let finalAnimationPlusCompletion = SKAction.sequence([
            finalAnimation,
            SKAction.run { [weak self] in
                self?.manuallyTriggerThePropertyObservers = false
            }
        ])
        
        /// Run the action with a name so it can be removed later
        self.run(finalAnimationPlusCompletion, withKey: actionName)
    }
    
    /**
     
     Stop all ongoing inertia and internal actions.
     This method should be called by the touchesBegan event handler of the scene that instantiates the camera.
     
     */
    func stop() {
        self.removeAction(forKey: actionName)
        
        positionVelocity = .zero
        scaleVelocity = .zero
        rotationVelocity = 0
    }
    
    /// Convenience method to set the camera to its default transform values.
    func reset(withAnimation: Bool = true) {
        setTo(
            position: defaultPosition,
            xScale: defaultXScale,
            yScale: defaultYScale,
            rotation: defaultRotation,
            withAnimation: withAnimation
        )
    }
    
    /**
     
     If inertia is enabled, the camera can be controlled programmatically by setting these values manually.
     The inertia simulation implemented by the update function writes on these values.
     
     */
    /// The state of position velocity.
    var positionVelocity = CGVector(dx: 0, dy: 0)
    /// The state of scale velocity.
    var scaleVelocity = CGVector(dx: 0, dy: 0)
    /// The state of rotation velocity.
    var rotationVelocity: CGFloat = 0
    
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
    
    // MARK: Property Observers
    /**
     
     The notifications for the camera protocol methods are made here.
     
     */
    weak var delegate: InertialCameraDelegate?
    
    /// Some transform changes, such as those made with SKAction, do not trigger property observers.
    /// https://developer.apple.com/documentation/spritekit/skaction/detecting_changes_at_each_step_of_an_animation
    /// This tracking variable is used to manually set the transforms in the appropriate run loop, for example in didEvaluateActions.
    private var manuallyTriggerThePropertyObservers: Bool = false
    
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
    
    override var xScale: CGFloat {
        didSet {
            checkAndReportScaleChange()
        }
    }
    
    override var yScale: CGFloat {
        didSet {
            checkAndReportScaleChange()
        }
    }
    
    /// The current x and y scales as a CGPoint.
    var currentScale: CGPoint {
        return CGPoint(x: xScale, y: yScale)
    }
    
    private var lastReportedScale = CGPoint.zero
    
    /// Check both x and y scale before notifying the delegate.
    private func checkAndReportScaleChange() {
        let newScale = currentScale
        if newScale != lastReportedScale {
            lastReportedScale = newScale
            delegate?.cameraDidScale(to: newScale)
        }
    }
    
    // MARK: Clamping
    
    private func clamp(position: CGPoint, to area: CGSize?) -> CGPoint {
        guard let area = area else { return position }
        
        let minX = -area.width / 2
        let maxX = area.width / 2
        let minY = -area.height / 2
        let maxY = area.height / 2
        
        let clampedX = max(minX, min(position.x, maxX))
        let clampedY = max(minY, min(position.y, maxY))
        
        return CGPoint(x: clampedX, y: clampedY)
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
            
            /// Clamp position to camera area
            self.position = clamp(position: self.position, to: area)
            
            /// It is important to implement panning by immediately applying delta translations to the current camera position.
            /// If we used a logic that applies the cumulative translation since the gesture has started, there would be a confilct with other logic that also change camera position repeatedly, such as rotation.
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
            
            /// Clamp position to camera area
            self.position = clamp(position: self.position, to: area)
            
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
            
            /// Store the rotation delta since the last gesture change, apply it to the camera, then reset the gesture rotation value
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
            
            /// Clamp position to camera area
            self.position = clamp(position: self.position, to: area)
            
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
        
        self.setTo(position: defaultPosition, xScale: defaultXScale, yScale: defaultYScale, rotation: defaultRotation)
    }
    
    // MARK: Update
    /**
     
     Simulate inertia.
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
            
            /// Clamp position to camera area
            self.position = clamp(position: self.position, to: area)
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
    
    // MARK: Gesture Recognizers
    
    func setupGestureRecognizers(gesturesView: UIView) {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panCamera(gesture:)))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(scaleCamera(gesture:)))
        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotateCamera(gesture:)))
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(gesture:)))
        
        /// Delegates are set to allow simultaneous gesture recognition
        panRecognizer.delegate = gestureRecognizerDelegate
        pinchRecognizer.delegate = gestureRecognizerDelegate
        rotationRecognizer.delegate = gestureRecognizerDelegate
        tapRecognizer.delegate = gestureRecognizerDelegate
        
        /// Recognize double taps
        tapRecognizer.numberOfTapsRequired = 2
        
        panRecognizer.delaysTouchesBegan = false
        pinchRecognizer.delaysTouchesBegan = false
        rotationRecognizer.delaysTouchesBegan = false
        tapRecognizer.delaysTouchesBegan = false
        
        /// Prevent the recognizers from cancelling touch events once a gesture is recognized.
        /// In UIKit, this property is set to true by default.
        panRecognizer.cancelsTouchesInView = false
        pinchRecognizer.cancelsTouchesInView = false
        rotationRecognizer.cancelsTouchesInView = false
        tapRecognizer.cancelsTouchesInView = false
        
        /// Allow `touchesEnded` to fire immediately, preventing delays caused by UIKit's default gesture handling.
        /// This avoids missing `touchesEnded` events when a gesture is recognized.
        panRecognizer.delaysTouchesEnded = false
        pinchRecognizer.delaysTouchesEnded = false
        rotationRecognizer.delaysTouchesEnded = false
        tapRecognizer.delaysTouchesEnded = false
        
        /// Attach the recognizers to the view
        gesturesView.addGestureRecognizer(panRecognizer)
        gesturesView.addGestureRecognizer(pinchRecognizer)
        gesturesView.addGestureRecognizer(rotationRecognizer)
        gesturesView.addGestureRecognizer(tapRecognizer)
    }
    
}
