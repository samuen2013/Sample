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
#import "FrameManager/H265Decoder.h"
#import "FrameManager/H265Decoder_ffmpeg.h"
#import "NSData+Hex.h"
#import "test-Swift.h"

typedef struct {
    DWORD dwAudioStreamType;
    DWORD dwAudioSamplingFreq;
    DWORD dwAudioChannelNum;
    BYTE  byG726Pack;
    DWORD dwBitRate;
} AudioSettings;

@interface FrameManagerWrapper()

@property (assign, nonatomic) FrameManager *frameManager;
@property (strong, nonatomic) H264Decoder *h264VideoDecoder;
@property (assign, nonatomic) H265DecoderFFMpeg *h265VideoDecoder;
//@property (strong, nonatomic) H265Decoder *h265VideoDecoder;
@property (assign, nonatomic) VideoDecoder* videoSWDecoder;

@property (strong, nonatomic) RemoteIOPlayer *audioRenderer;
@property (assign, nonatomic) AudioDecoder* audioDecoder;
@property (assign, nonatomic) AudioSettings audioSettings;

@property (assign, nonatomic) NSThread *videoDecodeThread;
@property (assign, nonatomic) bool releaseVideoRelated;

@property (assign, nonatomic) DWORD videoWidth;
@property (assign, nonatomic) DWORD videoHeight;

@property (assign, nonatomic) DWORD lastestVideoStreamType;
@property (assign, nonatomic) unsigned int latestFrameTime;
@property (assign, nonatomic) FisheyeMountType latestMountType;

@property (assign, nonatomic) long firstDecodeTS;
@property (assign, nonatomic) long firstPacketTS;
@property (assign, nonatomic) long lastDecodeTS;
@property (assign, nonatomic) long lastPacketTS;
@property (assign, nonatomic) float speed;
@property (assign, nonatomic) bool useRecordingTime;
@property (assign, nonatomic) bool supportHardwareDecode;

@property (assign, nonatomic) bool playAudio;
@property (assign, nonatomic) int audioFrameSecond;
@property (assign, nonatomic) int audioFrameMilliSecond;

@end

@implementation FrameManagerWrapper

