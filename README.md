<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />

#  SpriteKit Inertial Camera

This is a camera for SpriteKit that allows you to navigate around the scene using multi-touch gestures. You can pan, pinch, and rotate to control the camera. When a gesture ends, the camera maintain the velocity of its transformations then gradually slows them down over time.

## Video

A GIF (7.3MB, 10fps) is attached below. [Higher quality screen recording](https://www.achrafkassioui.com/images/SpriteKit-Inertial-Camera-Demo.mp4) (18MB).

<img src="Images/SpriteKit-Inertial-Camera-Demo-Compressed.gif" alt="SpriteKit-Inertial-Camera-Demo-Compressed" />

## Screenshots

<img src="Images/SpriteKit-Inertial-Camera-Screenshots.png" alt="SpriteKit-Inertial-Camera-Screenshots" style="width:100%;" />

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

In order to enable inertia, the `updateInertia()` method of `InertialCamera` can be called inside the `update` loop of the scene:

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
inertialCamera.enablePanInertia = true
inertialCamera.enableScaleInertia = true
inertialCamera.enableRotationInertia = true
```

Tweak the friction values of the inertia:

```swift
/// lower values = higher friction
inertialCamera.positionInertia = 0.95
inertialCamera.scaleInertia = 0.75
inertialCamera.rotationInertia = 0.85
```

### Zoom

Set the minimum and maximum zoom levels:

```swift
 /// a max zoom out of 0.01x
inertialCamera.maxScale = 100
 /// a max zoom in of 100x
inertialCamera.minScale = 0.01
```

### Lock

You can lock the camera. The lock disables the gesture recognition. In your own logic, you can dynamically control the lock to restrict the camera controls to a specific button or area. When locked, any ongoing inertia is halted.

```swift
inertialCamera.lock = false
```

### Adaptive filtering

Change the filtering mode of textures depending on camera zoom. When the scale is below 1 (zoom in) on either x or y, linear filtering on `SKSpriteNode` and anti-aliasing on `SKShapeNode` are disabled. When the scale is 1 or above (zoom out) on either x and y, linear filtering and anti aliasing are enabled (the default renderer behavior).

This is an opinionated feature. When the camera is zoomed in, I want to see the pixel grid, not a blur. This behavior can be toggled.

```swift
inertialCamera.adaptiveFiltering = true
```

## Support

Tested on iOS. Not adapted for macOS yet.

