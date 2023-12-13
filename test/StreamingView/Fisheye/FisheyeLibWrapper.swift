import Foundation

class FisheyeVerticesCallBack {

    struct UpdateVerticesCtx {
        var vertices: UnsafeMutablePointer<Vertex>
        var posScaleX: Float = 1
        var posScaleY: Float = 1
    }
    
    private var vertexPointer : UnsafeMutablePointer<Vertex>! // use in vertex callback function

    init() {
        vertexPointer = UnsafeMutablePointer<Vertex>.allocate(capacity: Int(FISHEYE_GL_VERTEX_CNT))
    }
    
    deinit {
        vertexPointer.deallocate()
    }
    
    func getFisheyeVertices(handle: HANDLE?, posScaleX: Float, posScaleY: Float, isOriginal: Bool) -> [Vertex] {
        
        let updateVerticesCallback : @convention(c) (Optional<UnsafeMutableRawPointer>, Float, Float, Float, Float) -> Void = {
            (p, px, py, tx, ty) -> Void in
            
            var ctx: UpdateVerticesCtx! = p?.load(as: UpdateVerticesCtx.self)
            ctx.vertices.pointee.pos.x = px * ctx.posScaleX
            ctx.vertices.pointee.pos.y = -py * ctx.posScaleY
            ctx.vertices.pointee.pos.z = 0
            ctx.vertices.pointee.pos.w = 1
            ctx.vertices.pointee.uv.x = tx
            ctx.vertices.pointee.uv.y = ty  // metal texture coordinate top-left is (0, 0)
            ctx.vertices += 1
            p?.storeBytes(of: ctx, as: UpdateVerticesCtx.self);
        }
        
        var x = UpdateVerticesCtx(vertices: vertexPointer, posScaleX: posScaleX, posScaleY: posScaleY)

        if isOriginal {
            Fisheye_GetOriginalVertexs(updateVerticesCallback, &x)
        }
        else {
            let ret:SCODE = Fisheye_UpdateVertexs(handle, updateVerticesCallback, &x)
            if  ret != FISHEYE_S_OK {
                print(String(format:"Fisheye_UpdateVertexs failed: %X", ret))
                
                // return 1O vertex
                Fisheye_GetOriginalVertexs(updateVerticesCallback, &x)
            }
        }
        
        return Array(UnsafeBufferPointer(start: vertexPointer, count: Int(FISHEYE_GL_VERTEX_CNT)))
    }
}

class FisheyeLibWrapper {
    
    private var isInitialized: Bool = false
    private var handle: HANDLE?
    private var options = TFisheyeOptionQt()
    private var lensId: Int = -1
    private var keepAspectRatio: Bool = false
    private var dewarpType: FisheyeMeshDewarpType = .dewarp1O
    private var dewarpPTZ = FisheyeDewarpPTZ()
    private var dewarpSettingsChanged: Bool = true
    private var originalSettingsChanged: Bool = false
    
    private var dewarpIndices = [UInt16]()
    private var dewarpVertices = [Vertex]()
    private var vertexPosScaleX: Float = 1
    private var vertexPosScaleY: Float = 1
    private var vertexCallback = FisheyeVerticesCallBack()

    var indices: [UInt16] {
        get {
            return dewarpIndices
        }
    }
    
    var vertices: [Vertex] {
        get {
            return dewarpVertices
        }
    }

    var mountType: FEMOUNTTYPE {
        get {
            return options.MountType
        }
    }
    
    init() {
    }
    
    deinit {
        release()
    }
    
    func initial() -> Bool {
        
        if isInitialized {
            return true
        }
        
        if handle == nil {
            let ret: SCODE = Fisheye_Initial(&handle, LibFisheyeVersion.version)
            if ret != FISHEYE_S_OK {
                print(String(format:"Fisheye_Initial failed: %X", ret))
                return false
            }
        }
        
        // Vertex and Indices
        dewarpVertices = Array(repeating: Vertex(pos: [0, 0, 0, 1], uv: [0, 0]), count: Int(FISHEYE_GL_VERTEX_CNT))
        dewarpIndices = Array(repeating: 0, count: Int(FISHEYE_GL_INDICE_CNT))

        // Default settings
        Fisheye_UpdateIndices(handle, &dewarpIndices)
        Fisheye_SetTransitionToOriginal(handle, true)
        
        dewarpVertices = vertexCallback.getFisheyeVertices(handle: handle, posScaleX: 1, posScaleY: 1, isOriginal: true)
   
        setInVPicture(width: 512, height: 512)
        setOutVPicture(width: 100, height: 100)
        setOutRoi(roi: FERECT(Left: 0, Top: 0, Right: 100, Bottom: 100))
        setCenterRadius(centerX: 256, centerY: 256, radius: 256)
        setMountType(mountType: FE_MOUNT_CEILING)
        setDewarpType(dewarpType: .dewarp1O)
        dewarpPTZ.reset()
        dewarpSettingsChanged = true
        
        isInitialized = true
        return true
    }
    
