//
//  H265Decoder.m
//  test
//
//  Created by 曹盛淵 on 2023/12/18.
//

#import "H265Decoder.h"
#import "NSData+Hex.h"
#import "test-Swift.h"

@interface H265Decoder ()
{
    CMVideoFormatDescriptionRef _videoFormatDescr;
    VTDecompressionSessionRef _session;
}

@property (strong, nonatomic) NSData *vpsData;
@property (strong, nonatomic) NSData *spsData;
@property (strong, nonatomic) NSData *ppsData;

@end

@implementation H265Decoder

void h265VideoDecompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
                                      void * CM_NULLABLE sourceFrameRefCon,
                                      OSStatus status,
                                      VTDecodeInfoFlags infoFlags,
                                      CM_NULLABLE CVImageBufferRef imageBuffer,
                                      CMTime presentationTimeStamp,
                                      CMTime presentationDuration ) {
    if (status != noErr) {
        NSLog(@"Video hard decode callback error status=%d", (int)status);
        return;
    }
    
    H265Decoder *decoder = (__bridge H265Decoder *)(decompressionOutputRefCon);
    [decoder.delegate didDecodeWithImageBuffer:imageBuffer];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _videoFormatDescr = NULL;
        _session = NULL;
        
        self.spsData = nil;
        self.ppsData = nil;
    }
    
    return self;
}

- (void)dealloc
{
    [self deinitDecoder];
}

- (void)deinitDecoder
{
    if (_session) {
        // Flush in-process frames.
        VTDecompressionSessionFinishDelayedFrames(_session);
        // Block until our callback has been called with the last frame.
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
        // Clean up.
        VTDecompressionSessionInvalidate(_session);
        
        CFRelease(_session);
        _session = NULL;
    }
    
    if (_videoFormatDescr) {
        CFRelease(_videoFormatDescr);
        _videoFormatDescr = NULL;
    }
}

- (SCODE)decodeFrame:(NSData *)frameData {
    NSString *dataHex = [frameData hexString];
    NSString *NALPrefix = @"00000001";
    NSArray *subStrings = [dataHex componentsSeparatedByString:NALPrefix];
    
    NSRange vpsRange = NSMakeRange(0, 0);
    NSRange spsRange = NSMakeRange(0, 0);
    NSRange ppsRange = NSMakeRange(0, 0);
    
    NSLog(@"subStrings count: %lu", (unsigned long)subStrings.count);
    for (NSString *subString in subStrings) {
        if (subString.length > 2) { // & 0x7E, >> 1
            if ([subString characterAtIndex:0] == '4' && [subString characterAtIndex:1] == '0') { // VPS, 0x20
                NSLog(@"get vps");
                vpsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:0] == '4' && [subString characterAtIndex:1] == '2') { // SPS, 0x21
                NSLog(@"get sps");
                spsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:0] == '4' && [subString characterAtIndex:1] == '4') { // PPS, 0x22
                NSLog(@"get pps");
                ppsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:0] == '2' && [subString characterAtIndex:1] == '6') { // IDR, 0x13
                NSLog(@"get IDR");
                if (vpsRange.location == NSNotFound || spsRange.location == NSNotFound || ppsRange.location == NSNotFound) {
                    return S_FAIL;
                }
                if (frameData.length < (vpsRange.location / 2) + (vpsRange.length / 2) ||
                    frameData.length < (spsRange.location / 2) + (spsRange.length / 2) ||
                    frameData.length < (ppsRange.location / 2) + (ppsRange.length / 2)) {
                    return S_FAIL;
                }
                NSData *vpsData = [frameData subdataWithRange:NSMakeRange(vpsRange.location / 2, vpsRange.length / 2)];
                NSData *spsData = [frameData subdataWithRange:NSMakeRange(spsRange.location / 2, spsRange.length / 2)];
                NSData *ppsData = [frameData subdataWithRange:NSMakeRange(ppsRange.location / 2, ppsRange.length / 2)];
                if ([self initDecoder:vpsData spsData:spsData ppsData:ppsData] != noErr) {
                    return S_FAIL;
                }
                if ([self decodeData:frameData range:[dataHex rangeOfString:subString]] != S_OK) {
                    return S_FAIL;
                }
            } else if ([subString characterAtIndex:0] == '0' && [subString characterAtIndex:1] == '2') { // p-frame, 0x01
                NSLog(@"get p-frame");
                if ([self decodeData:frameData range:[dataHex rangeOfString:subString]] != S_OK) {
                    return S_FAIL;
                }
            } else {
                NSLog(@"unhandle %@", subString);
            }
        }
    }
    
    return S_OK;
}

