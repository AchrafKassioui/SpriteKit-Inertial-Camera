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

Add the `InertialCamera` file or class to your project, then create an instance of the camera and set it as the scene camera. Note that the camera requires a view on which to setup the gesture recognizers. That view can be the SKView that renders the scene, or a parent UIView.

```swift
class MyScene: SKScene {
    let inertialCamera = InertialCamera()

    override func didMove(to view: SKView) {
        inertialCamera.gesturesView = view
        addChild(inertialCamera)
        camera = inertialCamera
    }
}
```

Add the the camera's `update()` function inside the scene's `update`. This will simulate inertia.

```swift
override func update(_ currentTime: TimeInterval) {
    inertialCamera.update()
}
```

Add the camera's `touchesBegan()` function inside the scene's touchesBegan handler. This will stop the camera whenever the scene is touched.
```swift
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
        inertialCamera.touchesBegan()
    }
}
```

## API

You can send the camera to a position, scale, or rotation with an animation.
If animated, the camera's position, rotation, and scale are applied in a specific order, depending on whether the camera is zooming in or out.
The duration of the animation is picked within a range, depending on how much the camera has to change. These custom values can be teaked in the definition of the `setTo` function. 

```swift
inertialCamera.setTo(
    position: CGPoint? = nil,
    xScale: CGFloat? = nil,
    yScale: CGFloat? = nil,
    rotation: CGFloat? = nil,
    withAnimation: Bool? = nil // Default is true
)

/// Example usage
inertialCamera.setTo(xScale: 2, yScale: 2)
```

If inertia is enabled, you can programmatically control the camera. Each value is evaluated once per frame in the update method. The inertia simulation itself writes on these values.

```swift
inertialCamera.positionVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.scaleVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.rotationVelocity: CGFloat = 0
```

You can stop all internal transforms and actions with `stop()`.

```swift
inertialCamera.stop()
```

## Protocol

The InertialCamera class provides a `InertialCameraDelegate` protocol that you can implement to receive notifications about various camera changes. A common use case for this protocol is to update the UI whenever the camera’s state changes. For example, in the demo scene, the zoom UI label is updated using the `cameraWillScale` and `cameraDidScale` protocol methods.

To implement the protocol, you first conform your class to `InertialCameraDelegate` and define the required protocol methods:

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

Next, in the scene where the InertialCamera is instantiated, set the delegate property of the camera to your object. Make sure to call the camera’s `didEvaluateActions()` method inside the scene's `didEvaluateActions()` override:

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

The `didEvaluateActions` method is necessary because some of the camera’s transformations are performed using SKAction. However, [SKAction does not automatically notify the camera of changes it makes to the camera’s properties](https://developer.apple.com/documentation/spritekit/skaction/detecting_changes_at_each_step_of_an_animation) (e.g., position, scale, or rotation). By invoking `didEvaluateActions` after actions are evaluated, the camera can update its state and ensure that the delegate methods are called with the latest values.

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
