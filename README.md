<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />

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

Add the camera's `touchesBegan()` function inside the scene's' touchesBegan handler. This will stop the camera whenever the scene is touched.
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

## Settings

### Inertia

Dynamically toggle inertia for each transform:

```swift
inertialCamera.enablePanInertia = true
inertialCamera.enableScaleInertia = true
inertialCamera.enableRotationInertia = true
```

Tweak the friction values:

```swift
/// lower values = higher friction
/// a value of 1 will maintain the velocity indefinitely
/// values above 1 will accelerate exponentially
/// values below 1 are unstable
inertialCamera.positionInertia = 0.95
inertialCamera.scaleInertia = 0.75
inertialCamera.rotationInertia = 0.85
```

### Zoom

Set a minimum and maximum zoom level:

```swift
/// Zoom out to 10%
inertialCamera.maxScale = 10
/// Zoom in to 400%
inertialCamera.minScale = 0.25
```

### Lock

Dynamically lock each transform:

```swift
inertialCamera.lockPan = false
inertialCamera.lockScale = false
inertialCamera.lockRotation = false

/// full lock, which disables gesture recognition
inertialCamera.lock = false
```

### Set to

Send the camera to a position, scale, and rotation with an animation:

```swift
inertialCamera.setTo(
    position: CGPoint(x: 0, y: 0),
    xScale: 1,
    yScale: 1,
    rotation: 0
)
```

## Compatibility

Developed with Xcode 15 and 16, and tested on iOS 17 and above.

On macOS, although the panning works, the controls aren't yet adapted to the trackpad, mouse, and keyboard.

## Credits

This project started as a fork of [SKCamera-Demo](https://github.com/HumboldtCodeClub/SKCamera-Demo). Thank you @HumboldtCodeClub for sharing and commenting your code.
