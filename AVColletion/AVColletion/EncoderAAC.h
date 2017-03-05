//
//  EncoderAAC.h
//  AVColletion
//
//  Created by Tg W on 2017/3/4.
//  Copyright © 2017年 oppsr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
@interface EncoderAAC : NSObject
-(void)encodeSmapleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
