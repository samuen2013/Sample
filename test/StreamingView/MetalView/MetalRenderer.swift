//
//  MetalRenderer.swift
//  iViewer
//
//  Created by sdk on 2021/5/11.
//  Copyright © 2021 Vivotek. All rights reserved.
//

import MetalKit

struct Vertex {
    var pos: simd_float4
    var uv: simd_float2
}

struct FragmentUniforms {
    var beautyFistUniforms: BeautyFistMetalUniforms
}

class MetalRenderer: NSObject {
    static let device = MTLCreateSystemDefaultDevice()
    static let commandQueue = device?.makeCommandQueue()
    enum RenderPipelineStatesKey {
        case RGB
        case YUV
        case NV12
        case P010
        case BeautyFistRGB
        case BeautyFistYUV
        case BeautyFistNV12
        case BeautyFistP010
    }
    static let renderPipelineStates: [RenderPipelineStatesKey: MTLRenderPipelineState] = {
        var rps = [RenderPipelineStatesKey: MTLRenderPipelineState]()
        if let library = device?.makeDefaultLibrary() {
            rps[.RGB] = library.makeRenderPipelineState("vert_func", "rgb_func", .bgra8Unorm)
            rps[.YUV] = library.makeRenderPipelineState("vert_func", "yuv_func", .bgra8Unorm)
            rps[.NV12] = library.makeRenderPipelineState("vert_func", "nv12_func", .bgra8Unorm)
            rps[.BeautyFistRGB] = library.makeRenderPipelineState("vert_func", "beautyFist_rgb_func", .bgra8Unorm)
            rps[.BeautyFistYUV] = library.makeRenderPipelineState("vert_func", "beautyFist_yuv_func", .bgra8Unorm)
            rps[.BeautyFistNV12] = library.makeRenderPipelineState("vert_func", "beautyFist_nv12_func", .bgra8Unorm)
            #if !targetEnvironment(simulator)
            rps[.P010] = library.makeRenderPipelineState("vert_func", "nv12_func", .bgr10_xr_srgb)
            rps[.BeautyFistP010] = library.makeRenderPipelineState("vert_func", "beautyFist_nv12_func", .bgr10_xr_srgb)
            #endif
        }
        return rps
    }()
    let textureCache = MetalTextureCache()
    var currentRenderPipelineState: MTLRenderPipelineState?
    var textures = [MTLTexture?](repeating: nil, count: 4)
    var buffers: [Int: MetalBuffer]?
    var imageBuffer: CVImageBuffer?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var fragmentBuffer: MTLBuffer?
    var isStereoDewarping: Bool = false

    func setMesh(vertices: [Vertex], indices: [UInt16]) {
        if let device = Self.device {
            vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count)
            indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count)
        }
    }
    
    func setFragmentUniforms(fragmentUniforms: inout FragmentUniforms) {
        if let device = Self.device {
            fragmentBuffer = device.makeBuffer(bytes: &fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride)
        }
    }
}

