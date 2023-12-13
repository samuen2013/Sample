#ifndef _AUDIODECODER_H_
#define _AUDIODECODER_H_

#ifdef __cplusplus
extern "C" {
#endif
#undef AVMediaType
#define AVMediaType FFMpeg_AVMediaType
#include <libavcodec/avcodec.h>
#undef AVMediaType
#define AVMediaType Cocoa_AVMediaType
#include <AVFoundation/AVFoundation.h>
#undef AVMediaType
#ifdef __cplusplus
}
#endif

#include "VideoDecoder.h"
#include "G726Decoder.h"

extern boost::mutex g_CodecInitMutex;

#define MAX_AUDIO_FRAME_SIZE 192000


class AudioDecoder
{
public:

    static void Init()
    {
        //avcodec_init();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        avcodec_register_all();
#pragma clang diagnostic pop
    }

    AudioDecoder(DWORD dwStreamType, DWORD pbyExtra, BYTE byG726Pack, int nBitrate):
    m_pCodec(NULL),
    m_pCodecCtxt(NULL),
    m_dwStreamType(dwStreamType),
    m_pDecoded_frame(NULL),
    m_pG726Decoder(NULL),
    m_byG726Pack(byG726Pack),
    m_nBitrate(nBitrate)
    {
        boost::mutex::scoped_lock lock(g_CodecInitMutex);
        
        if (m_dwStreamType != mctG726)
        {
            uint8_t extradata[2] = {0};
            if (m_dwStreamType == mctAAC)
            {
                m_pCodec = avcodec_find_decoder(AV_CODEC_ID_AAC);
                m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            
                extradata[0] = pbyExtra >> 8;
                extradata[1] = pbyExtra & 0x00ff;
                m_pCodecCtxt->extradata = extradata;
                m_pCodecCtxt->extradata_size = 2;
            }
            else if (m_dwStreamType == mctSAMR)
            {
                m_pCodec = avcodec_find_decoder(AV_CODEC_ID_AMR_NB);
                m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            }
            else if (m_dwStreamType == mctG711)
            {
                m_pCodec = avcodec_find_decoder(AV_CODEC_ID_PCM_MULAW);
                m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
                m_pCodecCtxt->channels = 1;
                m_pCodecCtxt->sample_rate = 8000;
            }
            else if (m_dwStreamType == mctG711A)
            {
                m_pCodec = avcodec_find_decoder(AV_CODEC_ID_PCM_ALAW);
                m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
                m_pCodecCtxt->channels = 1;
                m_pCodecCtxt->sample_rate = 8000;
            }
            else
            {
                assert(false&&"auido codec not support");
            }

            if(m_pCodec == NULL)
            {
                assert(false&&"Unsupported auido codec");
            }
        
            if(avcodec_open2(m_pCodecCtxt, m_pCodec, NULL) < 0)
            {
                assert(false&&"avcodec_open error");
            }
        
            m_pDecoded_frame = av_frame_alloc();
        }
        else
        {
            int bps = 0;
            
            switch (m_nBitrate)
            {
                case 16000:
                    bps = 2;
                break;
               
                case 24000:
                    bps = 3;
                break;
                
                case 32000:
                    bps = 4;
                break;
                
                case 40000:
                    bps = 5;
                break;
            }
            
            assert(bps != 0&&"bitrate error");
            m_pG726Decoder = new G726Decoder(m_byG726Pack, bps);
        }
    };

    ~AudioDecoder()
    {
        boost::mutex::scoped_lock lock(g_CodecInitMutex);
        
        // Close the codec
        
        if (m_pCodecCtxt != NULL)
        {
          avcodec_close(m_pCodecCtxt);
          av_free(m_pCodecCtxt);
        }
        
        if (m_pDecoded_frame != NULL)
        {
          av_frame_free(&m_pDecoded_frame);
        }
        
        if (m_pG726Decoder != NULL)
        {
            delete m_pG726Decoder;
        }
    };
    
    void avcodec_get_frame_defaults(AVFrame *frame)
    {
        
#if LIBAVCODEC_VERSION_MAJOR >= 55
        
        // extended_data should explicitly be freed when needed, this code is unsafe currently
        
        // also this is not compatible to the <55 ABI/API
        
        if (frame->extended_data != frame->data && 0)
            
            av_freep(&frame->extended_data);
        
#endif
        
        
        
        memset(frame, 0, sizeof(AVFrame));
        
        av_frame_unref(frame);
        
    }
    
