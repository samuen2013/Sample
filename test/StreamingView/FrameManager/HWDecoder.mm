//
//  HWDecoder.m
//  testFrameExtractor
//
//  Created by htaiwan on 6/19/15.
//  Copyright (c) 2015 appteam. All rights reserved.
//

#import "HWDecoder.h"
#import "FrameManager.h"

@interface HWDecoder ()
{
    CMVideoFormatDescriptionRef _videoFormatDescr;
    VTDecompressionSessionRef _session;
}

@property (strong, nonatomic) NSData *spsData;
@property (strong, nonatomic) NSData *ppsData;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;

@end

@implementation HWDecoder

void videoDecompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
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

    HWDecoder *decoder = (__bridge HWDecoder *)(decompressionOutputRefCon);
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
        
        _callbackQueue = dispatch_queue_create("h264 hard decode callback queue", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)dealloc
{
    [self internalRelease];
}

- (void)internalRelease
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

- (OSStatus)createVideoFormatDescriptionForH264WithSPSData:(NSData *)spsData ppsData:(NSData *)ppsData
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
        callback.decompressionOutputCallback = videoDecompressionOutputCallback;
        callback.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
        NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],(id)kCVPixelBufferMetalCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],(id)kCVPixelBufferPixelFormatTypeKey,nil];
        status = VTDecompressionSessionCreate(kCFAllocatorDefault, _videoFormatDescr, NULL, (__bridge CFDictionaryRef)destinationImageBufferAttributes, &callback, &_session);
        NSLog(@"Creating Video Decompression Session: %@.", (status == noErr) ? @"successfully." : @"failed.");
    }
    
    return status;
}

- (OSStatus)decodeWithBytes:(Byte *)data length:(int)dataLength
{
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

#pragma mark - VideoToolBox Decompress Frame CallBack
/*
 This callback gets called everytime the decompresssion session decodes a frame
 */
/*void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration )
{
    if (status != noErr || !imageBuffer)
    {
        // error -8969 codecBadDataErr
        // -12909 The operation couldn’t be completed. (OSStatus error -12909.)
        //NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
        return;
    }
    
    //NSLog(@"Got frame data.\n");
    //NSLog(@"Success decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
 
    if (decoder.delegate != nil)
    {
        [decoder.delegate didDecodeWithImageBuffer:imageBuffer];
    }
}*/

NSString * const naluTypesStrings[] =
{
    @"Unspecified (non-VCL)",
    @"Coded slice of a non-IDR picture (VCL)",
    @"Coded slice data partition A (VCL)",
    @"Coded slice data partition B (VCL)",
    @"Coded slice data partition C (VCL)",
    @"Coded slice of an IDR picture (VCL)",
    @"Supplemental enhancement information (SEI) (non-VCL)",
    @"Sequence parameter set (non-VCL)",
    @"Picture parameter set (non-VCL)",
    @"Access unit delimiter (non-VCL)",
    @"End of sequence (non-VCL)",
    @"End of stream (non-VCL)",
    @"Filler data (non-VCL)",
    @"Sequence parameter set extension (non-VCL)",
    @"Prefix NAL unit (non-VCL)",
    @"Subset sequence parameter set (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    @"Coded slice extension (non-VCL)",
    @"Coded slice extension for depth view components (non-VCL)",
    @"Reserved (non-VCL)",
    @"Reserved (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
    @"Unspecified (non-VCL)",
};

@end
