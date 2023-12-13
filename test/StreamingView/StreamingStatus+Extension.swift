//
//  StreamingStatus+Extension.swift
//  iOSCharmander
//
//  Created by DorisWu on 2021/8/31.
//

extension StreamingStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .initial: return "initial"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .disconnected: return "disconnected"
        case .tooManyConnections: return "tooManyConnections"
        case .receiveConnectionInfo: return "receiveConnectionInfo"
        case .unsupportedCodec: return "unsupportedCodec"
        @unknown default: return "unknown \(rawValue)"
        }
    }
}

extension StreamingVideoCodec: CustomStringConvertible {
    public var description: String {
        switch self {
        case .H264: return "H264"
        case .H265: return "H265"
        case .MPEG4: return "MPEG-4"
        case .JPEG: return "JPEG"
        case .unknown: return "Unknown"
        @unknown default: return "unknown \(rawValue)"
        }
    }
}

extension FisheyeDewarpType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .original: return "original"
        case .panoramic: return "panoramic"
        case .regional: return "regional"
        case .fullHD: return "fullHD"
        @unknown default: return "unknown \(rawValue)"
        }
    }
}

extension FisheyeMountType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .wall: return "wall"
        case .ceiling: return "ceiling"
        case .floor: return "floor"
        case .localdewrap: return "localdewrap"
        @unknown default: return "unknown \(rawValue)"
        }
    }
}
