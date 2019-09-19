//
//  ViewController.m
//  SpeechFramework框架_oc
//
//  Created by cui on 2019/9/19.
//  Copyright © 2019 Kitedge. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController ()<SFSpeechRecognizerDelegate>
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *startBtn;
@property (weak, nonatomic) IBOutlet UILabel *tipLabel;

// 创建语音识别器，指定语音识别的语言环境 locale ,将来会转化为什么语言，这里是使用的当前区域，那肯定就是简体汉语
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;

// 语音识别任务，可监控识别进度。通过他可以取消或终止当前的语音识别任务
@property (nonatomic, strong) SFSpeechRecognitionTask *recognitionTask;

// 发起语音识别请求，为语音识别器指定一个音频输入源，这里是在音频缓冲器中提供的识别语音。
// 除 SFSpeechAudioBufferRecognitionRequest 之外还包括：
// SFSpeechRecognitionRequest  从音频源识别语音的请求。
// SFSpeechURLRecognitionRequest 在录制的音频文件中识别语音的请求。
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *recognitionRequest;

// 语音引擎，负责提供录音输入
@property (nonatomic, strong) AVAudioEngine *audioEngine;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.textView.backgroundColor = [UIColor whiteColor];
    self.view.backgroundColor = [UIColor lightGrayColor];


//    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale currentLocale]];
    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh-CN"]];
    self.speechRecognizer.delegate = self;
//    NSLog(@"语音识别器支持的区域：%@",[SFSpeechRecognizer supportedLocales]);
//    NSLog(@"语音识别器支持的区域：%@",self.speechRecognizer.locale);
//    NSLocale *locale  = self.speechRecognizer.locale;
    
    self.audioEngine = [[AVAudioEngine alloc] init];
    
    self.startBtn.enabled = NO;
    
    //  在进行语音识别之前，你必须获得用户的相应授权，因为语音识别并不是在iOS 设备本地进行识别，而是在苹果的伺服器上进行识别的。所有的语音数据都需要传给苹果的后台服务器进行处理。因此必须得到用户的授权,这个方法并不是在主线程运行的。
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        switch (status) {
                //用户未决定
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
            {NSString *text = @"权限提示：用户未决定";
                [self setTioLabelText:text withBtnEnable:NO];}
                break;
                //拒绝
            case SFSpeechRecognizerAuthorizationStatusDenied:
            {NSString *text = @"权限提示：用户拒绝";
                [self setTioLabelText:text withBtnEnable:NO];}
                break;
                //不支持
            case SFSpeechRecognizerAuthorizationStatusRestricted:
            {NSString *text = @"权限提示：用户的设备不支持";
                [self setTioLabelText:text withBtnEnable:NO];}
                break;
                //允许
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
            {
                NSString *text = @"权限提示：用户允许";
                [self setTioLabelText:text withBtnEnable:YES];
                
            }
                break;
            default:
                break;
        }
    }];
}

- (void)setTioLabelText:(NSString *)text withBtnEnable:(BOOL)enAble{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tipLabel.text = text;
        self.startBtn.enabled = enAble;
    });
}