- (id)init {
    self = [super init];
    if (self) {
        _frameManager = new FrameManager();
        VideoDecoder::Init();
        _videoWidth = 0;
        _videoHeight = 0;
        
        _lastestVideoStreamType = 0;
        _latestFrameTime = 0;
        _latestMountType = FisheyeMountTypeUnknown;
        
        _firstDecodeTS = 0;
        _firstPacketTS = 0;
        _lastDecodeTS = 0;
        _lastPacketTS = 0;
        _speed = 1.0;
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
    [self releaseVideoRelatedResource];
    [self releaseAudioRelatedResource];
    
    if (_frameManager) {
        _frameManager->releaseAll();
        delete _frameManager;
        _frameManager = nil;
    }
    
    [super dealloc];
}

- (void)releaseAll {
    _frameManager->releaseAll();
}

- (void)cleanBuffer {
    _frameManager->releaseVideoRelated();
    _frameManager->releaseAudioRelated();
}

- (void)pause {
    _frameManager->pause();
}

- (void)resume {
    _firstPacketTS = 0;
    _firstDecodeTS = 0;
    _frameManager->resume();
}

- (void)enableAudio {
    _playAudio = true;
}

- (void)disableAudio {
    _playAudio = false;
}

- (void)setSpeed:(float)speed {
    _speed = speed;
    _firstPacketTS = 0;
    _firstDecodeTS = 0;
    _lastPacketTS = 0;
    _lastDecodeTS = 0;
}

- (void)setUseRecordingTime:(bool)useRecordingTime {
    _useRecordingTime = useRecordingTime;
}

- (void)releaseVideoRelatedResource {
    _firstPacketTS = 0;
    _firstDecodeTS = 0;
    _supportHardwareDecode = true;
    
    _frameManager->releaseVideoRelated();
    
    if (_videoSWDecoder) {
        delete _videoSWDecoder;
        _videoSWDecoder = nil;
    }
    
    if (_h264VideoDecoder) {
        _h264VideoDecoder.delegate = nil;
        [_h264VideoDecoder release];
        _h264VideoDecoder = nil;
    }
    
    if (_h265VideoDecoder) {
        delete _h265VideoDecoder;
        _h265VideoDecoder = nil;
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

- (void)decodeVideo {
    TMediaDataPacketInfo* packet = NULL;

    while (!_releaseVideoRelated) {
        if (_firstDecodeTS == 0 && _firstPacketTS == 0) {
            auto ret = _frameManager->getVideoFrame(&packet, 0);
            if (ret != S_OK || packet == NULL)
            {
                usleep(1 * 1000);
                continue;
            }
            
            [self decodePacket:packet];
            continue;
        }
        
        if (![self isNextPacketTime])
        {
            usleep(1 * 1000);
            continue;
        }
        
        auto ret = _frameManager->getVideoFrame(&packet, _firstDecodeTS - _firstPacketTS);
        if (ret != S_OK || packet == NULL)
        {
            usleep(1 * 1000);
            continue;
        }
        
        [self decodePacket:packet];
    }
}

- (bool)isNextPacketTime {
    auto packet = _frameManager->firstVideoPacket();
    
    if (packet == nullptr) return false;
    
    long dts = floorl([[NSDate date] timeIntervalSince1970] * 1000);
    long pts = (long)packet->dwFirstUnitSecond * 1000 + packet->dwFirstUnitMilliSecond;
    long frameInterval = pts - _lastPacketTS;
    bool segmentJump = frameInterval > 100;
    
    // In case timestamp diff over 100ms between last/current packet, decode state reset as initial
    if (segmentJump) {
        _firstPacketTS = 0;
        _firstDecodeTS = 0;
        return false;
    } else {
        return (dts - _lastDecodeTS >= (pts - _lastPacketTS) / _speed);
    }
}

- (void)decodePacket:(TMediaDataPacketInfo *)packet {
    auto dts = floorl([[NSDate date] timeIntervalSince1970] * 1000);
    auto pts = (long)packet->dwFirstUnitSecond * 1000 + packet->dwFirstUnitMilliSecond;
    
    auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
    if (_useRecordingTime) {
        VVTK::SDK::Utility::BitstreamReader reader(packetV3->tIfEx.tRv1.tExt.pbyTLVExt + sizeof(DWORD), packetV3->tIfEx.tRv1.tExt.dwTLVExtLen - sizeof(DWORD));
        while (reader.Available()) {
            DWORD dwTag = 0;
            DWORD dwLength = DataPacket_GetTagLength(reader, dwTag);
            if (dwTag == 0x61) {
                auto second = reader.GetBits<32>();
                if (_latestFrameTime != second) {
                    _latestFrameTime = second;
                    [_delegate didChangeStreamingTimestamp:second];
                }
                break;
            } else {
                reader.SkipBytes(dwLength);
            }
        }
    } else {
        auto second = packetV3->dwUTCTime;
        if (second != _latestFrameTime) {
            _latestFrameTime = second;
            [_delegate didChangeStreamingTimestamp:second];
        }
    }
    
    // if video resize in server
    if (_videoWidth != packetV3->tIfEx.dwWidth || _videoHeight != packetV3->tIfEx.dwHeight) {
        _videoWidth = packetV3->tIfEx.dwWidth;
        _videoHeight = packetV3->tIfEx.dwHeight;
    }

    [self sleepToWaitAudio:packet];
    
    if (_supportHardwareDecode) {
        if ([self hardwareDecode:packet] != S_OK) {
            NSLog(@"HW decode fail, switch to SW decode");
            _supportHardwareDecode = false;
            [self softwareDecode:packet];
        }
    } else {
        [self softwareDecode:packet];
    }
    
    if (_firstDecodeTS == 0) {
        _firstDecodeTS = dts;
    }
    if (_firstPacketTS == 0) {
        _firstPacketTS = pts;
    }
    _lastDecodeTS = dts;
    _lastPacketTS = pts;
    
    FrameManager::removeOnePacket(&packetV3);
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
            _h265VideoDecoder = new H265DecoderFFMpeg();
            if (_h265VideoDecoder->InitDecoder() != 0) {
                delete _h265VideoDecoder;
                _h265VideoDecoder = nil;
                return S_FAIL;
            }
        }
        
        AVFrame *pFrame = av_frame_alloc();
        if (_h265VideoDecoder->Decode(packet, pFrame) == 0) {
            auto buffer = (CVImageBufferRef)pFrame->data[3];
            [_delegate didDecodeWithImageBuffer:buffer];
        } else {
            av_frame_free(&pFrame);
            return S_FAIL;
        }
        av_frame_free(&pFrame);
        return S_OK;
    } else {
        NSLog(@"unsupport codec: %u", _lastestVideoStreamType);
        return S_FAIL;
    }
    
    return S_FAIL;
}

- (SCODE)softwareDecode:(TMediaDataPacketInfo *)packet {
    if (!_videoSWDecoder) {
        _videoSWDecoder = new VideoDecoder(packet->dwStreamType);
    }
    
    AVFrame *pFrame = av_frame_alloc();
    if (_videoSWDecoder->Decode(packet, pFrame)) {
        [_delegate didDecodeWithAVFrame:pFrame
                                  width:_videoSWDecoder->GetCodecContext()->width
                                 height:_videoSWDecoder->GetCodecContext()->height
                            pixelFormat:AVPixelFormat(_videoSWDecoder->GetCodecContext()->pix_fmt)];
    } else {
        av_frame_free(&pFrame);
        return S_FAIL;
    }
    
    av_frame_free(&pFrame);
    return S_OK;
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
        
        _frameManager->inputVideoPacket(packet);
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
            _audioSettings.byG726Pack = audioExtraInfo->byG726Pack;
            _audioSettings.dwBitRate = audioExtraInfo->dwBitRate;
            
            //release audio renderer
            _frameManager->releaseAudioRelated();
        }
        
        if (!_audioDecoder) {
            auto codeConfig = [self getAudioCodeConfig:packet->dwStreamType audioSamplingFreq:packet->dwAudioSamplingFreq];
            _audioDecoder = new AudioDecoder(packet->dwStreamType, codeConfig, audioExtraInfo->byG726Pack, audioExtraInfo->dwBitRate);
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
        
        _frameManager->inputAudioPacket(packet);
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

- (DWORD)getAudioCodeConfig:(DWORD)streamType audioSamplingFreq:(DWORD)audioSamplingFreq {
    if (streamType != mctAAC) return 0;
    
    if (audioSamplingFreq == 48000) return 4496;
    else if (audioSamplingFreq == 44100) return 4624;
    else if (audioSamplingFreq == 32000) return 4752;
    else if (audioSamplingFreq == 16000) return 5136;
    else return 5520;
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
        _audioSettings.byG726Pack == audioExtraInfo->byG726Pack &&
        _audioSettings.dwBitRate == audioExtraInfo->dwBitRate;
}

- (SCODE)didDecodeWithAudioBuffer:(uint8_t *)audioBuffer audioBufSize:(int *)audioBufSize { 
#ifndef __clang_analyzer__
    if (_lastPacketTS == 0) return S_FAIL; // In case video frame not decoded yet
    
    auto nextPacket = _frameManager->firstAudioPacket();
    if (nextPacket == NULL) return S_FAIL;
    
    auto nextPTS = (long)nextPacket->dwFirstUnitSecond * 1000 + nextPacket->dwFirstUnitMilliSecond;
    auto limitStart = _lastPacketTS - 50;
    auto limitEnd = _lastPacketTS + 50;
    if (nextPTS > limitEnd) return S_FAIL;
    
    TMediaDataPacketInfo *packet = nullptr;
    auto scRet = _frameManager->getAudioFrame(&packet);
    if (scRet != S_OK) return S_FAIL;
    
    int result = 0;
    if (limitStart <= nextPTS)
    {
        result = _audioDecoder->Decode(packet, (int16_t *)audioBuffer, audioBufSize);
        if (result != 0) {
            _audioFrameSecond = packet->dwFirstUnitSecond;
            _audioFrameMilliSecond = packet->dwFirstUnitMilliSecond;
        }
    }
    
    auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
    FrameManager::removeOnePacket(&packetV3);
    
    return (_playAudio && result != 0) ? S_OK : S_FAIL;
#endif
}

@end