    func release() {
        if isInitialized {
            Fisheye_Release(&handle)
            isInitialized = false
        }
    }
    
    func setInVPicture(width: Int, height: Int) {
        if options.InVPicture.Width != UInt32(width) || options.InVPicture.Height != UInt32(height) {
            options.InVPicture.Width = UInt32(width)
            options.InVPicture.Height = UInt32(height)
            options.InVPicture.Stride = UInt32(width * 4)
            options.InVPicture.Format = FE_PIXELFORMAT_RGB32
            dewarpSettingsChanged = true
        }
    }
    
    func setOutVPicture(width: Int, height: Int) {
        if options.OutVPicture.Width != UInt32(width) || options.OutVPicture.Height != UInt32(height) {
            options.OutVPicture.Width = UInt32(width)
            options.OutVPicture.Height = UInt32(height)
            options.OutVPicture.Stride = UInt32(width * 4)
            options.OutVPicture.Format = FE_PIXELFORMAT_RGB32
            dewarpSettingsChanged = true
        }
    }
    
    func setOutRoi(roi: FERECT) {
        if options.OutRoi.Left != roi.Left || options.OutRoi.Top != roi.Top || options.OutRoi.Right != roi.Right || options.OutRoi.Bottom != roi.Bottom {
            options.OutRoi = roi
            dewarpSettingsChanged = true
        }
    }

    func setPositionScale(x: Float, y: Float) {
        if vertexPosScaleX != x || vertexPosScaleY != y {
            vertexPosScaleX = x
            vertexPosScaleY = y
            dewarpSettingsChanged = true
            originalSettingsChanged = true
        }
    }
    
    func setKeepAspectRatio(keep: Bool) {
        if keepAspectRatio != keep {
            Fisheye_SetTransitionToOriginal(handle, keep)
            keepAspectRatio = keep
            dewarpSettingsChanged = true
        }
    }
    
    func setCenterRadius(centerX: Int, centerY: Int, radius: Int) {
        if options.FOVCenter.X != Int32(centerX) || options.FOVCenter.Y != Int32(centerY) || options.FOVRadius != UInt32(radius)  {
            options.FOVCenter.X = Int32(centerX)
            options.FOVCenter.Y = Int32(centerY)
            options.FOVRadius = UInt32(radius)
            dewarpSettingsChanged = true
        }
    }
    
    func setMountType(mountType: FEMOUNTTYPE) {
        if options.MountType != mountType {
            options.MountType = mountType
            
            // reset pan tilt zoom to default
            dewarpPTZ.mountType = mountType
            dewarpPTZ.reset()
            
            dewarpSettingsChanged = true
        }
    }
    
    func setDewarpType(dewarpType dt: FisheyeMeshDewarpType) {
        if (dewarpType != dt) {
            
            if dt == FisheyeMeshDewarpType.dewarp1R {
                options.DewarpType = FE_DEWARP_AERIALVIEW
            }
            else if dt == FisheyeMeshDewarpType.dewarp1P {
                options.DewarpType = FE_DEWARP_FULLVIEWPANORAMA
            }
            else if dt == FisheyeMeshDewarpType.dewarpCP {
                options.DewarpType = FE_DEWARP_CLIPVIEWPANORAMA
            }
            
            dewarpPTZ.dewarpType = options.DewarpType
            
            dewarpType = dt
            dewarpSettingsChanged = true
            originalSettingsChanged = true
        }
    }
    
    func setLensId(id: Int) {
        if lensId != id {
            lensId = id
            dewarpSettingsChanged = true
        }
    }
    
