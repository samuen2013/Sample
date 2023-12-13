import Foundation

public class LibFisheyeVersion {
    
    static var version : FourCharCode {
        get {
            return fourCharCodeFrom(string: "3601")
        }
    }
    
    private static func fourCharCodeFrom(string : String) -> FourCharCode {
        assert(string.count == 4, "String length must be 4")
        let a = Array(string.utf16)
        return FourCharCode(a[0]) + FourCharCode(a[1]) << 8 + FourCharCode(a[2]) << 16 + FourCharCode(a[3]) << 24
    }
}
