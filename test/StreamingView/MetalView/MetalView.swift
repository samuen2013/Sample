//
//  MetalView.swift
//  iViewer
//
//  Created by sdk on 2021/5/11.
//  Copyright © 2021 Vivotek. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    @objc weak var eaglViewDelegate: EAGLViewDelegate?
    @objc var label: UILabel?
    @objc var debugLabel: UILabel?
    @objc var projectModel: ProjectModel?
    @objc var showMetadataID = false
    @objc var showMetadataPositions = false
    @objc var showMetadataTrackingBlock = false
    @objc var showMetadataHeight = false
    @objc var showMetadataTime = false
    @objc var showMetadataGenderAge = false
    @objc var showVCARules = false
    @objc var showVCAName = false
    @objc var showVCADirection = false
    @objc var showVCAExclusiveArea = false
    var frameWidth: CGFloat = 0
    var frameHeight: CGFloat = 0
    var xScale = 1.0
    var yScale = 1.0
    var textureSize = CGSize()
    var renderType = eYUV
    let fisheyeMesh = FisheyeMesh()
    var eDewarpType = eFeDewarpNone
    var eMountType: FisheyeMountType = .unknown
    var beautyFist = BeautyFistWrapper()
    let viewportCtr = GLViewportCtrWrapper() // 放大縮小
    var isKeepAspectRatio = false
    let renderer = MetalRenderer()
    var vertices = [Vertex]()
    var fragmentUniforms = FragmentUniforms(beautyFistUniforms: BeautyFistMetalUniforms())
    
    init(frame: CGRect) {
        super.init(frame: frame, device: MetalRenderer.device)
        
        frameWidth = frame.size.width
        frameHeight = frame.size.height
        
        fisheyeMesh.setDewarpType(dewarpType: .dewarp1O, transitionTriggerable: false)
        setFisheyeDefaultPTZ()
        
        viewportCtr.reset()
        
        label = UILabel(frame: CGRect(origin: .zero, size: CGSize(width: frame.size.width, height: 20)))
        label?.textColor = .lightGray
        label?.backgroundColor = .clear
        label?.textAlignment = .center
        label?.font = .systemFont(ofSize: 10)
        label?.isHidden = true
        label?.alpha = 0.5
        addSubview(label!)
        
        debugLabel = UILabel(frame: CGRect(origin: .zero, size: CGSize(width: frame.size.width, height: 40)))
        debugLabel?.text = ""
        debugLabel?.textColor = .white
        debugLabel?.backgroundColor = .clear
        debugLabel?.textAlignment = .center
        debugLabel?.font = .systemFont(ofSize: 10)
        debugLabel?.lineBreakMode = .byWordWrapping
        debugLabel?.numberOfLines = 0
        debugLabel?.isHidden = true
        addSubview(debugLabel!)
        
        // Auto Layout
        label?.translatesAutoresizingMaskIntoConstraints = false
        label?.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        label?.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        label?.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        debugLabel?.translatesAutoresizingMaskIntoConstraints = false
        debugLabel?.topAnchor.constraint(equalTo: topAnchor, constant: 20).isActive = true
        debugLabel?.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        debugLabel?.heightAnchor.constraint(equalToConstant: 20).isActive = true

        delegate = renderer
        isPaused = true
        enableSetNeedsDisplay = true
        framebufferOnly = false
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if renderType == eFisheye {
            fisheyeRelease()
        } else if renderType == eStereo {
            stereoCameraRelease()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        frameWidth = frame.size.width
        frameHeight = frame.size.height
        
        _ = createFramebuffer()
    }
    
    func createFramebuffer() -> Bool {
        let backingWidth = drawableSize.width
        let backingHeight = drawableSize.height
        
        viewportCtr.initWithFramebufferW(Float(backingWidth), framebufferH: Float(backingHeight), textureW: Float(backingWidth), textureH: Float(backingHeight))
        
        if renderType == eFisheye {
            // 3. Init fisheye
            let bRet = fisheyeInitial()
            if bRet == false {
                return false
            }
            
            // set display size
            fisheyeMesh.setDisplaySize(width: Int(backingWidth), height: Int(backingHeight))
             
            if eDewarpType == eFeDewarpNone { // 1O
                fisheyeMesh.setDewarpType(dewarpType: .dewarp1O, transitionTriggerable: false)
            } else if eDewarpType == eFeDewarpPano { // 1P
                fisheyeMesh.setDewarpType(dewarpType: .dewarp1P, transitionTriggerable: false)
            } else if eDewarpType == eFeDewarpRect { // 1R
                fisheyeMesh.setDewarpType(dewarpType: .dewarp1R, transitionTriggerable: false)
            } else { // FOV mode = 1080P
                fisheyeMesh.setDewarpType(dewarpType: .dewarpCP, transitionTriggerable: false)
            }
            
            setFisheyeDefaultPTZ()
        } else if renderType == eStereo {
            // Init stereo camera
            let bRet = stereoCameraInitial()
            if bRet == false {
                return false
            }
        }
        
        return true
    }
    

    func renderNormalFrame() {
        var tx: Float = 0, ty: Float = 0, sx: Float = 1, sy: Float = 1
        viewportCtr.getShaderZoomVectorOf(x: &tx, y: &ty, w: &sx, h: &sy)
        let vertices = [
            Vertex(pos: [-1, 1, 0, 1], uv: [tx, ty]),
            Vertex(pos: [-1, -1, 0, 1], uv: [tx, sy + ty]),
            Vertex(pos: [1, -1, 0, 1], uv: [sx + tx, sy + ty]),
            Vertex(pos: [1, 1, 0, 1], uv: [sx + tx, ty])
        ]
        if !self.vertices.elementsEqual(vertices, by: { $0.uv == $1.uv }) {
            self.vertices = vertices
            renderer.setMesh(vertices: vertices, indices: [0, 1, 2, 0, 2, 3])
        }
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
    
    func renderFrame() {
        
        if isFisheyeDewarping() {
            renderFisheyeFrame()
        }
        else if isStereoCameraDewarping() {
            renderStereoCameraFrame()
        }
        else{
            renderNormalFrame()
        }
    }
    
    func updateSnapshotSize() {
        let textureSize = textureSize
        
        DispatchQueue.main.async {
            self.autoResizeDrawable = false
            
            if self.eDewarpType == eFeDewarpPano {
                switch self.eMountType {
                case .wall:
                    self.drawableSize = CGSize(width: textureSize.width, height: ceil(textureSize.width / 2.0))
                case .ceiling, .floor:
                    self.drawableSize = CGSize(width: textureSize.width, height: ceil(textureSize.width / 4.0))
                default:
                    self.drawableSize = textureSize
                }
            } else {
                self.drawableSize = textureSize
            }
        }
    }
}

//MARK: - EAGLViewProtocol
extension MetalView: EAGLViewProtocol {
    func render(with imageBuffer: CVImageBuffer!) {
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let lastTextureSize = textureSize
        textureSize = CGSize(width: width, height: height)
        
        fisheyeMesh.setResoluiton(width: Int(width), height: Int(height))
        
        if isKeepAspectRatio {
            viewportCtr.initWithFramebufferW(Float(frameWidth), framebufferH: Float(frameHeight), textureW: Float(width), textureH: Float(height))
        } else {
            viewportCtr.initWithFramebufferW(Float(frameWidth), framebufferH: Float(frameHeight), textureW: Float(frameWidth), textureH: Float(frameHeight))
        }
        
        renderer.imageBuffer = imageBuffer
        
        renderFrame()
        
        if autoResizeDrawable == true || lastTextureSize != textureSize {
            updateSnapshotSize()
        }
    }
    
    func render(with frame: UnsafeMutablePointer<AVFrame>!, width: uint, height: uint, pixelFormat: AVPixelFormat) {
        let lastTextureSize = textureSize
        textureSize = CGSize(width: Int(width), height: Int(height))
        
        fisheyeMesh.setResoluiton(width: Int(width), height: Int(height))
        
        if isKeepAspectRatio {
            viewportCtr.initWithFramebufferW(Float(frameWidth), framebufferH: Float(frameHeight), textureW: Float(width), textureH: Float(height))
        } else {
            viewportCtr.initWithFramebufferW(Float(frameWidth), framebufferH: Float(frameHeight), textureW: Float(frameWidth), textureH: Float(frameHeight))
        }
        
        var buffers = [Int: MetalBuffer]()
        
        switch pixelFormat {
        case AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUVJ420P:
            buffers[0] = MetalBuffer(bytes: frame.pointee.data.0!, bytesPerRow: Int(frame.pointee.linesize.0), pixelFormat: .r8Unorm, width: Int(width), height: Int(height))
            buffers[1] = MetalBuffer(bytes: frame.pointee.data.1!, bytesPerRow: Int(frame.pointee.linesize.1), pixelFormat: .r8Unorm, width: Int(width) / 2, height: Int(height) / 2)
            buffers[2] = MetalBuffer(bytes: frame.pointee.data.2!, bytesPerRow: Int(frame.pointee.linesize.2), pixelFormat: .r8Unorm, width: Int(width) / 2, height: Int(height) / 2)
        case AV_PIX_FMT_YUVJ422P:
            buffers[0] = MetalBuffer(bytes: frame.pointee.data.0!, bytesPerRow: Int(frame.pointee.linesize.0), pixelFormat: .r8Unorm, width: Int(width), height: Int(height))
            buffers[1] = MetalBuffer(bytes: frame.pointee.data.1!, bytesPerRow: Int(frame.pointee.linesize.1), pixelFormat: .r8Unorm, width: Int(width) / 2, height: Int(height))
            buffers[2] = MetalBuffer(bytes: frame.pointee.data.2!, bytesPerRow: Int(frame.pointee.linesize.2), pixelFormat: .r8Unorm, width: Int(width) / 2, height: Int(height))
        case AV_PIX_FMT_NV12:
            buffers[0] = MetalBuffer(bytes: frame.pointee.data.0!, bytesPerRow: Int(frame.pointee.linesize.0), pixelFormat: .r8Unorm, width: Int(width), height: Int(height))
            buffers[1] = MetalBuffer(bytes: frame.pointee.data.1!, bytesPerRow: Int(frame.pointee.linesize.1), pixelFormat: .rg8Unorm, width: Int(width) / 2, height: Int(height) / 2)
        default:
            return
        }
        
        renderer.updateCurrentRenderPipelineState(pixelFormat: pixelFormat)
        renderer.buffers = buffers
        
        renderFrame()
        
        if autoResizeDrawable == true || lastTextureSize != textureSize {
            updateSnapshotSize()
        }
    }
    
    func clear() {
        renderer.imageBuffer = nil
        renderer.currentRenderPipelineState = MetalRenderer.renderPipelineStates[.RGB]
        renderer.buffers = [:]
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
    
    func setScaleWithX(_ x: Double, y: Double) {
        let delta = x - xScale
        
        if renderType == eFisheye {
            if eDewarpType == eFeDewarpNone {
                return
            }
            
            fisheyeMesh.setGesturePinchScale(delta: Float(delta))
            xScale = x
        } else {
            let fMaxScale: Double = renderType == eMultiSensor ? 12 : 4
            
            xScale = max(1, min(x, fMaxScale))
            yScale = max(1, min(y, fMaxScale))
            
            viewportCtr.setScaleWithPivotX(Float(frameHeight) / 2, pivotY: Float(frameHeight) / 2, scale: Float(xScale))
        }
        
        renderFrame()
    }
    
    func setScaleWithDeltaX(_ deltaX: Double) {
        if renderType == eFisheye && eDewarpType == eFeDewarpRect {
            fisheyeMesh.setGesturePinchScale(delta: Float(deltaX))
            renderFrame()
        }
    }
    
    func getScale() -> Float {
        return Float(xScale)
    }
    
    func resetScale() {
        if renderType == eFisheye {
            xScale = 1.0
            yScale = 1.0
            fisheyeMesh.setPanTiltZoomByDefault(resetPanTilt: false, resetZoom: true)
        } else {
            xScale = 1.0
            yScale = 1.0
        }
        
        viewportCtr.setScale(1.0)
        
        renderFrame()
    }
    
    func setLocationWithX(_ x: Double, y: Double) {
    }
    
    func setLocationWithPoints(_ dBegX: Double, begY dBegY: Double, endX dEndX: Double, endY dEndY: Double) {
        // delta
        let xLocation = dEndX - dBegX
        let yLocation = dEndY - dBegY
        
        if renderType == eFisheye {
            fisheyeMesh.setGesturePanLocation(beginX: Float(dBegX), beginY: Float(dBegY), endX: Float(dEndX), endY: Float(dEndY))
        } else {
            viewportCtr.setTranslateWithDeltaX(Float(xLocation), deltaY: Float(yLocation))
        }
        
        renderFrame()
    }
    
    func setGestureEndPanbEnd(_ isEnd: Bool) {
        if renderType == eFisheye {
            fisheyeMesh.setGesturePanEnded()
        }
    }
    
    func resetLocation() {
        // fisheye
        fisheyeMesh.setPanTiltZoomByDefault(resetPanTilt: true, resetZoom: false)
        
        viewportCtr.setDefaultLocation()
        
        // redraw
        renderFrame()
    }
    
    func renderSize() -> CGSize {
        let renderSize: CGSize
        
        if renderType == eStereo {
            var width: UInt32 = 0
            var height: UInt32 = 0
            _ = beautyFist.getRectifiedPictureSize(UInt32(textureSize.width), UInt32(textureSize.height), &width, &height)
            renderSize = CGSize(width: Int(width), height: Int(height))
        } else {
            renderSize = textureSize
        }
        
        if renderSize.width == 0.0 && renderSize.height == 0.0 {
            return frame.size
        }
        
        return renderSize
    }
    
    func snapUIImage() -> UIImage! {
        let lastDrawableDisplayed = currentDrawable?.texture

        if let imageRef = lastDrawableDisplayed?.toImage() {
            return UIImage.init(cgImage: imageRef)
        }
        return UIImage()
    }
    
    func setRenderType(_ renderType: ERenderType) {
        let previousIsRenderType = self.renderType
        
        if previousIsRenderType == renderType {
            return
        }
        
        self.renderType = renderType
        
        // switch nomal shader and stereo dewarping shader
        renderer.isStereoDewarping = (renderType == eStereo)
        
        xScale = 1.0
        yScale = 1.0
        
        viewportCtr.setScale(1)
        
        if previousIsRenderType == eFisheye {
            fisheyeRelease()
        } else if previousIsRenderType == eStereo {
            stereoCameraRelease()
        }
        
        _ = createFramebuffer()
    }
    
    func getRenderType() -> ERenderType {
        return renderType
    }
    
    func isFisheyeDewarping() -> Bool {
        return renderType == eFisheye
    }
    
    func isStereoCameraDewarping() -> Bool {
        return renderType == eStereo
    }
    
    func setFisheyeDewarpType(_ dewarpType: Int) {
        if eDewarpType.rawValue == UInt32(dewarpType) {
            return
        }
        
        eDewarpType.rawValue = UInt32(dewarpType)
        
        // set dewarp type
        if eDewarpType == eFeDewarpNone { // 1O
            fisheyeMesh.setDewarpType(dewarpType: .dewarp1O, transitionTriggerable: true)
        } else if eDewarpType == eFeDewarpPano { // 1P
            fisheyeMesh.setDewarpType(dewarpType: .dewarp1P, transitionTriggerable: true)
        } else if eDewarpType == eFeDewarpRect { // 1R
            fisheyeMesh.setDewarpType(dewarpType: .dewarp1R, transitionTriggerable: true)
        } else { // FOV mode = 1080P
            fisheyeMesh.setDewarpType(dewarpType: .dewarpCP, transitionTriggerable: true)
        }

        renderFrame()
        
        updateSnapshotSize()
    }
    
    func getFisheyeDewarpType() -> EFisheyeDewarpType {
        return eDewarpType
    }
    
    func setEnableFisheyeTransition(_ enableFisheyeTransition: Bool) {
        fisheyeMesh.setTransitionAnimation(enabled: enableFisheyeTransition)
    }
    
    func setFisheyeDefaultPTZ() {
        DispatchQueue.main.async {
            if let delegate = self.eaglViewDelegate, delegate.responds(to: #selector(EAGLViewDelegate.fisheyePTZLocation(for:))) {
                if let location = delegate.fisheyePTZLocation?(for: nil), location.keys.count != 0 {
                    var dewarpPTZ = FisheyeMeshDewarpPTZ()
                    dewarpPTZ.rectPan = location["FeRectPan"] as! Float
                    dewarpPTZ.rectTilt = location["FeRectTilt"] as! Float
                    dewarpPTZ.rectZoom = location["FeRectZoom"] as! Float
                    dewarpPTZ.panoPan = location["FePanoPan"] as! Float
                    dewarpPTZ.panoTilt = location["FePanoTilt"] as! Float
                    dewarpPTZ.panoZoom = 1
                    self.fisheyeMesh.setPanTiltZoomByDewarpPTZ(ptz: dewarpPTZ)
                } else {
                    self.fisheyeMesh.setPanTiltZoomByDefault(resetPanTilt: true, resetZoom: true)
                }
            } else {
                self.fisheyeMesh.setPanTiltZoomByDefault(resetPanTilt: true, resetZoom: true)
            }
        }
    }
    
    func fisheyePTZLocation() -> [AnyHashable : Any]! {
        let dewarpPTZ = fisheyeMesh.getDewarpPTZ()
        return ["FeRectPan": dewarpPTZ.rectPan,
                "FeRectTilt": dewarpPTZ.rectTilt,
                "FeRectZoom": dewarpPTZ.rectZoom,
                "FePanoPan": dewarpPTZ.panoPan,
                "FePanoTilt": dewarpPTZ.panoTilt]
    }
    
    func setFisheyeMeshInfo(_ info: FisheyeMeshInfo) {
        fisheyeMesh.setFisheyeInfo(info: info)
    }
    
    func setRenderInfo(_ renderInfo: TRenderInfo) {
        if renderInfo.eRenderType == eFisheye.rawValue {
            let info = FisheyeMeshInfo(centerX: Int(renderInfo.tFisheyeInfo.wCenterX),
                                   centerY: Int(renderInfo.tFisheyeInfo.wCenterY),
                                   radius: Int(Double(renderInfo.tFisheyeInfo.wRadius)),
                                   lensId: Int(renderInfo.tFisheyeInfo.byId),
                                   installation: Int(renderInfo.tFisheyeInfo.byInstallation))
            
            fisheyeMesh.setFisheyeInfo(info: info)
        } else if renderInfo.eRenderType == eStereo.rawValue {
            beautyFist.setStereoCameraInfo(info: renderInfo.tStereoCameraInfo)
        }
    }
    
    func setKeepAspectRatiobKeep(_ isKeep: Bool) {
        isKeepAspectRatio = isKeep
        
        fisheyeMesh.setKeepAspectRatio(keep: isKeep)
    }
    
    func fitScreenHeight(withPivotX fX: Float, y fY: Float) {
        if renderType != eFisheye {
            if xScale != 1.0 {
                xScale = 1.0
                viewportCtr.setScale(Float(xScale))
            } else {
                xScale = Double(viewportCtr.getFitTopBotScale())
                viewportCtr.setScaleWithPivotX(fX, pivotY: fY, scale: Float(xScale))
            }
            renderFrame()
        }
    }
    
    func setFisheyeMountType(_ mountType: FisheyeMountType) {
        guard eMountType != mountType else { return }
        
        eMountType = mountType
        
        updateSnapshotSize()
    }
}
// MARK: -

// fisheye
extension MetalView {

    func fisheyeInitial() -> Bool {
        if !fisheyeMesh.isInitialized() {
            let scRet = fisheyeMesh.initialize()
            if scRet != true {
                return false
            }
            fisheyeMesh.setAnimationRenderFunction(renderCallback: renderFisheyeFrame)
        }
        return true
    }
    
    func fisheyeRelease() {
        fisheyeMesh.deinitialize()
    }
    
    func renderFisheyeFrame() {
        
        if !fisheyeMesh.isInitialized() {
            renderNormalFrame()
            return
        }
        
        let (dewarpVertices, dewarpIndices) = fisheyeMesh.update()
        
        if !self.vertices.elementsEqual(dewarpVertices, by: {$0.pos == $1.pos && $0.uv == $1.uv }) {
            self.vertices = dewarpVertices
            renderer.setMesh(vertices: vertices, indices: dewarpIndices)
        }
        
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
}

// stereo camera
extension MetalView {
    
    func stereoCameraInitial() -> Bool {
        if beautyFist.pBeautyFist == nil {
            let scRet = beautyFist.initial()
            if scRet != BEAUTYFIST_S_OK {
                return false
            }
        }
        return true
    }
    
    func stereoCameraRelease() {
        beautyFist.release()
    }
    
    func renderStereoCameraFrame() {
        
        let metalUniforms = beautyFist.getMetalUniforms(UInt32(textureSize.width), UInt32(textureSize.height))
        
        if fragmentUniforms.beautyFistUniforms != metalUniforms {
            fragmentUniforms.beautyFistUniforms = metalUniforms
            renderer.setFragmentUniforms(fragmentUniforms: &fragmentUniforms)
        }
    
        renderNormalFrame()
    }
}

extension MetalView: MetadataDrawable {
    var sizeScale: CGFloat {
        let sizeScale = renderSize().width / max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        if sizeScale != 0.0 {
            return sizeScale
        } else {
            return 1.0
        }
    }
    
    func didReceive(_ metadata: Metadata!) {
        clearMetadataObjects()
        
        metadata.frame?.objects?.forEach {
            drawMetadataObjects(withOriginX: $0.origin.x, originY: $0.origin.y, centroidX: $0.centroid.x, centroidY: $0.centroid.y, height: $0.height, timeStamp: $0.originUtcTime, gid: $0.gid)
        }
    }
    
    func drawMetadataObjects(withOriginX originX: Int, originY: Int, centroidX: Int, centroidY: Int, height: Int, timeStamp: String!, gid: Int) {
        guard let projectModel = projectModel else {
            return
        }
        
        let centroidPoint3D = projectModel.projectPoint(objectPoint: Point3D(x: Double(centroidX), y: Double(centroidY), z: Double(projectModel.camHeight - height * 2 / 3)))
        let centroidPoint = CGPoint(x: centroidPoint3D.x * Double(frame.size.width) / Double(projectModel.resolutionW), y: centroidPoint3D.y * Double(frame.size.height) / Double(projectModel.modResolutionH))
        
        let originPoint3D = projectModel.projectPoint(objectPoint: Point3D(x: Double(originX), y: Double(originY), z: 0))
        let originPoint = CGPoint(x: originPoint3D.x * Double(frame.size.width) / Double(projectModel.resolutionW), y: originPoint3D.y * Double(frame.size.height) / Double(projectModel.modResolutionH))
        
        var x = [Double](repeating: 0, count: 8)
        var y = [Double](repeating: 0, count: 8)
        
        let xOffset = [-180, 180, 180, -180]
        let yOffset = [-180, -180, 180, 180]
        
        for i in 0..<4 {
            let topPoint = projectModel.projectPoint(objectPoint: Point3D(x: Double(centroidX + xOffset[i]), y: Double(centroidY + yOffset[i]), z: 0))
            x[i] = topPoint.x * Double(frame.size.width) / Double(projectModel.resolutionW)
            y[i] = topPoint.y * Double(frame.size.height) / Double(projectModel.modResolutionH)
            
            let bottomPoint = projectModel.projectPoint(objectPoint: Point3D(x: Double(centroidX + xOffset[i]), y: Double(centroidY + yOffset[i]), z: Double(projectModel.camHeight - height)))
            x[i + 4] = bottomPoint.x * Double(frame.size.width) / Double(projectModel.resolutionW)
            y[i + 4] = bottomPoint.y * Double(frame.size.height) / Double(projectModel.modResolutionH)
        }
        
        // Draw box
        if showMetadataTrackingBlock {
            drawTrackingBlock(withTopPoint0: CGPoint(x: x[0], y: y[0]),
                              topPoint1: CGPoint(x: x[1], y: y[1]),
                              topPoint2: CGPoint(x: x[2], y: y[2]),
                              topPoint3: CGPoint(x: x[3], y: y[3]),
                              bottomPoint0: CGPoint(x: x[4], y: y[4]),
                              bottomPoint1: CGPoint(x: x[5], y: y[5]),
                              bottomPoint2: CGPoint(x: x[6], y: y[6]),
                              bottomPoint3: CGPoint(x: x[7], y: y[7]))
        }
        
        // Draw object
        if showMetadataPositions {
            drawObjectPositions(withCentroidPoint: centroidPoint, originPoint: originPoint, gid: gid)
        }
        
        if showMetadataID || showMetadataPositions || showMetadataTrackingBlock || showMetadataHeight || showMetadataTime || showMetadataGenderAge {
            drawObject(withCentroidPoint: centroidPoint, gid: gid)
        }
        
        if showMetadataID {
            drawObjectID(withCentroidPoint: centroidPoint, gid: gid)
        }
        
        // Draw text labels
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let date = dateFormatter.date(from: timeStamp)
        let durationTime = abs(Int(date?.timeIntervalSinceNow ?? 0))
        
        drawTextLabels(withCentroidPoint: centroidPoint,
                       gender: -1,
                       age: nil,
                       height: height / 10,
                       durationTime: durationTime)
    }
    
    static func color(ofGid gid: Int) -> UIColor! {
        switch gid % 5 {
        case 0:
            return UIColor(hexString: "#CC138F7C")
        case 1:
            return UIColor(hexString: "#CCA17619")
        case 2:
            return UIColor(hexString: "#CC9B3CA7")
        case 3:
            return UIColor(hexString: "#CC4FA814")
        case 4:
            return UIColor(hexString: "#CC2E8FB3")
        default:
            return UIColor(hexString: "#CC138F7C")
        }
    }
    
    func drawObject(withCentroidPoint centroidPoint: CGPoint, gid: Int) {
        let circlePath = UIBezierPath()
        circlePath.lineWidth = 1.0 * sizeScale
        
        // Draw circle
        let centroidPath = UIBezierPath()
        centroidPath.addArc(withCenter: centroidPoint, radius: 12.0 * sizeScale, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        centroidPath.lineWidth = 1.0 * sizeScale
        circlePath.append(centroidPath)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath
        shapeLayer.fillColor = Self.color(ofGid: gid)?.cgColor
        shapeLayer.strokeColor = Self.color(ofGid: gid)?.cgColor
        shapeLayer.name = "ShapeLayerObject+\(gid)"
        shapeLayer.opacity = 0.8
        shapeLayer.lineWidth = 1.0 * sizeScale
        
        // Draw border
        let borderPath = UIBezierPath()
        borderPath.lineWidth = 2.0 * sizeScale
        
        let centroidBorderPath = UIBezierPath()
        centroidBorderPath.addArc(withCenter: centroidPoint, radius: 13.0 * sizeScale, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        centroidBorderPath.lineWidth = 2.0 * sizeScale
        borderPath.append(centroidBorderPath)
        
        let borderLayer = CAShapeLayer()
        borderLayer.path = borderPath.cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor(hexString: "#99FFFFFF").cgColor
        borderLayer.name = "ShapeLayerObjectBorder+\(gid)"
        borderLayer.opacity = 0.6
        borderLayer.lineWidth = 2.0 * sizeScale
        
        layer.addSublayer(shapeLayer)
        layer.addSublayer(borderLayer)
    }
    
    func drawObjectID(withCentroidPoint centroidPoint: CGPoint, gid: Int) {
        let textLayer = CATextLayer()
        let width = 22.0 * sizeScale
        let height = 14.0 * sizeScale
        textLayer.frame = CGRect(x: centroidPoint.x - width / 2, y: centroidPoint.y - height / 2, width: width, height: height)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.truncationMode = .end
        textLayer.alignmentMode = .center
        textLayer.isWrapped = false
        textLayer.name = "ShapeLayerObjectIDText+\(gid)"
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.backgroundColor = UIColor.clear.cgColor
        textLayer.opacity = 1.0
        
        let font = UIFont.systemFont(ofSize: 12.0 * sizeScale)
        textLayer.font = CGFont(font.fontName as CFString)
        textLayer.fontSize = font.pointSize
        
        textLayer.string = "\(gid)"
        
        layer.addSublayer(textLayer)
    }
    
    func drawObjectPositions(withCentroidPoint centroidPoint: CGPoint, originPoint: CGPoint, gid: Int) {
        let circlePath = UIBezierPath()
        circlePath.lineWidth = 1.0 * sizeScale
        
        // Draw circle
        let originPath = UIBezierPath()
        originPath.addArc(withCenter: originPoint, radius: 3.0 * sizeScale, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        originPath.lineWidth = 1.0 * sizeScale
        circlePath.append(originPath)
        
        // Draw tracking line
        circlePath.move(to: originPoint)
        circlePath.addLine(to: centroidPoint)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath
        shapeLayer.fillColor = Self.color(ofGid: gid)?.cgColor
        shapeLayer.strokeColor = Self.color(ofGid: gid)?.cgColor
        shapeLayer.name = "ShapeLayerObjectPosition+\(gid)"
        shapeLayer.opacity = 0.8
        shapeLayer.lineWidth = 1.0 * sizeScale
        
        // Draw border
        let borderPath = UIBezierPath()
        borderPath.lineWidth = 2.0 * sizeScale
        
        let originBorderPath = UIBezierPath()
        originBorderPath.addArc(withCenter: originPoint, radius: 4.0 * sizeScale, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        originBorderPath.lineWidth = 2.0 * sizeScale
        borderPath.append(originBorderPath)
        
        let borderLayer = CAShapeLayer()
        borderLayer.path = borderPath.cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor(hexString: "#99FFFFFF").cgColor
        borderLayer.name = "ShapeLayerObjectPositionBorder+\(gid)"
        borderLayer.opacity = 0.6
        borderLayer.lineWidth = 2.0 * sizeScale
        
        layer.addSublayer(shapeLayer)
        layer.addSublayer(borderLayer)
    }
    
    func drawTrackingBlock(withTopPoint0 topPoint0: CGPoint, topPoint1: CGPoint, topPoint2: CGPoint, topPoint3: CGPoint, bottomPoint0: CGPoint, bottomPoint1: CGPoint, bottomPoint2: CGPoint, bottomPoint3: CGPoint) {
        let path = UIBezierPath()
        path.lineWidth = 1.0 * sizeScale
        
        path.move(to: topPoint0)
        path.addLine(to: topPoint1)
        path.addLine(to: topPoint2)
        path.addLine(to: topPoint3)
        path.close()
        
        path.move(to: bottomPoint0)
        path.addLine(to: bottomPoint1)
        path.addLine(to: bottomPoint2)
        path.addLine(to: bottomPoint3)
        path.close()
        
        path.move(to: topPoint0)
        path.addLine(to: bottomPoint0)
        path.move(to: topPoint1)
        path.addLine(to: bottomPoint1)
        path.move(to: topPoint2)
        path.addLine(to: bottomPoint2)
        path.move(to: topPoint3)
        path.addLine(to: bottomPoint3)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(hexString: "#FF2660B7").cgColor
        shapeLayer.name = "ShapeLayerTrackingBlock"
        shapeLayer.opacity = 1.0
        shapeLayer.lineWidth = 1.0 * sizeScale
        
        layer.addSublayer(shapeLayer)
    }
    
    func drawTextLabel(withCentroidPoint centroidPoint: CGPoint, text: String!, iconImage: UIImage!) {
        let textLayer = LCTextLayer()
        let width = 40.0 * sizeScale
        let height = 20.0 * sizeScale
        
        textLayer.frame = CGRect(x: centroidPoint.x - width / 2, y: centroidPoint.y - height / 2, width: width, height: height)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.truncationMode = .end
        textLayer.alignmentMode = .center
        textLayer.isWrapped = false
        textLayer.name = "ShapeLayerTextLabel+\(text!)"
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.backgroundColor = UIColor.black.cgColor
        textLayer.opacity = 0.6
        
        let font = UIFont.systemFont(ofSize: 10.0 * sizeScale)
        textLayer.font = CGFont(font.fontName as CFString)
        textLayer.fontSize = font.pointSize
        
        textLayer.string = text
        
        layer.addSublayer(textLayer)
        
        if let iconImage = iconImage {
            let imageLayer = CALayer()
            imageLayer.frame = CGRect(x: centroidPoint.x - 18.0 * sizeScale, y: centroidPoint.y + 4.0 * sizeScale, width: 8.0 * sizeScale, height: 12.0 * sizeScale)
            imageLayer.contents = iconImage.cgImage
            imageLayer.contentsGravity = .resizeAspectFill
            imageLayer.contentsScale = UIScreen.main.scale
            imageLayer.name = "ShapeLayerTextLabelIcon"
            layer.addSublayer(imageLayer)
        }
    }
    
    func drawTextLabels(withCentroidPoint centroidPoint: CGPoint, gender: Int, age: String!, height: Int, durationTime durationtime: Int) {
        var genderIcon: UIImage?
        switch gender {
        case 0:
            genderIcon = UIImage(named: "icon_Female.png")
        case 1:
            genderIcon = UIImage(named: "icon_Male.png")
        default:
            break
        }
        
        let ageText = "  \(age ?? "")"
        let heightText = "H:\(height)"
        let timeText = "T:\(durationtime)"
        
        var labels = [String]()
        
        if showMetadataGenderAge, let _ = genderIcon, let _ = age {
            labels.append(ageText)
        }
        
        if showMetadataHeight {
            labels.append(heightText)
        }
        
        if showMetadataTime {
            labels.append(timeText)
        }
        
        let yOffset = 14.0 * sizeScale
        let labelHeight = 20.0 * sizeScale
        let spacing = 2.0 * sizeScale
        
        for i in 0..<labels.count {
            let point = CGPoint(x: centroidPoint.x, y: centroidPoint.y + yOffset + labelHeight * CGFloat(i) + spacing * CGFloat(i + 1))
            if labels[i] == ageText {
                drawTextLabel(withCentroidPoint: point, text: labels[i], iconImage: genderIcon)
            } else {
                drawTextLabel(withCentroidPoint: point, text: labels[i], iconImage: nil)
            }
        }
    }
    
    func clearMetadataObjects() {
        layer.sublayers?.filter {
            ($0.name ?? "").contains("ShapeLayer")
        }.forEach {
            $0.removeFromSuperlayer()
        }
    }
}

extension CGRect {
    init(withCGPoints points: [Any]!) {
        let sortedArrayX = points.sorted {
            ($0 as! CGPoint).x < ($1 as! CGPoint).x
        }
        
        let left = sortedArrayX.first! as! CGPoint
        let right = sortedArrayX.last! as! CGPoint
        
        let sortedArrayY = points.sorted {
            ($0 as! CGPoint).y < ($1 as! CGPoint).y
        }
        
        let top = sortedArrayY.first! as! CGPoint
        let bottom = sortedArrayY.last! as! CGPoint
        
        self.init(x: left.x, y: top.y, width: abs(right.x - left.x), height: abs(bottom.y - top.y))
    }
}

extension MetalView: VCARulesDrawable {
    func drawVCARules(_ rules: [AnyHashable : Any]!) {
        clearVCARules()
        
        if let rules = rules {
            // ZoneDetection
            let zoneDetectionRules = rules["ZoneDetection"] as! [AnyHashable : Any]
            
            zoneDetectionRules.forEach {
                let rule = $1 as! [AnyHashable : Any]
                let ruleName = rule["RuleName"] as! String
                let fields = rule["Field"] as! [Any]
                let field = fields.first as! [Any]
                
                let points = field.map {
                    $0 as! [AnyHashable : Any]
                }.map {
                    CGPoint(x: Double($0["x"] as! Int) / 10000.0 * Double(renderSize().width),
                            y: Double($0["y"] as! Int) / 10000.0 * Double(renderSize().height))
                }
                
                drawZoneDetection(withName: ruleName, points: points)
            }
            
            // Counting
            let countingRules = rules["Counting"] as! [AnyHashable : Any]
            
            countingRules.forEach {
                let rule = $1 as! [AnyHashable : Any]
                let ruleName = rule["RuleName"] as! String
                let direction = rule["Direction"] as! String
                let lines = rule["Line"] as! [Any]
                let line = lines.first as! [Any]
                
                let points = line.map {
                    $0 as! [AnyHashable : Any]
                }.map {
                    CGPoint(x: Double($0["x"] as! Int) / 10000.0 * Double(renderSize().width),
                            y: Double($0["y"] as! Int) / 10000.0 * Double(renderSize().height))
                }
                
                if points.count >= 3 {
                    drawCounting(withName: ruleName, direction: direction, point0: points[0], point1: points[1], point2: points[2])
                }
            }
            
            // FlowPathCouting
            let flowPathCountingRules = rules["Counting"] as! [AnyHashable : Any]
            
            flowPathCountingRules.forEach {
                let rule = $1 as! [AnyHashable : Any]
                let ruleName = rule["RuleName"] as! String
                let direction = rule["Direction"] as! String
                let lines = rule["Line"] as! [Any]
                
                let points = lines.compactMap {
                    ($0 as! [Any]).map {
                        $0 as! [AnyHashable : Any]
                    }.map {
                        CGPoint(x: Double($0["x"] as! Int) / 10000.0 * Double(renderSize().width),
                                y: Double($0["y"] as! Int) / 10000.0 * Double(renderSize().height))
                    }
                }
                
                drawFlowPathCounting(withName: ruleName, direction: direction, points: points)
            }

            // Exclusive Area
            let exclusiveAreaRules = rules["ExclusiveArea"] as! [AnyHashable : Any]
            let fields = exclusiveAreaRules["Field"] as! [Any]
            let field = fields.first as! [Any]
            
            let points = field.map {
                $0 as! [AnyHashable : Any]
            }.map {
                CGPoint(x: Double($0["x"] as! Int) / 10000.0 * Double(renderSize().width),
                        y: Double($0["y"] as! Int) / 10000.0 * Double(renderSize().height))
            }
            
            drawExclusiveArea(withPoints: points)
        }
    }
    
    func drawRuleName(_ name: String!, on rect: CGRect) {
        if showVCAName {
            let textLayerWidth = 200 * sizeScale
            let textLayerHeight = 13 * sizeScale
            let spacing = 5 * sizeScale
            let textLayer = LCTextLayer()
            
            if rect.origin.y - textLayerHeight - spacing <= 0 {
                textLayer.frame = CGRect(x: rect.origin.x + (rect.size.width / 2) - (textLayerWidth / 2),
                                         y: rect.origin.y + rect.size.height + textLayerHeight + spacing,
                                         width: textLayerWidth,
                                         height: textLayerHeight)
            } else {
                textLayer.frame = CGRect(x: rect.origin.x + (rect.size.width / 2) - (textLayerWidth / 2),
                                         y: rect.origin.y - textLayerHeight - spacing,
                                         width: textLayerWidth,
                                         height: textLayerHeight)
            }
            
            textLayer.foregroundColor = UIColor(hexString: "#20F4D4").cgColor
            textLayer.truncationMode = .end
            textLayer.alignmentMode = .center
            textLayer.isWrapped = false
            textLayer.name = "RuleLayerTextLabel\(name!)"
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.backgroundColor = UIColor.clear.cgColor
            textLayer.opacity = 1.0
            
            let font = UIFont.systemFont(ofSize: 13.0 * sizeScale)
            textLayer.font = CGFont(font.fontName as CFString)
            textLayer.fontSize = font.pointSize
            
            textLayer.string = name
            
            layer.addSublayer(textLayer)
        }
    }
    
    func drawZoneDetection(withName name: String!, points: [Any]!) {
        if showVCARules {
            let path = UIBezierPath()
            path.lineWidth = 3.0 * sizeScale
            
            points.enumerated().forEach {
                if $0 == 0 {
                    path.move(to: $1 as! CGPoint)
                } else {
                    path.addLine(to: $1 as! CGPoint)
                }
            }
            path.close()
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = UIColor(hexString: "#20F4D4").cgColor
            shapeLayer.strokeColor = UIColor(hexString: "#20F4D4").cgColor
            shapeLayer.name = "RuleLayerZoneDetection+\(name!)"
            shapeLayer.opacity = 0.1
            
            // Draw border
            let borderPath = UIBezierPath()
            borderPath.lineWidth = 3.0 * sizeScale
            
            let borderLayer = CAShapeLayer()
            borderLayer.path = path.cgPath
            borderLayer.fillColor = UIColor.clear.cgColor
            borderLayer.strokeColor = UIColor(hexString: "#20F4D4").cgColor
            borderLayer.name = "RuleLayerZoneDetectionBorder+\(name!)"
            borderLayer.opacity = 1.0
            
            layer.addSublayer(shapeLayer)
            layer.addSublayer(borderLayer)
        }
        
        drawRuleName("\(name!)@ZoneDetection", on: CGRect(withCGPoints: points))
    }
    
    func drawExclusiveArea(withPoints points: [Any]!) {
        if showVCAExclusiveArea {
            let path = UIBezierPath()
            path.lineWidth = 1.0 * sizeScale
            
            points.enumerated().forEach {
                if $0 == 0 {
                    path.move(to: $1 as! CGPoint)
                } else {
                    path.addLine(to: $1 as! CGPoint)
                }
            }
            path.close()
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = UIColor(hexString: "#FF1D1D1D").cgColor
            shapeLayer.strokeColor = UIColor(hexString: "#FF1D1D1D").cgColor
            shapeLayer.name = "RuleLayerExclusiveArea"
            shapeLayer.opacity = 0.5
            
            layer.addSublayer(shapeLayer)
        }
    }
    
    func drawDirection(withCentroidPoint centroidPoint: CGPoint, directionText: String!) {
        if showVCADirection {
            var shapeColor: UIColor?
            
            if directionText == "Out" {
                shapeColor = UIColor(hexString: "#F46020")
            } else {
                shapeColor = UIColor(hexString: "#2660B7")
            }
            
            let circlePath = UIBezierPath()
            circlePath.lineWidth = 1.0 * sizeScale
            
            // Draw circle
            let centroidPath = UIBezierPath()
            centroidPath.addArc(withCenter: centroidPoint, radius: 19.0 * sizeScale, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
            centroidPath.lineWidth = 1.0 * sizeScale
            circlePath.append(centroidPath)
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = circlePath.cgPath
            shapeLayer.fillColor = shapeColor?.cgColor
            shapeLayer.strokeColor = shapeColor?.cgColor
            shapeLayer.name = "RuleLayerDirection+\(directionText!)"
            shapeLayer.opacity = 0.4
            shapeLayer.lineWidth = 1.0 * sizeScale
            
            layer.addSublayer(shapeLayer)
            
            let textLayer = CATextLayer()
            let width: CGFloat = 26.0 * sizeScale
            let height: CGFloat = 14.0 * sizeScale
            textLayer.frame = CGRect(x: centroidPoint.x - width / 2, y: centroidPoint.y - height / 2, width: width, height: height)
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.truncationMode = .end
            textLayer.alignmentMode = .center
            textLayer.isWrapped = false
            textLayer.name = "RuleLayerDirectionText+\(directionText!)"
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.backgroundColor = UIColor.clear.cgColor
            textLayer.opacity = 1.0
            
            let font = UIFont.systemFont(ofSize: 14.0 * sizeScale)
            textLayer.font = CGFont(font.fontName as CFString)
            textLayer.fontSize = font.pointSize

            textLayer.string = directionText
            
            layer.addSublayer(textLayer)
        }
    }
    
    func drawCounting(withName name: String!, direction: String!, point0: CGPoint, point1: CGPoint, point2: CGPoint) {
        let radius = 19.0 * Double(sizeScale)
        let spacing = 9.0 * Double(sizeScale)
        let a = Vector2D(x: Double(point0.x), y: Double(point0.y))
        let b = Vector2D(x: Double(point1.x), y: Double(point1.y))
        let c = Vector2D(x: Double(point2.x), y: Double(point2.y))
        
        let ab = b.minus(a)
        let bc = c.minus(b)
        
        let leftVec = ab.normalized().plus(bc.normalized()).rotate(-Double.pi / 2.0).normalized()
        let rightVec = leftVec.times(-1.0)
        let inVec = b.translate(leftVec.times(radius + spacing))
        let outVec = b.translate(rightVec.times(radius + spacing))
        
        switch direction {
        case "Out":
            drawDirection(withCentroidPoint: CGPoint(x: outVec.x, y: outVec.y), directionText: "Out")
        case "In":
            drawDirection(withCentroidPoint: CGPoint(x: inVec.x, y: inVec.y), directionText: "In")
        default:
            drawDirection(withCentroidPoint: CGPoint(x: inVec.x, y: inVec.y), directionText: "In")
            drawDirection(withCentroidPoint: CGPoint(x: outVec.x, y: outVec.y), directionText: "Out")
        }
        
        if showVCARules {
            let path = UIBezierPath()
            path.move(to: point0)
            path.addLine(to: point1)
            path.addLine(to: point2)
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.strokeColor = UIColor(hexString: "#20F4D4").cgColor
            shapeLayer.name = "RuleLayerCounting+\(name!)"
            shapeLayer.opacity = 1.0
            shapeLayer.lineWidth = 3.0 * sizeScale
            
            layer.addSublayer(shapeLayer)
        }
        
        var points = [point0, point1, point2]
        points.append(CGPoint(x: inVec.x, y: inVec.y + radius))
        points.append(CGPoint(x: inVec.x, y: inVec.y - radius))
        points.append(CGPoint(x: inVec.x - radius, y: inVec.y))
        points.append(CGPoint(x: inVec.x + radius, y: inVec.y))
        points.append(CGPoint(x: outVec.x, y: outVec.y + radius))
        points.append(CGPoint(x: outVec.x, y: outVec.y - radius))
        points.append(CGPoint(x: outVec.x - radius, y: outVec.y))
        points.append(CGPoint(x: outVec.x + radius, y: outVec.y))
        
        drawRuleName("\(name!)@Counting", on: CGRect(withCGPoints: points))
    }
    
    func drawFlowPathCounting(withName name: String!, direction: String!, points: [Any]!) {
        let radius = 19.0 * Double(sizeScale)
        let spacing = 9.0 * Double(sizeScale)
        
        let a = Vector2D(x: Double((points[points.count / 2 + 1] as! CGPoint).x), y: Double((points[points.count / 2 + 1] as! CGPoint).y))
        let b = Vector2D(x: Double((points[points.count / 2 + 2] as! CGPoint).x), y: Double((points[points.count / 2 + 2] as! CGPoint).y))
        let leftVec = a.minus(b).normalized()
        let rightVec = leftVec.times(-1.0)
        let inVec = a.translate(leftVec.times(radius + spacing))
        let outVec = b.translate(rightVec.times(radius + spacing))
        
        switch direction {
        case "Out":
            drawDirection(withCentroidPoint: CGPoint(x: outVec.x, y: outVec.y), directionText: "Out")
        case "In":
            drawDirection(withCentroidPoint: CGPoint(x: inVec.x, y: inVec.y), directionText: "In")
        default:
            drawDirection(withCentroidPoint: CGPoint(x: inVec.x, y: inVec.y), directionText: "In")
            drawDirection(withCentroidPoint: CGPoint(x: outVec.x, y: outVec.y), directionText: "Out")
        }
        
        if showVCARules {
            let path = UIBezierPath()
            let tailWidth = 1.0 * sizeScale
            let headWidth = 6.0 * sizeScale
            let headLength = 4.0 * sizeScale
            
            for i in stride(from: 0, to: points.count, by: 2) {
                let startPoint = points[i] as! CGPoint
                let endPoint = points[i + 1] as! CGPoint
                path.append(UIBezierPath.arrow(from: startPoint, to: endPoint, tailWidth: tailWidth, headWidth: headWidth, headLength: headLength))
            }
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = UIColor(hexString: "#20F4D4").cgColor
            shapeLayer.strokeColor = UIColor(hexString: "#20F4D4").cgColor
            shapeLayer.name = "RuleLayerFlowPathCounting+\(name!)"
            shapeLayer.opacity = 1.0
            shapeLayer.lineWidth = 3.0 * sizeScale
            
            layer.addSublayer(shapeLayer)
        }
        
        var points: [CGPoint] = points.map {
            $0 as! CGPoint
        }
        points.append(CGPoint(x: inVec.x, y: inVec.y + radius))
        points.append(CGPoint(x: inVec.x, y: inVec.y - radius))
        points.append(CGPoint(x: inVec.x - radius, y: inVec.y))
        points.append(CGPoint(x: inVec.x + radius, y: inVec.y))
        points.append(CGPoint(x: outVec.x, y: outVec.y + radius))
        points.append(CGPoint(x: outVec.x, y: outVec.y - radius))
        points.append(CGPoint(x: outVec.x - radius, y: outVec.y))
        points.append(CGPoint(x: outVec.x + radius, y: outVec.y))
        
        drawRuleName("\(name!)@FlowPath", on: CGRect(withCGPoints: points))
    }
    
    func clearVCARules() {
        layer.sublayers?.filter {
            ($0.name ?? "").contains("RuleLayer")
        }.forEach {
            $0.removeFromSuperlayer()
        }
    }
}
