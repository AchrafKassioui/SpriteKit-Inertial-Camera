/**
 
 # Helper functions for the demo
 
 Achraf Kassioui
 Created: 9 April 2024
 Updated: 9 April 2024
 
 */

import SpriteKit

/// grid generator with Core Graphics
func generateGridTexture(cellSize: CGFloat, rows: Int, cols: Int, color: SKColor) -> SKTexture? {
    
    /// Add 1 to the height and width to ensure the borders are within the sprite
    let size = CGSize(width: CGFloat(cols) * cellSize + 1, height: CGFloat(rows) * cellSize + 1)
    
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
        
        let bezierPath = UIBezierPath()
        let offset: CGFloat = 0.5
        
        /// vertical lines
        for i in 0...cols {
            let x = CGFloat(i) * cellSize + offset
            bezierPath.move(to: CGPoint(x: x, y: 0))
            bezierPath.addLine(to: CGPoint(x: x, y: size.height))
        }
        /// horizontal lines
        for i in 0...rows {
            let y = CGFloat(i) * cellSize + offset
            bezierPath.move(to: CGPoint(x: 0, y: y))
            bezierPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        
        /// stroke style
        color.setStroke()
        bezierPath.lineWidth = 1
        
        /// draw
        bezierPath.stroke()
    }
    
    return SKTexture(image: image)
}
