/**
 
 # App entry point
 
 Achraf Kassioui
 Created: 9 April 2024
 Updated: 19 December 2024
 
 */


import SwiftUI

@main
struct SpriteKit_Inertial_CameraApp: App {
    var body: some Scene {
        WindowGroup {
            UIKitViewControllerWrapper()
                .ignoresSafeArea()
                .persistentSystemOverlays(.hidden)
                .statusBarHidden(true)
        }
    }
}

/// A SwiftUI wrapper to put a UIKit View Controller in the WindowGroup above
struct UIKitViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> PlaygroundViewController {
        return PlaygroundViewController()
    }
    
    func updateUIViewController(_ uiViewController: PlaygroundViewController, context: Context) {
        /// Update the view controller if needed
    }
}
