<p align="center">
<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />
</p>

#  SpriteKit Inertial Camera

A custom SpriteKit camera designed for smooth navigation around your scene using multi-touch gestures. It supports panning, pinching, and rotating, with inertia applied to each transformation.

The camera includes many settings and features that you can customize.

## Video

https://github.com/user-attachments/assets/7d9ecf50-3d83-4db7-8daf-7e3d60b40206

## Run the Demo App

The project includes a demo app that you can compile and run on your device:
- Download or clone this project.
- Open the project in Xcode.
- Update the project’s signing settings with your own credentials.
- Choose a target (simulator or physical device) and run it with Command + R.

Alternatively, you can preview the demo scene without building or signing:
- Select the demo scene file in Xcode.
- Open the Xcode canvas with Option + Command + Enter.

## Setup the Camera

1. Include the InertialCamera file or class in your project. Then, create an instance of the camera and set it as the scene’s camera. The camera requires a view for its gesture recognizers. Assign a view (such as the SKView rendering the scene or a parent UIView in your view controller) to the `gesturesView` property.

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
2. Call the camera’s `update()` method in your scene’s update function to simulate inertia.

```swift
override func update(_ currentTime: TimeInterval) {
    inertialCamera.update()
}
```

3. Use the camera’s `touchesBegan()` function in your scene’s touchesBegan handler to stop the camera when the scene is touched.

```swift
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    inertialCamera.touchesBegan()
}
```

## API

The camera supports initialization with specific default transforms:

```swift
/// Default camera position.
inertialCamera.defaultPosition: CGPoint = .zero

/// Default camera rotation.
inertialCamera.defaultRotation: CGFloat = 0

/// Default camera X scale.
inertialCamera.defaultXScale: CGFloat = 1

/// Default camera Y scale
inertialCamera.defaultYScale: CGFloat = 1
```

The `setTo()` method animates the camera’s position, rotation, and scale. The order of animations depends on whether the camera is zooming in or out. The duration is dynamically determined based on the magnitude of the transformation, but these parameters can be customized in the `setTo()` method definition.

```swift
inertialCamera.setTo(
    position: CGPoint? = nil,   /// Target position (optional).
    xScale: CGFloat? = nil,     /// Target X scale (optional).
    yScale: CGFloat? = nil,     /// Target Y scale (optional).
    rotation: CGFloat? = nil,   /// Target rotation (optional, in radians).
    withAnimation: Bool? = nil  /// Animate transitions (default is true).
)

/// Example: Zoom in without changing position or rotation
inertialCamera.setTo(xScale: 2, yScale: 2)
```

If inertia is enabled, you can directly manipulate the camera’s motion by setting its velocities. These values are applied once per frame during the `update()` method. The inertia simulation writes on these values.

```swift
inertialCamera.positionVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.scaleVelocity = CGVector(dx: 0, dy: 0)
inertialCamera.rotationVelocity: CGFloat = 0
```

To immediately stop all camera transformations and animations, use the `stop()` method.

```swift
inertialCamera.stop()
```

## Protocol

The InertialCamera class provides a `InertialCameraDelegate` protocol that you can implement to receive notifications about various camera changes. A common use case for this protocol is to update the UI whenever the camera’s state changes. For example, in the demo scene, the zoom UI label is updated using the `cameraWillScale` and `cameraDidScale` protocol methods.

To implement the protocol, you first conform your class to `InertialCameraDelegate` and add the required protocol methods:

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

Then, in the scene where the InertialCamera is instantiated, set the delegate property of the camera to your object. Make sure to call the camera’s `didEvaluateActions()` method inside the scene's didEvaluateActions override:

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

The `didEvaluateActions` method is necessary because some of the camera’s transformations are performed using SKAction. However, [SKAction does not automatically notify the camera of changes it makes to the camera’s properties](https://developer.apple.com/documentation/spritekit/skaction/detecting_changes_at_each_step_of_an_animation) (e.g., position, scale, or rotation). By invoking `didEvaluateActions()` after actions are evaluated, the camera can update its state and ensure that the delegate methods are called with the latest values.

## Settings

### Zoom

The camera uses scaling to control zoom. A higher zoom percentage corresponds to a lower scale value.

```swift
/// Maximum zoom out. Default is 10, which is a 10% zoom.
inertialCamera.maxScale: CGFloat = 10

/// Maximum zoom in. Default is 0.25, which is a 400% zoom.
inertialCamera.minScale: CGFloat = 0.25
```

### Lock

You can restrict camera transformations to lock panning, scaling, or rotation individually, or lock all gestures entirely.

```swift
/// Lock camera pan (disable movement).
inertialCamera.lockPan = false

/// Lock camera scale (disable zoom).
inertialCamera.lockScale = false

/// Lock camera rotation (disable rotation).
inertialCamera.lockRotation = false

/// Fully lock the camera by disabling gesture recognizers.
inertialCamera.lock = false
```

### Inertia

Inertia settings allow fine-tuning of how motion decays over time. Each transformation has its own decay factor:
	•	1: no decay; motion continues indefinitely.
	•	Greater than 1: causes exponential acceleration.
	•	Negative values: unstable.

```swift
/// Velocity is multiplied by this factor every frame. Default is `0.95`.
inertialCamera.positionInertia: CGFloat = 0.95

/// Scale is multiplied by this factor every frame. Default is `0.75`.
inertialCamera.scaleInertia: CGFloat = 0.75

/// Rotation is multiplied by this factor every frame. Default is `0.85`.
inertialCamera.rotationInertia: CGFloat = 0.85

/// Toggle position inertia.
inertialCamera.enablePanInertia = true

/// Toggle scale inertia.
inertialCamera.enableScaleInertia = true

/// Toggle rotation inertia.
inertialCamera.enableRotationInertia = true
```

### Double Tap

You can enable a double-tap gesture to reset the camera to its default state.

```swift
/// Enable double-tap to reset camera (default is `false`).
inertialCamera.doubleTapToReset = false
```

## Compatibility

Developed with Xcode 15 and 16. Tested on iOS 17 and 18.

On macOS, although the panning works, the controls aren't yet adapted to the trackpad, mouse, and keyboard.

## Credits

This project started as a fork of [SKCamera-Demo](https://github.com/HumboldtCodeClub/SKCamera-Demo). Thank you @HumboldtCodeClub for sharing and commenting your code.