extension MetalRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        guard updateTextures() == true else { return }
        
        if let drawable = view.currentDrawable,
           let rpd = view.currentRenderPassDescriptor,
           let rps = currentRenderPipelineState,
           let indices = indexBuffer,
           let commandBuffer = Self.commandQueue?.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
            commandEncoder.setRenderPipelineState(rps)
            commandEncoder.setFragmentBuffer(fragmentBuffer, offset: 0, index: 0)
            commandEncoder.setFragmentTextures(textures, range: 0..<textures.count)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.length / MemoryLayout<UInt16>.stride, indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        imageBuffer = nil
    }
    
    func updateTextures() -> Bool {
        //Read me plz
        //imageBuffer is for hardware decode only, imageBuffer set as nil when MetalView clear
        //buffers is for software decode only, buffers set as 'empty' when MetalView clear
        
        if let buffers = buffers, !buffers.isEmpty {
            self.buffers = nil
            textureCache.removeAll()
            for i in 0..<3 {
                textures[i] = buffers[i]?.makeTexture()
            }
        } else if let imageBuffer = imageBuffer {
            textureCache.removeAll()
            
            updateCurrentRenderPipelineState(pixelFormat: CVPixelBufferGetPixelFormatType(imageBuffer))
            
            switch CVPixelBufferGetPixelFormatType(imageBuffer) {
            case kCVPixelFormatType_32BGRA:
                textures[0] = textureCache.createTextureFromImage(imageBuffer, .bgra8Unorm, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer), 0)
                textures[1] = nil
                textures[2] = nil
            case kCVPixelFormatType_420YpCbCr8Planar, kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                textures[0] = textureCache.createTextureFromImage(imageBuffer, .r8Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 0), CVPixelBufferGetHeightOfPlane(imageBuffer, 0), 0)
                textures[1] = textureCache.createTextureFromImage(imageBuffer, .r8Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 1), CVPixelBufferGetHeightOfPlane(imageBuffer, 1), 1)
                textures[2] = textureCache.createTextureFromImage(imageBuffer, .r8Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 2), CVPixelBufferGetHeightOfPlane(imageBuffer, 2), 2)
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                textures[0] = textureCache.createTextureFromImage(imageBuffer, .r8Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 0), CVPixelBufferGetHeightOfPlane(imageBuffer, 0), 0)
                textures[1] = textureCache.createTextureFromImage(imageBuffer, .rg8Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 1), CVPixelBufferGetHeightOfPlane(imageBuffer, 1), 1)
                textures[2] = nil
            case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
                textures[0] = textureCache.createTextureFromImage(imageBuffer, .r16Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 0), CVPixelBufferGetHeightOfPlane(imageBuffer, 0), 0)
                textures[1] = textureCache.createTextureFromImage(imageBuffer, .rg16Unorm, CVPixelBufferGetWidthOfPlane(imageBuffer, 1), CVPixelBufferGetHeightOfPlane(imageBuffer, 1), 1)
                textures[2] = nil
            default:
                textures[0] = nil
                textures[1] = nil
                textures[2] = nil
            }
        } else {
            return false
        }
        
        if textures[3] == nil {
            let canvas = MetalBuffer(width: 1, height: 1) { cgContext in }
            textures[3] = canvas?.makeTexture()
        }
        
        return true
    }
    
    func updateCurrentRenderPipelineState(pixelFormat: OSType) {
        if isStereoDewarping {
            switch pixelFormat {
            case kCVPixelFormatType_32BGRA:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistRGB]
            case kCVPixelFormatType_420YpCbCr8Planar, kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistYUV]
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistNV12]
            case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistP010]
            default:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistRGB]
            }
        }
        else {
            switch pixelFormat {
            case kCVPixelFormatType_32BGRA:
                currentRenderPipelineState = Self.renderPipelineStates[.RGB]
            case kCVPixelFormatType_420YpCbCr8Planar, kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                currentRenderPipelineState = Self.renderPipelineStates[.YUV]
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                currentRenderPipelineState = Self.renderPipelineStates[.NV12]
            case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
                currentRenderPipelineState = Self.renderPipelineStates[.P010]
            default:
                currentRenderPipelineState = Self.renderPipelineStates[.RGB]
            }
        }
    }
    
    func updateCurrentRenderPipelineState(pixelFormat: AVPixelFormat) {
        if isStereoDewarping {
            switch pixelFormat {
            case AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUVJ420P, AV_PIX_FMT_YUVJ422P:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistYUV]
            case AV_PIX_FMT_NV12:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistNV12]
            default:
                currentRenderPipelineState = Self.renderPipelineStates[.BeautyFistRGB]
            }
        }
        else {
            switch pixelFormat {
            case AV_PIX_FMT_YUV420P, AV_PIX_FMT_YUVJ420P, AV_PIX_FMT_YUVJ422P:
                currentRenderPipelineState = Self.renderPipelineStates[.YUV]
            case AV_PIX_FMT_NV12:
                currentRenderPipelineState = Self.renderPipelineStates[.NV12]
            default:
                currentRenderPipelineState = Self.renderPipelineStates[.RGB]
            }
        }
    }
}

extension MTLLibrary {
    func makeRenderPipelineState(_ vert: String, _ frag: String, _ pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = makeFunction(name: vert)
        descriptor.fragmentFunction = makeFunction(name: frag)
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
}
