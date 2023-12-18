import UIKit

@objc
public enum EncodeType: Int {
    case h264
    case h265
}

open class VideoPacket: NSObject {
    open private(set) var type: EncodeType
    open private(set) var buffer: UnsafePointer<UInt8>
    open private(set) var bufferSize: Int

    @objc
    public convenience init(_ data: NSData, type: EncodeType) {
        let buffer = data as Data
        self.init(buffer, type: type)
    }
    
    public convenience init(_ data: Data, type: EncodeType) {
        let buffer = [UInt8](data)
        self.init(buffer, type: type)
    }
    
    public convenience init(_ data: [UInt8], type: EncodeType) {
        let uint8Pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        uint8Pointer.initialize(from: data, count:data.count)
        let buffer = UnsafePointer(uint8Pointer)
        self.init(buffer, bufferSize: data.count, type: type)
        buffer.deallocate()
    }
    
    @objc
    public init(_ buffer: UnsafePointer<UInt8>, bufferSize: Int, type: EncodeType) {
        self.buffer = buffer.copy(capacity: bufferSize)
        self.bufferSize = bufferSize
        self.type = type
        super.init()
    }
    
    deinit {
        buffer.deallocate()
    }
}

public extension VideoPacket {
    static func ==(lhs: VideoPacket, rhs: VideoPacket) -> Bool {
        if lhs.bufferSize != rhs.bufferSize {
            return false
        }
        return memcmp(lhs.buffer, rhs.buffer, lhs.bufferSize) == 0
    }

    static func !=(lhs: VideoPacket, rhs: VideoPacket) -> Bool {
        if lhs.bufferSize != rhs.bufferSize {
            return true
        }
        return memcmp(lhs.buffer, rhs.buffer, lhs.bufferSize) != 0
    }
}
