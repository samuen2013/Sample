//
//  StreamingView.swift
//  iViewer
//
//  Created by davis.cho on 2021/5/27.
//  Copyright © 2021 Vivotek. All rights reserved.
//

import SwiftUI
import Combine

protocol StreamingActionProvider {
    var actionPublisher: Published<StreamingViewAction?>.Publisher { get }
}

struct StreamingViewWrapper: UIViewRepresentable {
    let streamingActionProvider: any StreamingActionProvider
    var onTimestampChanged: ((Date) -> Void)?
    
    @StateObject private var streamingView = StreamingView()
    func makeUIView(context: Context) -> StreamingView {
        streamingView.delegate = context.coordinator
        return streamingView
    }
    
    func updateUIView(_ streamingView: StreamingView, context: Context) {
    }
    
    static func dismantleUIView(_ streamingView: StreamingView, coordinator: Coordinator) {
        streamingView.releaseStreamingObjects()
    }
}

extension StreamingViewWrapper {
    func makeCoordinator() -> Coordinator {
        Coordinator(self, streamingActionProvider: streamingActionProvider)
    }
    
    class Coordinator: NSObject, StreamingViewDelegate {
        private let parent: StreamingViewWrapper
        private let logger = Logger(subsystem: CharmanderLogType.streamingViewWrapper.subsystem.rawValue, category: CharmanderLogType.streamingViewWrapper.rawValue)
        private var cancellable = Set<AnyCancellable>()
        
        init(_ parent: StreamingViewWrapper, streamingActionProvider: any StreamingActionProvider) {
            self.parent = parent
            
            super.init()
            
            streamingActionProvider.actionPublisher
                .sink { [weak self] action in
                    guard let self, let action else { return }
                    
                    logger.trace("\("\(action)")")
                    switch action {
                    case .stop:
                        parent.streamingView.stopStreaming()
                    case .startLive(let ip, let port, let streamIndex, let channelIndex):
                        parent.streamingView.startLiveStreaming(ip: ip, port: port, streamIndex: streamIndex, channelIndex: channelIndex)
                    case .startNVRLive(let ip, let port, let streamIndex, let channelIndex):
                        parent.streamingView.startNVRLiveStreaming(ip: ip, port: port, streamIndex: streamIndex, channelIndex: channelIndex)
                    case .startCameraPlayback(let ip, let port, let startDate, let isFusion):
                        parent.onTimestampChanged?(startDate)
                        parent.streamingView.startPlaybackStreaming(ip: ip, port: port, startTime: startDate.timeIntervalSince1970 * 1000, isFusion: isFusion)
                    case .startNVRPlayback(let ip, let port, let startDate, let streamIndex, let channelIndex):
                        parent.onTimestampChanged?(startDate)
                        parent.streamingView.startPlaybackStreaming(ip: ip, port: port, startTime: startDate.timeIntervalSince1970 * 1000, streamIndex: streamIndex, channelIndex: channelIndex)
                    case .seek(let date):
                        parent.onTimestampChanged?(date)
                        parent.streamingView.seek(to: date.timeIntervalSince1970)
                    case .resume:
                        parent.streamingView.resume()
                    case .pause:
                        parent.streamingView.pause()
                    case .enableAudio:
                        parent.streamingView.enableAudio()
                    case .disableAudio:
                        parent.streamingView.disableAudio()
                    case .snapshot(let completion):
                        if let snapshot = parent.streamingView.snapshot() {
                            completion(.success(snapshot))
                        } else {
                            completion(.failure(.invalidSnapshot))
                        }
                    case .setFisheyeDewarp(let type):
                        parent.streamingView.setFisheyeDewarpType(type)
                    case .setFisheyePanLocation(let offset):
                        parent.streamingView.setFisheyePanLocation(by: offset)
                    case .setFisheyeZoomScale(let deltaX):
                        parent.streamingView.setFisheyeZoomScale(with: deltaX)
                    case .changeSpeed(let speed):
                        parent.streamingView.changeSpeed(speed)
                    }
                }
                .store(in: &cancellable)
        }
        
        func didChangeStreamingStatus(_ status: StreamingStatus) {
            logger.trace("\("streaming status change to \(status)")")
        }
        
        func didChangeStreamingDate(_ date: Date) {
            logger.trace("\("streaming date change to \(date)")")
        }
        
        func didChangeStreamingVideoCodec(_ codec: StreamingVideoCodec) {
            logger.trace("\("streaming video codec change to \(codec)")")
        }
        
        func didChangeFisheyeMountType(_ type: FisheyeMountType) {
            logger.trace("\("fisheye mount type change to \(type)")")
        }
        
        func didChangeFrameSize(_ size: CGSize) {
            logger.trace("\("streaming size change to \(size)")")
        }
    }
}
