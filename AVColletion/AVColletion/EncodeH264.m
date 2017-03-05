//
//  EncodeH264.m
//  AVColletion
//
//  Created by Tg W on 2017/3/5.
//  Copyright © 2017年 oppsr. All rights reserved.
//

#import "EncodeH264.h"


@interface EncodeH264 (){
    
    dispatch_queue_t encodeQueue;
    FILE *file;
    long timeStamp;
    VTCompressionSessionRef encodeSesion;//压缩会话
    NSString *documentDic;
}
@property (nonatomic , assign) BOOL isObtainspspps;//判断是否已经获取到pps和sps
- (void) writeH264Data:(void*)data length:(size_t)length addStartCode:(BOOL)b;

@end

/**
 编码回调
 
 @param userData 回调参考值
 @param sourceFrameRefCon 帧的引用值
 @param status noErr代表压缩成功; 如果压缩不成功，则为错误代码。
 @param infoFlags 编码操作的信息
 @param sampleBuffer 包含压缩帧，如果压缩成功并且帧未被删除; 否则为NULL。
 
 */
void encodeOutputCallback(void *userData, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                          CMSampleBufferRef sampleBuffer )
{
    if (status != noErr) {
        NSLog(@"didCompressH264 error: with status %d, infoFlags %d", (int)status, (int)infoFlags);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    EncodeH264 *h264 = (__bridge EncodeH264*)userData;
    
    // 判断当前帧是否为关键帧
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    // 获取sps & pps数据. sps pps只需获取一次，保存在h264文件开头即可
    if (keyframe && !h264.isObtainspspps)
    {
        size_t spsSize, spsCount;
        size_t ppsSize, ppsCount;
        
        const uint8_t *spsData, *ppsData;
        
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        OSStatus err0 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 0, &spsData, &spsSize, &spsCount, 0 );
        OSStatus err1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 1, &ppsData, &ppsSize, &ppsCount, 0 );
        
        if (err0==noErr && err1==noErr)
        {
            h264.isObtainspspps = YES;
            [h264 writeH264Data:(void *)spsData length:spsSize addStartCode:YES];
            [h264 writeH264Data:(void *)ppsData length:ppsSize addStartCode:YES];
            
            NSLog(@"got sps/pps data. Length: sps=%zu, pps=%zu", spsSize, ppsSize);
        }
    }
    
    size_t lengthAtOffset, totalLength;
    char *data;
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    OSStatus error = CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &data);
    
    if (error == noErr) {
        size_t offset = 0;
        const int lengthInfoSize = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (offset < totalLength - lengthInfoSize) {
            uint32_t naluLength = 0;
            memcpy(&naluLength, data + offset, lengthInfoSize); // 获取nalu的长度，
            
            // 大端模式转化为系统端模式
            naluLength = CFSwapInt32BigToHost(naluLength);
            NSLog(@"got nalu data, length=%d, totalLength=%zu", naluLength, totalLength);
            
            // 保存nalu数据到文件
            [h264 writeH264Data:data+offset+lengthInfoSize length:naluLength addStartCode:YES];
            
            // 读取下一个nalu，一次回调可能包含多个nalu
            offset += lengthInfoSize + naluLength;
        }
    }
}

@implementation EncodeH264

- (instancetype)init {
    
    if ([super init]) {
        encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        timeStamp = 0;
        documentDic = [(NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES)) objectAtIndex:0];
    }
    return self;
}

- (BOOL)createEncodeSession:(int)width height:(int)height fps:(int)fps bite:(int)bt {
    
    OSStatus status;
    
    //帧压缩完成时调用的回调原型。
    VTCompressionOutputCallback cb = encodeOutputCallback;
    //创建压缩视频帧的会话。
    status = VTCompressionSessionCreate(kCFAllocatorDefault, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, cb, (__bridge void *)(self), &encodeSesion);
    
    if (status != noErr) {
        NSLog(@"VTCompressionSessionCreate failed. ret=%d", (int)status);
        return NO;
    }
    
    //******设置会话的属性******
    //提示视频编码器，压缩是否实时执行。
    status = VTSessionSetProperty(encodeSesion, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    NSLog(@"set realtime  return: %d", (int)status);
    
    //指定编码比特流的配置文件和级别。直播一般使用baseline，可减少由于b帧带来的延时
    status = VTSessionSetProperty(encodeSesion, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    NSLog(@"set profile   return: %d", (int)status);
    
    //设置比特率。 比特率可以高于此。默认比特率为零，表示视频编码器。应该确定压缩数据的大小。注意，比特率设置只在定时时有效，为源帧提供信息，并且一些编解码器提供不支持限制到指定的比特率。
    status  = VTSessionSetProperty(encodeSesion, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bt));
    //速率的限制
    status += VTSessionSetProperty(encodeSesion, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(bt*2/8), @1]); // Bps
    NSLog(@"set bitrate   return: %d", (int)status);
    
    // 设置关键帧速率。
    status = VTSessionSetProperty(encodeSesion, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(fps*2));
    
    // 设置预期的帧速率。
    status = VTSessionSetProperty(encodeSesion, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(fps));
    NSLog(@"set framerate return: %d", (int)status);
    
    // 开始编码
    status = VTCompressionSessionPrepareToEncodeFrames(encodeSesion);
    NSLog(@"start encode  return: %d", (int)status);
    
    return YES;

}
//保存h264数据到沙盒中document，可以下载TCL播放器播放
- (void)writeH264Data:(void*)data length:(size_t)length addStartCode:(BOOL)b
{
    // 添加start code
    const Byte bytes[] = "\x00\x00\x00\x01";
    
    if (file) {
        if(b)fwrite(bytes, 1, 4, file);
        fwrite(data, 1, length, file);
    } else {
        NSLog(@"file null error, check if it open successed");
    }
}
- (void) stopEncodeSession
{
    VTCompressionSessionCompleteFrames(encodeSesion, kCMTimeInvalid);
    
    VTCompressionSessionInvalidate(encodeSesion);
    
    CFRelease(encodeSesion);
    encodeSesion = NULL;
}

- (void)encodeSmapleBuffer:(CMSampleBufferRef)sampleBuffer {
 
    dispatch_sync(encodeQueue, ^{
        //CVImageBuffer的媒体数据。
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        // 此帧的呈现时间戳，将附加到样本缓冲区，传递给会话的每个显示时间戳必须大于上一个。
        timeStamp ++;
        CMTime pts = CMTimeMake(timeStamp, 1000);
        //此帧的呈现持续时间
        CMTime duration = kCMTimeInvalid;
        VTEncodeInfoFlags flags;
        // 调用此函数可将帧呈现给压缩会话。
        OSStatus statusCode = VTCompressionSessionEncodeFrame(encodeSesion,
                                                              imageBuffer,
                                                              pts, duration,
                                                              NULL, NULL, &flags);
        
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            
            [self stopEncodeSession];
            return;
        }
    });
}

- (void)openfile {
   
    file = fopen([[NSString stringWithFormat:@"%@/video.h264",documentDic] UTF8String], "wb");
}
- (void)closefile {
    
    fclose(file);
}
@end
