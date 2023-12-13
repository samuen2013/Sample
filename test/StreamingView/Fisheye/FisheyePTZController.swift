import Foundation

struct FisheyePTZ {
    var pan: Float = 0
    var tilt: Float = 0
    var zoom: Float = 1
}

class FisheyeDewarpPTZ {
    
    var rectPTZ = FisheyePTZ(pan: 0, tilt: 0, zoom: 2)
    var panoPTZ = FisheyePTZ(pan: 0, tilt: 0, zoom: 1)
    var transPTZ = FisheyePTZ(pan: 0, tilt: 0, zoom: 0)
    
    var mountType: FEMOUNTTYPE = FE_MOUNT_CEILING
    var dewarpType: FEDEWARPTYPE = FE_DEWARP_AERIALVIEW
    var isTransition: Bool = false
    
    private func limitRectZoom(value: Float) -> Float { return ((value < 2) ? 2 : value) }
    private func limitPanoZoom(value: Float) -> Float { return 1 }
    
    func reset() {
        resetPanTilt()
        resetZoom()
    }
    
    func resetPanTilt()  {
        rectPTZ.pan = (mountType == FE_MOUNT_FLOOR) ? 180 : 0
        rectPTZ.tilt = (mountType == FE_MOUNT_WALL) ? 0 : ((mountType == FE_MOUNT_CEILING) ? 44 : -44)
        
        panoPTZ.pan = (mountType == FE_MOUNT_WALL) ? 0 : 180
        panoPTZ.tilt = 0
    }
    
    func resetZoom() {
        rectPTZ.zoom = 2
        panoPTZ.zoom = 1
    }
    
    func setRect(pan p: Float, tilt t: Float, zoom z: Float) -> Bool {
        if rectPTZ.pan != p || rectPTZ.tilt != t || rectPTZ.zoom != z {
            rectPTZ.pan = p
            rectPTZ.tilt = t
            rectPTZ.zoom = limitRectZoom(value: z)
            return true
        }
        return false
    }
    
    func setPano(pan p: Float, tilt t: Float, zoom z: Float) -> Bool {
        if panoPTZ.pan != p || panoPTZ.tilt != t || panoPTZ.zoom != z {
            panoPTZ.pan = p
            panoPTZ.tilt = t
            panoPTZ.zoom = limitPanoZoom(value: z)
            return true
        }
        return false
    }
    
    func setTransition(pan p: Float, tilt t: Float, zoom z: Float) -> Bool {
        if transPTZ.pan != p || transPTZ.tilt != t || transPTZ.zoom != z {
            transPTZ.pan = p
            transPTZ.tilt = t
            transPTZ.zoom = z
            return true
        }
        return false
    }
    
    func set(pan p: Float, tilt t: Float) -> Bool {
        if isTransition {
            return setTransition(pan: p, tilt: t, zoom: transPTZ.zoom)
        }
        else if dewarpType == FE_DEWARP_AERIALVIEW {
            return setRect(pan: p, tilt: t, zoom: rectPTZ.zoom)
        }
        else if dewarpType == FE_DEWARP_FULLVIEWPANORAMA {
            return setPano(pan: p, tilt: t, zoom: panoPTZ.zoom)
        }
        return false
    }
    
    func set(zoom z: Float) -> Bool {
        if isTransition {
            return setTransition(pan: transPTZ.pan, tilt: transPTZ.tilt, zoom: z)
        }
        else if dewarpType == FE_DEWARP_AERIALVIEW {
            return setRect(pan: rectPTZ.pan, tilt: rectPTZ.tilt, zoom: z)
        }
        else if (dewarpType == FE_DEWARP_FULLVIEWPANORAMA) {
            return setPano(pan: panoPTZ.pan, tilt: panoPTZ.tilt, zoom: z)
        }
        return false
    }
    
    func setZoomBy(pinchScale s: Float) -> Bool {
        
        if dewarpType == FE_DEWARP_AERIALVIEW {
            var z: Float = rectPTZ.zoom
            if s > 1 { // zoom in
                z = rectPTZ.zoom * 1.05
            }
            else if s < 1 { // zoom out
                z = rectPTZ.zoom / 1.05
            }
            return set(zoom: z)
        }
        else if (dewarpType == FE_DEWARP_FULLVIEWPANORAMA) {
            return set(zoom: 1)
        }
        
        return false
    }
    
    func set(pan p: Float, tilt t: Float, zoom z: Float) -> Bool {
        if isTransition {
            return setTransition(pan: p, tilt: t, zoom: z)
        }
        else if dewarpType == FE_DEWARP_AERIALVIEW {
            return setRect(pan: p, tilt: t, zoom: z)
        }
        else if dewarpType == FE_DEWARP_FULLVIEWPANORAMA {
            return setPano(pan: p, tilt: t, zoom: z)
        }
        return false
    }
    
