import Foundation
import MetalKit

class LibBeautyFistVersion {
    
    static var version : FourCharCode {
        get {
            return fourCharCodeFrom(string: "2001")
        }
    }
    
    private static func fourCharCodeFrom(string : String) -> FourCharCode {
        assert(string.count == 4, "String length must be 4")
        let a = Array(string.utf16)
        return FourCharCode(a[0]) + FourCharCode(a[1]) << 8 + FourCharCode(a[2]) << 16 + FourCharCode(a[3]) << 24
    }
}

struct BeautyFistMetalUniforms: Equatable
{
    var k1: Float = 0
    var k2: Float = 0
    var p1: Float = 0
    var p2: Float = 0
    var k3: Float = 0
    var k4: Float = 0
    var k5: Float = 0
    var k6: Float = 0
    var s1: Float = 0
    var s2: Float = 0
    var s3: Float = 0
    var s4: Float = 0
    var fxfy = vector_float2(x: 0, y: 0)
    var u0v0 = vector_float2(x: 0, y: 0)
    var r036 = vector_float3(x: 0, y: 0, z: 0)
    var r147 = vector_float3(x: 0, y: 0, z: 0)
    var r258 = vector_float3(x: 0, y: 0, z: 0)
    var srcSize = vector_float2(x: 0, y: 0)
    var dstSize = vector_float2(x: 0, y: 0)
    var offset = vector_float2(x: 0, y: 0)
    var rangeX = vector_float2(x: 0, y: 0)
}

class BeautyFistWrapper: NSObject {
    var pBeautyFist: UnsafeMutablePointer<TBeautyFist>? = nil
   
    func initial() -> SCODE {
        return BeautyFist_Initial(&pBeautyFist, LibBeautyFistVersion.version)
    }
    
    func release() {
        pBeautyFist?.pointee.lpVtbl.pointee.Release(pBeautyFist)
        pBeautyFist = nil
    }
    
    func setCameraParams(_ pCameraParams: UnsafePointer<TBFCameraParams>?) -> SCODE {
        return pBeautyFist?.pointee.lpVtbl.pointee.SetCameraParams(pBeautyFist, pCameraParams) ?? SCODE(-1)
    }
    
    func getRectifiedPictureSize(_ uiInputW: UInt32, _ uiInputH: UInt32, _ puiOutputW: UnsafeMutablePointer<UInt32>?, _ puiOutputH: UnsafeMutablePointer<UInt32>?) -> SCODE {
        return pBeautyFist?.pointee.lpVtbl.pointee.GetRectifiedPictureSize(pBeautyFist, uiInputW, uiInputH, puiOutputW, puiOutputH) ?? SCODE(-1)
    }
    
    func getFragmentParams(_ uiInputW: UInt32, _ uiInputH: UInt32, _ ptParams: UnsafeMutablePointer<TBFFragmentParams>?) -> SCODE {
        return pBeautyFist?.pointee.lpVtbl.pointee.GetFragmentParams(pBeautyFist, uiInputW, uiInputH, ptParams) ?? SCODE(-1)
    }
}

extension BeautyFistWrapper {
    
    func setStereoCameraInfo(info: TStereoCameraInfo) {
        var cameraParams = TBFCameraParams(adM1: info.adM1,
                                           adD1: info.adD1,
                                           adM2: info.adM2,
                                           adD2: info.adD2,
                                           adR: info.adR,
                                           adT: info.adT,
                                           iRoiWidth: info.iRoiWidth,
                                           iRoiHeight: info.iRoiHeight,
                                           iOrgWidth: info.iOrgWidth,
                                           iOrgHeight: info.iOrgHeight,
                                           fZoomInFactor: info.fZoomInFactor,
                                           iZoomInOffsetX: info.iZoomInOffsetX,
                                           iZoomInOffsetY: info.iZoomInOffsetY)
        
        _ = setCameraParams(&cameraParams)
    }
    
    func getMetalUniforms(_ uiInputW: UInt32, _ uiInputH: UInt32) -> BeautyFistMetalUniforms {
        
        var tParams = TBFFragmentParams()
        let scRet: SCODE = getFragmentParams(uiInputW, uiInputH, &tParams)
        
        if scRet != BEAUTYFIST_S_OK {
            return BeautyFistMetalUniforms(k1: 0, k2: 0, p1: 0, p2: 0, k3: 0, k4: 0, k5: 0, k6: 0, s1: 0, s2: 0, s3: 0, s4: 0, fxfy: vector_float2(1, 1), u0v0: vector_float2(0, 0), r036: vector_float3(1, 0, 0), r147: vector_float3(0, 1, 0), r258: vector_float3(0, 0, 1), srcSize: vector_float2(1, 1), dstSize: vector_float2(1, 1), offset: vector_float2(0, 0), rangeX: vector_float2(0, 1))
        }
        
        return BeautyFistMetalUniforms(k1: tParams.fK1, k2: tParams.fK2,p1: tParams.fP1, p2: tParams.fP2,k3: tParams.fK3, k4: tParams.fK4, k5: tParams.fK5, k6: tParams.fK6, s1: tParams.fS1, s2: tParams.fS2, s3: tParams.fS3, s4: tParams.fS4, fxfy: vector_float2(tParams.tFxFy.fX, tParams.tFxFy.fY), u0v0: vector_float2(tParams.tU0V0.fX, tParams.tU0V0.fY), r036: vector_float3(tParams.tR036.fX, tParams.tR036.fY, tParams.tR036.fZ), r147: vector_float3(tParams.tR147.fX, tParams.tR147.fY, tParams.tR147.fZ), r258: vector_float3(tParams.tR258.fX, tParams.tR258.fY, tParams.tR258.fZ), srcSize: vector_float2(tParams.tSrcSize.fX, tParams.tSrcSize.fY), dstSize: vector_float2(tParams.tDstSize.fX, tParams.tDstSize.fY), offset: vector_float2(tParams.tOffset.fX, tParams.tOffset.fY), rangeX: vector_float2(tParams.tRangeX.fX, tParams.tRangeX.fY))
    }
}
