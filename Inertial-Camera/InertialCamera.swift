/**
 
 # The Inertial Camera class
 
 This is a custom camera that allows you to freely navigate around the scene in an infinite canvas fashion.
 You use pan, pinch, and rotate gestures to control the camera.
 The camera also implement inertia: at the end of each gesture, the velocity of the change is maintained then slowed down over time.
 
 Tested on iOS. Not adapted for macOS yet.
 
 ## Setup
 
 ```
 override func didMove(to view: SKView) {
     size = view.bounds.size
     let inertialCamera = InertialCameraNode(view: view, scene: self)
     camera = inertialCamera
     addChild(inertialCamera)
 }
 
 ```
 
 ## Inertia
 
 You can enable inertial panning, zooming, and rotating by calling the `updateInertia` method inside the SKScene update loop.
 
 ```
 override func update(_ currentTime: TimeInterval) {
    if let inertialCamera = camera as? InertialCamera {
        inertialCamera.updateInertia()
    }
 }
 ```
 
 You can also selectively toggle inertia on each of pan, pinch, and rotate in the camera settings inside the class.
 
 ## Texture filtering
 
 This camera is set up so it changes the filtering mode of SKSpriteNode and SKShapeNode depending on zoom level.
 The default SpriteKit smoothing is applied at 1:1 scale and when the camera is zoomed out.
 Smoothing is disabled when the camera is zoomed in (magnification), to see the pixel grid.
 This mimicks what bitmap graphical authoring tools do.
 
 
 ## Challenges
 
 Implementing simulataneous pan and rotation has been a challenge. See: https://gist.github.com/AchrafKassioui/bd835b99a78e9ce29b08ce406896c59b
 
 
 Achraf Kassioui
 Created: 8 April 2024
 Updated: 15 April 2024
 
 */

import SpriteKit

/// we subclass SKCameraNode, and add a delegate for UIKit gesture recognizers
class InertialCamera: SKCameraNode, UIGestureRecognizerDelegate {
    
    // MARK: - Settings
    
    /// toggle inertia
    var enablePanInertia = true
    var enableScaleInertia = true
    var enableRotationInertia = true
    
    /// inertia state
    var positionVelocity: (x: CGFloat, y: CGFloat) = (0, 0)
    var scaleVelocity: (x: CGFloat, y: CGFloat) = (0, 0)
    var rotationVelocity: CGFloat = 0
    
    /// inertia settings. Values between 0 and 1
    /// lower values = higher friction.
    /// values more than 1 accelerate exponentially. Negative values are unstable.
    var positionInertia: CGFloat = 0.95 /// default 0.95
    var scaleInertia: CGFloat = 0.75 /// default 0.75
    var rotationInertia: CGFloat = 0.85 /// default 0.85
    
    /// zoom settings
    var maxScale: CGFloat = 100 /// max zoom out. Default 0.01x = scale of 100
    var minScale: CGFloat = 0.01 /// max zoom in. Default 100x = scale of 0.01
    
    /// adaptive filtering
    var adaptiveFiltering = true
    
    /// selectively lock camera transforms
    /// the full lock `lock` is tied to the gesture recognizers. If true, the gesture recognizers are disabled.
    var lock = false
    var lockPan = false
    var lockScale = false
    var lockRotation = false
    
    // MARK: - Initialization
    /**
     
     We need methods from the `scene` and the `view` containing the camera.
     We pass a weak reference to the scene, which itself has a reference to its view.
     We setup the gesture recognizers on the view.
     
     */
    
    weak private var parentScene: SKScene?
    
