#import "FrameManager.h"
#import "RemoteIOPlayer.h"
#import "parsedatapacket/parsedatapacket.h"

using namespace std;

FrameInfo::FrameInfo(TMediaDataPacketInfo *packet, bool timeFromExt): packet(packet) {
    auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
    auto ptFuntionTable = packetV3->tIfEx.tRv1.tExt.ptFunctionTable;
    if (ptFuntionTable) {
        ptFuntionTable->pfAddRef(packetV3);
    }
    timestamp = retrieveTimestamp(timeFromExt);
    width = packetV3->tIfEx.dwWidth;
    height = packetV3->tIfEx.dwHeight;
    IFrame = packetV3->tIfEx.tInfo.tFrameType == MEDIADB_FRAME_INTRA;
}

FrameInfo::~FrameInfo() {
    if (packet != nullptr) {
        auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
        auto ptFuntionTable = packetV3->tIfEx.tRv1.tExt.ptFunctionTable;
        if (ptFuntionTable) {
            ptFuntionTable->pfRelease(packetV3);
        } else {
            delete [] packetV3->tIfEx.tInfo.pbyBuff;
            delete [] packetV3->tIfEx.tRv1.tExt.pbyTLVExt;
            delete packetV3;
        }
    }
}

long FrameInfo::retrieveTimestamp(bool fromExt) {
    auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
    if (fromExt) {
        VVTK::SDK::Utility::BitstreamReader reader(packetV3->tIfEx.tRv1.tExt.pbyTLVExt + sizeof(DWORD), packetV3->tIfEx.tRv1.tExt.dwTLVExtLen - sizeof(DWORD));
        while (reader.Available()) {
            DWORD dwTag = 0;
            DWORD dwLength = DataPacket_GetTagLength(reader, dwTag);
            if (dwTag == 0x61) {
                auto second = reader.GetBits<32>();
                auto milliSecond = reader.GetBits<32>();
                return (long)second * 1000 + milliSecond;
            } else {
                reader.SkipBytes(dwLength);
            }
        }
    }
    return (long)packetV3->dwUTCTime * 1000 + packetV3->tIfEx.tInfo.dwFirstUnitMilliSecond;
}

FrameManager::FrameManager() {}

FrameManager::~FrameManager()
{
    releaseAll();
}

void FrameManager::releaseAll()
{
    releaseVideoRelated();
    releaseAudioRelated();
    
    m_pause = false;
}

void FrameManager::releaseVideoRelated()
{
    boost::mutex::scoped_lock lock(m_videoListMutex);
    m_videoList.clear();
    m_firstDecodeTS = 0;
    m_firstPacketTS = 0;
    m_lastPacketTS = 0;
}

void FrameManager::releaseAudioRelated()
{
    boost::mutex::scoped_lock lock(m_audioListMutex);
    m_audioList.clear();
}

void FrameManager::pause()
{
    m_pause = true;
}

void FrameManager::resume()
{
    m_pause = false;
    m_firstDecodeTS = 0;
    m_firstPacketTS = 0;
}

void FrameManager::setSpeed(float speed)
{
    m_speed = speed;
    m_firstDecodeTS = 0;
    m_firstPacketTS = 0;
    m_lastPacketTS = 0;
}

void FrameManager::inputVideo(std::shared_ptr<FrameInfo> frame) {
    boost::mutex::scoped_lock lock(m_videoListMutex);
    m_videoList.push_back(frame);
}

void FrameManager::inputAudio(std::shared_ptr<FrameInfo> frame) {
    boost::mutex::scoped_lock lock(m_audioListMutex);
    m_audioList.push_back(frame);
}

std::shared_ptr<FrameInfo> FrameManager::getVideoFrame()
{
    boost::mutex::scoped_lock lock(m_videoListMutex);
    
    if (m_pause) return nullptr;
    if (m_videoList.size() == 0) return nullptr;
    
    auto now = floorl([[NSDate date] timeIntervalSince1970] * 1000);
    if (m_firstDecodeTS == 0) {
        auto frame = m_videoList.front();
        m_videoList.pop_front();
        m_firstDecodeTS = now;
        m_firstPacketTS = frame->timestamp;
        m_lastPacketTS = frame->timestamp;
        return frame;
    }
    
    auto targetFrameTS = m_firstPacketTS + (now - m_firstDecodeTS); // need to consider speed
    auto nextFrameTS = m_videoList.front()->timestamp;
    if ((nextFrameTS - m_lastPacketTS) > 2000) {
        // segment jump, there is no recording from 'm_lastPacketTS' to 'nextPacketTS'
        NSLog(@"segment jump, there is no recording from '%ld' to '%ld'", m_lastPacketTS, nextFrameTS);
        auto frame = m_videoList.front();
        m_videoList.pop_front();
        m_firstDecodeTS = now;
        m_firstPacketTS = frame->timestamp;
        m_lastPacketTS = frame->timestamp;
        return frame;
    } else if (nextFrameTS > targetFrameTS) {
        // render too fast, need to wait
        return nullptr;
    } else {
        auto frame = m_videoList.front();
        m_videoList.pop_front();
        m_lastPacketTS = frame->timestamp;
        pureVideoQueue();
        return frame;
    }
}

void FrameManager::pureVideoQueue() {
    if (m_videoList.size() < 2) return;
    if (m_videoList.back()->timestamp - m_videoList.front()->timestamp <= 4000) {
        return;
    }
    
    auto foundI = false;
    auto drop = 0;
    for (auto it = m_videoList.rbegin(); it != m_videoList.rend();) {
        if (foundI) {
            if ((*it)->IFrame) {
                it++;
            } else {
                m_videoList.erase(std::next(it).base());
                drop++;
            }
        } else {
            if ((*it)->IFrame) {
                foundI = true;
            }
            it++;
        }
    }
    NSLog(@"FrameManager, drop %d packets from video queue", drop);
}

std::shared_ptr<FrameInfo> FrameManager::getAudioFrame()
{
    if (m_pause) return nullptr;
    if (m_lastPacketTS == 0) return nullptr;
    
    boost::mutex::scoped_lock lock(m_audioListMutex);
    auto nextFrame = m_audioList.front();
    if (nextFrame == nullptr) return nullptr;
    
    auto nextFrameTS = nextFrame->timestamp;
    auto limitStart = m_lastPacketTS - 50;
    auto limitEnd = m_lastPacketTS + 50;
    if (nextFrameTS > limitEnd) return nullptr;
    
    m_audioList.pop_front();
    return limitStart <= nextFrameTS ? nextFrame : nullptr;
}
