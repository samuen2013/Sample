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
    ~PacketQueue()
    {
        releaseAll();
    }
    
    size_t count()
    {
        boost::mutex::scoped_lock lock(m_queueMutex);
        return m_queue.size();
    }
    
    TMediaDataPacketInfo* pop()
    {
        boost::mutex::scoped_lock lock(m_queueMutex);
        
        if (m_queue.empty())
            return nullptr;
        
        auto packet = m_queue.front();
        m_queue.pop();
        return packet;
    }
    
    TMediaDataPacketInfo* first()
    {
        boost::mutex::scoped_lock lock(m_queueMutex);
        
        if (m_queue.empty())
            return nullptr;
        
        auto packet = m_queue.front();
        return packet;
    }
    
    void input(TMediaDataPacketInfo *packet)
    {
        boost::mutex::scoped_lock lock(m_queueMutex);
        
        auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
        auto ptFuntionTable = packetV3->tIfEx.tRv1.tExt.ptFunctionTable;
        if (ptFuntionTable)
        {
            ptFuntionTable->pfAddRef(packetV3);
        }
        
        m_queue.push(packet);
    }
    
    void releaseAll()
    {
        boost::mutex::scoped_lock lock(m_queueMutex);
        
        while (!m_queue.empty())
        {
            auto packet = (TMediaDataPacketInfoV3 *)m_queue.front();
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

void FrameManager::pause()
{
    m_pause = true;
}

void FrameManager::resume()
{
    m_pause = false;
}

void FrameManager::releaseVideoRelated()
{
    m_videoQueue->releaseAll();
}

void FrameManager::releaseAudioRelated()
{
    m_audioQueue->releaseAll();
}

void FrameManager::inputVideoPacket(TMediaDataPacketInfo *packet) {
    if (m_bIntraFrameNeverAdded && packet->tFrameType != MEDIADB_FRAME_INTRA) {
        auto packetV3 = (TMediaDataPacketInfoV3 *)packet;
        removeOnePacket(&packetV3);
        return;
    } else if (m_bIntraFrameNeverAdded && packet->tFrameType == MEDIADB_FRAME_INTRA) {
        m_bIntraFrameNeverAdded = false;
    }
    
    m_videoQueue->input(packet);
}

void FrameManager::inputAudioPacket(TMediaDataPacketInfo *packet) {
    m_audioQueue->input(packet);
}

TMediaDataPacketInfo* FrameManager::firstVideoPacket() {
    return m_videoQueue->first();
}

TMediaDataPacketInfo* FrameManager::firstAudioPacket() {
    return m_audioQueue->first();
}

SCODE FrameManager::getVideoFrame(TMediaDataPacketInfo **packet, long diff)
{
    if (m_pause) return S_FAIL;
    if (m_videoQueue->count() < 5) return S_FAIL;
    
    auto dts = floorl([[NSDate date] timeIntervalSince1970] * 1000);
    auto targetPTS = dts - diff;
    if (m_videoQueue->count() > 45) return nextVideoFrame(packet, targetPTS);

    *packet = m_videoQueue->pop();
    return *packet != nullptr ? S_OK : S_FAIL;
}

SCODE FrameManager::nextVideoFrame(TMediaDataPacketInfo **packet, long targetPTS)
{
    auto lastPacket = m_videoQueue->pop();
    while (lastPacket != nullptr) {
        auto nextPacket = m_videoQueue->first();
        if (nextPacket == nullptr) {
            *packet = lastPacket;
            break;
        }
        
        auto lastPTS = (long)lastPacket->dwFirstUnitSecond * 1000 + lastPacket->dwFirstUnitMilliSecond;
        auto nextPTS = (long)nextPacket->dwFirstUnitSecond * 1000 + nextPacket->dwFirstUnitMilliSecond;
        if (lastPTS <= targetPTS && targetPTS < nextPTS)
        {
            *packet = lastPacket;
            break;
        }
        
        auto lastPacketV3 = (TMediaDataPacketInfoV3 *)lastPacket;
        removeOnePacket(&lastPacketV3);
        
        lastPacket = m_videoQueue->pop();
    }
    
    return *packet != nullptr ? S_OK : S_FAIL;
}

SCODE FrameManager::getAudioFrame(TMediaDataPacketInfo **packet)
{
    if (m_pause) return S_FAIL;
    
    *packet = m_audioQueue->pop();
    return *packet != nullptr ? S_OK : S_FAIL;
}
