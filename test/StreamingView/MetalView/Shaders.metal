//
//  Shaders.metal
//  iViewer
//
//  Created by sdk on 2021/5/11.
//  Copyright © 2021 Vivotek. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 pos [[position]];
    float2 uv;
};

struct BeautyFistMetalUniforms
{
    float k1, k2, p1, p2, k3, k4, k5, k6, s1, s2, s3, s4;
    float2 fxfy;
    float2 u0v0;
    float3 r036;
    float3 r147;
    float3 r258;
    float2 srcSize;
    float2 dstSize;
    float2 offset;
    float2 rangeX;
};

struct FragmentUniforms {
    struct BeautyFistMetalUniforms beautyFistMetalUniforms;
};

constant half Kb = 0.114;
constant half Kr = 0.299;
constant half3x3 yuvToBGRMatrix = half3x3(1, 1, 1, 0, -Kb/(1-Kb-Kr)*(2-2*Kb), 2-2*Kb, 2-2*Kr, -Kr/(1-Kb-Kr)*(2-2*Kr), 0);
constant half3 colorOffset = half3(0, -128.0/255, -128.0/255);

vertex Vertex vert_func(constant Vertex *vertices [[buffer(0)]],
                        uint vid [[vertex_id]]) {
    return vertices[vid];
}

fragment half4 rgb_func(Vertex vert [[stage_in]],
                        texture2d<half> texture [[texture(0)]],
                        texture2d<half> wTexture [[texture(3)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_zero);
    
    half4 over = wTexture.sample(s, vert.uv);
    return texture.sample(s, vert.uv) * (1 - over.a) + over;
}

fragment half4 yuv_func(Vertex vert [[stage_in]],
                        texture2d<half> yTexture [[texture(0)]],
                        texture2d<half> uTexture [[texture(1)]],
                        texture2d<half> vTexture [[texture(2)]],
                        texture2d<half> wTexture [[texture(3)]]) {
    constexpr sampler s(filter::linear);
    constexpr sampler sz(filter::linear, address::clamp_to_zero);
    
    half4 over = wTexture.sample(s, vert.uv);
    half3 yuv;
    yuv.x = yTexture.sample(sz, vert.uv).r;
    yuv.y = uTexture.sample(s, vert.uv).r;
    yuv.z = vTexture.sample(s, vert.uv).r;
    return half4(yuvToBGRMatrix * (yuv+colorOffset), 1) * (1 - over.a) + over;
}

fragment half4 nv12_func(Vertex vert [[stage_in]],
                         texture2d<half> yTexture [[texture(0)]],
                         texture2d<half> uvTexture [[texture(1)]],
                         texture2d<half> wTexture [[texture(3)]]) {
    constexpr sampler s(filter::linear);
    constexpr sampler sz(filter::linear, address::clamp_to_zero);
    
    half4 over = wTexture.sample(s, vert.uv);
    half3 yuv;
    yuv.x = yTexture.sample(sz, vert.uv).r;
    yuv.yz = uvTexture.sample(s, vert.uv).rg;
    return half4(yuvToBGRMatrix * (yuv+colorOffset), 1) * (1 - over.a) + over;
}

/*
  BeautyFist dewarping fragment shaders for stereo camera side-by-side to single eye
 */
float2 beautyFist_rectify(float2 texCoord,
                          BeautyFistMetalUniforms uniforms) {
    
    float2 dst = texCoord * uniforms.dstSize + uniforms.offset;
    float3 x0 = float3(dst.x, dst.x, dst.x);
    float3 y0 = float3(dst.y, dst.y, dst.y);
    float3 xyz = y0 * uniforms.r147 + uniforms.r258 + x0 * uniforms.r036;
    float x = xyz.x / xyz.z;
    float y = xyz.y / xyz.z;
    float x2 = x * x;
    float y2 = y * y;
    float r2 = x2 + y2;
    float _2xy = 2.0 * x * y;
    float kr = (1.0 + ((uniforms.k3 * r2 + uniforms.k2) * r2 + uniforms.k1) * r2) / (1.0 + ((uniforms.k6 * r2 + uniforms.k5) * r2 + uniforms.k4) * r2);
    float2 scale = float2(x * kr + uniforms.p1 * _2xy + uniforms.p2 * (r2 + 2.0 * x2) + uniforms.s1 * r2 + uniforms.s2 * r2 * r2, y * kr + uniforms.p1 * (r2 + 2.0 * y2) + uniforms.p2 * _2xy + uniforms.s3 * r2 + uniforms.s4 * r2 * r2);
    float2 newXY = (uniforms.fxfy * scale + uniforms.u0v0) / uniforms.srcSize;
    newXY.x = newXY.x * (uniforms.rangeX.y - uniforms.rangeX.x) + uniforms.rangeX.x;
    return newXY;
}

fragment half4 beautyFist_rgb_func(Vertex vert [[stage_in]],
                        texture2d<half> texture [[texture(0)]],
                        texture2d<half> wTexture [[texture(3)]],
                        constant FragmentUniforms &uniforms [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_zero);
    
    float2 coord = beautyFist_rectify(vert.uv, uniforms.beautyFistMetalUniforms);
    
    half4 over = wTexture.sample(s, coord);
    return texture.sample(s, coord) * (1 - over.a) + over;
}

fragment half4 beautyFist_yuv_func(Vertex vert [[stage_in]],
                        texture2d<half> yTexture [[texture(0)]],
                        texture2d<half> uTexture [[texture(1)]],
                        texture2d<half> vTexture [[texture(2)]],
                        texture2d<half> wTexture [[texture(3)]],
                        constant FragmentUniforms &uniforms [[buffer(0)]]) {
    constexpr sampler s(filter::linear);
    constexpr sampler sz(filter::linear, address::clamp_to_zero);
    
    float2 coord = beautyFist_rectify(vert.uv, uniforms.beautyFistMetalUniforms);
    
    half4 over = wTexture.sample(s, coord);
    half3 yuv;
    yuv.x = yTexture.sample(sz, coord).r;
    yuv.y = uTexture.sample(s, coord).r;
    yuv.z = vTexture.sample(s, coord).r;
    return half4(yuvToBGRMatrix * (yuv+colorOffset), 1) * (1 - over.a) + over;
}

fragment half4 beautyFist_nv12_func(Vertex vert [[stage_in]],
                         texture2d<half> yTexture [[texture(0)]],
                         texture2d<half> uvTexture [[texture(1)]],
                         texture2d<half> wTexture [[texture(3)]],
                         constant FragmentUniforms &uniforms [[buffer(0)]]) {
    constexpr sampler s(filter::linear);
    constexpr sampler sz(filter::linear, address::clamp_to_zero);
    
    float2 coord = beautyFist_rectify(vert.uv, uniforms.beautyFistMetalUniforms);
    
    half4 over = wTexture.sample(s, coord);
    half3 yuv;
    yuv.x = yTexture.sample(sz, coord).r;
    yuv.yz = uvTexture.sample(s, coord).rg;
    return half4(yuvToBGRMatrix * (yuv+colorOffset), 1) * (1 - over.a) + over;
}
