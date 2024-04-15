<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />

#  SpriteKit Inertial Camera

This custom SpriteKit camera allows you to navigate around the scene using multi-touch gestures. You can pan, pinch, and rotate to control the camera. When a gesture ends, the camera maintain the velocity of its transformations then gradually slows them down over time.

## Video

[Higher quality screen recording](https://www.achrafkassioui.com/images/SpriteKit-Inertial-Camera-Demo.mp4) (18MB).

## Screenshots



## Setup

Add the `InertialCamera` file or class to your project, then create an instance of the camera and set it as the scene camera, for example inside `didMove`:

```swift
override func didMove(to view: SKView) {
    size = view.bounds.size
    let inertialCamera = InertialCamera(view: view, scene: self)
    camera = inertialCamera
    addChild(inertialCamera)
}
```

In order to enable inertia, the `updateInertia()` method of can be called inside the `update` loop of the scene:

```swift
override func update(_ currentTime: TimeInterval) {
    if let inertialCamera = camera as? InertialCamera {
        inertialCamera.updateInertia()
    }
}
```

## Configuration

### Inertia

Selectively enable or disable inertia for each transformation:

```swift
inertialCamera.enablePanInertia = true /// default
inertialCamera.enableScaleInertia = true /// default
inertialCamera.enableRotationInertia = true /// default
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

Apply arbitrary values to the camera velocity:

```swift
inertialCamera.positionVelocity: (x: CGFloat, y: CGFloat) = (0, 0)
inertialCamera.scaleVelocity: (x: CGFloat, y: CGFloat) = (0, 0)
inertialCamera.rotationVelocity: CGFloat = 0.1
```

Stop all ongoing inertia. This is typically called with a `touchesBegan` event, so that the camera stops moving when the user touches the screen:

```swift
inertialCamera.stopInertia()
```

`stopInertia` is a convenience method. Under the hood, it sets to zero the current stored inertia for each transform.

### Zoom

Set the minimum and maximum zoom levels:

```swift
 /// a max zoom out of 0.01x
inertialCamera.maxScale = 100
 /// a max zoom in of 100x
inertialCamera.minScale = 0.01
```

### Lock

Selectively lock each transformation, or all of them. A full lock disables the gesture recognizers that have been attached to the view when the camera was instantiated.

```swift
inertialCamera.lockPan = false
inertialCamera.lockScale = false
inertialCamera.lockRotation = false

/// full lock
inertialCamera.lock = false
```

When reset, a lock set to zero the velocity of the corresponding transformation. The inertia simulation will stop.

### Adaptive filtering

Change the filtering mode of textures depending on camera zoom. When the scale is below 1 (zoom in) on either x or y, linear filtering on `SKSpriteNode` and anti-aliasing on `SKShapeNode` are disabled. When the scale is 1 or above (zoom out) on either x and y, linear filtering and anti aliasing are enabled (the default renderer behavior).

This is an opinionated feature. When the camera is zoomed in, I want to see the pixel grid, not a blur. This behavior can be toggled.

```swift
inertialCamera.adaptiveFiltering = true
```

## Compatibility

Developed with Xcode 15.4 and tested on iOS 17.4.1.

On macOS, although the panning works, the controls aren't yet adapted to the trackpad, mouse, and keyboard.

## Credits

This project started as a fork of [SKCamera-Demo](https://github.com/HumboldtCodeClub/SKCamera-Demo). Thank you @HumboldtCodeClub for sharing and commenting your code.

