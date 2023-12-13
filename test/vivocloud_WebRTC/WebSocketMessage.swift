//
//  WebSocketMessage.swift
//  test
//
//  Created by 曹盛淵 on 2023/11/22.
//

import WebRTC
enum WebSocketMessage: Decodable {
    case login(WebRTCLoginResponse)
    case answer(RTCSessionDescription)
    case iceCandidate(RTCIceCandidate)
    case snapshot(WebRTCSnapshotResponse)
    case error(Error)
    case ignore
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PredictKey.self)
        let singleValueContainer = try decoder.singleValueContainer()
        if let response = try? container.decode(String.self, forKey: .response) {
            switch response {
            case "success":
                if let request = try? container.decode(String.self, forKey: .request) {
                    if request == "webrtc login" {
                        self = .login(try singleValueContainer.decode(WebRTCLoginResponse.self))
                    } else {
                        self = .ignore
                    }
                } else {
                    self = .error(StreamingError.unknownRequest)
                }
            case "device offline":
                self = .error(StreamingError.deviceOffLine)
            case "permission denied":
                self = .error(StreamingError.permissionDenied)
            default:
                print("unknown response: \(response)")
                self = .error(StreamingError.unknownError)
            }
        } else if let request = try? container.decode(String.self, forKey: .request) {
            switch request {
            case "webrtc message":
                let type = try container.decode(WebRTCMessageType.self, forKey: .type)
                switch type {
                case .answer:
                    let message = try singleValueContainer.decode(SessionMessage.self)
                    self = .answer(RTCSessionDescription(type: .answer, sdp: message.sdp.sdp))
                case .ice:
                    let message = try singleValueContainer.decode(IceCandidateMessage.self)
                    self = .iceCandidate(message.sdp.rtcIceCandidate)
                }
            case "webrtc snapshot":
                self = .snapshot(try singleValueContainer.decode(WebRTCSnapshotResponse.self))
            default:
                print("unknown request: \(request)")
                self = .error(StreamingError.unknownRequest)
            }
        } else {
            self = .error(StreamingError.unknownError)
        }
    }
    
    enum PredictKey: String, CodingKey {
        case response
        case request
        case type
    }
    
    enum WebRTCMessageType: String, Decodable {
        case answer
        case ice
    }
}

struct WebRTCLoginRequest: Codable {
    var request: String = "webrtc login"
    var agent_ver: String = "iOS VIVOCloud"
    var webrtc_ver: String = "v3"
    let auth_token: String
    let auth_deviceid: String
}

struct WebRTCOfferRequest: Codable {
    var request: String = "webrtc message"
    var agent_ver: String = "iOS VIVOCloud"
    var webrtc_ver: String = "v3"
    var type: String = "offer"
    let sdp: SessionMessage.Description
    let caller_id: String
    let ice_config: IceConfig
    let auth_token: String
    let device_id: String
}

struct WebRTCIceCandidateRequest: Codable {
    var request: String = "webrtc message"
    var agent_ver: String = "iOS VIVOCloud"
    var webrtc_ver: String = "v3"
    var type: String = "ice"
    let sdp: IceCandidateMessage.IceCandidate
    let caller_id: String
    let device_id: String
}

struct WebRTCLoginResponse: Codable {
    let caller_id: String
    let ice_config: IceConfig
}

struct IceConfig: Codable {
    let iceServers: [IceServer]
    
    struct IceServer: Codable {
        let urls: String
        let username: String?
        let credential: String?
    }
}

struct WebRTCSnapshotResponse: Codable {
    let device_id: String
    let snapshot: String
}

enum StreamingError: Error {
    case connectServerFailed
    case iceConnectionStateFailed
    case addCandidateFailed
    case createDataChannelFailed
    
    case deviceOffLine
    case permissionDenied
    case unknownRequest
    case unknownError
    case setLocalDescriptionFailed
    case setRemoteDescriptionFailed
}
