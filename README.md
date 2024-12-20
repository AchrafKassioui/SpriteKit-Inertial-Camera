<center>
<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />
</center>

#  SpriteKit Inertial Camera

This is a custom SpriteKit camera that you can use to navigate around the scene using multi-touch gestures. It supports pan, pinch, and rotate, as well as inertia on each transforms. Inertial Camera naturally shows SpriteKit as it is, i.e. an infinite canvas.

## Video

https://github.com/user-attachments/assets/7d9ecf50-3d83-4db7-8daf-7e3d60b40206

## Setup

Add the `InertialCamera` file or class to your project, then create an instance of the camera and set it as the scene camera, for example inside `didMove`. Note that the camera requires a view on which to setup the gesture recognizers. That view can be the SKView that renders the scene, or a parent UIView.

```swift
override func didMove(to view: SKView) {
    let inertialCamera = InertialCamera()
    inertialCamera.gesturesView = view
    self.camera = inertialCamera
    addChild(inertialCamera)
}
```

Add the the camera's `update()` function inside the scene's `update`. This will simulate inertia.

```swift
override func update(_ currentTime: TimeInterval) {
    if let inertialCamera = camera as? InertialCamera {
        inertialCamera.update()
    }
}
```

Add the camera's `touchesBegan()` function inside the scene's touchesBegan handler. This will stop the camera whenever the scene is touched.
```swift
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
        if let inertialCamera = camera as? InertialCamera {
            inertialCamera.touchesBegan()
        }
}
```

## Protocol

InertialCamera has a `InertialCameraDelegate` protocol that you can implement to notify you of various camera changes. First, add the protocol to the object that you want the camera to send messages to, and include the required protocol methods:

```swift
class MyObject: InertialCameraDelegate {
    func cameraWillScale(to scale: (x: CGFloat, y: CGFloat)) {
    
    }
    
    func cameraDidScale(to scale: (x: CGFloat, y: CGFloat)) {
    
    }
    
    func cameraDidMove(to position: CGPoint) {
    
    }
    
    func cameraDidRotate(to angle: CGFloat) {
    
    }
}
```

Then, in the scene that instantiates the camera, make sure to call the camera’s `didEvaluateActions()` method inside the scene’s `didEvaluateActions()` override:

```swift
override func didEvaluateActions() {
    inertialCamera?.didEvaluateActions()
}
```

This is necessary because some camera methods use SKAction, and SKAction doesn’t automatically notify the camera of the transform changes it makes. Additional code is run after the actions have been evaluated, to keep the protocol functions up to date.

## API

If inertia is enabled and the camera update function is properly called, you can programmatically control the camera with these vector:

```swift
inertialCamera.positionVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.scaleVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.rotationVelocity: CGFloat = 0
```

You can stop ongoing camera inertia and internal actions with `stop()`.

```swift
inertialCamera.stop()
```

You can send the camera to a position, scale, or rotation with an animation. The animation positions, scales, then rotates the camera in a specific order, depending on whether the camera is zooming in or out. The duration of the animation is set within a specific range, depending on how far the camera has to travel. 

```swift
inertialCamera.animateTo(
    position: CGPoint(x: 0, y: 0),
    xScale: 1,
    yScale: 1,
    rotation: 0
)
```

## Settings

This camera has many settings that you can tweak, such as:

```swift
/// Scale works the opposite way of zoom.
/// A higher zoom percentage corresponds to a lower value scale.
/// Maximum zoom out. Default is 10, which is a 10% zoom.
var maxScale: CGFloat = 10
/// Maximum zoom in. Default is 0.25, which is a 400% zoom.
var minScale: CGFloat = 0.25

/// Lock camera pan.
var lockPan = false
/// Lock camera scale.
var lockScale = false
/// Lock camera rotation.
var lockRotation = false
/// Lock the camera by stoping the gesture recogniziers from responding.
var lock = false

/// Toggle position inertia.
var enablePanInertia = true
/// Toggle scale inertia.
var enableScaleInertia = true
/// Toggle rotation inertia.
var enableRotationInertia = true

/// Inertia factors for position, scale, and rotation.
/// These factors determine how motion decays over time.
/// - A value of `1`: no decay; motion continues indefinitely.
/// - A value greater than `1`: causes exponential acceleration.
/// - A negative value: unstable.
/// Lower values = higher friction, resulting in faster decay of motion.
/// Velocity is multiplied by this factor every frame. Default is `0.95`.
var positionInertia: CGFloat = 0.95
/// Scale is multiplied by this factor every frame. Default is `0.75`.
var scaleInertia: CGFloat = 0.75
/// Rotation is multiplied by this factor every frame. Default is `0.85`.
var rotationInertia: CGFloat = 0.85

/// Double tap the view to reset the camera to its default state.
var doubleTapToReset = false

/// Default camera position.
var defaultPosition: CGPoint = .zero
/// Default camera rotation.
var defaultRotation: CGFloat = 0
/// Default camera X scale.
var defaultXScale: CGFloat = 1
/// Default camera Y scale
var defaultYScale: CGFloat = 1
```

## Compatibility

Developed with Xcode 15 and 16, and tested on iOS 17 and above.

On macOS, although the panning works, the controls aren't yet adapted to the trackpad, mouse, and keyboard.

## Credits

This project started as a fork of [SKCamera-Demo](https://github.com/HumboldtCodeClub/SKCamera-Demo). Thank you @HumboldtCodeClub for sharing and commenting your code.