    int  Decode(TMediaDataPacketInfo* ptMediaDataPacket, int16_t *pAudioBuf, int* AudioBufSize)
    {
        int nCount = 0;
        AVPacket avpkt;
        
        if (ptMediaDataPacket->dwFrameNumber == 1) {
            if (m_dwStreamType != mctG726) {
                avcodec_get_frame_defaults(m_pDecoded_frame);
        
                av_init_packet(&avpkt);
                avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset;
                avpkt.size = ptMediaDataPacket->dwBitstreamSize;
                
                int got_frame = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                nCount += avcodec_decode_audio4(m_pCodecCtxt, m_pDecoded_frame, &got_frame, &avpkt);
#pragma clang diagnostic pop
                if (got_frame == 0) {
                    return 0;
                }

                if (m_pCodecCtxt->sample_fmt == AV_SAMPLE_FMT_FLTP) { //ACC
                    auto samples = m_pDecoded_frame->nb_samples;
                    auto channels = m_pCodecCtxt->channels;
                    *AudioBufSize = samples * channels * 2;
                    for (int i = 0; i < channels; i++) {
                        for (int c = 0; c < channels; c++) {
                            auto pData = (float *)m_pDecoded_frame->data[c];
                            auto sample = pData[i];
                            if (sample < -1.0f) sample = -1.0f;
                            else if (sample > 1.0f) sample = 1.0f;
                            pAudioBuf[i * channels + c] = (int16_t)round(sample * 32767.0f);
                        }
                    }
                } else if (m_pCodecCtxt->sample_fmt == AV_SAMPLE_FMT_S16) { //G711
                    *AudioBufSize = av_samples_get_buffer_size(NULL, m_pCodecCtxt->channels,
                                                           m_pDecoded_frame->nb_samples,
                                                           m_pCodecCtxt->sample_fmt, 1);
                    
                    memcpy(pAudioBuf, m_pDecoded_frame->data[0], *AudioBufSize);
                } else {
                    assert(false);
                }
            } else {
                EncodeData avpkt;
                avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset;
                avpkt.size = ptMediaDataPacket->dwBitstreamSize;
            
                SCODE scRet = m_pG726Decoder->decode_audio((uint8_t*) pAudioBuf, AudioBufSize, &avpkt);
                return scRet == S_OK ? 1 : 0;
            }
        } else {
            //AMR
            int nCount2 = 0;
            for (int i = 0; i < ptMediaDataPacket->dwFrameNumber; i++) {
                avcodec_get_frame_defaults(m_pDecoded_frame);
                
                av_init_packet(&avpkt);
                avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset + nCount;
                avpkt.size = ptMediaDataPacket->dwBitstreamSize / ptMediaDataPacket->dwFrameNumber;
                
                int got_frame = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                nCount += avcodec_decode_audio4(m_pCodecCtxt, m_pDecoded_frame, &got_frame, &avpkt);
#pragma clang diagnostic pop
                
                if (got_frame) {
                    return 0;
                }
                
                if (m_pCodecCtxt->sample_fmt == AV_SAMPLE_FMT_FLT) {
                    *AudioBufSize = av_samples_get_buffer_size(NULL, m_pCodecCtxt->channels,
                                                               m_pDecoded_frame->nb_samples,
                                                               m_pCodecCtxt->sample_fmt, 1);
                    
                    memcpy(((uint8_t*) pAudioBuf) + nCount2, m_pDecoded_frame->data[0], *AudioBufSize);
                    nCount2 += *AudioBufSize ;
                } else {
                    assert(false);
                }
            }
            
            *AudioBufSize = nCount2;
        }
        
        return nCount;
    };

    AVCodecContext* GetCodecContext()
    {
        return m_pCodecCtxt;
    }

protected:
    AVCodec         *m_pCodec;
    AVCodecContext  *m_pCodecCtxt;
    DWORD           m_dwStreamType;
    AVFrame         *m_pDecoded_frame;
    G726Decoder     *m_pG726Decoder;
    int             m_nBitrate;
    BYTE            m_byG726Pack;
};

#endif // _AUDIODECODER_H_
