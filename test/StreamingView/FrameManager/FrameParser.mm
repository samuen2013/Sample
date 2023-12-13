#import "FrameParser.h"
#import "parsedatapacket/parsedatapacket.h"

using namespace std;

SCODE __stdcall DataPacketParserTLVCB(void *pvContext, TTLVParseUnit *ptUnit)
{
#ifndef __clang_analyzer__
    TRenderInfo *ptRenderInfo = (TRenderInfo *)pvContext;
    BYTE *pbyData = ptUnit->pbyP;
    
    switch (ptUnit->dwTag)
    {
        case 0x13:
            ptRenderInfo->eRenderType = eFisheye;
            
            ptRenderInfo->tFisheyeInfo.wCenterX = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.wCenterY = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.wRadius = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.byId = *pbyData; pbyData++;
            ptRenderInfo->tFisheyeInfo.byInstallation = *pbyData;
            break;
        case 0x16:
            ptRenderInfo->tFisheyeInfo.tSensorCropInfo.wSensorWidth = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.tSensorCropInfo.wSensorHeight = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.tSensorCropInfo.wOffsetX = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.tSensorCropInfo.wOffsetY = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.tSensorCropInfo.wCropWidth = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tFisheyeInfo.tSensorCropInfo.wCropHeight = HTONS(*(WORD*)pbyData);
            break;
        case 0x17:
            ptRenderInfo->eRenderType = eMultiSensor;
            
            ptRenderInfo->tMultisensorInfo.byId = *pbyData; pbyData++;
            ptRenderInfo->tMultisensorInfo.bySensorNum = *pbyData; pbyData++;
            ptRenderInfo->tMultisensorInfo.wPanoramaW = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tMultisensorInfo.wPanoramaH = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            for (int i = 0; i < ptRenderInfo->tMultisensorInfo.bySensorNum; i++)
            {
                if (i < _countof(ptRenderInfo->tMultisensorInfo.atROIs))
                {
                    ptRenderInfo->tMultisensorInfo.atROIs[i].wX = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
                    ptRenderInfo->tMultisensorInfo.atROIs[i].wY = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
                    ptRenderInfo->tMultisensorInfo.atROIs[i].wW = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
                    ptRenderInfo->tMultisensorInfo.atROIs[i].wH = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
                }
            }
            break;
        case 0x19:
            ptRenderInfo->eRenderType = eStereo;
            
            for (int i = 0; i < 9; i++)
            {
                ((QWORD*)ptRenderInfo->tStereoCameraInfo.adM1)[i] = HTONLL(*(QWORD*)pbyData); pbyData += sizeof(QWORD);
                
            }
            for (int i = 0; i < 12; i++)
            {
                ((QWORD*)ptRenderInfo->tStereoCameraInfo.adD1)[i] = HTONLL(*(QWORD*)pbyData); pbyData += sizeof(QWORD);
            }
            for (int i = 0; i < 9; i++)
            {
                ((QWORD*)ptRenderInfo->tStereoCameraInfo.adM2)[i] = HTONLL(*(QWORD*)pbyData); pbyData += sizeof(QWORD);
            }
            for (int i = 0; i < 12; i++)
            {
                ((QWORD*)ptRenderInfo->tStereoCameraInfo.adD2)[i] = HTONLL(*(QWORD*)pbyData); pbyData += sizeof(QWORD);
            }
            for (int i = 0; i < 9; i++)
            {
                ((QWORD*)ptRenderInfo->tStereoCameraInfo.adR)[i] = HTONLL(*(QWORD*)pbyData); pbyData += sizeof(QWORD);
            }
            for (int i = 0; i < 3; i++)
            {
                ((QWORD*)ptRenderInfo->tStereoCameraInfo.adT)[i] = HTONLL(*(QWORD*)pbyData); pbyData += sizeof(QWORD);
            }
            
            *(DWORD*)&ptRenderInfo->tStereoCameraInfo.fZoomInFactor = HTONL(*(DWORD*)pbyData); pbyData += sizeof(DWORD);
            *(int*)&ptRenderInfo->tStereoCameraInfo.iZoomInOffsetX = HTONL(*(int*)pbyData); pbyData += sizeof(int);
            *(int*)&ptRenderInfo->tStereoCameraInfo.iZoomInOffsetY = HTONL(*(int*)pbyData); pbyData += sizeof(int);
            *(int*)&ptRenderInfo->tStereoCameraInfo.iRoiWidth = HTONL(*(int*)pbyData); pbyData += sizeof(int);
            *(int*)&ptRenderInfo->tStereoCameraInfo.iRoiHeight = HTONL(*(int*)pbyData); pbyData += sizeof(int);
            *(int*)&ptRenderInfo->tStereoCameraInfo.iOrgWidth = HTONL(*(int*)pbyData); pbyData += sizeof(int);
            *(int*)&ptRenderInfo->tStereoCameraInfo.iOrgHeight = HTONL(*(int*)pbyData); pbyData += sizeof(int);
            break;
        case 0x1A:
            ptRenderInfo->tDeviceAngleInfo.wPitch = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tDeviceAngleInfo.wYaw = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            ptRenderInfo->tDeviceAngleInfo.wRoll = HTONS(*(WORD*)pbyData); pbyData += sizeof(WORD);
            break;
        default:
            //NSLog(@"No Tag");
            break;
    }
    
    return S_OK;
#endif
}

TRenderInfo FrameParser::parseRenderInfo(BYTE **ppbyData, DWORD offset)
{
    const DWORD userDataOffset = 20;
    
    auto applicationData = *ppbyData;
    auto userData = applicationData + userDataOffset;
    auto userDataSize = offset - userDataOffset;
    
    parseOldMotionWindow(&userData, &userDataSize);
    passReservedBitField(&userData, &userDataSize);
    
    auto renderInfo = TRenderInfo();
    DataPacket_ParseLoop(userData, userDataSize, DataPacketParserTLVCB, (void *)&renderInfo);
    
    return renderInfo;
}

void FrameParser::parseOldMotionWindow(BYTE **ppbyData, DWORD *pdwDataSize)
{
    const DWORD kdwMaxMotionWindowCount = 3, kdwFixMotionWindowInfoLen = 6, kdwFixMotionWindowIndicatorLen = 1;
    
    BYTE *pbyData = *ppbyData;
    DWORD dwDataSize = *pdwDataSize;
    DWORD dwShift = 7;
    
    if (!dwDataSize) return;
    
    for (DWORD dwCount = 0; dwCount < kdwMaxMotionWindowCount; ++dwCount, --dwShift)
    {
        BYTE byMask = (1 << dwShift);
        
        if (*pbyData & byMask)
        {
            if (dwDataSize < kdwFixMotionWindowInfoLen) return;
            
            pbyData += kdwFixMotionWindowInfoLen;
            dwDataSize -= kdwFixMotionWindowInfoLen;
        }
    }
    
    if (dwDataSize < kdwFixMotionWindowIndicatorLen) return;
    
    pbyData += kdwFixMotionWindowIndicatorLen;
    dwDataSize += kdwFixMotionWindowIndicatorLen;
    
    *ppbyData = pbyData;
    *pdwDataSize = dwDataSize;
}

void FrameParser::passReservedBitField(BYTE **ppbyData, DWORD *pdwDataSize)
{
    BYTE *pbyData = *ppbyData;
    DWORD dwDataSize = *pdwDataSize;
    
    for (; dwDataSize > 0; --dwDataSize, pbyData++)
    {
        if (*pbyData != 0)
            break;
    }
    
    *ppbyData = pbyData;
    *pdwDataSize = dwDataSize;
}
