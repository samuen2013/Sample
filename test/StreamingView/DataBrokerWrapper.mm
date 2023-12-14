//
//  DataBrokerWrapper.m
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/8/26.
//

#import "DataBroker.h"
#import "DataBrokerWrapper.h"

@interface DataBrokerWrapper()
@property (assign, nonatomic) HANDLE g_hDataBrokerMgr;
@property (assign, nonatomic) HANDLE g_hConn;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@end

@implementation DataBrokerWrapper

SCODE __stdcall DataBrokerStatusCallBack(DWORD_PTR dwContext, TDataBrokerStatusType tStatusType, PVOID pvParam1, PVOID pvParam2)
{
    auto dataBrokerWrapper = (DataBrokerWrapper *)dwContext;
    
    auto param1 = reinterpret_cast<long>(pvParam1);
    auto param2 = reinterpret_cast<long>(pvParam2);
    
    switch (tStatusType) {
        case eOnOtherError:
            NSLog(@"eOnOtherError %lx %ld", param1, param2);
            if (param2 == 429) {
                [dataBrokerWrapper.delegate statusDidChange:dataBrokerWrapper status:StreamingStatusTooManyConnections];
            }
            break;
            
        case eOnStopped:
            NSLog(@"eOnStopped %ld %ld", param1, param2);
            [dataBrokerWrapper.delegate statusDidChange:dataBrokerWrapper status:StreamingStatusDisconnected];
            break;
            
        case eOnConnectionInfo:
            [dataBrokerWrapper.delegate statusDidChange:dataBrokerWrapper status:StreamingStatusReceiveConnectionInfo];
            break;
            
        default:
            break;
    }
    
    return S_OK;
}

SCODE __stdcall DataBrokerAVCallBack(DWORD_PTR dwContext, TMediaDataPacketInfo *pMediaDataPacket)
{
    auto dataBrokerWrapper = (DataBrokerWrapper *)dwContext;
    
    [dataBrokerWrapper.delegate packetDidRetrieve:dataBrokerWrapper packet:pMediaDataPacket];
    
    return S_OK;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [self.dateFormatter setDateFormat:@"yyyyMMdd'T'HHmmss.000'Z'"];
        
        DWORD dwMaxConn = 32;
        auto scRet = DataBroker_Initial(&_g_hDataBrokerMgr, dwMaxConn, DataBrokerStatusCallBack, DataBrokerAVCallBack, mctALLCODEC, 0, DATABROKER_VERSION);
        if (scRet != S_OK)
        {
            NSLog(@"DataBroker_Initial fail");
        }
    }
    
    return self;
}

- (void)dealloc
{
    if (_g_hConn != NULL)
    {
        DataBroker_Disconnect(_g_hConn);
        DataBroker_DeleteConnection(_g_hDataBrokerMgr, &_g_hConn);
        _g_hConn = NULL;
    }
    
    if (_g_hDataBrokerMgr)
    {
        DataBroker_Release(&_g_hDataBrokerMgr);
    }
    
    [super dealloc];
}

- (void)startStreaming:(NSString *)ip port:(NSInteger)port streamingUrl:(NSString *)streamingUrl
{
    auto scRet = DataBroker_CreateConnection(_g_hDataBrokerMgr, &_g_hConn);
    if (scRet != S_OK)
    {
        return;
    }
    
    TDataBrokerConnectionOptions opt;
    memset(&opt, 0, sizeof(opt));
    
    opt.pfStatus = DataBrokerStatusCallBack;
    opt.pfAV = DataBrokerAVCallBack;
    opt.dwStatusContext = (DWORD_PTR)self;
    opt.dwAVContext = (DWORD_PTR)self;
    opt.wHttpPort = port;
    opt.dwProtocolType = eptTCP;
    opt.dwMediaType = (emtVideo | emtAudio | emtMetaData);
    opt.pzServerType = (char *)[@"Darwin" UTF8String];
    opt.pzIPAddr = (char *)[ip UTF8String];
    opt.dwFlags = eConOptProtocolAndMediaType | eConOptHttpPort | (eConOptStatusCallback | eConOptStatusContext) | (eConOptAVCallback | eConOptAVContext);
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *user = [prefs stringForKey:@"connectDeviceUser"];
    if (user != nil) {
        opt.pzUID = (char *)[user UTF8String];
    }
    NSString *pwd = [prefs stringForKey:@"connectDevicePassword"];
    if (pwd != nil) {
        opt.pzPWD = (char *)[pwd UTF8String];
    }
    scRet = DataBroker_SetConnectionOptions(_g_hConn, &opt);
    if (scRet != S_OK) return;
    
#if DEBUG
    NSLog(@"[Debug] ip is %@, port is %ld, streamingUrl is %@", ip, (long)port, streamingUrl);
#endif
    
    scRet = DataBroker_SetConnectionUrlsExtra(_g_hConn, (char *)[streamingUrl UTF8String], NULL, NULL, NULL, NULL, NULL);
    if (IS_FAIL(scRet))
    {
        printf("DataBroker_SetConnectionUrlsExtra failed with error %X \n", scRet);
        return;
    }
    
    auto rtspPort = port != 80 ? port : 554;
    scRet = DataBroker_SetConnectionExtraOption(_g_hConn, eOptRtspCtrlPort, rtspPort, 0);
    if (IS_FAIL(scRet))
    {
        printf("DataBroker_SetConnectionExtraOption failed with error %X \n", scRet);
        return;
    }
    
    [self.delegate statusDidChange:self status:StreamingStatusConnecting];
    
    scRet = DataBroker_Connect(_g_hConn);
}

