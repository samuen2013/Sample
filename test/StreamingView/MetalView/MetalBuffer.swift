//
//  MetalBuffer.swift
//  iViewer
//
//  Created by sdk on 2021/5/11.
//  Copyright © 2021 Vivotek. All rights reserved.
//

import Metal

class MetalBuffer: NSObject {
    let pixelFormat: MTLPixelFormat
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let buffer: MTLBuffer
    
    init?(bytes pointer: UnsafeRawPointer, bytesPerRow stride: Int, pixelFormat f: MTLPixelFormat, width w: Int, height h: Int) {
        pixelFormat = f
        width = w
        height = h
        guard let device = MetalRenderer.device else {
            return nil
        }
        let mask: Int
        if #available(iOS 11.0, *) {
            mask = device.minimumLinearTextureAlignment(for: pixelFormat) - 1
        } else {
            mask = 256 - 1
        }
        bytesPerRow = (stride + mask) & ~mask
        guard let buffer = device.makeBuffer(length: bytesPerRow * height) else {
            return nil
        }
        let linesize = bytesPerRow
        autoreleasepool {
            let data = buffer.contents()
            if linesize == stride {
                data.copyMemory(from: pointer, byteCount: linesize * h)
            } else {
                for i in 0..<h {
                    data.advanced(by: linesize * i).copyMemory(from: pointer.advanced(by: stride * i), byteCount: stride)
                }
            }
        }
        self.buffer = buffer
    }
    
    init?(width w: Int, height h: Int, actions: (CGContext) -> Void) {
        pixelFormat = .bgra8Unorm
        width = w
        height = h
        guard let device = MetalRenderer.device else {
            return nil
        }
        let mask: Int
        if #available(iOS 11.0, *) {
            mask = device.minimumLinearTextureAlignment(for: pixelFormat) - 1
        } else {
            mask = 256 - 1
        }
        bytesPerRow = (width * 4 + mask) & ~mask
        guard let buffer = device.makeBuffer(length: bytesPerRow * height),
              let cgContext = CGContext(data: buffer.contents(),
                                        width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bytesPerRow: bytesPerRow,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue) else {
            return nil
        }
        cgContext.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height)))
        actions(cgContext)
        self.buffer = buffer
    }
    
    func makeTexture() -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        #if targetEnvironment(simulator)
        guard let texture = MetalRenderer.device?.makeTexture(descriptor: descriptor) else {
            return nil
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: buffer.contents(), bytesPerRow: bytesPerRow)
        return texture
        #else
        return buffer.makeTexture(descriptor: descriptor, offset: 0, bytesPerRow: bytesPerRow)
        #endif
    }
}
