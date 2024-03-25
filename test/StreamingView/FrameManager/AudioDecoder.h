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

#include <boost/thread/mutex.hpp>
static boost::mutex g_CodecInitMutex;

class AudioDecoder
{
public:
    AudioDecoder(DWORD dwStreamType, int nSampleRate, int nBitrate) :
    m_pCodec(NULL),
    m_pCodecCtxt(NULL),
    m_dwStreamType(dwStreamType),
    m_pDecoded_frame(NULL)
    {
        boost::mutex::scoped_lock lock(g_CodecInitMutex);
        
        if (m_dwStreamType == mctAAC) {
            m_pCodec = avcodec_find_decoder(AV_CODEC_ID_AAC);
            m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            m_pCodecCtxt->sample_rate = nSampleRate;
            m_pCodecCtxt->channels = 2;
            m_pCodecCtxt->bit_rate = nBitrate;
        } else if (m_dwStreamType == mctG711) {
            m_pCodec = avcodec_find_decoder(AV_CODEC_ID_PCM_MULAW);
            m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            m_pCodecCtxt->channels = 1;
            m_pCodecCtxt->sample_rate = 8000;
        } else if (m_dwStreamType == mctG711A) {
            m_pCodec = avcodec_find_decoder(AV_CODEC_ID_PCM_ALAW);
            m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            m_pCodecCtxt->channels = 1;
            m_pCodecCtxt->sample_rate = 8000;
        } else if (m_dwStreamType == mctSAMR) {
            if (nSampleRate == 8000) {
                m_pCodec = avcodec_find_decoder(AV_CODEC_ID_AMR_NB);
            } else if (nSampleRate == 16000) {
                m_pCodec = avcodec_find_decoder(AV_CODEC_ID_AMR_WB);
            } else {
                assert(false&&"Unsupported auido codec");
            }
            m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            m_pCodecCtxt->sample_rate = nSampleRate;
            m_pCodecCtxt->channels = 1;
            m_pCodecCtxt->bit_rate = nBitrate;
        } else if (m_dwStreamType == mctG726) {
            m_pCodec = avcodec_find_decoder(AV_CODEC_ID_ADPCM_G726LE);
            m_pCodecCtxt = avcodec_alloc_context3(m_pCodec);
            m_pCodecCtxt->sample_rate = nSampleRate;
            int code_size = (nBitrate + nSampleRate / 2) / nSampleRate;
            m_pCodecCtxt->bits_per_coded_sample = av_clip(code_size, 2, 5);
            m_pCodecCtxt->channels = 1;
            m_pCodecCtxt->bit_rate = nBitrate;
        }
        if(m_pCodec == NULL) {
            assert(false&&"Unsupported auido codec");
        }
        
        while(avcodec_open2(m_pCodecCtxt, m_pCodec, NULL) < 0) {
            usleep(1000);
        }
        m_pDecoded_frame = av_frame_alloc();
    }

    ~AudioDecoder()
    {
        boost::mutex::scoped_lock lock(g_CodecInitMutex);
        
        if (m_pCodecCtxt != NULL) {
            avcodec_close(m_pCodecCtxt);
            av_free(m_pCodecCtxt);
            m_pCodecCtxt = NULL;
        }
        
        if (m_pDecoded_frame != NULL) {
            av_frame_free(&m_pDecoded_frame);
        }
    };
    
    int DecodePacket(const AVPacket* avpkt) {
        int ret = avcodec_send_packet(m_pCodecCtxt, avpkt);
        if (ret < 0) return ret;
        
        return avcodec_receive_frame(m_pCodecCtxt, m_pDecoded_frame);
    }
    
    int Decode(TMediaDataPacketInfo* ptMediaDataPacket, int16_t *pAudioBuf, int* AudioBufSize)
    {
        AVPacket avpkt;
        if (ptMediaDataPacket->dwFrameNumber == 1) {
            if (m_dwStreamType == mctAAC || m_dwStreamType == mctG711 || m_dwStreamType == mctG711A || m_dwStreamType == mctG726) {
                av_frame_unref(m_pDecoded_frame);
                
                av_init_packet(&avpkt);
                avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset;
                avpkt.size = ptMediaDataPacket->dwBitstreamSize;
                int ret = DecodePacket(&avpkt);
                if (ret < 0) return ret;
                
                *AudioBufSize = av_samples_get_buffer_size(NULL, m_pCodecCtxt->channels, m_pDecoded_frame->nb_samples, m_pCodecCtxt->sample_fmt, 1);

                if (m_pCodecCtxt->sample_fmt == AV_SAMPLE_FMT_FLTP) {
                    float* channels1 = (float*) m_pDecoded_frame->data[0];
                    float* channels2 = (float*) m_pDecoded_frame->data[1];
                    float* outbuf = (float*) pAudioBuf;
                    for ( int i = 0; i < *AudioBufSize / 8; i++)
                    {
                        outbuf[i * 2] = channels1[i];
                        outbuf[i * 2 + 1] = channels2[i];
                    }
                } else if (m_pCodecCtxt->sample_fmt == AV_SAMPLE_FMT_S16) {
                    memcpy(pAudioBuf, m_pDecoded_frame->data[0], *AudioBufSize);
                } else {
                    assert(false);
                }
            }
        } else {
            int frameSize = ptMediaDataPacket->dwBitstreamSize / ptMediaDataPacket->dwFrameNumber;
            int nCount = 0;
            for (int i = 0; i < ptMediaDataPacket->dwFrameNumber; i++) {
                av_frame_unref(m_pDecoded_frame);
                
                av_init_packet(&avpkt);
                avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset + (frameSize * i);
                avpkt.size = frameSize;
                int ret = DecodePacket(&avpkt);
                if (ret < 0) return ret;
                
                if (m_pCodecCtxt->sample_fmt == AV_SAMPLE_FMT_FLT) {
                    int samples = m_pDecoded_frame->nb_samples;
                    *AudioBufSize += samples * 2;
                    
                    for(int s = 0; s < samples; ++s) {
                        float* pData = (float*)m_pDecoded_frame->data[0];
                        float sample = pData[s];
                        if (sample < -1.0f) sample = -1.0f;
                        else if (sample > 1.0f) sample = 1.0f;
                        pAudioBuf[s + nCount] = (int16_t)round(sample * 32767.0f);
                    }
                    nCount += samples;
                }
            }
        }
        
        return 0;
    };

protected:
    AVCodec         *m_pCodec;
    AVCodecContext  *m_pCodecCtxt;
    DWORD           m_dwStreamType;
    AVFrame         *m_pDecoded_frame;
};

#endif // _AUDIODECODER_H_
