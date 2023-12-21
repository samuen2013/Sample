//
//  StreamingView.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/12/4.
//

import Foundation

protocol StreamingViewDelegate: NSObject {
    func didChangeStreamingStatus(_ status: StreamingStatus)
    func didChangeStreamingDate(_ date: Date)
    func didChangeStreamingVideoCodec(_ codec: StreamingVideoCodec)
    func didChangeFisheyeMountType(_ type: FisheyeMountType)
    func didChangeFrameSize(_ size: CGSize)
}

class StreamingView: UIView, ObservableObject {
    weak var delegate: StreamingViewDelegate?
    
    private var dataBrokerWrapper: DataBrokerWrapper!
    private var frameManagerWrapper: FrameManagerWrapper!
    private var metalView: MetalView!
    
    private var isStreamingObjectsReleased = false
    private var status: StreamingStatus = .initial {
        didSet {
            if oldValue != status {
                delegate?.didChangeStreamingStatus(status)
            }
        }
    }
    private var streamingFrameSize: CGSize = .zero {
        didSet {
            if oldValue != streamingFrameSize {
                delegate?.didChangeFrameSize(streamingFrameSize)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        innerInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        innerInit()
    }
    private func innerInit() {
        dataBrokerWrapper = DataBrokerWrapper()
        dataBrokerWrapper.delegate = self
        frameManagerWrapper = FrameManagerWrapper()
        frameManagerWrapper.delegate = self
        metalView = MetalView(frame: bounds)
        metalView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth, .flexibleHeight]
        addSubview(metalView)
        autoresizesSubviews = true
    }
    
    deinit {
        releaseStreamingObjects()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
    }
}

extension StreamingView {
    func startLiveStreaming(ip: String, port: Int, streamIndex: Int, channelIndex: Int) {
        stopStreaming()
        dataBrokerWrapper.startLiveStreaming(ip, port: port, streamIndex: streamIndex, channelIndex: channelIndex)
        
        status = .connecting
    }
    
    func startNVRLiveStreaming(ip: String, port: Int, streamIndex: Int, channelIndex: Int) {
        stopStreaming()
        dataBrokerWrapper.startNVRLiveStreaming(ip, port: port, streamIndex: streamIndex, channelIndex: channelIndex)
        
        status = .connecting
    }
    
    func startPlaybackStreaming(ip: String, port: Int, startTime: TimeInterval, isFusion: Bool) {
        stopStreaming()
        dataBrokerWrapper.startPlaybackStreaming(ip, port: port, startTime: startTime , isFusion: isFusion)
        
        status = .connecting
    }
    
    func startPlaybackStreaming(ip: String, port: Int, startTime: TimeInterval, streamIndex: Int, channelIndex: Int) {
        stopStreaming()
        frameManagerWrapper.setUseRecordingTime(true)
        dataBrokerWrapper.startPlaybackStreaming(ip, port: port, startTime: startTime, streamIndex: streamIndex, channelIndex: channelIndex)
        
        status = .connecting
    }
    
    func stopStreaming() {
        stopStreaming(with: .initial)
    }
    
    func stopStreaming(with status: StreamingStatus) {
        dataBrokerWrapper.stopStreaming()
        frameManagerWrapper.releaseAll()
        metalView.clear()
        
        self.status = status
    }
    
    func seek(to time: TimeInterval) {
        dataBrokerWrapper.seek(to: time)
        frameManagerWrapper.cleanBuffer()
        
        status = .connecting
    }
    
    func pause() {
        if status == .connected {
            dataBrokerWrapper.pause()
            frameManagerWrapper.pause()
        }
    }
    
    func resume() {
        if status == .connected {
            frameManagerWrapper.resume()
            dataBrokerWrapper.resume()
        }
    }
    
    func enableAudio() {
        frameManagerWrapper.enableAudio()
    }
    
    func disableAudio() {
        frameManagerWrapper.disableAudio()
    }
    
    func snapshot() -> UIImage? {
        if UIApplication.shared.applicationState != .background {
            return metalView.snapUIImage()
        } else {
            return nil
        }
    }
    
