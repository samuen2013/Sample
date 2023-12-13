import Foundation

class FisheyeMeshImpl {
    
    // Fisheye library wrapper for 1O, 1R, 1P, and full pano
    private var fisheyeLib = FisheyeLibWrapper()
    
    // Parameters to determine which mesh is used (quad or dewarp)
    private var isLocalDewarp: Bool = false
    private var dewarpType: FisheyeMeshDewarpType = FisheyeMeshDewarpType.dewarp1O
    
    // Parameters to determine the fill mode (keep aspect ratio or fill screen)
    private var positionCtrl = FisheyePositionController()
    
    // Parameters to control animation
    private var mouse = FisheyeMouse()
    private var slideEffect = FisheyeSlideEffect()
    private var transition = FisheyeTransition()

    var isInit: Bool = false
    
    init() {
    }
    
    deinit {
    }
    
    func initial() -> Bool {
        if !isInit {
            isInit = fisheyeLib.initial()
            setResoluiton(width: 512, height: 512)
            setDisplaySize(width: 100, height: 100)
            setFisheyeInfo(info: FisheyeMeshInfo(centerX: 256, centerY: 256, radius: 256, lensId: -1, installation: 1))
            _ = setDewarpType(dewarpType: .dewarp1O, transitionTriggerable: false)
            setKeepAspectRatio(keep: false)
        }
        return isInit
    }
    
    func release() {
        if isInit {
            fisheyeLib.release()
            isInit = false
        }
    }
    
    func setResoluiton(width: Int, height: Int) {
        
        fisheyeLib.setInVPicture(width: width, height: height)
        positionCtrl.setImageSize(width: width, height: height)
    }
    
    func setDisplaySize(width: Int, height: Int) {
      
        fisheyeLib.setOutVPicture(width: width, height: height)
        positionCtrl.setDisplaySize(width: width, height: height)
    }
    
    func setFisheyeInfo(info: FisheyeMeshInfo) {
        
        isLocalDewarp = (UInt32(info.installation) == 3)
        
        if !isLocalDewarp {
            fisheyeLib.setCenterRadius(centerX: info.centerX, centerY: info.centerY, radius: info.radius)
            fisheyeLib.setMountType(mountType: FEMOUNTTYPE(UInt32(info.installation)))
            fisheyeLib.setLensId(id: info.lensId)
        }
    }
    
    func setDewarpType(dewarpType dt: FisheyeMeshDewarpType, transitionTriggerable: Bool) -> Bool {
        
        //print("[ fisheyeMeshImpl ] setDewarpType \(dewarpType) to \(dt)");
   
        var triggered = false
        
        if dewarpType == dt {
            stopTransitionAnimation()
            return false
        }
   
        if transitionTriggerable {
            triggered = startTransitionAnimation(from: dewarpType, to: dt)
        }
       
        if !triggered || (triggered && dt != .dewarp1O) {
            fisheyeLib.setDewarpType(dewarpType: dt)
            positionCtrl.setDewarpType(dewarpType: dt)
        }
        
        dewarpType = dt
    
        return triggered
    }
    
    func setPanTiltZoomByDefault(resetPanTilt: Bool, resetZoom: Bool) {
        
        stopTransitionAnimation()
        
        fisheyeLib.setPanTiltZoomByDefault(resetPanTilt: resetPanTilt, resetZoom: resetZoom)
    }
    
    func setDewarpPTZ(ptz: FisheyeMeshDewarpPTZ) {

        stopTransitionAnimation()
        
        fisheyeLib.setDewarpPTZ(ptz: ptz)
    }
    
    func getDewarpPTZ() -> FisheyeMeshDewarpPTZ {
        return fisheyeLib.getDewarpPTZ()
    }
    
    func setKeepAspectRatio(keep: Bool) {
        
        fisheyeLib.setKeepAspectRatio(keep: keep)
        positionCtrl.setKeepAspectRatio(keep: keep)
    }

    func setTransitionAnimation(enabled: Bool) {
        
        transition.enabled = enabled
        
        if !enabled {
            stopTransitionAnimation()
        }
    }
    
    func update() -> (vertices: [Vertex], indices: [UInt16]) {
        
        if !isInit {
            return ([Vertex](), [UInt16]())
        }
        
        positionCtrl.update()
        
        fisheyeLib.setOutRoi(roi: positionCtrl.outROI)
        fisheyeLib.setPositionScale(x: positionCtrl.vertexPositionScale.x, y: positionCtrl.vertexPositionScale.y)
        fisheyeLib.update()

        return (fisheyeLib.vertices, fisheyeLib.indices)
    }
}

