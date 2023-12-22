#ifndef _VIDEODECODER_H_
#define _VIDEODECODER_H_

#ifdef __cplusplus
extern "C" {
#endif

#undef AVMediaType
#define AVMediaType FFMpeg_AVMediaType
#include <libavcodec/avcodec.h>
#undef AVMediaType

#ifdef __cplusplus
}
#endif

#include <mach/mach_host.h>

class VideoDecoder
{
public:
    VideoDecoder() {}
	~VideoDecoder() {
        if (pCodecCtxt) {
            avcodec_close(pCodecCtxt);
            av_free(pCodecCtxt);
        }
	}
    
    int InitSoftwareDecoder(DWORD dwStreamType) {
        pCodec = getAVCodec(dwStreamType);
        if(pCodec == NULL) {
            fprintf(stderr, "avcodec_find_decoder %d failed\n", dwStreamType);
            return -1;
        }
        
        pCodecCtxt = avcodec_alloc_context3(pCodec);
        if (pCodec->capabilities&AV_CODEC_CAP_FRAME_THREADS) {
            pCodecCtxt->thread_count = countCores() > 1 ? 2 : 1;
            pCodecCtxt->thread_type =
                pCodec->capabilities & AV_CODEC_CAP_SLICE_THREADS ? FF_THREAD_FRAME | FF_THREAD_SLICE : FF_THREAD_FRAME;
        }
        
        auto ret = avcodec_open2(pCodecCtxt, pCodec, NULL);
        if (ret < 0) {
            fprintf(stderr, "avcodec_open2 failed, %d\n", ret);
            return -1;
        }
        
        return 0;
    }

	int Decode(TMediaDataPacketInfo* ptMediaDataPacket, AVFrame *pFrame) {
        AVPacket avpkt;
        av_init_packet(&avpkt);
        avpkt.data = ptMediaDataPacket->pbyBuff + ptMediaDataPacket->dwOffset;
        avpkt.size = ptMediaDataPacket->dwBitstreamSize;
        
        auto ret = avcodec_send_packet(pCodecCtxt, &avpkt);
        if (ret != 0) {
            fprintf(stderr, "avcodec_send_packet failed, %d\n", ret);
            return ret;
        }
        
        ret = avcodec_receive_frame(pCodecCtxt, pFrame);
        if (ret != 0) {
            fprintf(stderr, "avcodec_receive_frame failed, %d\n", ret);
            return ret;
        }
        return 0;
	};

	AVCodecContext* GetCodecContext() {
        return pCodecCtxt;
	}

protected:
	AVCodec *pCodec = NULL;
	AVCodecContext *pCodecCtxt = NULL;
    
private:
    AVCodec* getAVCodec(DWORD dwStreamType) {
        if (dwStreamType == mctMP4V) {
            return avcodec_find_decoder(AV_CODEC_ID_MPEG4);
        } else if (dwStreamType == mctJPEG) {
            return avcodec_find_decoder(AV_CODEC_ID_MJPEG);
        } else if (dwStreamType == mctH264) {
            return avcodec_find_decoder(AV_CODEC_ID_H264);
        } else if (dwStreamType == mctHEVC) {
            return avcodec_find_decoder(AV_CODEC_ID_HEVC);
        } else {
            return NULL;
        }
    }
    
    unsigned int countCores() {
        host_basic_info_data_t hostInfo;
        mach_msg_type_number_t infoCount;
        
        infoCount = HOST_BASIC_INFO_COUNT;
        host_info(mach_host_self(), HOST_BASIC_INFO,
                  (host_info_t)&hostInfo, &infoCount);
        
        return (unsigned int)(hostInfo.max_cpus);
    }
};

#endif // _VIDEODECODER_H_
