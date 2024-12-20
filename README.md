<p align="center">
<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />
</p>

#  SpriteKit Inertial Camera

A custom SpriteKit camera designed for smooth navigation around your scene using multi-touch gestures. It supports panning, pinching, and rotating, with inertia applied to each transformation. SpriteKit's scene becomes an infinite canvas.

The camera includes many settings and features that you can customize.

## Video

https://github.com/user-attachments/assets/7d9ecf50-3d83-4db7-8daf-7e3d60b40206

## Run the Demo App

The project comes with an app that you can compile and run on your device:
- Download or clone this project.
- Open with Xcode.
- Change the project's signing to your own.
- Choose a target, whether the simulator or a physical device, and run (Command + R).

Alternatively, the demo scene is setup with Xcode live preview, which works without signing and running:
- Select the demo scene file.
- Open Xcode canvas (Option + Command + Enter).

## Setup the Camera

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
}
```

## API

If inertia is enabled, you can programmatically control the camera with these values:

```swift
inertialCamera.positionVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.scaleVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.rotationVelocity: CGFloat = 0
```

You can stop ongoing inertia and internal actions with `stop()`.

```swift
inertialCamera.stop()
```

You can send the camera to a position, scale, or rotation with an animation. The animation positions, rotates, then scales the camera in a specific order, depending on whether the camera is zooming in or out. The duration of the animation is set within a specific range, depending on how far the camera has to travel. 

```swift
inertialCamera.animateTo(
    position: CGPoint(x: 0, y: 0),
    xScale: 1,
    yScale: 1,
    rotation: 0
)
```

## Protocol

InertialCamera has a `InertialCameraDelegate` protocol that you can implement to notify you of various camera changes. First, add the protocol to the object that you want the camera to send messages to, and include the required protocol methods:

```swift
class MyObject: InertialCameraDelegate {
    func cameraWillScale(to scale: (x: CGFloat, y: CGFloat)) {
        /// Handle pre-scaling logic here
    }
    
    func cameraDidScale(to scale: (x: CGFloat, y: CGFloat)) {
        /// Handle post-scaling logic here
    }
    
    func cameraDidMove(to position: CGPoint) {
        /// Handle camera move logic here
    }
    
    func cameraDidRotate(to angle: CGFloat) {
        /// Handle camera rotation logic here
    }
}
```

Then, in the scene that instantiates the camera, set the camera delegate property, and make sure to call the camera’s `didEvaluateActions()` method inside the scene’s `didEvaluateActions()` override:

```swift
class MyScene: SKScene {
    let myObject = MyObject()

    override func didMove(to view: SKView) {
        inertialCamera.delegate = myObject
    }

    override func didEvaluateActions() {
        inertialCamera.didEvaluateActions()
    }
}
```

We use didEvaluateActions because some camera methods use SKAction, and SKAction doesn’t automatically notify the camera of the transform changes it makes. Additional code is run after the actions have been evaluated, to keep the protocol functions up to date.

## Settings

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

Developed with Xcode 15 and 16. Tested on iOS 17 and 18.

On macOS, although the panning works, the controls aren't yet adapted to the trackpad, mouse, and keyboard.

## Credits

This project started as a fork of [SKCamera-Demo](https://github.com/HumboldtCodeClub/SKCamera-Demo). Thank you @HumboldtCodeClub for sharing and commenting your code.
