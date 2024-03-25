#ifndef _AVSYNC2AP_FRAMEMANAGER_H_
#define _AVSYNC2AP_FRAMEMANAGER_H_

#include <queue>
#include <memory>

class PacketQueue;
class FrameManager
{
public:
	FrameManager();
	~FrameManager();
    
    static void removeOnePacket(TMediaDataPacketInfoV3 **packetV3);
    
    void releaseAll();
    void releaseVideoRelated();
    void releaseAudioRelated();
    
    void pause();
    void resume();
    void setSpeed(float speed);
    
    void inputVideoPacket(TMediaDataPacketInfo *packet);
    void inputAudioPacket(TMediaDataPacketInfo *packet);
    
    SCODE getVideoFrame(TMediaDataPacketInfo **pptMediaDataPacket);
    SCODE getAudioFrame(TMediaDataPacketInfo **pptMediaDataPacket);
    
private:
    long parseTimestamp(TMediaDataPacketInfo *packet);
    void pureVideoQueue();
    
    std::shared_ptr<PacketQueue> m_videoQueue;
    std::shared_ptr<PacketQueue> m_audioQueue;

    bool m_pause = false;
    
    long m_firstDecodeTS = 0;
    long m_lastDecodeTS = 0;
    
    long m_firstPacketTS = 0;
    long m_lastPacketTS = 0;
    
    float m_speed = 1.0;
};

#endif // _AVSYNC2AP_FRAMEMANAGER_H_
