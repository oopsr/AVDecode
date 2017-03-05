//
//  EncoderAAC.m
//  AVColletion
//
//  Created by Tg W on 2017/3/4.
//  Copyright © 2017年 oppsr. All rights reserved.
//

#import "EncoderAAC.h"

typedef struct {
    // pcm数据指针
    void *source;
    // pcm数据的长度
    UInt32 sourceSize;
    // 声道数
    UInt32 channelCount;
    
    AudioStreamPacketDescription *packetDescription;
}FillComplexInputParm;

typedef struct {
    AudioConverterRef converter;
    int samplerate;
    int channles;
}ConverterContext;

// AudioConverter的提供数据的回调函数
OSStatus audioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,UInt32 * ioNumberDataPacket,AudioBufferList *ioData,AudioStreamPacketDescription ** outDataPacketDescription,void *inUserData){
    // ioData用来接受需要转换的pcm数据給converter进行编码
    
    FillComplexInputParm *param = (FillComplexInputParm *)inUserData;
    if (param->sourceSize <= 0) {
        *ioNumberDataPacket = 0;
        return  - 1;
    }
    ioData->mBuffers[0].mData = param->source;
    ioData->mBuffers[0].mDataByteSize = param->sourceSize;
    ioData->mBuffers[0].mNumberChannels = param->channelCount;
    *ioNumberDataPacket = 1;
    param->sourceSize = 0;
    return noErr;
}
@interface EncoderAAC (){
     ConverterContext *convertContext;
     dispatch_queue_t encodeQueue;
}
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSFileHandle *handle;
@end
@implementation EncoderAAC

- (instancetype)init {
    
    if ( self = [super init]) {
        encodeQueue = dispatch_queue_create("myencode", DISPATCH_QUEUE_SERIAL);
        //保存aac数据到沙盒中document，可以iTunes播放
        self.path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"audio.aac"];
        NSFileManager *manager = [NSFileManager defaultManager];
        BOOL a =  [manager createFileAtPath:_path contents:nil attributes:nil];
        if (a) {
            NSLog(@"creat file success");
        }else{
            NSLog(@"creat file fail");
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:_path];
        self.handle = handle;
        
    }
    return self;
}

- (void)setUpConverter:(CMSampleBufferRef)sampleBuffer{
    // 获取audioformat的描述信息
    CMAudioFormatDescriptionRef audioFormatDes =  (CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer);
    // 获取输入的asbd的信息
    AudioStreamBasicDescription inAudioStreamBasicDescription = *(CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDes));
    //  开始构造输出的asbd
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0};
    // 对于压缩格式必须设置为0
    outAudioStreamBasicDescription.mBitsPerChannel = 0;
    outAudioStreamBasicDescription.mBytesPerFrame = 0;
    // 设定声道数为1
    outAudioStreamBasicDescription.mChannelsPerFrame = 1;
    // 设定输出音频的格式
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC;
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC;
    // 填充输出的音频格式
    UInt32 size = sizeof(outAudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &outAudioStreamBasicDescription);
    // 选择aac的编码器（用来描述一个已经安装的编解码器）
    AudioClassDescription audioClassDes;
    // 初始化为0
    memset(&audioClassDes, 0, sizeof(audioClassDes));
    // 获取满足要求的aac编码起的总大小
    UInt32 countSize  = 0;
    AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(outAudioStreamBasicDescription.mFormatID), &outAudioStreamBasicDescription.mFormatID, &countSize);
    // 用来计算aac的编解码器的个数
    int cout = countSize / sizeof(audioClassDes);
    // 创建一个包含有cout个数的编码器数组
    AudioClassDescription descriptions[cout];
    // 将编码起数组信息写入到descriptions中。
    AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(outAudioStreamBasicDescription.mFormatID), &outAudioStreamBasicDescription.mFormatID, &countSize, descriptions);
    for (int i = 0; i < cout; cout++) {
        AudioClassDescription temp  = descriptions[i];
        if (temp.mManufacturer == kAppleSoftwareAudioCodecManufacturer && temp.mSubType ==outAudioStreamBasicDescription.mFormatID) {
            audioClassDes = temp;
            break;
        }
    }
    // 创建convertcontext用来保存converter的信息
    ConverterContext *context = malloc(sizeof(ConverterContext));
    self->convertContext = context;
    OSStatus result = AudioConverterNewSpecific(&inAudioStreamBasicDescription, &outAudioStreamBasicDescription, 1, &audioClassDes, &(context->converter));
    if (result == noErr) {
        // 创建编解码器成功
        AudioConverterRef converter = context->converter;
        
        // 设置编码起属性
        UInt32 temp = kAudioConverterQuality_High;
        AudioConverterSetProperty(converter, kAudioConverterCodecQuality, sizeof(temp), &temp);
        
        // 设置比特率
        UInt32 bitRate = 96000;
        result = AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate);
        if (result != noErr) {
            NSLog(@"设置比特率失败");
        }
    }else{
        // 创建编解码器失败
        free(context);
        context = NULL;
        NSLog(@"创建编解码器失败");
    }
}


