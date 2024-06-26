//
//  FrameManagerWrapper.m
//  iOSCharmander
//
//  Created by 曹盛淵 on 2023/11/30.
//

#import "FrameManagerWrapper.h"
#import "FrameManager/FrameManager.h"
#import "FrameManager/FrameParser.h"
#import "FrameManager/VideoDecoder.h"
#import "FrameManager/AudioDecoder.h"
#import "FrameManager/H264Decoder.h"
#import "NSData+Hex.h"
#import "test-Swift.h"

typedef struct {
    DWORD dwAudioStreamType;
    DWORD dwAudioSamplingFreq;
    DWORD dwAudioChannelNum;
    DWORD dwBitRate;
} AudioSettings;

@interface FrameManagerWrapper()

@property (assign, nonatomic) FrameManager *frameManager;
@property (strong, nonatomic) H264Decoder* h264VideoDecoder;
@property (assign, nonatomic) VideoDecoder* h265VideoDecoder;
@property (assign, nonatomic) VideoDecoder* videoSWDecoder;

@property (strong, nonatomic) RemoteIOPlayer *audioRenderer;
@property (assign, nonatomic) AudioDecoder* audioDecoder;
@property (assign, nonatomic) AudioSettings audioSettings;

@property (assign, nonatomic) NSThread *videoDecodeThread;
@property (assign, nonatomic) bool releaseVideoRelated;

@property (assign, nonatomic) DWORD videoWidth;
@property (assign, nonatomic) DWORD videoHeight;

@property (assign, nonatomic) DWORD lastestVideoStreamType;
@property (assign, nonatomic) unsigned long latestFrameTime;
@property (assign, nonatomic) FisheyeMountType latestMountType;

@property (assign, nonatomic) bool useRecordingTime;
@property (assign, nonatomic) bool supportHardwareDecode;

@property (assign, nonatomic) bool playAudio;
@property (assign, nonatomic) int audioFrameSecond;
@property (assign, nonatomic) int audioFrameMilliSecond;

@end

@implementation FrameManagerWrapper

//MARK: - public
- (id)init {
    self = [super init];
    if (self) {
        _frameManager = new FrameManager();
        _videoWidth = 0;
        _videoHeight = 0;
        
        _lastestVideoStreamType = 0;
        _latestFrameTime = 0;
        _latestMountType = FisheyeMountTypeUnknown;
        
        _useRecordingTime = false;
        _supportHardwareDecode = true;
        
        _audioSettings = {0};
        _playAudio = false;
        _audioFrameSecond = 0;
        _audioFrameMilliSecond = 0;
    }
    
    return self;
}

- (void)dealloc {
    [self releaseAll];
    
    if (_frameManager) {
        delete _frameManager;
        _frameManager = nil;
    }
    
    [super dealloc];
}

- (void)releaseAll {
    _frameManager->releaseAll();
    [self releaseVideoRelatedResource];
    [self releaseAudioRelatedResource];
}

- (void)cleanBuffer {
    _frameManager->releaseVideoRelated();
    _frameManager->releaseAudioRelated();
}

- (void)pause {
    _frameManager->pause();
}

- (void)resume {
    _frameManager->resume();
}

- (void)enableAudio {
    _playAudio = true;
}

- (void)disableAudio {
    _playAudio = false;
}

- (void)setSpeed:(float)speed {
    _frameManager->setSpeed(speed);
}

- (void)setUseRecordingTime:(bool)useRecordingTime {
    _useRecordingTime = useRecordingTime;
}