// Touch Control
extension FisheyeMeshImpl  {
    
    private func isMouseControlAvailable() -> Bool {
        return (dewarpType != .dewarp1O) && (dewarpType != .dewarpCP) && isTransitionAnimationStopped()
    }
    
    func setMouseWheel(delta: Float) {
        
        if !isMouseControlAvailable() {
            return
        }
        
        if dewarpType == FisheyeMeshDewarpType.dewarp1R {
            fisheyeLib.setZoomBy(pinchScale: delta)
        }
    }
    
    func setMouseDown(x: Float, y: Float) {
        
        if !isMouseControlAvailable() {
            return
        }
        
        stopSlideEffectAnimation()
        
        mouse.clicked = true
        mouse.beginX = x
        mouse.beginY = y
    }
    
    func setMouseMove(x: Float, y: Float) {
        
        if !isMouseControlAvailable() || !mouse.clicked {
            return
        }
        
        mouse.moveX = x
        mouse.moveY = y
        
        fisheyeLib.setPanTiltZoomByMove(from: FisheyeMeshPoint(x: mouse.beginX, y: mouse.beginY), to: FisheyeMeshPoint(x: mouse.moveX, y: mouse.moveY))
        
        // update slide effect parameter
        slideEffect.setMouseMovement(dx: mouse.moveX - mouse.beginX, dy: mouse.moveY - mouse.beginY)

        mouse.beginX = mouse.moveX
        mouse.beginY = mouse.moveY
    }
    
    func setMouseMoveEnd(x: Float, y: Float) {
        
        if !isMouseControlAvailable() {
            return
        }
        
        mouse.clicked = false
        mouse.beginX = x
        mouse.beginY = y
    }
    
    func setMouseUp() -> Bool {
        
        if !isMouseControlAvailable() {
            return false
        }
        
        mouse.clicked = false
         
        let triggered = slideEffect.start()
        return triggered
    }
    
    func isSlideEffectAnimationStopped() -> Bool {
        return slideEffect.isRunning == false
    }
    
    func stopSlideEffectAnimation() {
        slideEffect.stop()
    }
    
    func updatePanTiltZoomBySlideEffectAnimation() {

        let (dx, dy) = slideEffect.getMouseMovement()
        
        if !slideEffect.isRunning {
            stopSlideEffectAnimation()
            return
        }
        
        // update mouse move point
        mouse.moveX += dx;
        mouse.moveY += dy;
        
        if dewarpType != .dewarp1O {
            fisheyeLib.setPanTiltZoomByMove(from: FisheyeMeshPoint(x: mouse.beginX, y: mouse.beginY), to: FisheyeMeshPoint(x: mouse.moveX, y: mouse.moveY))
        }
    
        mouse.beginX = mouse.moveX
        mouse.beginY = mouse.moveY
    }
}

// Transition
extension FisheyeMeshImpl {
        
    func isTransitionAnimationStopped() -> Bool {
        return transition.isRunning == false
    }
    
    func stopTransitionAnimation() {
        transition.stop()
        fisheyeLib.setTransitionPTZEnabled(enabled: false)
        positionCtrl.setTransitionType(type: .none)
        
        // Set dewarp to 1O when transition is running from R -> O or P -> O
        if dewarpType == .dewarp1O {
            fisheyeLib.setDewarpType(dewarpType: dewarpType)
            positionCtrl.setDewarpType(dewarpType: dewarpType)
        }
    }
    
    private func startTransitionAnimation(from dt1: FisheyeMeshDewarpType, to dt2: FisheyeMeshDewarpType) -> Bool {
        
        if !transition.enabled {
            return false
        }
        
        let triggered = transition.start(from: dt1, to: dt2, mountType: fisheyeLib.mountType, ptz: fisheyeLib.getDewarpPTZ())
        
        if triggered {
            positionCtrl.setTransitionType(type: transition.type)
            fisheyeLib.setTransitionPTZEnabled(enabled: true)
            updatePanTiltZoomByTransition()
        }
        
        return triggered
    }

    func updatePanTiltZoomByTransition() {
        let (p, t, z) = transition.getTransitionPTZ()
        
        if !transition.isRunning {
            stopTransitionAnimation()
            return
        }
        
        fisheyeLib.setPanTiltZoomByTransition(pan: p, tilt: t, zoom: z)
    }
}

