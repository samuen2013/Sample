//
//  SignalingMessage.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/10/27.
//

import WebRTC

struct SessionMessage: Codable {
    let sdp: Description
    
    struct Description: Codable {
        let sdp: String
        var type: String?
    }
}

struct IceCandidateMessage: Codable {
    var sdp: IceCandidate
    
    init(from rtcIceCandidate: RTCIceCandidate) {
        self.sdp = IceCandidate(from: rtcIceCandidate)
    }
    
    /// This struct is a swift wrapper over `RTCIceCandidate` for easy encode and decode
    struct IceCandidate: Codable {
        let candidate: String
        let sdpMLineIndex: Int32
        let sdpMid: String?
        
        init(from iceCandidate: RTCIceCandidate) {
            self.sdpMLineIndex = iceCandidate.sdpMLineIndex
            self.sdpMid = iceCandidate.sdpMid
            self.candidate = iceCandidate.sdp
        }
        
        var rtcIceCandidate: RTCIceCandidate {
            return RTCIceCandidate(sdp: self.candidate, sdpMLineIndex: self.sdpMLineIndex, sdpMid: self.sdpMid)
        }
    }
}
