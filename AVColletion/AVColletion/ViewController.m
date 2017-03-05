//
//  ViewController.m
//  AVColletion
//
//  Created by Tg W on 2017/3/1.
//  Copyright © 2017年 oppsr. All rights reserved.
//

#import "ViewController.h"
#import "MyCaptureSession.h"
#import "EncoderAAC.h"
#import "EncodeH264.h"
@interface ViewController ()<MycaptureSessionDelegate> {
    
    EncoderAAC *_aac;
    EncodeH264 *_h264;
}
@property (nonatomic, strong) MyCaptureSession *captureSession;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //初始化音频编码
    _aac = [[EncoderAAC alloc] init];
    //初始化视频编码
    _h264 = [[EncodeH264 alloc] init];
    //创建视频解码会话
    [_h264 createEncodeSession:480 height:640 fps:25 bite:640*1000];
    //创建音视频采集会话
    _captureSession = [[MyCaptureSession alloc]initCaptureWithSessionPreset:CaptureSessionPreset640x480];
    //采集代理
    _captureSession.delegate = self;
    
    AVCaptureVideoPreviewLayer *preViewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession.session];
    //创建视频展示layer
    preViewLayer.frame = CGRectMake(0.f, 0.f, self.view.bounds.size.width, self.view.bounds.size.height);
    // 设置layer展示视频的方向
    preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:preViewLayer];
    [self.view bringSubviewToFront:self.startBtn];

}

- (IBAction)startCode:(UIButton *)sender {
    
    sender.selected = !sender.selected;
    if (sender.selected) {
        //存储操作其实可以提取出来
        [_h264 openfile];
        [_captureSession start];
        [sender setTitle:@"停止编码" forState:UIControlStateNormal];
        
    }else {
        [_h264 closefile];
        [_captureSession stop];
        [sender setTitle:@"开始编码" forState:UIControlStateNormal];
    }

}

- (void)audioWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    [_aac encodeSmapleBuffer:sampleBuffer];
}

- (void)videoWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    [_h264 encodeSmapleBuffer:sampleBuffer];
}


@end
