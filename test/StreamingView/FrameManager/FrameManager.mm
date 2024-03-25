#import "FrameManager.h"
#import "RemoteIOPlayer.h"
#import "parsedatapacket/parsedatapacket.h"

using namespace std;

void FrameManager::removeOnePacket(TMediaDataPacketInfoV3 **packetV3)
{
    if (packetV3 == nullptr || *packetV3 == nullptr) return;
    
    auto ptFuntionTable = (*packetV3)->tIfEx.tRv1.tExt.ptFunctionTable;
    if (ptFuntionTable)
    {
        ptFuntionTable->pfRelease(*packetV3);
    }
    else
    {
        delete [] (*packetV3)->tIfEx.tInfo.pbyBuff;
        delete [] (*packetV3)->tIfEx.tRv1.tExt.pbyTLVExt;
        delete *packetV3;
        *packetV3 = nullptr;
    }
}

class PacketQueue
{
public:
    PacketQueue() {}
    ~PacketQueue() {
        releaseAll();
    }
    
    size_t count() {
        boost::mutex::scoped_lock lock(m_queueMutex);
        return m_queue.size();
    }
    TMediaDataPacketInfo* pop() {
        boost::mutex::scoped_lock lock(m_queueMutex);
        if (m_queue.empty()) return nullptr;
        
        auto packet = m_queue.front();
        m_queue.pop();
        return packet;
    }
    TMediaDataPacketInfo* first() {
        boost::mutex::scoped_lock lock(m_queueMutex);
        return m_queue.front();
    }
    TMediaDataPacketInfo* last() {
        boost::mutex::scoped_lock lock(m_queueMutex);
        return m_queue.back();
    }
    void input(TMediaDataPacketInfo *packet) {
        boost::mutex::scoped_lock lock(m_queueMutex);
        auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
        auto ptFuntionTable = packetV3->tIfEx.tRv1.tExt.ptFunctionTable;
        if (ptFuntionTable) {
            ptFuntionTable->pfAddRef(packetV3);
        }
        m_queue.push(packet);
    }
    void releaseAll() {
        boost::mutex::scoped_lock lock(m_queueMutex);
        while (!m_queue.empty()) {
            auto packet = (TMediaDataPacketInfoV3 *) m_queue.front();
            m_queue.pop();
            FrameManager::removeOnePacket(&packet);
        }
    }
    
private:
    boost::mutex m_queueMutex;
    
    std::queue<TMediaDataPacketInfo *> m_queue;
};

FrameManager::FrameManager()
{
    m_videoQueue = std::make_shared<PacketQueue>();
    m_audioQueue = std::make_shared<PacketQueue>();
}

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
    m_videoQueue->releaseAll();
    m_firstDecodeTS = 0;
    m_firstPacketTS = 0;
    m_lastDecodeTS = 0;
    m_lastPacketTS = 0;
}

void FrameManager::releaseAudioRelated()
{
    m_audioQueue->releaseAll();
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
    m_lastDecodeTS = 0;
    m_lastPacketTS = 0;
}

void FrameManager::inputVideoPacket(TMediaDataPacketInfo *packet) {
    m_videoQueue->input(packet);
}

void FrameManager::inputAudioPacket(TMediaDataPacketInfo *packet) {
    m_audioQueue->input(packet);
}

long FrameManager::parseTimestamp(TMediaDataPacketInfo *packet) {
    return packet != nullptr ? (long)packet->dwFirstUnitSecond * 1000 + packet->dwFirstUnitMilliSecond : 0;
}

SCODE FrameManager::getVideoFrame(TMediaDataPacketInfo **packet)
{
    if (m_pause) return S_FAIL;
    
    auto now = floorl([[NSDate date] timeIntervalSince1970] * 1000);
    if (m_firstDecodeTS == 0) {
        if (m_videoQueue->count() == 0) return S_FAIL;
        *packet = m_videoQueue->pop();
        m_firstDecodeTS = now;
        m_lastDecodeTS = now;
        auto pts = parseTimestamp(*packet);
        m_firstPacketTS = pts;
        m_lastPacketTS = pts;
        return S_OK;
    }
    
    auto targetPacketTS = m_firstPacketTS + (now - m_firstDecodeTS); // need to consider speed
    if (m_videoQueue->count() == 0) {
//        m_firstDecodeTS = now;
//        m_firstPacketTS = targetPacketTS;
        NSLog(@"video queue is empty, update firstDecodeTS and firstPacketTS");
        return S_FAIL;
    }
    
    auto nextPacketTS = parseTimestamp(m_videoQueue->first());
    if ((nextPacketTS - m_lastPacketTS) > 2000) {
        // segment jump, there is no recording from 'm_lastPacketTS' to 'nextPacketTS'
        NSLog(@"segment jump, there is no recording from '%ld' to '%ld'", m_lastPacketTS, nextPacketTS);
        *packet = m_videoQueue->pop();
        m_firstDecodeTS = now;
        m_lastDecodeTS = now;
        auto pts = parseTimestamp(*packet);
        m_firstPacketTS = pts;
        m_lastPacketTS = pts;
        return S_OK;
    } else if (nextPacketTS > targetPacketTS) {
        // render too fast, need to wait
        return S_FAIL;
    } else {
        *packet = m_videoQueue->pop();
        m_lastDecodeTS = now;
        auto pts = parseTimestamp(*packet);
        m_lastPacketTS = pts;
        pureVideoQueue();
        return S_OK;
    }
}

void FrameManager::pureVideoQueue() {
    if (m_videoQueue->count() < 2) return;
    if (parseTimestamp(m_videoQueue->last()) - parseTimestamp(m_videoQueue->first()) <= 4000) {
        return;
    }
    
    auto newVideoQueue = std::make_shared<PacketQueue>();
    
    auto foundI = false;
    auto drop = 0;
    do {
        auto packet = m_videoQueue->pop();
        if (foundI) {
            if (packet->tFrameType == MEDIADB_FRAME_INTRA) {
                newVideoQueue->input(packet);
            } else {
                auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
                removeOnePacket(&packetV3);
                drop++;
            }
        } else {
            if (packet->tFrameType == MEDIADB_FRAME_INTRA) {
                foundI = true;
            }
            newVideoQueue->input(packet);
        }
    } while(m_videoQueue->count() > 0);
    m_videoQueue = newVideoQueue;
    
    NSLog(@"FrameManager, drop %d packets from video queue", drop);
}

SCODE FrameManager::getAudioFrame(TMediaDataPacketInfo **packet)
{
    if (m_pause) return S_FAIL;
    if (m_lastPacketTS == 0) return S_FAIL;
    
    auto nextPacket = m_audioQueue->first();
    if (nextPacket == nullptr) return S_FAIL;
    
    auto nextPTS = (long)nextPacket->dwFirstUnitSecond * 1000 + nextPacket->dwFirstUnitMilliSecond;
    auto limitStart = m_lastPacketTS - 50;
    auto limitEnd = m_lastPacketTS + 50;
    if (nextPTS > limitEnd) return S_FAIL;
    
    if (limitStart <= nextPTS) {
        *packet = m_audioQueue->pop();
        return *packet != nullptr ? S_OK : S_FAIL;
    } else {
        auto packet = (TMediaDataPacketInfoV3 *)m_audioQueue->pop();
        removeOnePacket(&packet);
        return S_FAIL;
    }
}