- (void)inputPacket:(TMediaDataPacketInfo *)packet {
    if (packet->dwStreamType <= mctDMYV) {
        // video codec changed, release video decoder
        if (_lastestVideoStreamType != packet->dwStreamType) {
            _lastestVideoStreamType = packet->dwStreamType;
            [_delegate didChangeStreamingVideoCodec:[self parseStreamingVideoCodec:packet->dwStreamType]];
            [self releaseVideoRelatedResource];
        }
        
        if (packet->dwStreamType != mctMP4V &&
            packet->dwStreamType != mctH264 &&
            packet->dwStreamType != mctJPEG &&
            packet->dwStreamType != mctHEVC) {
            [_delegate didReceiveUnsupportedVideoCodec];
            return;
        }
        
        [self handleRenderInfoInPacket:packet];
        
        auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
        _videoWidth = packetV3->tIfEx.dwWidth;
        _videoHeight = packetV3->tIfEx.dwHeight;
        
        if (!_videoDecodeThread) {
            _releaseVideoRelated = false;
            _videoDecodeThread = [[NSThread alloc]initWithTarget:self selector:@selector(decodeVideo) object:nil];
            [_videoDecodeThread start];
        }
        _frameManager->inputVideo(std::make_shared<FrameInfo>(packet, _useRecordingTime));
    } else if (packet->dwStreamType <= mctDMYA) {
        //just support aac, amr, g726, g711 and g711a
        if (packet->dwStreamType != mctAAC &&
            packet->dwStreamType != mctSAMR &&
            packet->dwStreamType != mctG711 &&
            packet->dwStreamType != mctG711A &&
            packet->dwStreamType != mctG726) {
            return;
        }
        
        auto audioExtraInfo = (TAudioExtraInfo*)packet->wMotionDetectionAxis;
        
        //change audio code
        //30 -> audio queue size normally keep 1~2 ,set Maximum 30 to check queue size and reset it.
        if (![self isTheSameAudioSettings:packet]) { // In case audio queue size > 30, currently we modify flow for audioDecode
            _audioSettings.dwAudioStreamType = packet->dwStreamType;
            _audioSettings.dwAudioSamplingFreq = packet->dwAudioSamplingFreq;
            _audioSettings.dwAudioChannelNum = packet->byAudioChannelNum;
            _audioSettings.dwBitRate = audioExtraInfo->dwBitRate;
            
            //release audio renderer
            [self releaseAudioRelatedResource];
        }
        
        if (!_audioDecoder) {
            NSLog(@"Initial AudioDecoder, dwStreamType: %u, dwAudioSamplingFreq: %u, dwBitRate: %u", packet->dwStreamType, packet->dwAudioSamplingFreq, audioExtraInfo->dwBitRate);
            _audioDecoder = new AudioDecoder(packet->dwStreamType, packet->dwAudioSamplingFreq, audioExtraInfo->dwBitRate);
        }
        
        if (!_audioRenderer) {
            //Initialise the audio player
            auto player = [[RemoteIOPlayer alloc] init];
            if ([player intialiseAudio:packet->dwStreamType :packet->dwAudioSamplingFreq :packet->byAudioChannelNum] == 0 && [player start] == 0) {
                player.delegate = self;
                _audioRenderer = player;
            } else {
                //Stop & clean if any error occurs during intialise or start
                //Audio player will be initialised again on next packet input
                [player stop];
                [player cleanUp];
                [player release];
                player = nil;
            }
        }
        
        _frameManager->inputAudio(std::make_shared<FrameInfo>(packet, _useRecordingTime));
    } else if (packet->dwStreamType == mctMETJ) {
        auto data = [NSData dataWithBytes:packet->pbyBuff + packet->dwOffset length:packet->dwBitstreamSize];
        auto jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        auto metadata = [[Metadata alloc] initWithJson:jsonString];
        [jsonString release];
        if (metadata.frame) {
            [metadata retain];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate didReceiveMetadata:metadata];
                [metadata release];
            });
        } else {
            [metadata release];
        }
    }
}

//MARK: - private
- (void)releaseVideoRelatedResource {
    _frameManager->releaseVideoRelated();
    _supportHardwareDecode = true;
    
    if (_h264VideoDecoder) {
        _h264VideoDecoder.delegate = nil;
        [_h264VideoDecoder release];
        _h264VideoDecoder = nil;
    }
    
    if (_h265VideoDecoder) {
        delete _h265VideoDecoder;
        _h265VideoDecoder = nil;
    }
    
    if (_videoSWDecoder) {
        delete _videoSWDecoder;
        _videoSWDecoder = nil;
    }
    
    if (_videoDecodeThread) {
        _releaseVideoRelated = true;
        [_videoDecodeThread cancel];
        _videoDecodeThread = nil;
    }
}

- (void)releaseAudioRelatedResource {
    _frameManager->releaseAudioRelated();
    
    if (_audioRenderer) {
        [_audioRenderer stop];
        [_audioRenderer cleanUp];
        [_audioRenderer release];
        _audioRenderer = NULL;
    }
    
    if (_audioDecoder) {
        delete _audioDecoder;
        _audioDecoder = NULL;
    }
}