- (void)startRecordingPersonSpeech{
    // 检查 recognitionTask 任务是否处于运行状态。如果是，取消任务开始新的任务
    if (self.recognitionTask != nil) {
        // 取消当前语音识别任务
        [self.recognitionTask cancel];
        NSLog(@"语音识别任务的当前状态 : %ld",(long)self.recognitionTask.state);
        self.recognitionTask = nil;
    }
    
    // 建立一个AVAudioSession 用于录音
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // category 设置为 record,录音
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    // mode 设置为 measurement
    [audioSession setMode:AVAudioSessionModeMeasurement error:nil];
    // 开启 audioSession
    [audioSession setActive:YES error:nil];
    
    // 初始化RecognitionRequest，在后边我们会用它将录音数据转发给苹果服务器
    self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    
    // 检查 iPhone 是否有有效的录音设备
    AVAudioInputNode *inputNode = self.audioEngine.inputNode;
    if (!inputNode) {
        self.tipLabel.text = @"无效的录音设备";
    }

    // 在用户说话的同时，将识别结果分批次返回
    self.recognitionRequest.shouldReportPartialResults = YES;
    
    // 使用recognitionTask方法开始识别。
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        // 用于检查识别是否结束
        BOOL isFinal = NO;
        if (result != nil) {
            // 将 textView.text 设置为 result 的最佳音译
            self.textView.text = result.bestTranscription.formattedString;
            
            // 如果 result 是最终，将 isFinal 设置为 true
            isFinal = result.isFinal;
        }
        
        // 如果没有错误发生，或者 result 已经结束，停止audioEngine 录音，终止 recognitionRequest 和 recognitionTask
        if (error != nil || isFinal) {
            [self.audioEngine stop];
            [inputNode removeTapOnBus:0];
            
            self.recognitionRequest = nil;
            self.recognitionTask = nil;
            
            // 开始录音按钮可用
            self.startBtn.enabled = YES;
        }
    }];
    
    // 向recognitionRequest加入一个音频输入
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [self.recognitionRequest appendAudioPCMBuffer:buffer];
    }];
    
    [self.audioEngine prepare];
    
    [self.audioEngine startAndReturnError:nil];
    
    self.textView.text = @"请讲话...";
}

- (IBAction)startBtnClick:(id)sender {
    if (self.audioEngine.isRunning) {
        // 停止录音
        [self.audioEngine stop];
        // 表示音频源已完成，并且不会再将音频附加到识别请求。
        [self.recognitionRequest endAudio];
        self.startBtn.enabled = NO;
        [self.startBtn setTitle:@"开始" forState:UIControlStateNormal];
    }else{
        [self startRecordingPersonSpeech];
        [self.startBtn setTitle:@"结束" forState:UIControlStateNormal];
    }
}

//在创建语音识别任务时，我们首先得确保语音识别的可用性，需要实现delegate 方法。如果语音识别不可用，或是改变了状态，应随之设置 按钮的enable
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available{
    if (available) {
        self.startBtn.enabled = YES;
    }else{
        self.startBtn.enabled = NO;
    }
}

@end




/*
 * 检查 recognitionTask 的运行状态，如果正在运行，取消任务。
 
 * 创建一个 AVAudioSession 对象为音频录制做准备。这里我们将录音分类设置为 Record，模式设为 Measurement，然后启动。注意，设置这些属性有可能会抛出异常，因此你必须将其置于 try catch 语句中。
 
 * 实例化 recognitionResquest。创建 SFSpeechAudioBufferRecognitionRequest 对象，然后我们就可以利用它将音频数据传输到 Apple 的服务器。
 
 * 检查 audioEngine (你的设备)是否支持音频输入以录音。如果不支持，报一个 fatal error。
 
 * 检查 recognitionRequest 对象是否已被实例化，并且值不为 nil。
 
 * 告诉 recognitionRequest 不要等到录音完成才发送请求，而是在用户说话时一部分一部分发送语音识别数据。
 
 * 在调用 speechRecognizer 的 recognitionTask 函数时开始识别。该函数有一个完成回调函数，每次识别引擎收到输入时都会调用它，在修改当前识别结果，亦或是取消或停止时，返回一个最终记录。
 
 * 定义一个 boolean 变量来表示识别是否已结束。
 
 * 倘若结果非空，则设置 textView.text 属性为结果中的最佳记录。同时若为最终结果，将 isFinal 置为 true。
 
 * 如果请求没有错误或已经收到最终结果，停止 audioEngine (音频输入)，recognitionRequest 和 recognitionTask。同时，将开始录音按钮的状态切换为可用。
 
 * 向 recognitionRequest 添加一个音频输入。值得留意的是，在 recognitionTask 启动后再添加音频输入完全没有问题。Speech 框架会在添加了音频输入之后立即开始识别任务。
 
 * 将 audioEngine 设为准备就绪状态，并启动引擎。
 */