    func setFisheyeDewarpType(_ type: FisheyeDewarpType) {
        metalView.setFisheyeDewarpType(type.rawValue)
        metalView.drawableSize = bounds.size
        metalView.autoResizeDrawable = true
    }
    
    func setFisheyePanLocation(by offset: CGSize) {
        metalView.setLocationWithPoints(0.0, begY: 0.0, endX: offset.width * 1.3, endY: offset.height * 1.3)
    }
    
    func setFisheyeZoomScale(with deltaX: CGFloat) {
        metalView.setScaleWithDeltaX(deltaX)
    }
    
    func changeSpeed(_ speed: Float) {
        dataBrokerWrapper.changeSpeed(speed)
        frameManagerWrapper.setSpeed(speed)
    }
    
    func releaseStreamingObjects() {
        if !isStreamingObjectsReleased {
            dataBrokerWrapper.delegate = nil
            dataBrokerWrapper.releaseHandling()
            dataBrokerWrapper = nil
            
            frameManagerWrapper.delegate = nil
            frameManagerWrapper.releaseAll()
            frameManagerWrapper = nil
            
            metalView.clear()
            metalView.removeFromSuperview()
            metalView = nil
            
            isStreamingObjectsReleased = true
        }
    }
}

extension StreamingView: DataBrokerWrapperDelegate {
    func statusDidChange(_ sender: DataBrokerWrapper!, status: StreamingStatus) {
        self.status = status
    }
    
    func packetDidRetrieve(_ sender: DataBrokerWrapper!, packet: UnsafeMutablePointer<TMediaDataPacketInfo>!) {
        frameManagerWrapper.inputPacket(packet)
    }
}

extension StreamingView: FrameManagerWrapperDelegate {
    func didChangeStreamingTimestamp(_ timestamp: UInt32) {
        delegate?.didChangeStreamingDate(Date(timeIntervalSince1970: TimeInterval(integerLiteral: Int64(timestamp))))
        status = .connected
    }
    func didChange(_ type: FisheyeMountType) {
        DispatchQueue.main.async { [weak self] in
            self?.metalView.setFisheyeMountType(type)
            self?.delegate?.didChangeFisheyeMountType(type)
        }
    }
    func didChangeFisheyeDewrap(_ type: EFisheyeDewarpType) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let oldType = metalView.getFisheyeDewarpType()
            if (type == eFeDewarpNone && oldType == eFeDewarpFullHD) || (type == eFeDewarpFullHD && oldType != eFeDewarpFullHD) {
                metalView.setFisheyeDewarpType(Int(type.rawValue))
            }
        }
    }
    func didChangeFisheyeRenderInfo(_ info: TRenderInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.metalView.setRenderInfo(info)
        }
    }
    func didChangeFisheyeRenderType(_ type: ERenderType) {
        DispatchQueue.main.async { [weak self] in
            self?.metalView.setRenderType(type)
        }
    }
    func didChange(_ streamingVideoCodec: StreamingVideoCodec) {
        delegate?.didChangeStreamingVideoCodec(streamingVideoCodec)
    }
    func didReceiveUnsupportedVideoCodec() {
        DispatchQueue.main.async { [weak self] in
            self?.stopStreaming(with: .unsupportedCodec)
        }
    }
    func didReceive(_ metadata: Metadata!) {
        DispatchQueue.main.async { [weak self] in
            self?.metalView.didReceive(metadata)
        }
    }
    func didDecode(with imageBuffer: CVImageBuffer!) {
        metalView.render(with: imageBuffer)
        
        streamingFrameSize = CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
    }
    func didDecode(with avFrame: UnsafeMutablePointer<AVFrame>!, width: CGFloat, height: CGFloat, pixelFormat: AVPixelFormat) {
        metalView.render(with: avFrame, width: uint(width), height: uint(height), pixelFormat: pixelFormat)
        
        streamingFrameSize = CGSize(width: width, height: height)
    }
}
