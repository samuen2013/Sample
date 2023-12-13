//
//  StreamingViewAction.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/10/25.
//

import CoreGraphics

enum StreamingViewAction {
    case stop
    case startLive(ip: String, port: Int, streamIndex: Int, channelIndex: Int)
    case startNVRLive(ip: String, port: Int, streamIndex: Int, channelIndex: Int)
    case startCameraPlayback(ip: String, port: Int, startDate: Date, isFusion: Bool)
    case startNVRPlayback(ip: String, port: Int, startDate: Date, streamIndex: Int, channelIndex: Int)
//    case startCloudPlayback(MediaFile)
    case seek(to: Date)
    case resume
    case pause
    case snapshot(completion: (Result<UIImage, CharmanderError>) -> Void)
    case enableAudio
    case disableAudio
    case setFisheyeDewarp(_ type: FisheyeDewarpType)
    case setFisheyePanLocation(_ offset: CGSize)
    case setFisheyeZoomScale(_ delta: CGFloat)
    case changeSpeed(_ speed: Float)
}

extension StreamingViewAction: Equatable { // for unit test
    static func == (lhs: StreamingViewAction, rhs: StreamingViewAction) -> Bool {
        switch (lhs, rhs) {
        case (.startLive(let lhsIP, let lhsPort, let lhsStreamIndex, let lhsChannelIndex), .startLive(let rhsIP, let rhsPort, let rhsStreamIndex, let rhsChannelIndex)):
            return lhsIP == rhsIP && lhsPort == rhsPort && lhsStreamIndex == rhsStreamIndex && lhsChannelIndex == rhsChannelIndex
        case (.startNVRLive(let lhsIP, let lhsPort, let lhsStreamIndex, let lhsChannelIndex), .startNVRLive(let rhsIP, let rhsPort, let rhsStreamIndex, let rhsChannelIndex)):
            return lhsIP == rhsIP && lhsPort == rhsPort && lhsStreamIndex == rhsStreamIndex && lhsChannelIndex == rhsChannelIndex
        case (.startCameraPlayback(let lhsIP, let lhsPort, let lhsStartDate, let lhsIsFusion), .startCameraPlayback(let rhsIP, let rhsPort, let rhsStartDate, let rhsIsFusion)):
            return lhsIP == rhsIP && lhsPort == rhsPort && lhsStartDate == rhsStartDate && lhsIsFusion == rhsIsFusion
        case (.startNVRPlayback(let lhsIP, let lhsPort, let lhsStartDate, let lhsStreamIndex, let lhsChannelIndex), .startNVRPlayback(let rhsIP, let rhsPort, let rhsStartDate, let rhsStreamIndex, let rhsChannelIndex)):
            return lhsIP == rhsIP && lhsPort == rhsPort && lhsStartDate == rhsStartDate && lhsStreamIndex == rhsStreamIndex && lhsChannelIndex == rhsChannelIndex
//        case (.startCloudPlayback(let lhsMediaFile), .startCloudPlayback(let rhsMediaFile)):
//            return lhsMediaFile == rhsMediaFile
        case (.seek(let lhsDate), .seek(let rhsDate)):
            return lhsDate == rhsDate
        case (.stop, .stop),
            (.resume, .resume),
            (.pause, .pause),
            (.snapshot, .snapshot),
            (.enableAudio, .enableAudio),
            (.disableAudio, .disableAudio),
            (.setFisheyeDewarp, .setFisheyeDewarp),
            (.setFisheyePanLocation, .setFisheyePanLocation),
            (.setFisheyeZoomScale, .setFisheyeZoomScale),
            (.changeSpeed, .changeSpeed):
            return true
        default:
            return false
        }
    }
}