- (void)startLiveStreaming:(NSString *)ip port:(NSInteger)port streamIndex:(NSInteger)streamIndex channelIndex:(NSInteger)channelIndex
{
    NSString *liveUrl = [NSString stringWithFormat:@"/live_stream=%ld_channel=%ld", (long)streamIndex, (long)channelIndex];
    [self startStreaming:ip port:port streamingUrl:liveUrl];
}

- (void)startNVRLiveStreaming:(NSString *)ip port:(NSInteger)port streamIndex:(NSInteger)streamIndex channelIndex:(NSInteger)channelIndex
{
//    NSString *liveUrl = [NSString stringWithFormat:@"/live?stream=%ld&channel=%ld", (long)streamIndex, (long)channelIndex];
    NSString *liveUrl = [NSString stringWithFormat:@"/Media/Live/Normal?camera=C_%ld&streamindex=%ld", (long)channelIndex + 1, (long)streamIndex + 1];
    [self startStreaming:ip port:port streamingUrl:liveUrl];
}

- (void)startPlaybackStreaming:(NSString *)ip port:(NSInteger)port startTime:(NSTimeInterval)startTime isFusion:(BOOL)isFusion
{
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:60*60*24*7];
    NSTimeInterval endTime = [endDate timeIntervalSince1970] * 1000;
    
    NSString *playbackUrl = [NSString stringWithFormat:@"/playback?start=%.0f&end=%.0f&fusion=%s", startTime, endTime, isFusion ? "true" : "false"];
    [self startStreaming:ip port:port streamingUrl:playbackUrl];
}

- (void)startPlaybackStreaming:(NSString *)ip port:(NSInteger)port startTime:(NSTimeInterval)startTime streamIndex:(NSInteger)streamIndex channelIndex:(NSInteger)channelIndex
{
    NSDate *endDate = [[NSDate date] dateByAddingTimeInterval:60*60*24*7];
    NSTimeInterval endTime = [endDate timeIntervalSince1970] * 1000;
    
    NSString *playbackUrl = [NSString stringWithFormat:@"/playback?start=%.0f&end=%.0f&channel=%ld&stream=%ld", startTime, endTime, (long)channelIndex, (long)streamIndex];
//    NSString *playbackUrl = [NSString stringWithFormat:@"/Media/Database/Normal?LOCATION=Loc1&fullspeedbeforejam=yes&knowgoodbye=true&STIME=20230613_000000.000"];
    [self startStreaming:ip port:port streamingUrl:playbackUrl];
}

- (void)changeSpeed:(float)speed
{
    TDataBrokerRTSPPlayOptions tPlayOpions;
    memset(&tPlayOpions, 0, sizeof(tPlayOpions));
    tPlayOpions.fSpeed = speed;
    SCODE scRet = DataBroker_SetRTSPPlayOptions(_g_hConn, &tPlayOpions);
 
    if (IS_FAIL(scRet))
    {
        printf("DataBroker_SetRTSPPlayOptions failed with error %X \n", scRet);
    }
}

- (void)seekTo:(NSTimeInterval)timestamp
{
    NSString *rtspStartTime = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
    NSString *rtspEndTime = [self.dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:(timestamp + 60*60*24*7)]];
    NSString *range = [NSString stringWithFormat:@"clock=%@-%@\r\nImmediate: yes", rtspStartTime, rtspEndTime];
    NSLog(@"seekTo:%@", range);
    
    TDataBrokerRTSPPlayOptions tOpts = {};
    tOpts.pszRange = (char *)[range UTF8String];
    SCODE scRet = DataBroker_SetRTSPPlayOptions(_g_hConn, &tOpts);
    
    if (IS_FAIL(scRet))
    {
        printf("DataBroker_SetRTSPPlayOptions failed with error %X \n", scRet);
        return;
    }
}

- (void)stopStreaming
{
    if (_g_hConn != NULL)
    {
        DataBroker_Disconnect(_g_hConn);
        DataBroker_DeleteConnection(_g_hDataBrokerMgr, &_g_hConn);
        
        _g_hConn = NULL;
    }
}

- (void)pause
{
    if (_g_hConn) {
        DataBroker_PauseMediaStreaming(_g_hConn);
    }
}

- (void)resume
{
    if (_g_hConn) {
        DataBroker_ResumeMediaStreaming(_g_hConn);
    }
}

- (void)releaseHandling
{
    if (_g_hConn != NULL)
    {
        DataBroker_Disconnect(_g_hConn);
        DataBroker_DeleteConnection(_g_hDataBrokerMgr, &_g_hConn);
        _g_hConn = NULL;
    }
    
    if (_g_hDataBrokerMgr)
    {
        DataBroker_Release(&_g_hDataBrokerMgr);
    }
}

@end
