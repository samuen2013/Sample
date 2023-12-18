//
//  HWDecoder.m
//  testFrameExtractor
//
//  Created by htaiwan on 6/19/15.
//  Copyright (c) 2015 appteam. All rights reserved.
//

#import "H264Decoder.h"
#import "NSData+Hex.h"
#import "test-Swift.h"

@interface H264Decoder ()
{
    CMVideoFormatDescriptionRef _videoFormatDescr;
    VTDecompressionSessionRef _session;
}

@property (strong, nonatomic) NSData *spsData;
@property (strong, nonatomic) NSData *ppsData;

@end

@implementation H264Decoder

void h264VideoDecompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
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

    H264Decoder *decoder = (__bridge H264Decoder *)(decompressionOutputRefCon);
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
    
    NSRange spsRange = NSMakeRange(0, 0);
    NSRange ppsRange = NSMakeRange(0, 0);
    
    for (NSString *subString in subStrings) {
        if (subString.length > 1) {
            if ([subString characterAtIndex:1] == '7') { // SPS
                spsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:1] == '8') { // PPS
                ppsRange = [dataHex rangeOfString:subString];
            } else if ([subString characterAtIndex:1] == '5') { // IDR
                if (spsRange.location == NSNotFound || ppsRange.location == NSNotFound) {
                    return S_FAIL;
                }
                if (frameData.length < (spsRange.location / 2) + (spsRange.length / 2) ||
                    frameData.length < (ppsRange.location / 2) + (ppsRange.length / 2)) {
                    return S_FAIL;
                }
                NSData *spsData = [frameData subdataWithRange:NSMakeRange(spsRange.location / 2, spsRange.length / 2)];
                NSData *ppsData = [frameData subdataWithRange:NSMakeRange(ppsRange.location / 2, ppsRange.length / 2)];
                if ([self initDecoder:spsData ppsData:ppsData] != noErr)
                {
                    return S_FAIL;
                }
                if ([self createDecompressionSession] != noErr)
                {
                    return S_FAIL;
                }
                if ([self decodeData:frameData] != S_OK) {
                    return S_FAIL;
                }
            } else {
                if ([self decodeData:frameData] != S_OK) {
                    return S_FAIL;
                }
            }
        }
    }
    
    return S_OK;
}

- (SCODE)decodeData:(NSData *)data {
    @autoreleasepool {
        NSString *dataHex = [data hexString];
        NSString *NALPrefix = @"00000001";
        NSArray *subStrings = [dataHex componentsSeparatedByString:NALPrefix];
        
        NSRange rawRange = [dataHex rangeOfString:[subStrings lastObject]]; // Not containing NAL Prefix "00000001"
        if (rawRange.location == NSNotFound) {
            return S_FAIL;
        }
        
        NSRange rawWithNALPrefixRange = NSMakeRange(rawRange.location - NALPrefix.length, rawRange.length + NALPrefix.length); // Containing NAL Prefix "00000001"
        
        if (data.length < (rawWithNALPrefixRange.location / 2) + (rawWithNALPrefixRange.length / 2)) {
            return S_FAIL;
        }
        
        NSData *rawData = [data subdataWithRange:NSMakeRange(rawWithNALPrefixRange.location / 2, rawWithNALPrefixRange.length / 2)];
        
        if ([self decodeWithBytes:(Byte *)rawData.bytes length:(int)rawData.length] != noErr)
        {
            return S_FAIL;
        }
    }
    
    return S_OK;
}

- (OSStatus)initDecoder:(NSData *)spsData ppsData:(NSData *)ppsData
{
    OSStatus status = noErr;
    
    if (![_spsData isEqualToData:spsData] || ![_ppsData isEqualToData:ppsData]) // Only setup when format has changed
    {
        if (spsData && ppsData)
        {
            self.spsData = spsData;
            self.ppsData = ppsData;
            
            // Release previous resource
            [self releaseDecompressionSession];
            [self releaseVideoFormatDescription];
            
            // 1. create  CMFormatDescription
            const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)[spsData bytes], (const uint8_t*)[ppsData bytes] };
            const size_t parameterSetSizes[2] = { [spsData length], [ppsData length] };
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &_videoFormatDescr);
            NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
        }
    }
    
    return status;
}

- (OSStatus)createDecompressionSession
{
    OSStatus status = noErr;
    
    if (!_session)
    {
        // 2. create VTDecompressionSession
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = h264VideoDecompressionOutputCallback;
        callback.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
        NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],(id)kCVPixelBufferMetalCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],(id)kCVPixelBufferPixelFormatTypeKey,nil];
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, _videoFormatDescr, NULL, (__bridge CFDictionaryRef)destinationImageBufferAttributes, &callback, &_session);
        NSLog(@"Creating Video Decompression Session: %@.", (status == noErr) ? @"successfully." : @"failed.");
    }
    
    return status;
}

- (OSStatus)decodeWithBytes:(Byte *)data length:(int)dataLength {
    OSStatus status = noErr;
    
    int startCodeIndex = 0;
    for (int i = 0; i < 5; i++)
    {
        if (data[i] == 0x01)
        {
            startCodeIndex = i;
            break;
        }
    }
    
    int nalu_type = ((uint8_t)data[startCodeIndex + 1] & 0x1F);
    //NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[nalu_type]);
    
    if (nalu_type == 1 || nalu_type == 5)
    {
        // 4. get NALUnit payload into a CMBlockBuffer,
        CMBlockBufferRef videoBlock = NULL;
        status = CMBlockBufferCreateWithMemoryBlock(NULL, data, dataLength, kCFAllocatorNull, NULL, 0, dataLength, 0, &videoBlock);
        (void)status;
        //NSLog(@"BlockBufferCreation: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        // 5.  making sure to replace the separator code with a 4 byte length code (the length of the NalUnit including the unit code)
        int reomveHeaderSize = dataLength - 4;
        const uint8_t sourceBytes[] = {(uint8_t)(reomveHeaderSize >> 24), (uint8_t)(reomveHeaderSize >> 16), (uint8_t)(reomveHeaderSize >> 8), (uint8_t)reomveHeaderSize};
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
        (void)status;
        //NSLog(@"BlockBufferReplace: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");
        
        NSString *tmp3 = @"";
        for (int i = 0; i < sizeof(sourceBytes); i++)
        {
            NSString *str = [NSString stringWithFormat:@" %.2X",sourceBytes[i]];
            tmp3 = [tmp3 stringByAppendingString:str];
        }
        
        //NSLog(@"size = %i , 16Byte = %@",reomveHeaderSize,tmp3);
        
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
    }
    
    return status;
}

@end