    init(scene: SKScene) {
        self.parentScene = scene
        
        super.init()
        
        if let view = scene.view {
            self.setupGestureRecognizers(view: view)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Set camera
    /**
     
     Send the camera to a specific position, scale, and rotation.
     
     */
    
    func setCameraTo(position: CGPoint, xScale: CGFloat, yScale: CGFloat, rotation: CGFloat) {
        /// the minimum and maximum durations for the animation of each transform
        let minDuration: CGFloat = 0.3
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
        if initialScale >= 1 {
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
        let scaleAction = SKAction.scale(to: CGSize(width: xScale, height: yScale), duration: scaleDuration)
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
        
        self.run(finalAnimation)
    }
    
    // MARK: - Adaptive filtering
    /**
     
     The filtering mode of textures is changed depending on camera zoom.
     When the scale is below 1 (zoom in) on either x or y, linear filtering and anti aliasing are disabled.
     When the scale is 1 or above (zoom out) on either x and y, linear filtering and anti aliasing are enabled (default renderer behavior).
     This is an opinionated choice. When the camera is zoomed in, I want to see the pixel grid, not a blur. This behavior can be toggled.
     
     Adaptive filtering is called whenever the camera scale is changed after initialization, thanks to the observer `didSet` on the camera scale property.
     
     */
    
    private var wasCameraScaleBelowOne: (x: Bool, y: Bool) = (false, false)
    
    /// override to access the super class (SKCameraNode) scale properties
    override var xScale: CGFloat {
        didSet { updateFilteringMode() }
    }
    
    override var yScale: CGFloat {
        didSet { updateFilteringMode() }
    }
    
    private func updateFilteringMode() {
        /// check both scales
        let isCameraScaleBelowOne = xScale < 1 || yScale < 1
        
        /// check if the scale state has changed (crossed the threshold of 1)
        if adaptiveFiltering && (wasCameraScaleBelowOne.x != isCameraScaleBelowOne || wasCameraScaleBelowOne.y != isCameraScaleBelowOne) {
            /// apply pixelated rendering for sprite textures when the camera is zoomed in
            let filteringMode: SKTextureFilteringMode = isCameraScaleBelowOne ? .nearest : .linear
            /// disable antialiasing for shape nodes when camera is zommed in
            let shouldAntialias = !isCameraScaleBelowOne
            
            /// there is probably a more performant way to implement this logic
            enumerateChildNodes(withName: "//*") { node, _ in
                if let spriteNode = node as? SKSpriteNode {
                    spriteNode.texture?.filteringMode = filteringMode
                } else if let shapeNode = node as? SKShapeNode {
                    shapeNode.isAntialiased = shouldAntialias
                    shapeNode.fillTexture?.filteringMode = filteringMode
                }
            }
            
            wasCameraScaleBelowOne = (xScale < 1, yScale < 1)
        }
    }
    
    // MARK: - Pan
    
    /// pan state
    private var positionBeforePanGesture = CGPoint.zero
    
    @objc private func panCamera(gesture: UIPanGestureRecognizer) {
        if lockPan { return }
        
        guard let scene = parentScene else { return }
        
        if gesture.state == .began {
            
            //positionVelocity = (0, 0)
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
            self.position = CGPoint(
                x: self.position.x - dx * self.xScale,
                y: self.position.y - dy * self.yScale
            )
            
            /// it is important to implement panning by immediately applying delta translations to the current camera position.
            /// if we used a logic that applies the cumulative translation since the gesture has started, there would be a confilct with other logics that also change camera position repeatedly, such as rotation.
            /// see: https://gist.github.com/AchrafKassioui/bd835b99a78e9ce29b08ce406896c59b
            /// we reset the translation so that after each gesture change, we get a delta, not an accumulation.
            gesture.setTranslation(.zero, in: scene.view)
            
        } else if gesture.state == .ended {
            
            /// at the end of the gesture, calculate the velocity to pass to the inertia simulation.
            /// we devide by an arbitrary factor for better user experience
            positionVelocity.x = self.xScale * gesture.velocity(in: scene.view).x / 100
            positionVelocity.y = self.yScale * gesture.velocity(in: scene.view).y / 100
            
        } else if gesture.state == .cancelled {
            
            /// if the gesture is cancelled, revert to the camera's position at the beginning of the gesture
            self.position = positionBeforePanGesture
            
        }
    }
    
    // MARK: Scale
    
    /// zoom state
    private var scaleBeforePinchGesture: (x: CGFloat, y: CGFloat) = (1, 1)
    private var positionBeforePinchGesture = CGPoint.zero
    
    @objc private func scaleCamera(gesture: UIPinchGestureRecognizer) {
        if lockScale { return }
        
        guard let scene = parentScene else { return }

        let scaleCenterInView = gesture.location(in: scene.view)
        let scaleCenterInScene = scene.convertPoint(fromView: scaleCenterInView)
        
        if gesture.state == .began {
            
            scaleVelocity = (0, 0)
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
            
        } else if gesture.state == .ended {
            
            scaleVelocity.x = self.xScale * gesture.velocity / 100
            scaleVelocity.y = self.xScale * gesture.velocity / 100
            
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
    private var cumulativeRotation: CGFloat = 0
    private var rotationPivot = CGPoint.zero
    
    @objc private func rotateCamera(gesture: UIRotationGestureRecognizer) {
        if lockRotation { return }
        
        guard let scene = parentScene else { return }
        
        let midpointInView = gesture.location(in: scene.view)
        let midpointInScene = scene.convertPoint(fromView: midpointInView)
        
        if gesture.state == .began {
            
            rotationVelocity = 0
            rotationBeforeRotationGesture = self.zRotation
            positionBeforeRotationGesture = self.position
            rotationPivot = midpointInScene
            cumulativeRotation = 0
            
        } else if gesture.state == .changed {
            
            /// update camera rotation
            self.zRotation = gesture.rotation + rotationBeforeRotationGesture
            
            /// store the rotation change since the last change
            /// needed to update the camera position live
            let rotationDelta = gesture.rotation - cumulativeRotation
            cumulativeRotation += rotationDelta
            
            /// Calculate how the camera should be moved to simulate rotation around the gesture midpoint
            let offsetX = self.position.x - rotationPivot.x
            let offsetY = self.position.y - rotationPivot.y
            
            let rotatedOffsetX = cos(rotationDelta) * offsetX - sin(rotationDelta) * offsetY
            let rotatedOffsetY = sin(rotationDelta) * offsetX + cos(rotationDelta) * offsetY
            
            let newCameraPositionX = rotationPivot.x + rotatedOffsetX
            let newCameraPositionY = rotationPivot.y + rotatedOffsetY
            
            self.position.x = newCameraPositionX
            self.position.y = newCameraPositionY
            
        } else if gesture.state == .ended {
            
            rotationVelocity = self.xScale * gesture.velocity / 100
            
        } else if gesture.state == .cancelled {
            
            self.zRotation = rotationBeforeRotationGesture
            self.position = positionBeforeRotationGesture
            
        }
    }
    
    // MARK: Simulate inertia
    /**
     
     Inertia is simulated by getting a velocity from the gesture recognizer, then integrating it over time according to the inertia setting.
     This method should be called by the update function of the scene that instantiates the camera.
     
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
    
    /// convenience method. Called to stop all ongoing inertia
    func stopInertia() {
        positionVelocity = (0.0, 0.0)
        scaleVelocity = (0.0, 0.0)
        rotationVelocity = 0
    }
    
    // MARK: Gesture recognizers
    
    private func setupGestureRecognizers(view: SKView) {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panCamera(gesture:)))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(scaleCamera(gesture:)))
        let rotationRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(rotateCamera(gesture:)))
        
        panRecognizer.delegate = self
        pinchRecognizer.delegate = self
        rotationRecognizer.delegate = self
        
        panRecognizer.maximumNumberOfTouches = 2
        
        /// this prevents the recognizer from cancelling touch events once a gesture is recognized
        /// In UIKit, this property is set to true by default
        panRecognizer.cancelsTouchesInView = false
        pinchRecognizer.cancelsTouchesInView = false
        rotationRecognizer.cancelsTouchesInView = false
        
        view.addGestureRecognizer(panRecognizer)
        view.addGestureRecognizer(pinchRecognizer)
        view.addGestureRecognizer(rotationRecognizer)
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
