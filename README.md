<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />

#  SpriteKit Inertial Camera

This is a custom SpriteKit camera that you can use to navigate around the scene using multi-touch gestures. It supports pan, pinch, and rotate, as well as inertia on each transforms.

## Video

https://github.com/AchrafKassioui/SpriteKit-Inertial-Camera/assets/1216689/9846b646-fd6b-4306-91fa-d8f758b5f3fb

https://github.com/AchrafKassioui/SpriteKit-Inertial-Camera/assets/1216689/d05ca33b-07b7-4ecd-972a-50a5eae10fe5

https://github.com/AchrafKassioui/SpriteKit-Inertial-Camera/assets/1216689/d0ff13d8-8c71-4ea0-b2e5-a75623d5ef4f

## Setup

Add the `InertialCamera` file or class to your project, then create an instance of the camera and set it as the scene camera, for example inside `didMove`:

```swift
override func didMove(to view: SKView) {
    size = view.bounds.size
    let inertialCamera = InertialCamera(scene: self)
    camera = inertialCamera
    addChild(inertialCamera)
}
```

In order to enable inertia, call the `updateInertia()` inside the scene `update`:

```swift
override func update(_ currentTime: TimeInterval) {
    if let inertialCamera = camera as? InertialCamera {
        inertialCamera.updateInertia()
    }
}
```

## Configuration

### Scene

The scene object is optional during initialization, which allows to create an inertial camera object in a model without a reference to the scene. However, passing a scene is necessary to setup the gesture recognizers. You can initialize the camera without a scene, then pass a scene later through the `parentScene` property:

```swift
struct MyModel {
    var myCamera = InertialCamera()
}

class myScene: SKScene {
    var myModel = MyModel()
    
    override func didMove(to view: SKView) {
        let inertialCamera = myModel.myCamera
        inertialCamera.delegate = self
        inertialCamera.parentScene = self
        camera = inertialCamera
        addChild(inertialCamera)
    }
}
```

### Protocol

InertialCamera has a `InertialCameraDelegate` protocol that you can use to notify you of various camera changes. You implement the protocol like this:

```swift
/// Add the protocol to your scene declaration
class myScene: SKScene, InertialCameraDelegate {

    override func didMove(to view: SKView) {
        let inertialCamera = InertialCamera(scene: self)
        
        /// Set the scene as delegate of the camera
        inertialCamera.delegate = self
        
        camera = inertialCamera
        addChild(inertialCamera)
    }

    /// Include the methods required by the protocol
    
    func cameraWillScale(to scale: (x: CGFloat, y: CGFloat)) {
        /// Called before the camera is about to scale
    }

    func cameraDidScale(to scale: (x: CGFloat, y: CGFloat)) {
        /// Called after the camera has scaled
    }

    func cameraDidMove(to position: CGPoint) {
        /// Called after the camera has moved
    }
}
```

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

If inertia is enabled, programmatically change the camera's velocity:

```swift
inertialCamera.positionVelocity = (0, 0)
inertialCamera.scaleVelocity = (0, 0)
inertialCamera.rotationVelocity = 0
```

Stop all ongoing inertia. This is typically called by a `touchesBegan` event, so that the camera stops moving when the user touches the screen.

```swift
inertialCamera.stopInertia()
```

`stopInertia()` is a convenience method equivalent to setting all velocities to zero.

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

### Adaptive filtering

Change the filtering mode of textures depending on camera zoom. When the scale is below 1 (zoom in) on either x or y, linear filtering on `SKSpriteNode` and anti-aliasing on `SKShapeNode` are disabled. When the scale is 1 or above (zoom out) on either x and y, linear filtering and anti-aliasing are enabled, which is the default renderer behavior.

This is an opinionated feature. This behavior can be toggled:

```swift
inertialCamera.adaptiveFiltering = true
```

Note that in SpriteKit, filtering and anti-aliasing properties are only available on `SKTexture` and `SKShapeNode`. Other drawing nodes such as `SKLabelNode` or `SKEmitterNode` do not expose such properties.

## Compatibility

Developed with Xcode 15 and tested on iOS 17.

On macOS, although the panning works, the controls aren't yet adapted to the trackpad, mouse, and keyboard.

## Credits

This project started as a fork of [SKCamera-Demo](https://github.com/HumboldtCodeClub/SKCamera-Demo). Thank you @HumboldtCodeClub for sharing and commenting your code.