    func setPanTiltZoom(pan p: Float, tilt t: Float, zoom z: Float) {
        
        let ptzChanged = dewarpPTZ.set(pan: p, tilt: t, zoom: z)
        
        if ptzChanged {
            dewarpSettingsChanged = true
        }
    }
    
    func update() {
        if !isInitialized {
            return
        }
        
        if dewarpType == .dewarp1O && originalSettingsChanged {
            dewarpVertices = vertexCallback.getFisheyeVertices(handle: handle, posScaleX: vertexPosScaleX, posScaleY: vertexPosScaleY, isOriginal: true)
            originalSettingsChanged = false
        }
        else if dewarpType != .dewarp1O && dewarpSettingsChanged {
            let use1O = (false == updateDewarpSettings())
            dewarpVertices = vertexCallback.getFisheyeVertices(handle: handle, posScaleX: vertexPosScaleX, posScaleY: vertexPosScaleY, isOriginal: use1O)
        }
    }
    
    private func updateEssentialOptions() -> Bool {
    
        var ret:SCODE = Fisheye_SetOptionQt(handle, &options)
        if  ret != FISHEYE_S_OK {
            print(String(format:"Fisheye_SetOptionQt failed: %X", ret))
            return false
        }
        
        if lensId != -1 {
            ret = Fisheye_SetModelLensId(handle, UInt32(lensId))
            if  ret != FISHEYE_S_OK {
                print(String(format:"Fisheye_SetModelLensId failed: %X", ret))
                return false
            }
        }
        
        return true
    }
    
    private func updatePanTiltZoomSettings() -> Bool {
        
        if options.DewarpType != FE_DEWARP_AERIALVIEW && options.DewarpType != FE_DEWARP_FULLVIEWPANORAMA {
            return true
        }
        
        var ptz = dewarpPTZ.get()
        
        var ret:SCODE =  Fisheye_SetPanTiltZoom(handle, FE_POSITION_ABSOLUTE, ptz.pan, ptz.tilt, ptz.zoom)
        if  ret != FISHEYE_S_OK {
            print(String(format:"Fisheye_SetPanTiltZoom failed: %X", ret))
            return false
        }

        ret = Fisheye_GetPanTiltZoom(handle, &ptz.pan, &ptz.tilt, &ptz.zoom)
        if ret != FISHEYE_S_OK {
            print(String(format:"Fisheye_GetPanTiltZoom failed: %X", ret))
            return false
        }
        
        _ = dewarpPTZ.set(pan: ptz.pan, tilt: ptz.tilt, zoom: ptz.zoom)
        
        // dewarpPTZ.printValue()
         
        return true
    }
    
    private func updateDewarpSettings() -> Bool {
    
        if handle == nil {
            return false
        }
        
        if !dewarpSettingsChanged {
            return true
        }
            
        if !updateEssentialOptions() {
            return false
        }
        
        if !updatePanTiltZoomSettings() {
            return false
        }
        
        dewarpSettingsChanged = false

        return true
    }
}

extension FisheyeLibWrapper {
    
    func setTransitionPTZEnabled(enabled: Bool) {
        if dewarpPTZ.isTransition != enabled {
            dewarpPTZ.isTransition = enabled
            dewarpSettingsChanged = true
        }
    }
    
    func setPanTiltZoomByTransition(pan p: Float, tilt t: Float, zoom z: Float) {
        
        let ptzChanged = dewarpPTZ.setTransition(pan: p, tilt: t, zoom: z)
        
        if ptzChanged {
            dewarpSettingsChanged = true
        }
    }
    
    func setPanTiltZoomByMove(from begin: FisheyeMeshPoint, to end: FisheyeMeshPoint) {
        
        let (newPan, newTilt) = calculatePanTiltByMove(from: begin, to: end)
        
        let ptzChanged = dewarpPTZ.set(pan: newPan, tilt: newTilt)
        
        if ptzChanged {
            dewarpSettingsChanged = true
        }
    }
    
    func setPanTiltZoomByDefault(resetPanTilt: Bool, resetZoom: Bool) {
        
        if resetPanTilt {
            dewarpPTZ.resetPanTilt()
            dewarpSettingsChanged = true
        }
        
        if resetZoom {
            dewarpPTZ.resetZoom()
            dewarpSettingsChanged = true
        }
    }
    
