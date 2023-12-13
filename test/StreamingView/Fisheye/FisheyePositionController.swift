import Foundation

struct FisheyeMeshPoint {
    var x: Float = 0
    var y: Float = 0
}

struct FisheyeMeshSize {
    var width: Float = 0
    var height: Float = 0
}

class FisheyePositionController {
    
    private var imageSize = FisheyeMeshSize()
    private var displaySize = FisheyeMeshSize()
    private var dewarpType: FisheyeMeshDewarpType = FisheyeMeshDewarpType.dewarp1O
    private var transitionType: FisheyeTransitionType = FisheyeTransitionType.none
    private var keepAspectRatio: Bool = false
    private var needUpdateViewport: Bool = true
    private var scaleX: Float = 1
    private var scaleY: Float = 1
    private var dewarpOutROI = FERECT()
    
    var outROI: FERECT {
        return dewarpOutROI
    }

    var vertexPositionScale: (x: Float, y: Float) {
        return (x: scaleX, y: scaleY)
    }
    
    func setImageSize(width: Int, height: Int) {
        if imageSize.width != Float(width) || imageSize.height != Float(height) {
            imageSize = FisheyeMeshSize(width: Float(width), height: Float(height))
            needUpdateViewport = true
        }
    }
    
    func setDisplaySize(width: Int, height: Int) {
        if displaySize.width != Float(width) || displaySize.height != Float(height) {
            displaySize = FisheyeMeshSize(width: Float(width), height: Float(height))
            needUpdateViewport = true
        }
    }
    
    func setDewarpType(dewarpType dt: FisheyeMeshDewarpType) {
        if dewarpType != dt {
            dewarpType = dt
            needUpdateViewport = true
        }
    }
    
    func setTransitionType(type: FisheyeTransitionType) {
        if transitionType != type {
            transitionType = type
            needUpdateViewport = true
        }
    }
    
    func setKeepAspectRatio(keep: Bool) {
        if keepAspectRatio != keep {
            keepAspectRatio = keep
            needUpdateViewport = true
        }
    }
    
    func update() {
        
        if !needUpdateViewport {
            return
        }
  
        if imageSize.width == 0 || imageSize.height == 0 || displaySize.width == 0 || displaySize.height == 0 {
            return
        }
        
        // Landscape panorama fill the screen
        let fillScreen: Bool = (displaySize.width > displaySize.height) && (dewarpType == FisheyeMeshDewarpType.dewarp1P || transitionType == .o2p || transitionType == .p2o)
        
        let (x, y, w, h) = calculateViewport(keepAspectRatio: (keepAspectRatio && !fillScreen),
                                             imageWidth: Int(imageSize.width), imageHeight: Int(imageSize.height),
                                             displayWidth: Int(displaySize.width), displayHeight:  Int(displaySize.height))
        
        scaleX = Float(w) / Float(displaySize.width)
        scaleY = Float(h) / Float(displaySize.height)
        dewarpOutROI = FERECT(Left: Int32(x), Top: Int32(y), Right: Int32(x + w), Bottom: Int32(y + h))
        
        needUpdateViewport = false
    }
    
    private func calculateViewport(keepAspectRatio: Bool, imageWidth: Int, imageHeight: Int, displayWidth: Int, displayHeight: Int) -> (x: Int, y: Int, width: Int, height: Int)
    {
        if !keepAspectRatio {
            return (x: 0, y: 0, width: displayWidth, height: displayHeight)
        }

        var width: Int = 0
        var height: Int = 0
        var imageAspectRatio: Float = 1
        var displayAspectRatio: Float = 1
        
        if imageWidth != 0 && imageHeight != 0 {
            imageAspectRatio = Float(imageWidth) / Float(imageHeight)
        }

        if displayWidth != 0 && displayHeight != 0 {
            displayAspectRatio = Float(displayWidth) / Float(displayHeight)
        }

        if imageAspectRatio >= displayAspectRatio {
            width = displayWidth
            height = Int(Float(displayWidth) / imageAspectRatio)
        }
        else {
            width =  Int(Float(displayHeight) * imageAspectRatio)
            height = displayHeight
        }

        let x = Int(displayWidth / 2 - width / 2)
        let y = Int(displayHeight / 2 - height / 2)
        
        return (x: x, y: y, width: width, height: height)
    }
}