    func get() -> FisheyePTZ {
        if isTransition {
            return transPTZ
        }
        else if (dewarpType == FE_DEWARP_AERIALVIEW) {
            return rectPTZ
        }
        else if (dewarpType == FE_DEWARP_FULLVIEWPANORAMA) {
            return panoPTZ
        }
        return FisheyePTZ(pan: 0, tilt: 0, zoom: 1)
    }
    
    func printValue() {
        print("[ FisheyeDewarpPTZ ] R: (\(rectPTZ.pan), \(rectPTZ.tilt), \(rectPTZ.zoom)), P: (\(panoPTZ.pan), \(panoPTZ.tilt), \(panoPTZ.zoom)), T: (\(transPTZ.pan), \(transPTZ.tilt), \(transPTZ.zoom))")
    }
}

class FisheyeMouse {
    var clicked: Bool = false
    var beginX: Float = 0
    var beginY: Float = 0
    var moveX: Float = 0
    var moveY: Float = 0
}

class FisheyeSlideEffect {
    
    private var isSlideEffectRunning: Bool = false
    private var slideEffectDx: Float = 0
    private var slideEffectDy: Float = 0
    private var slideIncX: Float = 0
    private var slideIncY: Float = 0
    private var slideEffectCount: Int = 0
    private let slideEffectMaxCount: Int = 15
    
    var isRunning: Bool {
        get {
            return isSlideEffectRunning
        }
    }
    
    func setMouseMovement(dx: Float, dy: Float) {
        slideEffectDx = dx;
        slideEffectDy = dy;
    }
    
    func start() -> Bool {
        
        // ignore slight movements
        let error: Float = 2
        if (fabsf(slideEffectDx) <= error && fabsf(slideEffectDy) <= error) {
            isSlideEffectRunning = false
            return false
        }

        isSlideEffectRunning = true;
        slideEffectCount = 0;

        // avoid violent movements
        let maxMovement: Float = 30
        if (slideEffectDx > maxMovement) {
            slideEffectDx = maxMovement;
        }
        else if (slideEffectDx < -maxMovement) {
            slideEffectDx = -maxMovement;
        }
        
        if (slideEffectDy > maxMovement) {
            slideEffectDy = maxMovement;
        }
        else if (slideEffectDy < -maxMovement) {
            slideEffectDy = -maxMovement;
        }
        
        // render slide effect about 15 frames
        let incX = slideEffectDx / Float(slideEffectMaxCount)
        let incY = slideEffectDy / Float(slideEffectMaxCount)
        slideIncX = (fabsf(slideEffectDx) > fabsf(incX)) ? incX : slideEffectDx
        slideIncY = (fabsf(slideEffectDy) > fabsf(incY)) ? incY : slideEffectDy
        
        return true
    }
    
    func getMouseMovement() -> (dx: Float, dy: Float) {
        if slideEffectDx == 0 || slideEffectDy == 0 || slideEffectCount >= slideEffectMaxCount {
            isSlideEffectRunning = false
            return (dx: 0, dy: 0)
        }

        slideEffectDx -= slideIncX
        slideEffectDy -= slideIncY
        slideEffectCount += 1
        
        return (dx: slideEffectDx, dy: slideEffectDy)
    }
    
    func stop() {
        isSlideEffectRunning = false
        slideEffectDx = 0;
        slideEffectDy = 0;
        slideIncX = 0
        slideIncY = 0
        slideEffectCount = 0
    }
}

class NumberAnimation {
    public var isRunning: Bool = false
    private var from: Float = 0
    private var to: Float = 0
    private var count: Float = 0
    private var maxCount: Float = 0
    
    func start(from n1: Float, to n2: Float, maxCount m: Float) {
        isRunning = true
        from = n1
        to = n2
        maxCount = m
        count = 0
    }
    
    func stop() {
        isRunning = false
    }
    
    func getNumber() -> Float {
        var value = to
        if isRunning && count <= maxCount {
            value = from + (to - from) * count / maxCount
            count += 1
        }
        else {
            stop()
        }
        return value
    }
}

enum FisheyeTransitionType {
    case none, o2p, p2o, o2r, r2o
}

class FisheyeTransition {
    
    var enabled: Bool = true
    var type: FisheyeTransitionType = FisheyeTransitionType.none
    var pan: Float = 0
    var tilt: Float = 0
    var zoom: Float = 0
    
    private let maxCountOP: Float = 30
    private let maxCountOO: Float = 10
    private let maxCountOR: Float = 20
    
    private var numberPan = NumberAnimation()
    private var numberTilt = NumberAnimation()
    private var numberZoom = NumberAnimation()
    private var numberZoom2D3DO = NumberAnimation()
    
    private var isTransitionRunning: Bool = false
    
    var isRunning: Bool {
        get {
            return isTransitionRunning
        }
    }
    
