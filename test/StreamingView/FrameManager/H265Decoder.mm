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
    auto packet = [[VideoPacket alloc] init:frameData type:EncodeTypeH265];
    auto units = [NalUnitParser unitParserWithPacket:packet];
    
    NSData *vpsData;
    NSData *spsData;
    NSData *ppsData;
    for (id<NalUnitProtocol> unit in units) {
        switch(unit.type) {
            case NalUnitTypeOther:
                break;
            case NalUnitTypeVps:
                vpsData = [[NSData alloc] initWithBytes:unit.buffer length:unit.bufferSize];
                break;
            case NalUnitTypeSps:
                spsData = [[NSData alloc] initWithBytes:unit.buffer length:unit.bufferSize];
                break;
            case NalUnitTypePps:
                ppsData = [[NSData alloc] initWithBytes:unit.buffer length:unit.bufferSize];
                break;
            case NalUnitTypeIdr:
                if ([self initDecoder:vpsData spsData:spsData ppsData:ppsData] != noErr) {
                    return S_FAIL;
                }
                if ([self createDecompressionSession] != noErr) {
                    return S_FAIL;
                }
                if ([self decodeData:frameData] != S_OK) {
                    return S_FAIL;
                }
                break;
            case NalUnitTypePFrame:
                if ([self decodeData:frameData] != S_OK) {
                    return S_FAIL;
                }
                break;
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
        
        if ([self decodeWithBytes:(Byte *)rawData.bytes length:(int)rawData.length] != noErr) {
            return S_FAIL;
        }
    }
    
    return S_OK;
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
