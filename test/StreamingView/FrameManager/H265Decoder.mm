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
    [self releaseDecompressionSession];
    [self releaseVideoFormatDescription];
}

- (void)releaseDecompressionSession
{
    if (_session)
    {
        // Flush in-process frames.
        VTDecompressionSessionFinishDelayedFrames(_session);
        // Block until our callback has been called with the last frame.
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
        // Clean up.
        VTDecompressionSessionInvalidate(_session);
        
        CFRelease(_session);
        _session = NULL;
    }
}

- (void)releaseVideoFormatDescription
{
    if (_videoFormatDescr)
    {
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
    
    for (NSString *subString in subStrings) {
        if (subString.length > 2) { // & 0x7E, >> 1
            if ([subString characterAtIndex:0] == '4' && [subString characterAtIndex:1] == '0') { // VPS, 0x20
                vpsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:0] == '4' && [subString characterAtIndex:1] == '2') { // SPS, 0x21
                spsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:0] == '4' && [subString characterAtIndex:1] == '4') { // PPS, 0x22
                ppsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:0] == '2' && [subString characterAtIndex:1] == '6') { // IDR, 0x13
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
                if ([self createDecompressionSession] != noErr) {
                    return S_FAIL;
                }
                if ([self decodeData:frameData range:[dataHex rangeOfString:subString]] != S_OK) {
                    return S_FAIL;
                }
            } else if ([subString characterAtIndex:0] == '0' && [subString characterAtIndex:1] == '2') { // p-frame, 0x01
                if ([self decodeData:frameData range:[dataHex rangeOfString:subString]] != S_OK) {
                    return S_FAIL;
                }
            } else {
                NSLog(@"unhandle substring: %@", subString);
            }
        }
    }
    
    return S_OK;
}

- (OSStatus)initDecoder:(NSData *)vpsData spsData:(NSData *)spsData ppsData:(NSData *)ppsData {
    OSStatus status = noErr;
    
    if (![_vpsData isEqualToData:vpsData] || ![_spsData isEqualToData:spsData] || ![_ppsData isEqualToData:ppsData]) { // Only setup when format has changed
        if (vpsData && spsData && ppsData) {
            self.vpsData = vpsData;
            self.spsData = spsData;
            self.ppsData = ppsData;
            
            // Release previous resource
            [self releaseDecompressionSession];
            [self releaseVideoFormatDescription];
            
            // 1. create  CMFormatDescription
            const uint8_t* const parameterSetPointers[3] = { (const uint8_t*)[vpsData bytes], (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[3] = { [vpsData length], [spsData length], [ppsData length] };
            status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, 3, parameterSetPointers, parameterSetSizes, 4, nil, &_videoFormatDescr);
            NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
        }
    }
    
    return noErr;
}

- (OSStatus)createDecompressionSession {
    OSStatus status = noErr;
    
    if (!_session)
    {
        // 2. create VTDecompressionSession
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = h265VideoDecompressionOutputCallback;
        callback.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
        NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],(id)kCVPixelBufferMetalCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],(id)kCVPixelBufferPixelFormatTypeKey,nil
        ];
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, _videoFormatDescr, NULL, (__bridge CFDictionaryRef)destinationImageBufferAttributes, &callback, &_session);
        NSLog(@"Creating Video Decompression Session: %@.", (status == noErr) ? @"successfully." : @"failed.");
    }
    
    return status;
}

- (SCODE)decodeData:(NSData *)data range:(NSRange)range {
    @autoreleasepool {
        NSString *NALPrefix = @"00000001";
        NSRange rawWithNALPrefixRange = NSMakeRange(range.location - NALPrefix.length, range.length + NALPrefix.length); // Containing NAL Prefix "00000001"
        if (data.length < (rawWithNALPrefixRange.location / 2) + (rawWithNALPrefixRange.length / 2)) {
            return S_FAIL;
        }
        
        NSData *rawData = [data subdataWithRange:NSMakeRange(rawWithNALPrefixRange.location / 2, rawWithNALPrefixRange.length / 2)];
        NSString *dataHex = [rawData hexString];
        NSLog(@"raw data: %@", dataHex);
        
        if ([self decodeWithBytes:(Byte *)rawData.bytes length:(int)rawData.length] != noErr) {
            return S_FAIL;
        }
    }
    
    return S_OK;
}

- (OSStatus)decodeWithBytes:(Byte *)data length:(int)dataLength {
    OSStatus status = noErr;
    
    CMBlockBufferRef blockBuffer = NULL;
    status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, data, dataLength, kCFAllocatorNull, nil, 0, dataLength, 0, &blockBuffer);
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"CMBlockBufferCreateWithMemoryBlock failed: %d", (int)status);
        return status;
    }
    
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {static_cast<size_t>(dataLength)};
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, _videoFormatDescr, 1, 0, nil, 1, sampleSizeArray, &sampleBuffer);
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"CMSampleBufferCreateReady failed: %d", (int)status);
        return status;
    }
    
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags flagOut;
    status = VTDecompressionSessionDecodeFrame(_session, sampleBuffer, flags, nil, &flagOut);
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"VTDecompressionSessionDecodeFrame failed: %d", (int)status);
        return status;
    }
    
    return noErr;
}

@end


//open func decodeVideoUnit(_ unit: NalUnitProtocol) {

//    if let blockBuff = blockBuffer {
//        if let sampleBuff = sampleBuffer, let session = session {
//            
//            var flagOut: VTDecodeInfoFlags = []
//            status = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sampleBuff, flags: flagIn, frameRefcon: nil, infoFlagsOut: &flagOut)
//            if status != noErr {
//                delegate.decodeOutput(error: .decompressionSessionDecodeFrame(status))
//            }
//            
//        }
//        
//    }
//    
//}
