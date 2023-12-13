//
//  CharmanderLogType.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/10/24.
//

import OSLog

enum CharmanderLogType: String {
    case app = "App"
    case appDelegate = "AppDelegate"
    case signInViewModel = "SignInViewModel"
    case homeViewModel = "HomeViewModel"
    case deviceManager = "DeviceManager"
    case themeManager = "ThemeManager"
    case viewcellControl = "ViewcellControl"
    case timelineViewModel = "TimelineViewModel"
    case streamingViewWrapper = "StreamingViewWrapper"
    case cloudStreamingView = "CloudStreamingView"
    case avPlayerController = "AVPlayerController"
    case deviceSettingViewModel = "DeviceSettingViewModel"
    case orientationControl = "OrientationControl"
    case messageViewModel = "MessageViewModel"
    case sheetControl = "SheetControl"
    case deepSearchViewModel = "DeepSearchViewModel"
    case thumbnailManager = "ThumbnailManager"
    case webRtcConnection = "WebRtcConnection"
    case remoteConfigValues = "RemoteConfigValues"
    case searchLightViewModel = "SearchLightViewModel"
    case forceUpdateUtility = "ForceUpdateUtility"
    
    case backend = "Backend"
    case amplifyWrapper = "AmplifyWrapper"
    case vortexApiManager = "VortexApiManager"
    case vortexAIService = "VortexAIService"
    case awsS3Manager = "AWSS3Manager"
    case mqttManager = "MQTTManager"
    
    case odysseyClient = "OdysseyClient"
    case rtcClient = "RTCClient"
    case rtcPeerConnectionWrapper = "RTCPeerConnectionWrapper"
    case signalClient = "SignalClient"
    case mqttClient = "MQTTClient"
    case socketManager = "SocketManager"

    case httpRequestManager = "HttpRequestManager"
    case apollo = "Apollo"
    
    case apiTestViewModel = "ApiTestViewModel"
    
    var subsystem: SubSystem {
        switch self {
        case .backend, .amplifyWrapper, .vortexApiManager, .awsS3Manager, .mqttManager:
            return .backend
        case .httpRequestManager, .apollo:
            return .thirdParty
        case .odysseyClient, .rtcClient, .rtcPeerConnectionWrapper, .signalClient, .mqttClient, .socketManager:
            return .odyssey
        case .apiTestViewModel:
            return .developeMode
        default:
            return .vortex
        }
    }
    
    enum SubSystem: String {
        case vortex = "VORTEX"
        case backend = "Backend"
        case thirdParty = "ThirdParty"
        case odyssey = "Odyssey"
        case developeMode = "DevelopeMode"
    }
}