- (StreamingVideoCodec)parseStreamingVideoCodec:(DWORD)streamType {
    switch (streamType) {
        case mctJPEG: {
            return StreamingVideoCodecJPEG;
        }
        case mctMP4V: {
            return StreamingVideoCodecMPEG4;
        }
        case mctH264: {
            return StreamingVideoCodecH264;
        }
        case mctHEVC: {
            return StreamingVideoCodecH265;
        }
        default: {
            return StreamingVideoCodecUnknown;
        }
    }
}

- (void)handleRenderInfoInPacket:(TMediaDataPacketInfo *)packet {
    auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
    
    auto renderInfo = [self parseRenderInfo:packet];
    
    auto previousWidth = _videoWidth;
    auto previousHeight = _videoHeight;
    auto currentWidth = packetV3->tIfEx.dwWidth;
    auto currentHeight = packetV3->tIfEx.dwHeight;
    
    if (renderInfo.eRenderType == eFisheye) {
        if (previousWidth != currentWidth || previousHeight != currentHeight) {
            auto renderType = renderInfo.tFisheyeInfo.byInstallation == 3 ? eYUV : eFisheye;
            [_delegate didChangeFisheyeRenderType:renderType];
        }
        
        if (renderInfo.tFisheyeInfo.byInstallation != 3) {
            auto dewrapType = currentWidth == currentHeight ? eFeDewarpNone : eFeDewarpFullHD;
            [_delegate didChangeFisheyeDewrapType:dewrapType];
            [_delegate didChangeFisheyeRenderInfo:renderInfo];
            
            auto mountType = (FisheyeMountType)renderInfo.tFisheyeInfo.byInstallation;
            if (mountType != _latestMountType) {
                _latestMountType = mountType;
                [_delegate didChangeFisheyeMountType:mountType];
            }
        }
    } else if (renderInfo.eRenderType == eMultiSensor) {
        [_delegate didChangeFisheyeRenderType:eMultiSensor];
        [_delegate didChangeFisheyeRenderInfo:renderInfo];
    } else if (renderInfo.eRenderType == eStereo) {
        [_delegate didChangeFisheyeRenderType:eStereo];
        [_delegate didChangeFisheyeRenderInfo:renderInfo];
    } else if (packet->tFrameType == MEDIADB_FRAME_INTRA) {
        [_delegate didChangeFisheyeRenderType:eYUV];
    }
}

- (TRenderInfo)parseRenderInfo:(TMediaDataPacketInfo *)packet {
    auto renderInfo = FrameParser::parseRenderInfo(&packet->pbyBuff, packet->dwOffset);
    
    auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
    [self updateFisheyeStreamType:&renderInfo packetV3:packetV3];
    [self updateFisheyeCenterRadius:&renderInfo packetV3:packetV3];
    
    return renderInfo;
}

- (void)updateFisheyeStreamType:(TRenderInfo *)renderInfo packetV3:(TMediaDataPacketInfoV3 *)packetV3 {
    if (renderInfo->eRenderType == eFisheye) {
        if (packetV3->tVUExt.tCapWinInfo.wCapW == 1920 && packetV3->tVUExt.tCapWinInfo.wCapH == 1080) {
            renderInfo->tFisheyeInfo.byStreamType = 1;
        } else if (renderInfo->tFisheyeInfo.byInstallation == 3) { // parsed from user data
            renderInfo->tFisheyeInfo.byStreamType = 2;
        } else {
            renderInfo->tFisheyeInfo.byStreamType = 0;
        }
    }
}