    func setZoomBy(pinchScale: Float) {
        
        let zoomChanged = dewarpPTZ.setZoomBy(pinchScale: pinchScale)
        
        if zoomChanged {
            dewarpSettingsChanged = true
        }
    }
    
    func setDewarpPTZ(ptz: FisheyeMeshDewarpPTZ) {
        
        let rectChanged = dewarpPTZ.setRect(pan: ptz.rectPan, tilt: ptz.rectTilt, zoom: ptz.rectZoom)
        let panoChanged = dewarpPTZ.setPano(pan: ptz.panoPan, tilt: ptz.panoTilt, zoom: ptz.panoZoom)
        
        if rectChanged || panoChanged {
            dewarpSettingsChanged = true
        }
    }
    
    func getDewarpPTZ() -> FisheyeMeshDewarpPTZ {
        
        var ptz = FisheyeMeshDewarpPTZ()
        ptz.rectPan = dewarpPTZ.rectPTZ.pan
        ptz.rectTilt = dewarpPTZ.rectPTZ.tilt
        ptz.rectZoom = dewarpPTZ.rectPTZ.zoom
        ptz.panoPan = dewarpPTZ.panoPTZ.pan
        ptz.panoTilt = dewarpPTZ.panoPTZ.tilt
        ptz.panoZoom = dewarpPTZ.panoPTZ.zoom
        return ptz
    }
    
    private func radToDeg(rad: Float) -> Float { return Float(Double(rad) * 180 / Double.pi) }

    private func calculatePanTiltByMove(from begin: FisheyeMeshPoint, to end: FisheyeMeshPoint) -> (pan: Float, tilt: Float) {
        
        let dx = end.x - begin.x
        let dy = end.y - begin.y
        
        var currPan: Float = 0
        var currTilt: Float = 0
        var currZoom: Float = 0
        
        var newPan: Float = 0
        var newTilt: Float = 0
        
        let ret: SCODE = Fisheye_GetPanTiltZoom(handle, &currPan, &currTilt, &currZoom)
        if ret != FISHEYE_S_OK {
            print(String(format:"Fisheye_GetPanTiltZoom failed: %X", ret))
            return (newPan, newTilt)
        }
        
        var scaleRatio: Float = currZoom
        var deltaPan: Float = 0
        var deltaTilt: Float = 0

        let outRoiW: Float = Float(options.OutRoi.Right - options.OutRoi.Left);
        let outRoiH: Float = Float(options.OutRoi.Bottom - options.OutRoi.Top);
    
        if (FE_DEWARP_RECTILINEAR == options.DewarpType || FE_DEWARP_AERIALVIEW == options.DewarpType)
        {
            if (FE_DEWARP_AERIALVIEW == options.DewarpType && currZoom >= 2)
            {
                scaleRatio = currZoom - 1
            }

            // move right/left
            if (FE_MOUNT_WALL == options.MountType)
            {
                let aspectRatio: Float = outRoiW / outRoiH
                let d1: Float = (begin.x / outRoiW * 2.0 - 1.0) / scaleRatio * aspectRatio
                let d2: Float = (end.x / outRoiW * 2.0 - 1.0) / scaleRatio * aspectRatio
                let theta1: Float = radToDeg(rad: atan(d1))
                let theta2: Float = radToDeg(rad: atan(d2))
                deltaPan = theta2 - theta1
            }
            else
            {
                deltaPan = radToDeg(rad: atan(dx / (outRoiW * 0.5 * scaleRatio)))
            }

            // move up/down
            deltaTilt = radToDeg(rad: atan(dy / (outRoiH * 0.5 * scaleRatio)));

            // update pan/tilt
            newPan = currPan - deltaPan
            newTilt = currTilt + deltaTilt
        }
        else if (FE_DEWARP_FULLVIEWPANORAMA == options.DewarpType)
        {
            if (FE_MOUNT_WALL == options.MountType)
            {
                // NOTE: not support for mobile
                let fluentPanoTilt: Float = 100
                deltaTilt = dy / outRoiH * fluentPanoTilt
            }
            else
            {
                let fluentPanoPan: Float = 360
                deltaPan = dx / outRoiW * fluentPanoPan
            }

            // update pan/tilt
            newPan = currPan - deltaPan
            newTilt = currTilt + deltaTilt
        }

        return (newPan, newTilt)
    }
}
