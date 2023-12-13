//
//  RTCDataChannelWrapper.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/11/18.
//

import Foundation
import WebRTC

protocol DataChannelProvider {
    var label: String { get }
    var readyState: RTCDataChannelState { get }
    func close()
    func sendData(_ data: RTCDataBuffer)
}

class RTCDataChannelWrapper: NSObject {
    private var rtcDataChannel: RTCDataChannel
    private var onOpened: () -> Void
    private var onClosed: () -> Void
    private var onReceived: (RTCDataBuffer) -> Void
    
    init(rtcDataChannel: RTCDataChannel,
         onOpened: @escaping () -> Void = {},
         onClosed: @escaping () -> Void = {},
         onReceived: @escaping (RTCDataBuffer) -> Void)
    {
        self.rtcDataChannel = rtcDataChannel
        self.onOpened = onOpened
        self.onClosed = onClosed
        self.onReceived = onReceived
        
        super.init()
        
        self.rtcDataChannel.delegate = self
    }
    
    deinit {
        rtcDataChannel.delegate = nil
    }
}

extension RTCDataChannelWrapper: DataChannelProvider {
    var label: String { rtcDataChannel.label }
    var readyState: RTCDataChannelState { rtcDataChannel.readyState }
    
    func close() {
        rtcDataChannel.close()
        onClosed()
    }
    
    func sendData(_ data: RTCDataBuffer) {
        print("send data: \(data.data.asString)")
        rtcDataChannel.sendData(data)
    }
}

extension RTCDataChannelWrapper: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        if dataChannel.readyState == .open {
            onOpened()
        } else if dataChannel.readyState == .closed {
            onClosed()
        }
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        onReceived(buffer)
    }
}
