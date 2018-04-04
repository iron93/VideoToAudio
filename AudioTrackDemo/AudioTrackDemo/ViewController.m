//
//  ViewController.m
//  AudioTrackDemo
//
//  Created by iron on 17/3/28.
//  Copyright © 2017年 iron. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController ()<AVAudioPlayerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *playerBtn;
@property (strong, nonatomic)AVAudioPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.playerBtn.enabled = NO;

}

- (IBAction)convert:(UIButton *)sender {
    
    [self convertVideo:sender];
    
}
- (IBAction)play:(UIButton *)sender
{
    sender.enabled = NO;
    
    NSString *storePath = nil;
    
    NSString *path  = [[NSBundle mainBundle] resourcePath];
    
    NSRange range = [path rangeOfString:@"/" options:NSBackwardsSearch];
    
    if (range.location != NSNotFound) {
        
        NSString *pathRoot = [path substringToIndex:range.location];
        

        storePath = [pathRoot stringByAppendingPathComponent:@"copy.wav"];
        
    }
    
    
    NSURL *exportURL = [NSURL fileURLWithPath:storePath];

    NSError *error;

    self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:exportURL error:&error];
    
    if (error)
    {
        NSLog(@"%@",error);
    }

    self.player.delegate = self;
    
    [self.player play];
}


- (void)convertVideo:(UIButton *)sender
{
    sender.enabled = NO;
    
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"shark" ofType:@"mp4"];
    
    NSURL *videoUrl = [NSURL fileURLWithPath:videoPath];
    
    AVAsset *songAsset = [AVAsset assetWithURL:videoUrl]; //获取文件
    
    AVAssetTrack *track = [[songAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    
    //读取配置
    NSDictionary *dic = @{AVFormatIDKey :@(kAudioFormatLinearPCM),
                          AVLinearPCMIsBigEndianKey:@NO,    // 小端存储
                          AVLinearPCMIsFloatKey:@NO,    //采样信号是整数
                          AVLinearPCMBitDepthKey :@(16)  //采样位数默认 16
                          };
    
    
    NSError *error;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error]; //创建读取
    if (!reader) {
        NSLog(@"%@",[error localizedDescription]);
    }
    //读取输出，在相应的轨道上输出对应格式的数据
    AVAssetReaderTrackOutput *readerOutput = [[AVAssetReaderTrackOutput alloc]initWithTrack:track outputSettings:dic];
    
    //赋给读取并开启读取
    [reader addOutput:readerOutput];
    
    // writer
    NSError *writerError = nil;
    
    NSString *storePath = nil;
    
    NSString *path  = [[NSBundle mainBundle] resourcePath];
    
    NSRange range = [path rangeOfString:@"/" options:NSBackwardsSearch];
    
    if (range.location != NSNotFound) {
        
        NSString *pathRoot = [path substringToIndex:range.location];
        
        storePath = [pathRoot stringByAppendingPathComponent:@"copy.wav"];
        
    }
    
    
    NSURL *exportURL = [NSURL fileURLWithPath:storePath];
    
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:exportURL
                                                      fileType:AVFileTypeAppleM4A
                                                         error:&writerError];
    
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    
    // use different values to affect the downsampling/compression
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                    [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                    [NSNumber numberWithInt:128000], AVEncoderBitRateKey,
                                    [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                    nil];
    
    AVAssetWriterInput *writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                                     outputSettings:outputSettings];
    [writerInput setExpectsMediaDataInRealTime:NO];
    [writer addInput:writerInput];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    [reader startReading];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    [writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        
        NSLog(@"Asset Writer ready : %d", writerInput.readyForMoreMediaData);
        while (writerInput.readyForMoreMediaData) {
            CMSampleBufferRef nextBuffer;
            if ([reader status] == AVAssetReaderStatusReading && (nextBuffer = [readerOutput copyNextSampleBuffer])) {
                if (nextBuffer) {
                    NSLog(@"Adding buffer");
                    
                    [writerInput appendSampleBuffer:nextBuffer];
                }
            } else {
                [writerInput markAsFinished];
                
                switch ([reader status])
                {
                    case AVAssetReaderStatusReading:
                        
                        break;
                    case  AVAssetReaderStatusUnknown:
                        break;
                    case  AVAssetReaderStatusCancelled:
                        break;
                    case AVAssetReaderStatusFailed:
                        [writer cancelWriting];
                        break;
                    case AVAssetReaderStatusCompleted:
                        NSLog(@"Writer completed");
                    
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            sender.enabled = NO;
                            [sender setTitle:@"完成" forState:UIControlStateDisabled];
                            self.playerBtn.enabled = YES;
                        });
                       
                        [writer endSessionAtSourceTime:songAsset.duration];
                        [writer finishWritingWithCompletionHandler:^{
                            
                        }];
                        [reader cancelReading];
                        break;
                }
                break;
            }
        }
    }];

}




- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"stop");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




@end
