import UIKit

@objc
public enum NalUnitType: Int {
    case other
    case vps
    case sps
    case pps
    case idr
    case pFrame
}

@objc
public protocol NalUnitProtocol: AnyObject {
    
    var type: NalUnitType { get }
    
    var buffer: UnsafePointer<UInt8> { get }
    
    var bufferSize: Int { get }
    
    var outHeadBuffer: UnsafePointer<UInt8> { get }
    
    var lengthHeadBuffer: UnsafePointer<UInt8>? { get }
    
}
