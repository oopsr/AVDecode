//
//  MyCaptureSession.m
//  AVColletion
//
//  Created by Tg W on 2017/3/1.
//  Copyright © 2017年 oppsr. All rights reserved.
//

#import "MyCaptureSession.h"

@interface MyCaptureSession()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic ,strong) AVCaptureDevice *videoDevice; //设备
@property (nonatomic ,strong) AVCaptureDevice *audioDevice;

@property (nonatomic ,strong) AVCaptureDeviceInput *videoInput;//输入对象
@property (nonatomic ,strong) AVCaptureDeviceInput *audioInput;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;//输出对象
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;

@property (nonatomic, assign) CaptureSessionPreset definePreset;
@property (nonatomic, strong) NSString *realPreset;
@end
@implementation MyCaptureSession

- (instancetype)initCaptureWithSessionPreset:(CaptureSessionPreset)preset {
    
    if ([super init]) {
        
        [self initAVcaptureSession];
        _definePreset = preset;
    }
    return self;
}

- (void)initAVcaptureSession {
    
    //初始化AVCaptureSession
    _session = [[AVCaptureSession alloc] init];
    // 设置录像分辨率
    if (![self.session canSetSessionPreset:self.realPreset]) {
        if (![self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
            if (![self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            }
        }
    }
    
    //开始配置
    [_session beginConfiguration];
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    //获取视频设备对象
    for(AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            self.videoDevice = device;//前置摄像头

        }
    }
    //初始化视频捕获输入对象
    NSError *error;
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.videoDevice error:&error];
    if (error) {
        NSLog(@"摄像头错误");
        return;
    }
    //输入对象添加到Session
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    //输出对象
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    //是否卡顿时丢帧
    self.videoOutput.alwaysDiscardsLateVideoFrames = NO;
    // 设置像素格式
    [self.videoOutput setVideoSettings:@{
                                         (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                                         }];
    //将输出对象添加到队列、并设置代理
    dispatch_queue_t captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self.videoOutput setSampleBufferDelegate:self queue:captureQueue];
    
    // 判断session 是否可添加视频输出对象
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
        // 链接视频 I/O 对象
    }
    //创建连接  AVCaptureConnection输入对像和捕获输出对象之间建立连接。
    AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    //视频的方向
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    //设置稳定性，判断connection连接对象是否支持视频稳定
    if ([connection isVideoStabilizationSupported]) {
        //这个稳定模式最适合连接
        connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    //缩放裁剪系数
    connection.videoScaleAndCropFactor = connection.videoMaxScaleAndCropFactor;
    
//***************音频设置***********

    NSError *error1;
    //获取音频设备对象
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    //初始化捕获输入对象
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&error];
    if (error1) {
        NSLog(@"== 录音设备出错");
    }
    // 添加音频输入对象到session
    if ([self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
    }
    //初始化输出捕获对象
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    // 添加音频输出对象到session
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    
    // 创建设置音频输出代理所需要的线程队列
    dispatch_queue_t audioQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    [self.audioOutput setSampleBufferDelegate:self queue:audioQueue];    // 提交配置
    [self.session commitConfiguration];

}

- (NSString*)realPreset {
    switch (_definePreset) {
            case CaptureSessionPreset640x480:
                _realPreset = AVCaptureSessionPreset640x480;
                break;
            case CaptureSessionPresetiFrame960x540:
                _realPreset = AVCaptureSessionPresetiFrame960x540;
    
                break;
            case CaptureSessionPreset1280x720:
                _realPreset = AVCaptureSessionPreset1280x720;
    
                break;
            default:
                _realPreset = AVCaptureSessionPreset640x480;
    
                break;
        }
    
    return _realPreset;
}

- (void)start {
    
    [self.session startRunning];

}
- (void)stop {
    
    [self.session stopRunning];
}
- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (captureOutput == self.audioOutput) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(audioWithSampleBuffer:)]) {
            [self.delegate audioWithSampleBuffer:sampleBuffer];
        }
    }else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoWithSampleBuffer:)]) {
            [self.delegate videoWithSampleBuffer:sampleBuffer];
        }
    }
    
}
@end