    func start(from dt1: FisheyeMeshDewarpType, to dt2: FisheyeMeshDewarpType, mountType: FEMOUNTTYPE, ptz: FisheyeMeshDewarpPTZ) -> Bool {
        
        type = getTransitionType(from: dt1, to: dt2)
        
        if !enabled || type == .none {
            stop()
            return false
        }
        
        isTransitionRunning = true
        
        // transition to previous ptz
        let opPan = transitionOPBegin(mountType: mountType)
        let orPan = transitionORPanBeg(mountType: mountType, currentPan: ptz.rectPan)
        
        switch type {
        case .o2p:
            numberPan.start(from: opPan, to: ptz.panoPan, maxCount: maxCountOP)
            numberTilt.start(from: 0, to: ptz.panoTilt, maxCount: maxCountOP)
            numberZoom.start(from: 0, to: 1, maxCount: maxCountOP)
            pan = ptz.panoPan
            tilt = ptz.panoTilt
            zoom = 1
        case .p2o:
            numberPan.start(from: ptz.panoPan, to: opPan, maxCount: maxCountOP)
            numberTilt.start(from: ptz.panoTilt, to: 0, maxCount: maxCountOP)
            numberZoom.start(from: 1, to: 0, maxCount: maxCountOP)
            pan = ptz.panoPan
            tilt = ptz.panoTilt
            zoom = 1
        case .o2r:
            numberZoom2D3DO.start(from: 0, to: 1, maxCount: maxCountOO)
            numberPan.start(from: orPan, to: ptz.rectPan, maxCount: maxCountOR)
            numberTilt.start(from: 0, to: ptz.rectTilt, maxCount: maxCountOR)
            numberZoom.start(from: 1, to: ptz.rectZoom, maxCount: maxCountOR)
            pan = ptz.rectPan
            tilt = ptz.rectTilt
            zoom = ptz.rectZoom
        case .r2o:
            numberPan.start(from: ptz.rectPan, to: orPan, maxCount: maxCountOR)
            numberTilt.start(from: ptz.rectTilt, to: 0, maxCount: maxCountOR)
            numberZoom.start(from: ptz.rectZoom, to: 1, maxCount: maxCountOR)
            numberZoom2D3DO.start(from: 1, to: 0, maxCount: maxCountOO)
            pan = ptz.rectPan
            tilt = ptz.rectTilt
            zoom = ptz.rectZoom
        default:
            break
        }
        
        return true;
    }
    
    func stop() {
        type = .none
        isTransitionRunning = false
    }
    
    func getTransitionPTZ() -> (p: Float, t: Float, z: Float) {
        
        var valueUpdated: Bool = false
        var p: Float = 0
        var t: Float = 0
        var z: Float = 0
        
        if type == .o2p || type == .p2o {
            if numberZoom.isRunning {
                p = numberPan.getNumber();
                t = numberTilt.getNumber();
                z = numberZoom.getNumber();
                valueUpdated = true
            }
        }
        else if type == .o2r {
            if numberZoom2D3DO.isRunning {
                p = 0
                t = 0
                z = numberZoom2D3DO.getNumber()
                valueUpdated = true
            }
            else if numberZoom.isRunning {
                p = numberPan.getNumber()
                t = numberTilt.getNumber()
                z = numberZoom.getNumber()
                valueUpdated = true
            }
        }
        else if type == .r2o {
            if numberZoom.isRunning {
                p = numberPan.getNumber()
                t = numberTilt.getNumber()
                z = numberZoom.getNumber()
                valueUpdated = true
            }
            else if numberZoom2D3DO.isRunning {
                z = numberZoom2D3DO.getNumber()
                valueUpdated = true
            }
        }
        
        if (valueUpdated) {
            return (p: p, t: t, z: z)
        }
        else {
            isTransitionRunning = false
            return (p: pan, t: tilt, z: zoom)
        }
    }
    
    private func getTransitionType(from dt1: FisheyeMeshDewarpType, to dt2: FisheyeMeshDewarpType) -> FisheyeTransitionType {
        
        if dt1 == FisheyeMeshDewarpType.dewarp1O && dt2 == FisheyeMeshDewarpType.dewarp1P {
            return .o2p
        }
        else if dt1 == FisheyeMeshDewarpType.dewarp1P && dt2 == FisheyeMeshDewarpType.dewarp1O {
            return .p2o
        }
        else if dt1 == FisheyeMeshDewarpType.dewarp1O && dt2 == FisheyeMeshDewarpType.dewarp1R {
            return .o2r
        }
        else if dt1 == FisheyeMeshDewarpType.dewarp1R && dt2 == FisheyeMeshDewarpType.dewarp1O {
            return .r2o
        }
        
        return .none
    }
    
    private func transitionOPBegin(mountType: FEMOUNTTYPE) -> Float {
       return (mountType == FE_MOUNT_WALL) ? 0 : 180
    }

    private func transitionORPanBeg(mountType: FEMOUNTTYPE, currentPan: Float) -> Float {
       return (mountType == FE_MOUNT_WALL) ? 0 : ((currentPan > 180) ? 360 : 0)
    }
}

