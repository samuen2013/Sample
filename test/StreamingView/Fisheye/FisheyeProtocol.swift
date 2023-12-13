import Foundation

struct FisheyeMeshInfo {
    var centerX: Int = 0
    var centerY: Int = 0
    var radius: Int = 0
    var lensId: Int = 0
    var installation: Int = 0   // = mount type
}

enum FisheyeMeshDewarpType : Int {
    case dewarp1O = 0   // original fisheye image
    case dewarp1P = 1   // panorama
    case dewarp1R = 2   // rectilinear
    case dewarpCP = 3   // dewarp full HD image
}

struct FisheyeMeshDewarpPTZ {
    // PTZ of dewarp 1R
    var rectPan: Float = 0
    var rectTilt: Float = 0
    var rectZoom: Float = 0
    
    // PTZ of dewarp 1P
    var panoPan: Float = 0
    var panoTilt: Float = 0
    var panoZoom: Float = 0
}

protocol FisheyeMeshProtocol {
    
    // Init / Deinit functions
    func initialize() -> Bool
    func deinitialize()
    func isInitialized() -> Bool
    
    // Set fisheye image resolution ( = texture size )
    func setResoluiton(width: Int, height: Int)
    
    // Set display size ( = view size )
    func setDisplaySize(width: Int, height: Int)
    
    // Set keep aspect ratio. Default value is true
    // Note: Panorama in landscape view will fill screen
    func setKeepAspectRatio(keep: Bool)
    
    // Set fisheye info ( = user data info of tag 0x13 )
    func setFisheyeInfo(info: FisheyeMeshInfo)
    
    // Set dewarp type.
    // Note: if you'd like to trigger transition animaiton when dewarp type is changed, set transitionTriggerable = true
    func setDewarpType(dewarpType dt: FisheyeMeshDewarpType, transitionTriggerable: Bool)
    
    // Enable running transition animaiton when it is triggered on dewarp type changed
    // Default value is true
    func setTransitionAnimation(enabled: Bool)
    
    // Set renderer callcack function to repaint fisheye animations in MTKView
    func setAnimationRenderFunction(renderCallback: @escaping (() -> ()))
    
    // Set pan/tilt/zoom
    func setPanTiltZoomByDefault(resetPanTilt: Bool, resetZoom: Bool)
    func setPanTiltZoomByDewarpPTZ(ptz: FisheyeMeshDewarpPTZ)
    
    // Get current pan/tilt/zoom
    func getDewarpPTZ() -> FisheyeMeshDewarpPTZ
    
    // Call this function to update mesh in MTKView
    func update() -> (vertices: [Vertex], indices: [UInt16])
    
    // Gesture control
    // Zoom in/out
    func setGesturePinchScale(delta: Float)
     
    // Pan/Tilt control
    func setGesturePanLocation(beginX: Float, beginY: Float, endX: Float, endY: Float)

    // Pan/Tilt control is ended and start running slide effect animation
    func setGesturePanEnded()
}
