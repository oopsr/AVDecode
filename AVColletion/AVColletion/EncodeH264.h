//
//  EncodeH264.h
//  AVColletion
//
//  Created by Tg W on 2017/3/5.
//  Copyright © 2017年 oppsr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
@interface EncodeH264 : NSObject


/**
 创建压缩视频帧的会话

 @param width 宽度（以像素为单位）。如果视频编码器不能支持所提供的宽度和高度，则可以更改它们。
 @param height 高度
 @param fps 帧速率
 @param bt 比特率，表示视频编码器。应该确定压缩数据的大小。
 @return 会话创建是否成功，成功返回YES。
 */
- (BOOL)createEncodeSession:(int)width height:(int)height fps:(int)fps bite:(int)bt;


- (void)encodeSmapleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)openfile;

- (void)closefile;
@end