// 编码samplebuffer数据
-(void)encodeSmapleBuffer:(CMSampleBufferRef)sampleBuffer{
   
    if (!self->convertContext) {
        [self setUpConverter:sampleBuffer];
    }
    ConverterContext *cxt = self->convertContext;
    if (cxt && cxt->converter) {
        // 从samplebuffer中提取数据
        CFRetain(sampleBuffer);
        dispatch_async(encodeQueue, ^{
            // 从samplebuffer众获取blockbuffer
            CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
            size_t  pcmLength = 0;
            char * pcmData = NULL;
            // 获取blockbuffer中的pcm数据的指针和长度
            OSStatus status =  CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &pcmLength, &pcmData);
            if (status != noErr) {
                NSLog(@"从block众获取pcm数据失败");
                CFRelease(sampleBuffer);
                return ;
            }else{
                // 在堆区分配内存用来保存编码后的aac数据
                char *outputBuffer = malloc(pcmLength);
                memset(outputBuffer, 0, pcmLength);
                
                UInt32 packetSize = 1;
                AudioStreamPacketDescription *outputPacketDes = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * packetSize);
                // 使用fillcomplexinputparm来保存pcm数据
                FillComplexInputParm userParam;
                userParam.source = pcmData;
                userParam.sourceSize = (UInt32)pcmLength;
                userParam.channelCount = 1;
                userParam.packetDescription = NULL;
                
                // 在堆区创建audiobufferlist
                //                AudioBufferList *bufferList = malloc(sizeof(AudioBufferList));
                AudioBufferList outputBufferList;
                outputBufferList.mNumberBuffers = 1;
                outputBufferList.mBuffers[0].mData = outputBuffer;
                outputBufferList.mBuffers[0].mDataByteSize = pcmLength;
                outputBufferList.mBuffers[0].mNumberChannels = 1;
                
                status = AudioConverterFillComplexBuffer(convertContext->converter, audioConverterComplexInputDataProc, &userParam, &packetSize, &outputBufferList, outputPacketDes);
                free(outputPacketDes);
                outputPacketDes = NULL;
                if (status == noErr) {
                    static int64_t totoalLength = 0;
                    if (totoalLength >= 1024 * 1024 * 1) {
                        return;
                    }
                    NSLog(@"编码成功");
                    // 获取原始的aac数据
                    NSData *rawAAC = [NSData dataWithBytes:outputBufferList.mBuffers[0].mData length:outputBufferList.mBuffers[0].mDataByteSize];
                    free(outputBuffer);
                    outputBuffer = NULL;
                    
                    //  设置adts头
                    int headerLength = 0;
                    char *packetHeader = newAdtsDataForPacketLength(rawAAC.length, 44100, 1, &headerLength);
                    NSData *adtsHeader = [NSData dataWithBytes:packetHeader length:headerLength];
                    free(packetHeader);
                    packetHeader = NULL;
                    NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
                    [fullData appendData:rawAAC];
                    [_handle seekToEndOfFile];
                    [_handle writeData:fullData];
                    fullData = nil;
                    rawAAC = nil;
                    totoalLength+=fullData.length;
                    if (totoalLength >= 1024 * 1024 *1) {
                        [_handle closeFile];
                    }
                }
                CFRelease(sampleBuffer);
                
            }
        });
    }
}
// 給aac加上adts头, packetLength 为rewaac的长度，
char *newAdtsDataForPacketLength(int packetLength,int sampleRate,int channelCout, int *ioHeaderLen){
    // adts头的长度为固定的7个字节
    int adtsLen = 7;
    // 在堆区分配7个字节的内存
    char *packet = malloc(sizeof(char) * adtsLen);
    // 选择AAC LC
    int profile = 2;
    // 选择采样率对应的下标
    int freqIdx = 4;
    // 选择声道数所对应的下标
    int chanCfg = 1;
    // 获取adts头和raw aac的总长度
    NSUInteger fullLength = adtsLen + packetLength;
    // 设置syncword
    packet[0] = 0xFF;
    packet[1] = 0xF9;
    packet[2] = (char)(((profile - 1)<<6) + (freqIdx<<2)+(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6)+(fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF)>>3);
    packet[5] = (char)(((fullLength&7)<<5)+0x1F);
    packet[6] = (char)0xFC;
    *ioHeaderLen =adtsLen;
    return packet;
}
@end
