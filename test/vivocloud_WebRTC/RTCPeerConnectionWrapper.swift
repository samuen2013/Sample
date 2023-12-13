//
//  RTCPeerConnectionWrapper.swift
//  iOSCharmander
//
//  Created by DorisWu on 2021/11/17.
//

import WebRTC

class RTCPeerConnectionWrapper: NSObject {
    private let peerConnection: RTCPeerConnection
    private let onStatusChanged: (RTCPeerConnectionState) -> Void
    private let onIceCandidateGenerated: (RTCIceCandidate) -> Void
    
    private static let factory = RTCPeerConnectionFactory()
    
    private var liveChannel: RTCDataChannelWrapper?
    
    init(config: Config,
         onStatusChanged: @escaping (RTCPeerConnectionState) -> Void,
         onIceCandidateGenerated: @escaping (RTCIceCandidate) -> Void)
    {
        peerConnection = RTCPeerConnectionWrapper.createPeerConnection(by: config)
        self.onStatusChanged = onStatusChanged
        self.onIceCandidateGenerated = onIceCandidateGenerated
        
        super.init()
        
        peerConnection.delegate = self
//        peerConnection.dataChannel(forLabel: "DefaultDataChannel", configuration: RTCDataChannelConfiguration())
        
        createDefaultDataChannel()
    }
    
    private static func createPeerConnection(by config: Config) -> RTCPeerConnection {
        let rtcConfig = RTCConfiguration()
        rtcConfig.iceServers = [RTCIceServer(urlStrings: config.urls, username: config.username, credential: config.credential)]
        rtcConfig.bundlePolicy = RTCBundlePolicy.balanced
        rtcConfig.iceTransportPolicy = config.transportPolicy
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peerConnection = RTCPeerConnectionWrapper.factory.peerConnection(with: rtcConfig, constraints: constraints, delegate: nil) else {
            fatalError("Could not create new RTCPeerConnection")
        }
        return peerConnection
    }
    
    private func createDefaultDataChannel() {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true
        config.channelId = 0
        peerConnection.dataChannel(forLabel: "data", configuration: config)
        config.channelId = 1
        if let channel = peerConnection.dataChannel(forLabel: "liveview-0", configuration: config) {
            liveChannel = RTCDataChannelWrapper(rtcDataChannel: channel, onOpened: {
                print("liveChannel is open")
            }, onReceived: { buffer in
                print("liveChannel receive \(buffer.data.asString)")
            })
        }
        config.channelId = 2
        peerConnection.dataChannel(forLabel: "liveview-1", configuration: config)
        config.channelId = 3
        peerConnection.dataChannel(forLabel: "liveview-2", configuration: config)
        config.channelId = 4
        peerConnection.dataChannel(forLabel: "liveview-3", configuration: config)
        config.channelId = 5
        peerConnection.dataChannel(forLabel: "volalarm", configuration: config)
        config.channelId = 6
        peerConnection.dataChannel(forLabel: "talk", configuration: config)
    }
    
    struct Config {
        let urls: [String]
        let username: String?
        let credential: String?
        var transportPolicy: RTCIceTransportPolicy = .all
    }
    
    func startLive() {
        let aaa = """
DESCRIBE rtsp://localhost/live_stream=0_channel=0 RTSP/1.0
CSeq: 1
Accept: application/sdp
User-Agent: RTPExPlayer
Bandwidth: 512000
Accept-Language: en-GB
""".data(using: .utf8)!
        self.liveChannel?.sendData(RTCDataBuffer(data: aaa, isBinary: false))
    }
}

extension RTCPeerConnectionWrapper {
    func offerForConstraints() async throws -> RTCSessionDescription {
        let optionalConstraints = [
            "DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue,
            "internalSctpDataChannels": kRTCMediaConstraintsValueTrue
        ]
        let constrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
        return try await peerConnection.offer(for: constrains)
    }
    func setLocalDescription(_ sdp: RTCSessionDescription) async throws {
        try await peerConnection.setLocalDescription(sdp)
    }
    func setRemoteDescription(_ sdp: RTCSessionDescription) async throws {
        try await peerConnection.setRemoteDescription(sdp)
    }
    func add(_ candidate: RTCIceCandidate) async throws {
        if peerConnection.remoteDescription?.type != .none {
            try await peerConnection.add(candidate)
        } else {
            throw StreamingError.addCandidateFailed
        }
    }
    func close() async {
        peerConnection.close()
        peerConnection.delegate = nil
    }
    
    func createDataChannel(forLabel label: String) async throws -> RTCDataChannel {
        guard let dataChannel = peerConnection.dataChannel(forLabel: label, configuration: RTCDataChannelConfiguration()) else {
            throw StreamingError.createDataChannelFailed
        }
        return dataChannel
    }
}

extension RTCPeerConnectionWrapper: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        onStatusChanged(newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        onIceCandidateGenerated(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("peer connection open data channel: \(dataChannel.label)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) { }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) { }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) { }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) { }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) { }
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) { }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) { }
}
