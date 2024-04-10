<img src="Images/SpriteKit-Inertial-Camera-Icon-Alpha.png" alt="SpriteKit-Inertial-Camera-Icon" style="width:25%;" />

#  SpriteKit Inertial Camera

This is a custom camera for SpriteKit that allows you to freely navigate around the scene.
You can use pan, pinch, and rotation gestures to control the camera.
The camera simulates inertia when you let go : at the end of each gesture, the velocity of the change is maintained then slowed down over time.

## Screenshots

<img src="Images/SpriteKit-Inertial-Camera-Screenshots.png" alt="SpriteKit-Inertial-Camera-Screenshots" style="width:100%;" />

## Screen recording

<video src="Images/SpriteKit-Inertial-Camera-Demo-Compressed.mp4" width="320"></video>

## Setup

Add the `InertialCamera` file or class to your project, then create an instance of the camera, for example inside `didMove`:

```swift

 override func didMove(to view: SKView) {
     size = view.bounds.size
     let myCamera = InertialCameraNode(view: view, scene: self)
     camera = myCamera
     addChild(myCamera)
 }

```

## Support

Tested on iOS. Not adapted for macOS yet.

