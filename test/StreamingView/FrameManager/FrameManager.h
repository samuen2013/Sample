#ifndef _AVSYNC2AP_FRAMEMANAGER_H_
#define _AVSYNC2AP_FRAMEMANAGER_H_

#include <memory>

class FrameInfo {
public:
    TMediaDataPacketInfo *packet = nullptr;
    long timestamp = 0;
    int width = 0;
    int height = 0;
    bool IFrame = false;
    
    FrameInfo(TMediaDataPacketInfo *packet, bool timeFromExt = false);
    virtual ~FrameInfo();
    
private:
    long retrieveTimestamp(bool fromExt);
};

class FrameManager
{
public:
    FrameManager();
    ~FrameManager();
    
    void releaseAll();
    void releaseVideoRelated();
    void releaseAudioRelated();
    
    void pause();
    void resume();
    void setSpeed(float speed);
    
    void inputVideo(std::shared_ptr<FrameInfo> frame);
    void inputAudio(std::shared_ptr<FrameInfo> frame);
    
    std::shared_ptr<FrameInfo> getVideoFrame();
    std::shared_ptr<FrameInfo> getAudioFrame();
    
private:
    void pureVideoQueue();
    
    boost::mutex m_videoListMutex;
    boost::mutex m_audioListMutex;
    std::list<std::shared_ptr<FrameInfo>> m_videoList;
    std::list<std::shared_ptr<FrameInfo>> m_audioList;

    bool m_pause = false;
    
    long m_firstDecodeTS = 0;
    long m_firstPacketTS = 0;
    long m_lastPacketTS = 0;
    
    float m_speed = 1.0;
};

#endif // _AVSYNC2AP_FRAMEMANAGER_H_