- (void)updateFisheyeCenterRadius:(TRenderInfo *)renderInfo packetV3:(TMediaDataPacketInfoV3 *)packetV3 {
    if (renderInfo->eRenderType == eFisheye && renderInfo->tFisheyeInfo.byInstallation != 3) {
        auto wCropWidth = (renderInfo->tFisheyeInfo.tSensorCropInfo.wCropWidth == 0) ? packetV3->tVUExt.tCapWinInfo.wCapW : renderInfo->tFisheyeInfo.tSensorCropInfo.wCropWidth;
        auto wCropHeight = (renderInfo->tFisheyeInfo.tSensorCropInfo.wCropHeight == 0) ? packetV3->tVUExt.tCapWinInfo.wCapH : renderInfo->tFisheyeInfo.tSensorCropInfo.wCropHeight;
        
        switch (renderInfo->tFisheyeInfo.byId) {
        case 0:
        case 2:
            renderInfo->tFisheyeInfo.wCenterX = renderInfo->tFisheyeInfo.wCenterX * packetV3->tIfEx.dwWidth / packetV3->tVUExt.tCapWinInfo.wCapW;
            if (packetV3->tIfEx.dwWidth == 1920 && packetV3->tIfEx.dwHeight == 1080) {
                renderInfo->tFisheyeInfo.wRadius = packetV3->tVUExt.tCapWinInfo.wCapW / 2;
            } else {
                renderInfo->tFisheyeInfo.wCenterY = renderInfo->tFisheyeInfo.wCenterY * packetV3->tIfEx.dwHeight / packetV3->tVUExt.tCapWinInfo.wCapH;
                renderInfo->tFisheyeInfo.wRadius = renderInfo->tFisheyeInfo.wRadius * packetV3->tIfEx.dwHeight / packetV3->tVUExt.tCapWinInfo.wCapH;
            }
            break;
        case 1:
            renderInfo->tFisheyeInfo.wCenterX = renderInfo->tFisheyeInfo.wCenterX * packetV3->tIfEx.dwWidth / 1920;
            if (packetV3->tIfEx.dwWidth == 1920 && packetV3->tIfEx.dwHeight == 1080) {
                renderInfo->tFisheyeInfo.wCenterY = renderInfo->tFisheyeInfo.wCenterY - 420;
                renderInfo->tFisheyeInfo.wRadius = packetV3->tVUExt.tCapWinInfo.wCapW / 2;
            } else {
                renderInfo->tFisheyeInfo.wCenterY = renderInfo->tFisheyeInfo.wCenterY * packetV3->tIfEx.dwHeight / 1920;
                renderInfo->tFisheyeInfo.wRadius = renderInfo->tFisheyeInfo.wRadius * packetV3->tIfEx.dwHeight / 1920;
            }
            break;
        default:
            renderInfo->tFisheyeInfo.wCenterX = renderInfo->tFisheyeInfo.wCenterX * packetV3->tIfEx.dwWidth / wCropWidth;
            if (packetV3->tIfEx.dwWidth == 1920 && packetV3->tIfEx.dwHeight == 1080) {
                renderInfo->tFisheyeInfo.wRadius = packetV3->tVUExt.tCapWinInfo.wCapW / 2;
            } else {
                renderInfo->tFisheyeInfo.wCenterY = renderInfo->tFisheyeInfo.wCenterY * packetV3->tIfEx.dwHeight / wCropHeight;
                renderInfo->tFisheyeInfo.wRadius = renderInfo->tFisheyeInfo.wRadius * packetV3->tIfEx.dwHeight / wCropHeight;
            }
        }
    }
}

- (void)decodeVideo {
    NSLog(@"start to decode video");
    
    while (!_releaseVideoRelated) {
        auto frame = _frameManager->getVideoFrame();
        if (frame == nullptr) {
            usleep(1 * 1000);
            continue;
        }
        
        if (_videoWidth != frame->width || _videoHeight != frame->height) {
            _videoWidth = frame->width;
            _videoHeight = frame->height;
        }
        
        [self decodePacket:frame->packet];
        [self updateStreamingTimestamp:(frame->timestamp / 1000)];
    }
    
    NSLog(@"end to decode video");
}

- (void)decodePacket:(TMediaDataPacketInfo *)packet {
    [self hardwareDecode:packet];
//    if (_supportHardwareDecode) {
//        if ([self hardwareDecode:packet] != S_OK) {
//            NSLog(@"HW decode fail, switch to SW decode");
//            _supportHardwareDecode = false;
//            [self softwareDecode:packet];
//        }
//    } else {
//        [self softwareDecode:packet];
//    }
}

- (void)updateStreamingTimestamp:(unsigned long)timestamp {
    if (timestamp != _latestFrameTime) {
        _latestFrameTime = timestamp;
        [_delegate didChangeStreamingTimestamp:timestamp];
    }
}

