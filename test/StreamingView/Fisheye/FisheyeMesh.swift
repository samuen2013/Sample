import Foundation

class FisheyeMesh : FisheyeMeshProtocol {
    
    private var impl = FisheyeMeshImpl()
    private var animationTimer : Timer?
    private var redrawCallbackFunction: () -> () = {}
    
    init() {
    }
    
    deinit {
        deinitialize()
    }
    
    // Init / Deinit functions
    func initialize() -> Bool {
        return impl.initial()
    }
    
    func deinitialize() {
        stopAnimationTimer()
        impl.release()
    }
    
    func isInitialized() -> Bool {
        return impl.isInit
    }
    
    // Set fisheye image resolution ( = texture size )
    func setResoluiton(width: Int, height: Int) {
        impl.setResoluiton(width: width, height: height)
    }
    
    // Set display size ( = view size )
    func setDisplaySize(width: Int, height: Int) {
        impl.setDisplaySize(width: width, height: height)
    }
    
    // Set keep aspect ratio. Default value is true
    // Note: Panorama in landscape view will fill screen
    func setKeepAspectRatio(keep: Bool) {
        impl.setKeepAspectRatio(keep: keep)
    }
    
    // Set fisheye info ( = user data info of tag 0x13 )
    func setFisheyeInfo(info: FisheyeMeshInfo) {
        impl.setFisheyeInfo(info: info)
    }
    
    // Set dewarp type.
    // Note: if you'd like to trigger transition animaiton when dewarp type is changed, set transitionTriggerable = true
    func setDewarpType(dewarpType dt: FisheyeMeshDewarpType, transitionTriggerable: Bool) {
        
        let isAnimationTriggered = impl.setDewarpType(dewarpType: dt, transitionTriggerable: transitionTriggerable)
        
        if isAnimationTriggered {
            startFisheyeAnimation()
        }
    }
    
    // Enable running transition animaiton when it is triggered on dewarp type changed
    // Default value is true
    func setTransitionAnimation(enabled: Bool) {
        if !enabled {
            stopFisheyeAnimation()
        }
        impl.setTransitionAnimation(enabled: enabled)
    }
    
    // Set renderer callcack function to repaint fisheye animations in MTKView
    func setAnimationRenderFunction(renderCallback: @escaping (() -> ())) {
        redrawCallbackFunction = renderCallback
    }
    
    // Set pan/tilt/zoom
    func setPanTiltZoomByDefault(resetPanTilt: Bool, resetZoom: Bool) {
        stopFisheyeAnimation()
        impl.setPanTiltZoomByDefault(resetPanTilt: resetPanTilt, resetZoom: resetZoom)
    }
    
    func setPanTiltZoomByDewarpPTZ(ptz: FisheyeMeshDewarpPTZ) {
        stopFisheyeAnimation()
        impl.setDewarpPTZ(ptz: ptz)
    }
    
    // Get current pan/tilt/zoom
    func getDewarpPTZ() -> FisheyeMeshDewarpPTZ {
        return impl.getDewarpPTZ()
    }
    
    // Call this function to update mesh in MTKView
    func update() -> (vertices: [Vertex], indices: [UInt16]) {
        return impl.update()
    }
}

extension FisheyeMesh {
    
   // Zoom in/out
    func setGesturePinchScale(delta: Float) {
        impl.setMouseWheel(delta: delta)
    }
    
    // Pan/Tilt control
    func setGesturePanLocation(beginX: Float, beginY: Float, endX: Float, endY: Float) {
        impl.setMouseDown(x: beginX, y: beginY)
        impl.setMouseMove(x: endX, y: endY)
        impl.setMouseMoveEnd(x: endX, y: endY)
    }
    
    // Pan/Tilt control is ended and start running slide effect animation
    func setGesturePanEnded() {
        let isAnimationTriggered = impl.setMouseUp()
        
        if isAnimationTriggered {
            startFisheyeAnimation()
        }
    }
}

extension FisheyeMesh {
    
    private func startFisheyeAnimation() {
        startAnimationTimer()
    }
    
    private func stopFisheyeAnimation() {
        impl.stopSlideEffectAnimation()
        impl.stopTransitionAnimation()
        stopAnimationTimer()
    }
    
    private func startAnimationTimer() {
        stopAnimationTimer()
        
        guard animationTimer == nil else { return }
        
        //print("[ fisheyeMesh ] start animation timer")
        animationTimer = Timer.scheduledTimer(timeInterval: 0.0060, target: self, selector: #selector(renderFisheyeAnimation), userInfo: nil, repeats: true)
    }
    
    private func stopAnimationTimer() {

        guard animationTimer != nil else { return }
        
        //print("[ fisheyeMesh ] stop animation timer")
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    @objc private func renderFisheyeAnimation() {
        
        if impl.isSlideEffectAnimationStopped() && impl.isTransitionAnimationStopped() {
            stopAnimationTimer()
        }
        else if !impl.isSlideEffectAnimationStopped() {
            impl.updatePanTiltZoomBySlideEffectAnimation()
            redrawCallbackFunction()
        }
        else if !impl.isTransitionAnimationStopped() {
            impl.updatePanTiltZoomByTransition()
            redrawCallbackFunction()
        }
    }
}

