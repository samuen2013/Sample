//
//  MetalTextureCache.swift
//  iViewer
//
//  Created by sdk on 2021/5/13.
//  Copyright © 2021 Vivotek. All rights reserved.
//

import CoreVideo

class MetalTextureCache {
    var cache: CVMetalTextureCache?
    var images = [Int : CVMetalTexture]()
    
    init() {
        if let device = MetalRenderer.device {
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        }
    }
    
    func removeAll() {
        images.removeAll()
    }
    
    func createTextureFromImage(_ sourceImage: CVImageBuffer, _ pixelFormat: MTLPixelFormat, _ width: Int, _ height: Int, _ planeIndex: Int) -> MTLTexture? {
        if let textureCache = cache {
            var texture: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, sourceImage, nil, pixelFormat, width, height, planeIndex, &texture)
            if let image = texture {
                images[planeIndex] = image
                return CVMetalTextureGetTexture(image)
            }
        }
        return nil
    }
}