- (void)didDecodeWithImageBuffer:(CVImageBufferRef)imageBuffer {
    [_delegate didDecodeWithImageBuffer:imageBuffer];
}

- (SCODE)hardwareDecode:(TMediaDataPacketInfo *)packet {
    if (_lastestVideoStreamType == mctH264) {
        if (!_h264VideoDecoder) {
            _h264VideoDecoder = [[H264Decoder alloc] init];
            _h264VideoDecoder.delegate = self;
        }
        
        // Extract H.264 slices and decode with HWDecoder
        auto frameData = [NSData dataWithBytesNoCopy:packet->pbyBuff + packet->dwOffset length:packet->dwBitstreamSize freeWhenDone:NO];
        return [_h264VideoDecoder decodeFrame:frameData];
    } else if (_lastestVideoStreamType == mctHEVC) {
        if (!_h265VideoDecoder) {
            _h265VideoDecoder = new VideoDecoder();
            if (_h265VideoDecoder->InitHardwareDecoder(_lastestVideoStreamType) != 0) {
                delete _h265VideoDecoder;
                _h265VideoDecoder = nil;
                return S_FAIL;
            }
        }
        
        AVFrame *pFrame = av_frame_alloc();
        if (_h265VideoDecoder->Decode(packet, pFrame) != 0) {
            av_frame_free(&pFrame);
            return S_FAIL;
        }
        [_delegate didDecodeWithImageBuffer:(CVImageBufferRef)pFrame->data[3]];
        av_frame_free(&pFrame);
        return S_OK;
    } else {
        NSLog(@"unsupport hardware decode codec: %u", _lastestVideoStreamType);
        return S_FAIL;
    }
}

- (SCODE)softwareDecode:(TMediaDataPacketInfo *)packet {
    if (!_videoSWDecoder) {
        _videoSWDecoder = new VideoDecoder();
        if (_videoSWDecoder->InitSoftwareDecoder(_lastestVideoStreamType) != 0) {
            delete _videoSWDecoder;
            _videoSWDecoder = nil;
            return S_FAIL;
        }
    }
    
    AVFrame *pFrame = av_frame_alloc();
    if (_videoSWDecoder->Decode(packet, pFrame) != 0) {
        av_frame_free(&pFrame);
        return S_FAIL;
    }
    [_delegate didDecodeWithAVFrame:pFrame
                              width:_videoSWDecoder->GetCodecContext()->width
                             height:_videoSWDecoder->GetCodecContext()->height
                        pixelFormat:AVPixelFormat(_videoSWDecoder->GetCodecContext()->pix_fmt)];
    av_frame_free(&pFrame);
    return S_OK;
}

- (void)sleepToWaitAudio:(TMediaDataPacketInfo *)packet {
    if (_audioFrameSecond && _audioFrameMilliSecond && packet->dwStreamType != mctJPEG) {
        //For AV Sync, make video render waits for audio
        auto diff = ((int)(packet->dwFirstUnitSecond - _audioFrameSecond)) * 1000 + (int)(packet->dwFirstUnitMilliSecond - _audioFrameMilliSecond);
        if (diff > 0 && diff < 10) {
            NSLog(@"FrameManager::hardwareDecode sleep to wait for audio");
            usleep(diff * 1000);
        }
    }
}

- (bool)isTheSameAudioSettings:(TMediaDataPacketInfo *)packet {
    auto audioExtraInfo = (TAudioExtraInfo*)packet->wMotionDetectionAxis;
    return _audioSettings.dwAudioStreamType == packet->dwStreamType &&
        _audioSettings.dwAudioSamplingFreq == packet->dwAudioSamplingFreq &&
        _audioSettings.dwAudioChannelNum == packet->byAudioChannelNum &&
        _audioSettings.dwBitRate == audioExtraInfo->dwBitRate;
}

- (SCODE)didDecodeWithAudioBuffer:(uint8_t *)audioBuffer audioBufSize:(int *)audioBufSize {
#ifndef __clang_analyzer__
    auto frame = _frameManager->getAudioFrame();
    if (frame == nullptr) return S_FAIL;
    
    auto result = _audioDecoder->Decode(frame->packet, (int16_t *)audioBuffer, audioBufSize);
    return (_playAudio && result == 0) ? S_OK : S_FAIL;
#endif
}

@end
