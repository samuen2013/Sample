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
    void pause();
    void resume();
    
    void inputVideoPacket(TMediaDataPacketInfo *packet);
    void inputAudioPacket(TMediaDataPacketInfo *packet);
    void releaseVideoRelated();
    void releaseAudioRelated();
    
    SCODE getVideoFrame(TMediaDataPacketInfo **pptMediaDataPacket, long diff);
    SCODE getAudioFrame(TMediaDataPacketInfo **pptMediaDataPacket);
    TMediaDataPacketInfo* firstVideoPacket();
    TMediaDataPacketInfo* firstAudioPacket();
    
private:
    SCODE nextVideoFrame(TMediaDataPacketInfo **pptMediaDataPacket, long targetPTS);
    
    bool m_pause = false;
    
    std::shared_ptr<PacketQueue> m_videoQueue;
    std::shared_ptr<PacketQueue> m_audioQueue;

    bool m_bDropPFrame = false;
    bool m_bIntraFrameNeverAdded = true;
};

#endif // _AVSYNC2AP_FRAMEMANAGER_H_