- (OSStatus)initDecoder:(NSData *)vpsData spsData:(NSData *)spsData ppsData:(NSData *)ppsData {
    if (![_vpsData isEqualToData:vpsData] || ![_spsData isEqualToData:spsData] || ![_ppsData isEqualToData:ppsData]) { // Only setup when format has changed
        [self deinitDecoder];
        
        if (vpsData && spsData && ppsData) {
            self.vpsData = vpsData;
            self.spsData = spsData;
            self.ppsData = ppsData;
            
            // 1. create  CMFormatDescription
            const uint8_t* const parameterSetPointers[3] = { (const uint8_t*)[vpsData bytes], (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[3] = { [vpsData length], [spsData length], [ppsData length] };
            auto status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, 3, parameterSetPointers, parameterSetSizes, 4, nil, &_videoFormatDescr);
            if (status != noErr) {
                NSLog(@"CMVideoFormatDescriptionCreateFromHEVCParameterSets failed: %d", (int)status);
                return status;
            }
            
            if (!_session) {
                VTDecompressionOutputCallbackRecord callback;
                callback.decompressionOutputCallback = h265VideoDecompressionOutputCallback;
                callback.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
                
                NSDictionary *attributes = @{
                    (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                    (id)kCVPixelBufferOpenGLCompatibilityKey: [NSNumber numberWithBool:true]
                };
                status = VTDecompressionSessionCreate(kCFAllocatorDefault, _videoFormatDescr, NULL, (__bridge CFDictionaryRef)attributes, &callback, &_session);
                
                if (status != noErr) {
                    NSLog(@"VTDecompressionSessionCreate failed: %d", (int)status);
                    return status;
                }
            }
        }
        
        NSLog(@"finish initial h265 decoder");
    }
    
    return noErr;
}

- (SCODE)decodeData:(NSData *)data range:(NSRange)range {
    @autoreleasepool {
        NSString *NALPrefix = @"00000001";
        NSRange rawWithNALPrefixRange = NSMakeRange(range.location - NALPrefix.length, range.length + NALPrefix.length); // Containing NAL Prefix "00000001"
        if (data.length < (rawWithNALPrefixRange.location / 2) + (rawWithNALPrefixRange.length / 2)) {
            return S_FAIL;
        }
        
        NSData *rawData = [data subdataWithRange:NSMakeRange(rawWithNALPrefixRange.location / 2, rawWithNALPrefixRange.length / 2)];
        if ([self decodeWithBytes:(Byte *)rawData.bytes length:(int)rawData.length] != noErr) {
            return S_FAIL;
        }
    }
    
    return S_OK;
}

- (OSStatus)decodeWithBytes:(Byte *)data length:(int)dataLength {
    OSStatus status = noErr;

    // 4. get NALUnit payload into a CMBlockBuffer,
    CMBlockBufferRef videoBlock = NULL;
    status = CMBlockBufferCreateWithMemoryBlock(NULL, data, dataLength, kCFAllocatorNull, NULL, 0, dataLength, 0, &videoBlock);
    (void)status;
    
    // 5. making sure to replace the separator code with a 4 byte length code (the length of the NalUnit including the unit code)
    int reomveHeaderSize = dataLength - 4;
    const uint8_t sourceBytes[] = {(uint8_t)(reomveHeaderSize >> 24), (uint8_t)(reomveHeaderSize >> 16), (uint8_t)(reomveHeaderSize >> 8), (uint8_t)reomveHeaderSize};
    status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
    (void)status;
    
    NSString *tmp3 = @"";
    for (int i = 0; i < sizeof(sourceBytes); i++) {
        NSString *str = [NSString stringWithFormat:@" %.2X",sourceBytes[i]];
        tmp3 = [tmp3 stringByAppendingString:str];
    }
    
    // 6. create a CMSampleBuffer.
    CMSampleBufferRef sbRef = NULL;
    const size_t sampleSizeArray[] = {static_cast<size_t>(dataLength)};
    status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, _videoFormatDescr, 1, 0, NULL, 1, sampleSizeArray, &sbRef);
    (void)status;
    //NSLog(@"SampleBufferCreate: %@", (status == noErr) ? @"successfully." : @"failed.");
    
    // 7. use VTDecompressionSessionDecodeFrame
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags flagOut;
    status = VTDecompressionSessionDecodeFrame(_session, sbRef, flags, NULL, &flagOut);
    //NSLog(@"VTDecompressionSessionDecodeFrame: %@", (status == noErr) ? @"successfully." : @"failed.");
    
    CFRelease(sbRef);
    sbRef = NULL;
    
    CFRelease(videoBlock);
    videoBlock = NULL;
    
    return status;
}

@end
