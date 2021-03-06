//
//  QUEditViewController.m
//  AliyunVideo
//
//  Created by Vienta on 2017/3/6.
//  Copyright (C) 2010-2017 Alibaba Group Holding Limited. All rights reserved.
//
#import <AliyunVideoSDKPro/AliyunPasterManager.h>
#import <AliyunVideoSDKPro/AliyunEditor.h>
#import <AliyunVideoSDKPro/AliyunEditor.h>
#import <AliyunVideoSDKPro/AliyunEffectMusic.h>
#import <AliyunVideoSDkPro/AliyunPasterBaseView.h>
#import <AliyunVideoSDkPro/AliyunClip.h>
#import <AliyunVideoSDKPro/AVAsset+AliyunSDKInfo.h>
#import <AliyunVideoSDKPro/AliyunNativeParser.h>
#import <AliyunVideoSDKPro/AliyunImporter.h>
#import <AliyunVideoSDKPro/AliyunErrorCode.h>
#import "AliyunEditViewController.h"
#import "AliyunTimelineView.h"
#import "AliyunEditButtonsView.h"
#import "AliyunEditHeaderView.h"
#import "AliyunTabController.h"
#import "AliyunPasterView.h"
#import "AliyunPasterTextInputView.h"
#import "AliyunEditZoneView.h"
#import "AliyunPasterShowView.h"
#import "AliyunEffectMoreViewController.h"
#import "AliyunEffectMVView.h"
#import "AliyunEffectCaptionShowView.h"
#import "AliyunEffectMVView.h"
#import "AliyunEffectMusicView.h"
#import "AliyunTimelineItem.h"
#import "AliyunTimelineMediaInfo.h"
#import "AliyunPathManager.h"
#import "AliyunEffectFontInfo.h"
#import "AliyunDBHelper.h"
#import "AliyunResourceFontDownload.h"
#import "MBProgressHUD.h"
#import "AliyunPaintEditView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "AliyunCustomFilter.h"
#import "AVAsset+VideoInfo.h"
#import "AliyunPublishViewController.h"
#import "AliyunEffectFilterView.h"
#import "AliyunEffectTimeFilterView.h"
#import "AliyunCompressManager.h"
#import "AVC_ShortVideo_Config.h"
typedef enum : NSUInteger {
    AliyunEditSouceClickTypeNone = 0,
    AliyunEditSouceClickTypeFilter,
    AliyunEditSouceClickTypePaster,
    AliyunEditSouceClickTypeSubtitle,
    AliyunEditSouceClickTypeMV,
    AliyunEditSouceClickTypeMusic,
    AliyunEditSouceClickTypePaint,
    AliyunEditSouceClickTypeTimeFilter
} AliyunEditSouceClickType;

typedef struct _AliyunPasterRange {
    CGFloat startTime;
    CGFloat duration;
} AliyunPasterRange;

extern NSString * const AliyunEffectResourceDeleteNoti;

//TODO:此类需再抽一层,否则会太庞大
@interface AliyunEditViewController () <AliyunIExporterCallback, AliyunIPlayerCallback>

@property (nonatomic, strong) UIView *movieView;
@property (nonatomic, strong) AliyunTimelineView *timelineView;
@property (nonatomic, strong) AliyunEditButtonsView *editButtonsView;
@property (nonatomic, strong) AliyunEditHeaderView *editHeaderView;
@property (nonatomic, strong) AliyunTabController *tabController;
@property (nonatomic, strong) UIButton *backgroundTouchButton;
@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UIButton *playButton;

@property (nonatomic, strong) AliyunPasterManager *pasterManager;
@property (nonatomic, strong) AliyunEditZoneView *editZoneView;
@property (nonatomic, strong) AliyunEditor *editor;
@property (nonatomic, strong) id<AliyunIPlayer> player;
@property (nonatomic, strong) id<AliyunIExporter> exporter;
@property (nonatomic, strong) id<AliyunIClipConstructor> clipConstructor;
@property (nonatomic, strong) AliyunEffectImage *paintImage;

@property (nonatomic, strong) AliyunEffectMVView *mvView;
@property (nonatomic, strong) AliyunEffectFilterView *filterView;
@property (nonatomic, strong) AliyunEffectTimeFilterView *timeFilterView;
@property (nonatomic, strong) AliyunEffectMusicView *musicView;
@property (nonatomic, strong) AliyunPasterShowView *pasterShowView;
@property (nonatomic, strong) AliyunEffectCaptionShowView *captionShowView;
@property (nonatomic, strong) AliyunPaintEditView *paintShowView;
@property (nonatomic, strong) AliyunDBHelper *dbHelper;

@property (nonatomic, assign) BOOL isExporting;
//@property (nonatomic, assign) BOOL isExported;
@property (nonatomic, assign) BOOL isPublish;
@property (nonatomic, assign) BOOL isAddMV;
@property (nonatomic, assign) BOOL isBackground;
@property (nonatomic, assign) BOOL editorError;
@property (nonatomic, assign) CGSize outputSize;
@property (nonatomic, strong) AliyunCustomFilter *filter;
@property (nonatomic, strong) UIButton *staticImageButton;
// 倒播相关
@property (nonatomic, strong) AliyunNativeParser *parser;
@property (nonatomic, assign) BOOL invertAvailable; // 视频是否满足倒播条件
@property (nonatomic, strong) AliyunCompressManager *compressManager;
//动效滤镜
@property (nonatomic, strong) NSMutableArray *animationFilters;

@end

@implementation AliyunEditViewController {
    AliyunPasterTextInputView *_currentTextInputView;
    AliyunEditSouceClickType _editSouceClickType;
    BOOL _prePlaying;
    BOOL _haveStaticImage;
    AliyunEffectStaticImage *_staticImage;
    AliyunEffectFilter *_processAnimationFilter;
    AliyunTimelineFilterItem *_processAnimationFilterItem;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    Class c = NSClassFromString(@"AliyunEffectPrestoreManager");
    NSObject *prestore = (NSObject *)[[c alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [prestore performSelector:@selector(insertInitialData)];
#pragma clang diagnostic pop
    // 校验视频分辨率，如果首段视频是横屏录制，则outputSize的width和height互换
    _outputSize = [_config fixedSize];
    
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor colorWithRed:35.0/255 green:42.0/255 blue:66.0/255 alpha:1];
    [self addSubviews];
    // 单视频接入编辑页面，生成一个新的taskPath
    if (!_taskPath) {
        _taskPath = [AliyunPathManager compositionRootDir];
        AliyunImporter *importer = [[AliyunImporter alloc] initWithPath:_taskPath outputSize:_outputSize];
        AliyunClip *clip = [[AliyunClip alloc] initWithVideoPath:_videoPath animDuration:0];
        [importer addMediaClip:clip];
        [importer generateProjectConfigure];
        
        NSString *root = [AliyunPathManager compositionRootDir];
        _config.outputPath = [[root stringByAppendingPathComponent:[AliyunPathManager uuidString]] stringByAppendingPathExtension:@"mp4"];
    }
    
    
    // editor
    self.editor = [[AliyunEditor alloc] initWithPath:_taskPath preview:self.movieView];
    self.editor.delegate = (id)self;
    
    // player
    self.player = [self.editor getPlayer];
    // exporter
    self.exporter = [self.editor getExporter];
    // constructor
    self.clipConstructor = [self.editor getClipConstructor];
    
    // setup pasterEditZoneView
    self.editZoneView = [[AliyunEditZoneView alloc] initWithFrame:self.movieView.bounds];
    self.editZoneView.delegate = (id)self;
    [self.movieView addSubview:self.editZoneView];
    
    // setup pasterManager
    self.pasterManager = [self.editor getPasterManager];
    self.pasterManager.displaySize = self.editZoneView.bounds.size;
    self.pasterManager.outputSize = _outputSize;
    self.pasterManager.previewRenderSize = [self.editor getPreviewRenderSize];
    self.pasterManager.delegate = (id)self;
    
    [self.editor startEdit];
    [self.editor setRenderBackgroundColor:[UIColor blackColor]];

    // setup timeline
    NSArray *clips = [self.clipConstructor mediaClips];
    NSMutableArray *mediaInfos = [[NSMutableArray alloc] init];
    for (int idx = 0; idx < [clips count]; idx++ ) {
        AliyunClip *clip = clips[idx];
        AliyunTimelineMediaInfo *mediaInfo = [[AliyunTimelineMediaInfo alloc] init];
        mediaInfo.mediaType = (AliyunTimelineMediaInfoType)clip.mediaType;
        mediaInfo.path = clip.src;
        mediaInfo.duration = clip.duration;
        mediaInfo.startTime = clip.startTime;
        [mediaInfos addObject:mediaInfo];
    }
    [self.timelineView setMediaClips:mediaInfos segment:8.0 photosPersegent:8];
  
    // update views
    [self updateSubViews];
    [self addNotifications];
    
//    [self.view addSubview:self.staticImageButton];
}

- (UIButton *)staticImageButton {
    if (!_staticImageButton) {
        _staticImageButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _staticImageButton.frame = CGRectMake(ScreenWidth - 120, 120, 100, 40);
        [_staticImageButton addTarget:self action:@selector(staticImageButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_staticImageButton setTitle:@"静态贴图" forState:UIControlStateNormal];
    }
    return _staticImageButton;
}

- (void)staticImageButtonTapped:(id)sender {
    if (_haveStaticImage == NO) {
        _haveStaticImage = YES;
        _staticImage = [[AliyunEffectStaticImage alloc]  init];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"yuanhao8" ofType:@"png"];
        _staticImage.startTime = 5;
        _staticImage.endTime = 10;
        _staticImage.path = path;
        
        CGSize displaySize = self.editZoneView.bounds.size;
        CGFloat scale = [[UIScreen mainScreen] scale];
        _staticImage.displaySize = CGSizeMake(displaySize.width * scale, displaySize.height * scale);//displaySize需要进行scale换算
        _staticImage.frame = CGRectMake(_staticImage.displaySize.width /2 - 200, _staticImage.displaySize.height / 2 -200, 400, 400);//图片自身宽高
        [self.editor applyStaticImage:_staticImage];
    } else {
        _haveStaticImage = NO;
        [self.editor removeStaticImage:_staticImage];
    }
    
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    if (self.isPublish) {//规避低端机内存不够
//        self.isPublish = NO;
//        [self.editor startEdit];
//    }
    
    [self.player play];
    [self.playButton setSelected:NO];
    
    
    NSString *watermarkPath = [[NSBundle mainBundle] pathForResource:@"watermark" ofType:@"png"];
    AliyunEffectImage *watermark = [[AliyunEffectImage alloc] initWithFile:watermarkPath];
    watermark.frame = CGRectMake(40, 20, 42, 30);
    [self.editor setWaterMark:watermark];
    
    
    NSString *tailWatermarkPath = [[NSBundle mainBundle] pathForResource:@"tail" ofType:@"png"];
    AliyunEffectImage *tailWatermark = [[AliyunEffectImage alloc] initWithFile:tailWatermarkPath];
    tailWatermark.frame = CGRectMake(CGRectGetMidX(self.movieView.bounds) - 84 / 2, CGRectGetMidY(self.movieView.bounds) - 60 / 2, 84, 60);
    tailWatermark.endTime = 2;
    [self.editor setTailWaterMark:tailWatermark];
    
    self.timelineView.actualDuration = [self.player getStreamDuration]; //为了让导航条播放时长匹配，必须在这里设置时长
    _prePlaying = YES;
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.player stop];
    self.filter = nil;
}
- (BOOL)shouldAutorotate
{
    return NO;
}
- (void)didReceiveMemoryWarning {
    NSLog(@"mem warning");
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [self.editor destroyAllEffect];//清理所有效果
    [self.editor stopEdit];
    [self removeNotifications];
}

#pragma mark - Notification

- (void)addNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resourceDeleteNoti:)
                                                 name:AliyunEffectResourceDeleteNoti
                                               object:nil];
}

- (void)removeNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification Action
- (void)resourceDeleteNoti:(NSNotification *)noti {
    NSArray *deleteResourcePaths = noti.object;
    for (NSString *delePath in deleteResourcePaths) {
        NSString *deleIconPath = [delePath stringByAppendingPathComponent:@"icon.png"];
        NSArray *pasterList = [self.pasterManager getAllPasterControllers];
        [pasterList enumerateObjectsUsingBlock:^(AliyunPasterController *controller, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([[controller getIconPath] isEqualToString:deleIconPath]) {
                [controller.delegate onRemove:controller]; // 删除paster
            }
        }];
    }
}

- (void)applicationDidBecomeActive {
    if (self.isExporting) {
        [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
        self.isExporting = NO;
    }
    [self forceFinishLastEditPasterView];
    if (self.editorError) {
        self.editorError = NO;
        [self.player play];
    }
    self.isBackground = NO;
}

- (void)applicationWillResignActive {
    self.isBackground = YES;
}

#pragma mark - AliyunIPlayerCallback -

- (void)playerDidStart {
    NSLog(@"play start");
}

- (void)playerDidEnd {
    
    if (_processAnimationFilter) {//如果当前有正在添加的动效滤镜 则pause
        [self.player play];
        _processAnimationFilter.endTime = [self.player getDuration];
        _processAnimationFilter.streamEndTime = [self.player getStreamDuration];
        [self didEndLongPress];
    } else {
        if (!self.isExporting) {
            [self.player play];
            self.isExporting = NO;
            [self forceFinishLastEditPasterView];
        }
    }
}


- (void)playProgress:(double)playSec streamProgress:(double)streamSec {
    [self.timelineView seekToTime:streamSec];
    self.currentTimeLabel.text = [self stringFromTimeInterval:streamSec];
}

- (void)seekDidEnd {
    NSLog(@"seek end");
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

- (void)playError:(int)errorCode {
    NSLog(@"playError:%d,%x",errorCode,errorCode);
    if (self.isBackground) {
        self.editorError = YES;
    }else {
//        if (errorCode == ALIV_FRAMEWORK_MEDIA_POOL_CACHE_DATA_SIZE_OVERFLOW) {
            [self.player play];
//        }
    }
}

- (int)customRender:(int)srcTexture size:(CGSize)size {
    // 自定义滤镜渲染
//    if (!self.filter) {
//        self.filter = [[AliyunCustomFilter alloc] initWithSize:size];
//    }
//    return [self.filter render:srcTexture size:size];
    return srcTexture;
}

#pragma mark - AliyunIExporterCallback 

-(void)exporterDidStart {
    NSLog(@"TestLog, %@:%@", @"log_edit_start_time", @([NSDate date].timeIntervalSince1970));

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeDeterminate;
    hud.removeFromSuperViewOnHide = YES;
    [hud.button setTitle:NSLocalizedString(@"cancel_camera_import", nil) forState:UIControlStateNormal];
    [hud.button addTarget:self action:@selector(cancelExport) forControlEvents:UIControlEventTouchUpInside];
    hud.label.text = NSLocalizedString(@"video_is_exporting_edit", nil);
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    
}

-(void)exporterDidEnd:(NSString *)outputPath {

    NSLog(@"TestLog, %@:%@", @"log_edit_complete_time", @([NSDate date].timeIntervalSince1970));

    [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    if (self.isExporting) {
        self.isExporting = NO;
        
        NSURL *outputPathURL = [NSURL fileURLWithPath:_config.outputPath];
        AVAsset *as = [AVAsset assetWithURL:outputPathURL];
        CGSize size = [as aliyunNaturalSize];
        CGFloat videoDuration = [as aliyunVideoDuration];
        float frameRate = [as aliyunFrameRate];
        float bitRate = [as aliyunBitrate];
        float estimatedKeyframeInterval =  [as aliyunEstimatedKeyframeInterval];
        
        NSLog(@"TestLog, %@:%@", @"log_output_resolution", NSStringFromCGSize(size));
        NSLog(@"TestLog, %@:%@", @"log_video_duration", @(videoDuration));
        NSLog(@"TestLog, %@:%@", @"log_frame_rate", @(frameRate));
        NSLog(@"TestLog, %@:%@", @"log_bit_rate", @(bitRate));
        NSLog(@"TestLog, %@:%@", @"log_i_frame_interval", @(estimatedKeyframeInterval));
        
        
        ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:outputPathURL
                                    completionBlock:^(NSURL *assetURL, NSError *error)
        {
            /* process assetURL */
            if (!error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"video_exporting_finish_edit", nil) message:NSLocalizedString(@"video_local_save_edit", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alert show];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"video_exporting_finish_fail_edit", nil) message:NSLocalizedString(@"video_exporting_check_autho", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alert show];
            }
        }];
    }
    [self.player play];
}

-(void)exporterDidCancel {
    [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    [self.player play];
}

- (void)exportProgress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        MBProgressHUD *hub = [MBProgressHUD HUDForView:self.view];
        hub.progress = progress;
    });
}

-(void)exportError:(int)errorCode {
    NSLog(@"exportError:%d,%x",errorCode,errorCode);
    [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    if (self.isBackground) {
        self.editorError = YES;
    }else {
        [self.player play];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)addSubviews {
    CGFloat factor = _outputSize.height/_outputSize.width;
    self.movieView = [[UIView alloc] initWithFrame:CGRectMake(0, 44 + ScreenWidth / 8 + SafeTop, ScreenWidth,ScreenWidth * factor)];
    self.movieView.backgroundColor = [[UIColor brownColor] colorWithAlphaComponent:.3];
    [self.view addSubview:self.movieView];
    
    self.editHeaderView = [[AliyunEditHeaderView alloc] initWithFrame:CGRectMake(0, SafeTop, ScreenWidth, 44)];
    [self.view addSubview:self.editHeaderView];
    
    __weak typeof(self) weakSelf = self;
    self.editHeaderView.backClickBlock = ^{
        [weakSelf back];
    };
    self.editHeaderView.saveClickBlock = ^{
        [weakSelf save];
    };
    
    self.timelineView = [[AliyunTimelineView alloc] initWithFrame:CGRectMake(0, 44+SafeTop, ScreenWidth, ScreenWidth / 8)];
    self.timelineView.backgroundColor = [UIColor whiteColor];
    self.timelineView.delegate = (id)self;
    [self.view addSubview:self.timelineView];

    self.currentTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 12)];
    self.currentTimeLabel.backgroundColor = RGBToColor(27, 33, 51);
    self.currentTimeLabel.textColor = [UIColor whiteColor];
    self.currentTimeLabel.textAlignment = NSTextAlignmentCenter;
    self.currentTimeLabel.font = [UIFont systemFontOfSize:11];
    self.currentTimeLabel.center = CGPointMake(ScreenWidth / 2, self.timelineView.frame.origin.y + CGRectGetHeight(self.timelineView.bounds) + 6);
//    [self.currentTimeLabel sizeToFit];
    [self.view addSubview:self.currentTimeLabel];

    self.editButtonsView = [[AliyunEditButtonsView alloc] initWithFrame:CGRectMake(0, ScreenHeight - 40 - SafeBottom, ScreenWidth, 40)];
    [self.view addSubview:self.editButtonsView];
    self.editButtonsView.delegate = (id)self;
    
    _playButton = [[UIButton alloc] initWithFrame:CGRectMake(20, CGRectGetHeight(self.view.frame) - 120 - SafeTop - SafeBottom, 64, 64)];
    [_playButton setImage:[AliyunImage imageNamed:@"qu_pause"] forState:UIControlStateNormal];
    [_playButton setImage:[AliyunImage imageNamed:@"qu_play"] forState:UIControlStateSelected];
    [_playButton setAdjustsImageWhenHighlighted:NO];
    [_playButton addTarget:self action:@selector(playControlClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playButton];
}

- (void)updateSubViews {
    // 9:16模式下 view透明
    if ([_config mediaRatio] == AliyunMediaRatio9To16) {
        self.movieView.frame = self.movieView.bounds;
        self.editHeaderView.alpha = 0.5;
        [self.timelineView updateTimelineViewAlpha:0.5];
        self.editButtonsView.alpha = 0.5;
    }
}

- (AliyunTabController *)tabController {
    if (!_tabController) {
        _tabController = [[AliyunTabController alloc] init];
        _tabController.delegate = (id)self;
    }
    return _tabController;
}

#pragma mark - Action

- (void)playControlClick:(UIButton *)sender {
//if (self.isExported) {
//        self.isExported = NO;
//        [self.player replay];
//        sender.selected = NO;
//    } else {
        if (!sender.selected) {
            [self.player pause];
            sender.selected = YES;
            _prePlaying = NO;
        } else {
            [self forceFinishLastEditPasterView];
            [self.player resume];
            sender.selected = NO;
            _prePlaying = YES;
        }    
//    }
}

#pragma mark - Private Methods -

- (void)back {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)save {
    [self forceFinishLastEditPasterView];

    if (self.isExporting) return;
//
//    当前页面合成视频
//    NSString *path = _config.outputPath;
//    [self.exporter startExport:path];
//    self.isExporting = YES;
    
//    [self.editor stopEdit];
//    self.isPublish = YES; //     发布页面合成视频 如果在低端机器上收到内存警报 则可以将当前的页面editor销毁以释放资源

    AliyunPublishViewController *vc = [[AliyunPublishViewController alloc] init];
    vc.taskPath = _taskPath;
    vc.config = _config;
    vc.outputSize = _outputSize;
    vc.backgroundImage = _timelineView.coverImage;
    [self.navigationController pushViewController:vc animated:YES];

}

- (void)cancelExport {
    self.isExporting = NO;
    [self.exporter cancelExport];
    [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
    [self.player play];
}

- (void)presentBackgroundButton
{
    [self dismissBackgroundButton];
    self.backgroundTouchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.backgroundTouchButton.frame = self.view.bounds;
    self.backgroundTouchButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.3];
    [self.backgroundTouchButton addTarget:self action:@selector(backgroundTouchButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backgroundTouchButton];
}

- (void)dismissBackgroundButton
{
    [self.backgroundTouchButton removeFromSuperview];
    self.backgroundTouchButton = nil;
}

- (void)backgroundTouchButtonClicked:(id)sender
{
    [self dismissBackgroundButton];
    if (_editSouceClickType == AliyunEditSouceClickTypeSubtitle) {
        [self dismissEffectView:self.captionShowView duration:0.2f];
    } else if (_editSouceClickType == AliyunEditSouceClickTypePaster) {
        [self dismissEffectView:self.pasterShowView duration:0.2f];
    } else if (_editSouceClickType == AliyunEditSouceClickTypeFilter) {
        [self dismissEffectView:self.filterView duration:0.2f];
    } else if (_editSouceClickType == AliyunEditSouceClickTypeMusic) {
        [self dismissEffectView:self.musicView duration:0.2f];
    } else if (_editSouceClickType == AliyunEditSouceClickTypeMV) {
        [self dismissEffectView:self.mvView duration:0.2f];
    } else if (_editSouceClickType == AliyunEditSouceClickTypeTimeFilter) {
        [self dismissEffectView:self.timeFilterView duration:0.2f];
    }
    if (_currentTextInputView) {
        [self textInputViewEditCompleted];
    }
}

- (void)textInputViewEditCompleted {
    [self.tabController dismissPresentTabContainerView];
    [self showTopView];
    self.editZoneView.currentPasterView = nil;
    
    AliyunPasterController *editPasterController = [self.pasterManager getCurrentEditPasterController];
    if (editPasterController) {//当前有正在编辑的动图控制器，则更新
        AliyunPasterView *pasterView = (AliyunPasterView *)editPasterController.pasterView;
        pasterView.text = [_currentTextInputView getText];
        pasterView.textFontName = [_currentTextInputView fontName];
        pasterView.textColor = [_currentTextInputView getTextColor];
        editPasterController.subtitle = pasterView.text;
        editPasterController.subtitleFontName = [_currentTextInputView fontName];
        [editPasterController editCompletedWithImage:[pasterView textImage]];
        editPasterController.subtitleStroke = pasterView.textColor.isStroke;
        editPasterController.subtitleColor = [pasterView contentColor];
        editPasterController.subtitleStrokeColor = [pasterView strokeColor];
        [self makePasterControllerBecomeEditStatus:editPasterController];
        
    } else {//当前无正在编辑的动图控制器，则新建
        NSString *text = [_currentTextInputView getText];
        if (text == nil || [text isEqualToString:@""]) {
            [self destroyInputView];
            return;
        }
        CGRect inputViewBounds = _currentTextInputView.bounds;
        
        AliyunPasterRange range = [self calculatePasterStartTimeWithDuration:1];
        
        AliyunPasterController *pasterController = [self.pasterManager addSubtitle:text bounds:inputViewBounds startTime:range.startTime duration:range.duration];
        [self addPasterViewToDisplayAndRender:pasterController pasterFontId:-1];
        [self addPasterToTimeline:pasterController]; //加到timelineView联动
        [self makePasterControllerBecomeEditStatus:pasterController];
    }
    [self destroyInputView];
}

- (void)destroyInputView {
    [_currentTextInputView removeFromSuperview];
    _currentTextInputView = nil;
}

- (void)makePasterControllerBecomeEditStatus:(AliyunPasterController *)pasterController {
    self.editZoneView.currentPasterView = (AliyunPasterView *)[pasterController pasterView];
    [pasterController editWillStart];
    self.editZoneView.currentPasterView.editStatus = YES;
    [self editPasterItemBy:pasterController]; //TimelineView联动
}

- (void)addPasterViewToDisplayAndRender:(AliyunPasterController *)pasterController pasterFontId:(NSInteger)fontId {
    AliyunPasterView *pasterView = [[AliyunPasterView alloc] initWithPasterController:pasterController];
    
    if (pasterController.pasterType == AliyunPasterEffectTypeSubtitle) {
        pasterView.textColor = [_currentTextInputView getTextColor];
        pasterView.textFontName = [_currentTextInputView fontName];
        pasterController.subtitleFontName = pasterView.textFontName;
        pasterController.subtitleStroke = pasterView.textColor.isStroke;
        pasterController.subtitleColor = [pasterView contentColor];
        pasterController.subtitleStrokeColor = [pasterView strokeColor];
    }
    if (pasterController.pasterType == AliyunPasterEffectTypeCaption) {
        UIColor *textColor = pasterController.subtitleColor;
        UIColor *textStokeColor = pasterController.subtitleStrokeColor;
        BOOL stroke = pasterController.subtitleStroke;
        AliyunColor *color = [[AliyunColor alloc] initWithColor:textColor strokeColor:textStokeColor stoke:stroke];
        pasterView.textColor = color;
        AliyunEffectFontInfo *fontInfo = (AliyunEffectFontInfo *)[self.dbHelper queryEffectInfoWithEffectType:1 effctId:fontId];
        
        if (fontInfo == nil) {
            AliyunResourceFontDownload *download = [[AliyunResourceFontDownload alloc] init];
            [download downloadFontWithFontId:fontId progress:nil completion:^(AliyunEffectResourceModel *newModel, NSError *error) {
                pasterView.textFontName = newModel.fontName;
                pasterController.subtitleFontName = newModel.fontName;
            }];
        } else {
            pasterView.textFontName = fontInfo.fontName;
            pasterController.subtitleFontName = fontInfo.fontName;
        }
    }
    
    pasterView.delegate = (id)pasterController;
    pasterView.actionTarget = (id)self;
    
    CGAffineTransform t = CGAffineTransformIdentity;
    t = CGAffineTransformMakeRotation(-pasterController.pasterRotate);
    pasterView.layer.affineTransform = t;
    
    [pasterController setPasterView:pasterView];
    [self.editZoneView addSubview:pasterView];
    
    if (pasterController.pasterType == AliyunPasterEffectTypeSubtitle) {
        [pasterController editCompletedWithImage:[pasterView textImage]];
    } else if (pasterController.pasterType == AliyunPasterEffectTypeNormal) {
        [pasterController editCompleted];
    } else {
        [pasterController editCompletedWithImage:[pasterView textImage]];
    }
}

- (AliyunPasterRange)calculatePasterStartTimeWithDuration:(CGFloat)duration {
    
    AliyunPasterRange pasterRange;
    
    if (duration >= [self.player getStreamDuration]) { //默认动画时间长于视频长度  将默认时间设置为视频长
        pasterRange.duration = [self.player getStreamDuration];
        pasterRange.startTime = 0;
    } else {
        if ([self.player getStreamDuration] - [self.player getCurrentStreamTime] <= duration) { //默认动画的播放时间超过总视频长
            pasterRange.duration = duration;
            pasterRange.startTime = [self.player getStreamDuration] - duration;
        } else { //默认动画时间未超出总视频
            pasterRange.duration = duration;
            pasterRange.startTime = [self.player getCurrentStreamTime];
        }
    }
    return pasterRange;
}

#pragma mark - AliyunTimelineView相关 -
- (void)addAnimationFilterToTimeline:(AliyunEffectFilter *)animationFilter {
    AliyunTimelineFilterItem *filterItem = [[AliyunTimelineFilterItem alloc] init];

    if ([self.editor getTimeFilter] == 3) {//倒放
        filterItem.startTime = animationFilter.streamEndTime;
        filterItem.endTime = animationFilter.streamStartTime;
    } else {
        filterItem.startTime = animationFilter.streamStartTime;
        filterItem.endTime = animationFilter.streamEndTime;
    }
    
    filterItem.displayColor = [self colorWithName:animationFilter.name];
    filterItem.obj = animationFilter;
    [self.timelineView addTimelineFilterItem:filterItem];
}

- (void)updateAnimationFilterToTimeline:(AliyunEffectFilter *)animationFilter {
    if (_processAnimationFilterItem == NULL) {
        _processAnimationFilterItem = [[AliyunTimelineFilterItem alloc] init];
    }
    
    if ([self.editor getTimeFilter] == 3) {//倒放
        _processAnimationFilterItem.endTime = animationFilter.streamStartTime;
        _processAnimationFilterItem.startTime = animationFilter.streamEndTime;
    } else {
        _processAnimationFilterItem.startTime = animationFilter.streamStartTime;
//        _processAnimationFilterItem.endTime = [self.player getCurrentTime];
        _processAnimationFilterItem.endTime = animationFilter.streamEndTime;
    }
    _processAnimationFilterItem.displayColor = [self colorWithName:animationFilter.name];
    
    [self.timelineView updateTimelineFilterItems:_processAnimationFilterItem];
}

- (void)removeAnimationFilterFromTimeline:(AliyunTimelineFilterItem *)animationFilterItem {
    [self.timelineView removeTimelineFilterItem:animationFilterItem];
}

- (void)removeLastAnimtionFilterItemFromTimeLineView {
    [self.timelineView removeLastFilterItemFromTimeline];
}

- (void)addPasterToTimeline:(AliyunPasterController *)pasterController {
    AliyunTimelineItem *timeline = [[AliyunTimelineItem alloc] init];
    timeline.startTime = pasterController.pasterStartTime;
    timeline.endTime = pasterController.pasterEndTime;
    timeline.obj = pasterController;
    timeline.minDuration = pasterController.pasterMinDuration;
    [self.timelineView addTimelineItem:timeline];
}

- (void)removePasterFromTimeline:(AliyunPasterController *)pasterController {
    AliyunTimelineItem *timeline = [self.timelineView getTimelineItemWithOjb:pasterController];
    [self.timelineView removeTimelineItem:timeline];
}

- (void)editPasterItemBy:(AliyunPasterController *)pasterController {
    AliyunTimelineItem *timeline = [self.timelineView getTimelineItemWithOjb:pasterController];
    [self.timelineView editTimelineItem:timeline];
}

- (void)editPasterItemComplete {
    [self.timelineView editTimelineComplete];
}

#pragma mark - AliyunPasterManagerDelegate -
- (void)pasterManagerWillDeletePasterController:(AliyunPasterController *)pasterController {
    [self removePasterFromTimeline:pasterController]; //与timelineView联动
}

#pragma mark - AliyunTimelineViewDelegate -
- (void)timelineDraggingTimelineItem:(AliyunTimelineItem *)item {
    [[self.pasterManager getAllPasterControllers] enumerateObjectsUsingBlock:^(AliyunPasterController *pasterController, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([pasterController isEqual:item.obj]) {
            pasterController.pasterStartTime = item.startTime;
            pasterController.pasterEndTime = item.endTime;
            
            *stop = YES;
        }
    }];
}

- (void)timelineBeginDragging {
    self.playButton.selected = YES;
    [self forceFinishLastEditPasterView];
}

- (void)timelineDraggingAtTime:(CGFloat)time {
    [self.player seek:time];
    self.currentTimeLabel.text = [self stringFromTimeInterval:time];
//    [self.currentTimeLabel sizeToFit];
}

- (void)timelineEndDraggingAndDecelerate:(CGFloat)time  {
    if (_prePlaying) {
        [self.player seek:time];
        [self.player resume];
        [self.playButton setSelected:NO];
    }
}

#pragma mark - AliyunPasterViewActionTarget -
- (void)oneClick:(id)obj {
    [self presentBackgroundButton];
    AliyunPasterView *pasterView = (AliyunPasterView *)obj;
    AliyunPasterController *pasterController = (AliyunPasterController *)pasterView.delegate;
    [pasterController editDidStart];
    
    int maxCharacterCount = 0;
    if (pasterController.pasterType == AliyunPasterEffectTypeCaption) {
        maxCharacterCount = 20;
    }
    AliyunPasterTextInputView *inputView = [AliyunPasterTextInputView createPasterTextInputViewWithText:[pasterController subtitle]
                                                                                      textColor:pasterView.textColor
                                                                                       fontName:pasterView.textFontName
                                                                                   maxCharacterCount:maxCharacterCount];
    [self.view addSubview:inputView];
    inputView.delegate = (id)self;
    inputView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds) - 50);
    _currentTextInputView = inputView;
}

#pragma mark - AliyunEditZoneViewDelegate -
- (void)currentTouchPoint:(CGPoint)point {
    if (self.editZoneView.currentPasterView) {//如果当前有正在编辑的动图，且点击的位置正好在动图上
        BOOL hitSubview = [self.editZoneView.currentPasterView touchPoint:point fromView:self.editZoneView];
        if (hitSubview == YES) {
            return;
        }
    }
    AliyunPasterController *pasterController = [self.pasterManager touchPoint:point atTime:[self.player getCurrentStreamTime]];
    if (pasterController) {
        [self.player pause];
        [self.playButton setSelected:YES];
        AliyunPasterView *pasterView = (AliyunPasterView *)[pasterController pasterView];
        if (pasterView) {//当前点击的位置有动图 逻辑：将上次有编辑的动图完成，让该次选择的动图进入编辑状态
            [self forceFinishLastEditPasterView];
            [self makePasterControllerBecomeEditStatus:pasterController];
        }
    } else {
        [self forceFinishLastEditPasterView];
    }
}

//强制将上次正在编辑的动图进入编辑完成状态
- (void)forceFinishLastEditPasterView {
    if (!self.editZoneView.currentPasterView) {
        return;
    }
    AliyunPasterController *editPasterController = (AliyunPasterController *)self.editZoneView.currentPasterView.delegate;
    self.editZoneView.currentPasterView.editStatus = NO;
    if (editPasterController.pasterType == AliyunPasterEffectTypeSubtitle) {
        [editPasterController editCompletedWithImage:[self.editZoneView.currentPasterView textImage]];
    } else if (editPasterController.pasterType == AliyunPasterEffectTypeNormal) {
        [editPasterController editCompleted];
    } else {
        [editPasterController editCompletedWithImage:[self.editZoneView.currentPasterView textImage]];
    }
    [self editPasterItemComplete];
    self.editZoneView.currentPasterView = nil;
    
    // 产品要求 动图需要一直放在涂鸦下面，所以每次加新动图，需要重新加一次涂鸦
    if (self.paintImage) {
        [self.editor removePaint:self.paintImage];
        [self.editor applyPaint:self.paintImage];
    }
}

- (void)mv:(CGPoint)fp to:(CGPoint)tp {
    if (self.editZoneView.currentPasterView) {
        [self.editZoneView.currentPasterView touchMoveFromPoint:fp to:tp];
    }
}

- (void)touchEnd {
    if (self.editZoneView.currentPasterView) {
        [self.editZoneView.currentPasterView touchEnd];
    }
}

#pragma mark - AliyunTabControllerDelegate -
- (void)completeButtonClicked {
    [self backgroundTouchButtonClicked:AliyunEditSouceClickTypeNone];
}

- (void)keyboardShouldHidden {
    [_currentTextInputView shouldHiddenKeyboard];
}

- (void)keyboardShouldAppear {
    [_currentTextInputView shouldAppearKeyboard];
}

- (void)textColorChanged:(AliyunColor *)color {
    [_currentTextInputView setFilterTextColor:color];
}

- (void)textFontChanged:(NSString *)fontName {
    [_currentTextInputView setFontName:fontName];
}

#pragma mark - AliyunEditButtonsViewDelegate -
- (void)filterButtonClicked:(AliyunEditButtonType)type {
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    _editSouceClickType = AliyunEditSouceClickTypeFilter;
    [self showEffectView:self.filterView duration:0.2f];
    [self.filterView reloadDataWithEffectType:type];
}

- (void)pasterButtonClicked {
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    _editSouceClickType = AliyunEditSouceClickTypePaster;
    [self showEffectView:self.pasterShowView duration:0.2f];
    [self.pasterShowView fetchPasterGroupDataWithCurrentShowGroup:nil];
}

- (void)subtitleButtonClicked {
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    _editSouceClickType = AliyunEditSouceClickTypeSubtitle;
    [self showEffectView:self.captionShowView duration:0.2f];
    [self.captionShowView fetchCaptionGroupDataWithCurrentShowGroup:nil];
}

- (void)mvButtonClicked:(AliyunEditButtonType)type {
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    _editSouceClickType = AliyunEditSouceClickTypeMV;
    [self showEffectView:self.mvView duration:0.2f];
    [self.mvView reloadDataWithEffectType:type];
}

- (void)musicButtonClicked {
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    _editSouceClickType = AliyunEditSouceClickTypeMusic;
    [self showEffectView:self.musicView duration:0.2f];
}

- (void)paintButtonClicked {
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    if (self.paintImage) {
        [self.editor removePaint:self.paintImage];
    }
    _editSouceClickType = AliyunEditSouceClickTypePaint;
    [self showEffectView:self.paintShowView duration:0];
    [self.playButton setHidden:YES];
    [self.paintShowView updateDrawRect:self.movieView.frame];
}
- (void)timeButtonClicked {
    AliyunClip* clip = self.clipConstructor.mediaClips[0];
    if (self.clipConstructor.mediaClips.count > 1 || clip.mediaType == 1) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.label.text = @"多段视频或图片不支持时间特效";
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.bezelView.color = rgba(0, 0, 0, 0.7);
        hud.label.textColor = [UIColor whiteColor];
        hud.bezelView.style = MBProgressHUDBackgroundStyleSolidColor;
        [hud hideAnimated:YES afterDelay:1.5f];
        return;
    }
    [self forceFinishLastEditPasterView];
    [self presentBackgroundButton];
    _editSouceClickType = AliyunEditSouceClickTypeTimeFilter;
    [self showEffectView:self.timeFilterView duration:0.2f];
}

- (void)showEffectView:(UIView *)view duration:(CGFloat)duration {
    view.hidden = NO;
    [self.view bringSubviewToFront:view];
    [self dismissTopView];
    [UIView animateWithDuration:duration animations:^{
        CGRect f = view.frame;
        f.origin.y = ScreenHeight - CGRectGetHeight(f)-SafeBottom;
        view.frame = f;
    }];
}

- (void)dismissEffectView:(UIView *)view duration:(CGFloat)duration {
    [self dismissBackgroundButton];
    [self showTopView];
    [UIView animateWithDuration:duration animations:^{
        CGRect f = view.frame;
        f.origin.y = ScreenHeight;
        view.frame = f;
    } completion:^(BOOL finished) {
        view.hidden = YES;
    }];
}

- (void)dismissTopView {
    
    [UIView animateWithDuration:.2f animations:^{
        CGRect timelineF = self.timelineView.frame;
        CGRect headerF = self.editHeaderView.frame;
        CGRect movieF = self.movieView.frame;
        CGRect timeF = self.currentTimeLabel.frame;
        timelineF.origin.y = SafeTop;
        headerF.origin.y = timelineF.origin.y - headerF.size.height;
        timeF.origin.y = timelineF.origin.y + timelineF.size.height;
        movieF.origin.y = timelineF.origin.y + timelineF.size.height;
        self.timelineView.frame = timelineF;
        self.editHeaderView.frame = headerF;
        self.movieView.frame = movieF;
        self.currentTimeLabel.frame = timeF;
        [self updateSubViews];
    }];
}

- (void)showTopView {
    
    [UIView animateWithDuration:.2f animations:^{
        CGRect headerF = self.editHeaderView.frame;
        CGRect timelineF = self.timelineView.frame;
        CGRect movieF = self.movieView.frame;
        CGRect timeF = self.currentTimeLabel.frame;
        headerF.origin.y = SafeTop;
        timelineF.origin.y = headerF.origin.y + headerF.size.height;
        movieF.origin.y = timelineF.origin.y + timelineF.size.height;
        timeF.origin.y = timelineF.origin.y + timelineF.size.height;
        self.timelineView.frame = timelineF;
        self.editHeaderView.frame = headerF;
        self.movieView.frame = movieF;
        self.currentTimeLabel.frame = timeF;
        [self updateSubViews];
    }];
}



- (void)didSelectEffectFilter:(AliyunEffectFilterInfo *)filter {
    AliyunEffectFilter *filter2 =[[AliyunEffectFilter alloc] initWithFile:[filter localFilterResourcePath]];
    [self.editor applyFilter:filter2];
}

- (void)didSelectEffectMV:(AliyunEffectMvGroup *)mvGroup {
    NSString *str = [mvGroup localResoucePathWithVideoRatio:(AliyunEffectMVRatio)[_config mediaRatio]];
    [self.player stop];
    [self.editor removeMusics];
    [self.editor applyMV:[[AliyunEffectMV alloc] initWithFile:str]];
    [self.player play];
}

- (void)didSelectEffectMoreMv {
    __weak typeof (self)weakSelf = self;
    [self presentAliyunEffectMoreControllerWithAliyunEffectType:AliyunEffectTypeMV completion:^(AliyunEffectInfo *selectEffect) {
        if (selectEffect) {
            weakSelf.mvView.selectedEffect = selectEffect;
        }
        [weakSelf.mvView reloadDataWithEffectType:AliyunEffectTypeMV];
    }];
}

- (void)animtionFilterButtonClick {
    [self.player pause];
    [self.playButton setSelected:YES];
}

//长按开始时，由于结束时间未定，先将结束时间设置为较长的时间  !!!注意这里的实现方式!!!
- (void)didBeganLongPressEffectFilter:(AliyunEffectFilterInfo *)animtinoFilterInfo {
    [self.player resume];
    AliyunEffectFilter *animationFilter = [[AliyunEffectFilter alloc] initWithFile:[animtinoFilterInfo localFilterResourcePath]];
    
    float currentSec = [self.player getCurrentTime];
    float currentStreamSec = [self.player getCurrentStreamTime];
    animationFilter.startTime = currentSec;
    animationFilter.endTime = [self.player getDuration];
    animationFilter.streamStartTime = currentStreamSec;
    animationFilter.streamEndTime = [self.player getStreamDuration];
    [self.animationFilters addObject:animationFilter];
    [self.editor applyAnimationFilter:animationFilter];
    
    
    _processAnimationFilter = [[AliyunEffectFilter alloc] initWithFile:[animtinoFilterInfo localFilterResourcePath]];
    _processAnimationFilter.startTime = currentSec;
    _processAnimationFilter.endTime = currentSec;
    _processAnimationFilter.streamStartTime = currentStreamSec;
    _processAnimationFilter.streamEndTime = currentStreamSec;
    
    [self updateAnimationFilterToTimeline:_processAnimationFilter];
}

- (UIColor *)colorWithName:(NSString *)name {
    UIColor *color = nil;
    if ([name isEqualToString:@"抖动"]) {
        color = [UIColor colorWithRed:254.0/255 green:160.0/255 blue:29.0/255 alpha:0.9];
    } else if ([name isEqualToString:@"幻影"]) {
        color = [UIColor colorWithRed:251.0/255 green:222.0/255 blue:56.0/255 alpha:0.9];
    } else if ([name isEqualToString:@"重影"]) {
        color = [UIColor colorWithRed:98.0/255 green:182.0/255 blue:254.0/255 alpha:0.9];
    } else if ([name isEqualToString:@"科幻"]) {
        color = [UIColor colorWithRed:220.0/255 green:92.0/255 blue:179.0/255 alpha:0.9];
    } else if ([name isEqualToString:@"朦胧"]) {
        color = [UIColor colorWithRed:243.0/255 green:92.0/255 blue:75.0/255 alpha:0.9];
    }
    
    return color;
}


//长按进行时 更新
- (void)didTouchingProgress {
    if (_processAnimationFilter) {
        
        if ([self.editor getTimeFilter] == 3) {//倒放
            if (_processAnimationFilter.endTime < _processAnimationFilter.startTime) {
                return;
            }
            _processAnimationFilter.endTime = [self.player getCurrentTime];
            _processAnimationFilter.streamEndTime = [self.player getCurrentStreamTime];
            [self updateAnimationFilterToTimeline:_processAnimationFilter];
            
        } else {
            if (_processAnimationFilter.endTime < _processAnimationFilter.startTime) {
                return;
            }
            _processAnimationFilter.endTime = [self.player getCurrentTime];
            _processAnimationFilter.streamEndTime = [self.player getCurrentStreamTime];
            [self updateAnimationFilterToTimeline:_processAnimationFilter];
        }
    }
}

//手势结束后，将当前正在编辑的特效滤镜删掉，重新加一个 这时动效滤镜的开始和结束时间都确定了
- (void)didEndLongPress {
    if (_processAnimationFilter == NULL) { //当前没有正在添加的动效滤镜 则不操作
        return;
    }
    float pendTime = _processAnimationFilter.endTime;
    float psEndTime = _processAnimationFilter.streamEndTime;
    float pStartTime = _processAnimationFilter.startTime;
    float psStartTime = _processAnimationFilter.streamStartTime;
    [self.player pause];
    [self removeAnimationFilterFromTimeline:_processAnimationFilterItem];
    _processAnimationFilterItem = NULL;
    _processAnimationFilter = NULL;

    AliyunEffectFilter *currentFilter = [self.animationFilters lastObject];
    
    if ([self.editor getTimeFilter] == 3) {//倒放
        currentFilter.startTime = psEndTime;
        currentFilter.streamStartTime = psStartTime;
        currentFilter.streamEndTime = psEndTime;
        currentFilter.endTime = psStartTime;
    } else {
        currentFilter.endTime = pendTime;
        currentFilter.streamEndTime = psEndTime;
        currentFilter.streamStartTime = psStartTime;
        currentFilter.startTime = pStartTime;
    }
    [self.editor updateAnimationFilter:currentFilter];
    [self addAnimationFilterToTimeline:currentFilter];
}

- (void)cancelButtonClick {
    [self dismissEffectView:self.filterView duration:0.2f];
    [self dismissEffectView:self.mvView duration:0.2f];
}

- (void)didRevokeButtonClick {
    AliyunEffectFilter *currentFilter = [self.animationFilters lastObject];
    [self.editor removeAnimationFilter:currentFilter];
    [self.animationFilters removeLastObject];
    //TODO:这里删除
    [self removeLastAnimtionFilterItemFromTimeLineView];
}

#pragma mark - Getter

-(AliyunEffectMusicView *)musicView {
    if (!_musicView) {
        _musicView = [[AliyunEffectMusicView alloc] initWithFrame:CGRectMake(0, ScreenHeight, ScreenWidth, ScreenHeight-220)];
        _musicView.delegate = (id)self;
        [self.view addSubview:_musicView];
    }
    return _musicView;
}

#pragma mark - AliyunEffectMusicViewDelegate

- (void)musicViewDidUpdateMute:(BOOL)mute {
    [self.editor setMute:mute];
}

- (void)musicViewDidUpdateAudioMixWeight:(float)weight {
    [self.editor setAudioMixWeight:weight*100];
}

- (void)musicViewDidUpdateMusic:(NSString *)path startTime:(CGFloat)startTime duration:(CGFloat)duration streamStart:(CGFloat)streamStart streamDuration:(CGFloat)streamDuration{
    AliyunEffectMusic *music = [[AliyunEffectMusic alloc] initWithFile:path];
    music.startTime = startTime;
    music.duration = duration;
    music.streamStartTime = streamStart * [_player getStreamDuration];
    music.streamDuration = streamDuration * [_player getStreamDuration];
    [self.editor removeMVMusic];
    [self.editor removeMusics];
    [self.editor applyMusic:music];
    [self.player resume];
    [self.playButton setSelected:NO];
}

#pragma mark - AliyunPasterTextInputView -

- (void)keyboardFrameChanged:(CGRect)rect animateDuration:(CGFloat)duration {
    [self.tabController presentTabContainerViewInSuperView:self.view height:rect.size.height duration:duration];
    [self dismissTopView];
}

- (void)editWillFinish:(CGRect)inputviewFrame text:(NSString *)text fontName:(NSString *)fontName {
    [self backgroundTouchButtonClicked:AliyunEditSouceClickTypeNone];
    [self textInputViewEditCompleted];
}

#pragma mark - AliyunPasterShowViewDelegate -

//添加普通动图
- (void)onClickPasterWithPasterModel:(AliyunEffectPasterInfo *)pasterInfo {
    [self.player pause];
    [self.playButton setSelected:YES];
    [self forceFinishLastEditPasterView];
    
    AliyunPasterRange range = [self calculatePasterStartTimeWithDuration:[pasterInfo defaultDuration]];
    
    AliyunPasterController *pasterController = [self.pasterManager addPaster:pasterInfo.resourcePath startTime:range.startTime duration:range.duration];
    [self addPasterViewToDisplayAndRender:pasterController pasterFontId:[pasterInfo.fontId integerValue]];
    [self addPasterToTimeline:pasterController];
    [self makePasterControllerBecomeEditStatus:pasterController];
}

- (void)onClickRemovePaster {
    //移除所有的普通动图
    [self dismissEffectView:self.pasterShowView duration:0.2f];
    [self.pasterManager removeAllNormalPasterControllers];
}

- (void)onClickPasterDone {
    [self dismissEffectView:self.pasterShowView duration:0.2f];
}

- (void)onClickMorePaster {
    
    [self forceFinishLastEditPasterView];
    __weak typeof (self)weakSelf = self;
    [self presentAliyunEffectMoreControllerWithAliyunEffectType:AliyunEffectTypePaster completion:^(AliyunEffectInfo *selectEffect) {
        
        [weakSelf.pasterShowView fetchPasterGroupDataWithCurrentShowGroup:(AliyunEffectPasterGroup *)selectEffect];
    }];
}

#pragma mark - AliyunPaintEditViewDelegate -
- (void)onClickPaintFinishButtonWithImagePath:(NSString *)path {

    self.paintImage = [[AliyunEffectImage alloc] initWithFile:path];
    self.paintImage.frame = self.movieView.bounds;
    [self.editor applyPaint:self.paintImage];
    [self.playButton setHidden:NO];
    [self dismissEffectView:self.paintShowView duration:0];
}

- (void)onClickPaintCancelButton {
    if (self.paintImage) {
        self.paintImage = nil;
    }
    [self.playButton setHidden:NO];
    [self dismissEffectView:self.paintShowView duration:0];
}

#pragma mark - AliyunEffectTimeFilterDelegate
- (void)didSelectNone {
    [_editor removeTimeFilter];
    [_player resume];
    [_timelineView removeAllTimelineTimeFilterItem];
}

- (void)didSelectMomentSlow {
    AliyunEffectTimeFilter *timeFilter = [[AliyunEffectTimeFilter alloc] init];
    timeFilter.startTime = [_player getCurrentStreamTime];
    timeFilter.endTime = timeFilter.startTime + 1;
    timeFilter.type = TimeFilterTypeSpeed;
    timeFilter.param = 0.5;
    [self.editor applyTimeFilter:timeFilter];
    [self.player resume];
    // time line
    AliyunTimelineTimeFilterItem *item = [AliyunTimelineTimeFilterItem new];
    item.startTime = timeFilter.startTime;
    item.endTime = timeFilter.endTime;
    [_timelineView removeAllTimelineTimeFilterItem];
    [_timelineView addTimelineTimeFilterItem:item];
}

- (void)didSelectWholeSlow {
    AliyunEffectTimeFilter *timeFilter = [[AliyunEffectTimeFilter alloc] init];
    timeFilter.type = TimeFilterTypeSpeed;
    timeFilter.param = 0.5;
    [self.editor applyTimeFilter:timeFilter];
    [self.player resume];
    // time line
    AliyunTimelineTimeFilterItem *item = [AliyunTimelineTimeFilterItem new];
    item.startTime = 0;
    item.endTime =  [_player getStreamDuration];
    [_timelineView removeAllTimelineTimeFilterItem];
    [_timelineView addTimelineTimeFilterItem:item];
}

- (void)didSelectMomentFast {
    AliyunEffectTimeFilter *timeFilter = [[AliyunEffectTimeFilter alloc] init];
    timeFilter.startTime = [_player getCurrentStreamTime];
    timeFilter.endTime = timeFilter.startTime  + 1;
    timeFilter.type = TimeFilterTypeSpeed;
    timeFilter.param = 2.0;
    [self.editor applyTimeFilter:timeFilter];
    [self.player resume];
    // time line
    AliyunTimelineTimeFilterItem *item = [AliyunTimelineTimeFilterItem new];
    item.startTime = timeFilter.startTime;
    item.endTime = timeFilter.endTime;
    [_timelineView removeAllTimelineTimeFilterItem];
    [_timelineView addTimelineTimeFilterItem:item];
}

- (void)didSelectWholeFast {
    AliyunEffectTimeFilter *timeFilter = [[AliyunEffectTimeFilter alloc] init];
    timeFilter.type = TimeFilterTypeSpeed;
    timeFilter.param = 2.0;
    [self.editor applyTimeFilter:timeFilter];
    [self.player resume];
    // time line
    AliyunTimelineTimeFilterItem *item = [AliyunTimelineTimeFilterItem new];
    item.startTime = 0;
    item.endTime =  [_player getStreamDuration];
    [_timelineView removeAllTimelineTimeFilterItem];
    [_timelineView addTimelineTimeFilterItem:item];
}

- (void)didSelectRepeat {
    AliyunEffectTimeFilter *timeFilter = [[AliyunEffectTimeFilter alloc] init];
    timeFilter.type = TimeFilterTypeRepeat;
    timeFilter.param = 3;
    timeFilter.startTime = [_player getCurrentStreamTime];
    timeFilter.endTime = timeFilter.startTime + 1;
    [self.editor applyTimeFilter:timeFilter];
    [self.player resume];
    // time line
    AliyunTimelineTimeFilterItem *item = [AliyunTimelineTimeFilterItem new];
    item.startTime = timeFilter.startTime;
    item.endTime =  timeFilter.endTime;
    [_timelineView removeAllTimelineTimeFilterItem];
    [_timelineView addTimelineTimeFilterItem:item];
}

- (void)didSelectInvert {
    if (!_invertAvailable) {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        AliyunClip *clip = self.clipConstructor.mediaClips[0];
        NSString *inputPath = clip.src;
        int estimatedSize = [self.editor getMaxEstimatedCacheSize:inputPath];
        int maxSize = [self.editor getMaxCacheSize];
        _invertAvailable = estimatedSize < maxSize;
        if (!_invertAvailable) {
            [self.player pause];
            AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:inputPath]];
            NSString *root = [AliyunPathManager compositionRootDir];
            NSString *outputPath = [[root stringByAppendingPathComponent:[AliyunPathManager uuidString]] stringByAppendingPathExtension:@"mp4"];
            AliyunMediaConfig *config = [AliyunMediaConfig invertConfig];
            self.compressManager = [[AliyunCompressManager alloc] initWithMediaConfig:config];
            [self.compressManager compressWithSourcePath:inputPath outputPath:outputPath outputSize:[asset aliyunNaturalSize] success:^{
                _invertAvailable = YES;
                [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
                [self.editor stopEdit];
                clip.src = outputPath;
                [self.clipConstructor updateMediaClip:clip atIndex:0];
                [self.editor startEdit];
                [self.player play];
                [self invert];
            } failure:^{
                [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
                [self.player play];
            }];
        }else {
            [[MBProgressHUD HUDForView:self.view] hideAnimated:YES];
            [self invert];
        }
    }else {
        [self invert];
    }
}

- (void)invert {
    AliyunEffectTimeFilter *timeFilter = [[AliyunEffectTimeFilter alloc] init];
    timeFilter.type = TimeFilterTypeInvert;
    [self.player stop];
    [self.editor applyTimeFilter:timeFilter];
    [self.player play];
    // time line
    AliyunTimelineTimeFilterItem *item = [AliyunTimelineTimeFilterItem new];
    item.startTime = 0;
    item.endTime =  [_player getStreamDuration];
    [_timelineView removeAllTimelineTimeFilterItem];
    [_timelineView addTimelineTimeFilterItem:item];
}

#pragma mark - AliyunEffectCaptionShowViewDelegate
//添加字幕动图
- (void)onClickCaptionWithPasterModel:(AliyunEffectPasterInfo *)pasterInfo {
    [self.player pause];
    [self.playButton setSelected:YES];
    [self forceFinishLastEditPasterView];
    
    AliyunPasterRange range = [self calculatePasterStartTimeWithDuration:[pasterInfo defaultDuration]];
    AliyunPasterController *pasterController = [self.pasterManager addPaster:pasterInfo.resourcePath startTime:range.startTime duration:range.duration];
    [self addPasterViewToDisplayAndRender:pasterController pasterFontId:[pasterInfo.fontId integerValue]];
    [self addPasterToTimeline:pasterController];
    [self makePasterControllerBecomeEditStatus:pasterController];
}

- (void)onClickFontWithFontInfo:(AliyunEffectFontInfo *)font {
    [self.player pause];
    [self.playButton setSelected:YES];
    [self forceFinishLastEditPasterView];
    
    [self presentBackgroundButton];
    AliyunPasterTextInputView *textInputView = [AliyunPasterTextInputView createPasterTextInputView];
    textInputView.fontName = font.fontName;
    [self.view addSubview:textInputView];
    textInputView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds) - 50);
    textInputView.delegate = (id)self;
    _currentTextInputView = textInputView;
}

- (void)onClickRemoveCaption {
    // 移除纯文字动图和字幕动图
    [self dismissEffectView:self.captionShowView duration:0.2f];
    
    [self.pasterManager removeAllSubtitlePasterControllers];
    [self.pasterManager removeAllCaptionPasterControllers];
}

- (void)onClickMoreCaption {
    [self forceFinishLastEditPasterView];
    __weak typeof (self)weakSelf = self;
    [self presentAliyunEffectMoreControllerWithAliyunEffectType:AliyunEffectTypeCaption completion:^(AliyunEffectInfo *selectEffect) {
        
        [weakSelf.captionShowView fetchCaptionGroupDataWithCurrentShowGroup:(AliyunEffectCaptionGroup*)selectEffect];
    }];
}

- (void)onClickCaptionDone {
    [self dismissEffectView:self.captionShowView duration:0.2f];
}


#pragma mark - PresentEffectMoreVC

- (void)presentAliyunEffectMoreControllerWithAliyunEffectType:(AliyunEffectType)effectType
                                           completion:(void(^)(AliyunEffectInfo *selectEffect))completion {
    
    AliyunEffectMoreViewController *effectMoreVC = [[AliyunEffectMoreViewController alloc] initWithEffectType:effectType];
    UINavigationController *effecNC = [[UINavigationController alloc] initWithRootViewController:effectMoreVC];
    [self presentViewController:effecNC animated:YES completion:nil];
    effectMoreVC.effectMoreCallback = ^(AliyunEffectInfo *info){
        completion(info);
    };
}

#pragma mark - Setter -

- (AliyunPasterShowView *)pasterShowView {
    if (!_pasterShowView) {
        _pasterShowView = [[AliyunPasterShowView alloc] initWithFrame:(CGRectMake(0, ScreenHeight, ScreenWidth, SizeHeight(170)))];
        _pasterShowView.delegate = (id)self;
        [self.view addSubview:_pasterShowView];
    }
    return _pasterShowView;
}

- (AliyunEffectCaptionShowView *)captionShowView {
    if (!_captionShowView) {
        _captionShowView = [[AliyunEffectCaptionShowView alloc] initWithFrame:CGRectMake(0, ScreenHeight, ScreenWidth, SizeHeight(142))];
        _captionShowView.delegate = (id)self;
        [self.view addSubview:_captionShowView];
    }
    return _captionShowView;
}

- (AliyunEffectMVView *)mvView {
    if (!_mvView) {
        _mvView = [[AliyunEffectMVView alloc] initWithFrame:CGRectMake(0, ScreenHeight, ScreenWidth, 142)];
        _mvView.delegate = (id<AliyunEffectFilterViewDelegate>)self;
        [self.view addSubview:_mvView];
    }
    return _mvView;
}

- (AliyunEffectFilterView *)filterView {
    if (!_filterView) {
        _filterView = [[AliyunEffectFilterView alloc] initWithFrame:CGRectMake(0, ScreenHeight, ScreenWidth, 142)];
        _filterView.delegate = (id<AliyunEffectFilter2ViewDelegate>)self;
        [self.view addSubview:_filterView];
    }
    return _filterView;
}

- (AliyunEffectTimeFilterView *)timeFilterView {
    if (!_timeFilterView) {
        _timeFilterView = [[AliyunEffectTimeFilterView alloc] initWithFrame:CGRectMake(0, ScreenHeight, ScreenWidth, 142)];
        _timeFilterView.delegate = (id<AliyunEffectTimeFilterDelegate>)self;
        [self.view addSubview:_timeFilterView];
    }
    return _timeFilterView;
}

- (AliyunPaintEditView *)paintShowView {
    if (!_paintShowView) {
        _paintShowView = [[AliyunPaintEditView alloc] initWithFrame:(CGRectMake(0, ScreenHeight, ScreenWidth, ScreenHeight)) drawRect:self.movieView.frame];
        _paintShowView.backgroundColor = [UIColor clearColor];
        _paintShowView.delegate = (id<AliyunPaintEditViewDelegate>)self;
        [self.view addSubview:_paintShowView];
    }
    return _paintShowView;
}

- (AliyunDBHelper *)dbHelper
{
    if (!_dbHelper) {
        _dbHelper = [[AliyunDBHelper alloc] init];
        [_dbHelper openResourceDBSuccess:nil failure:nil];
    }
    return _dbHelper;
}

- (NSMutableArray *)animationFilters {
    if (!_animationFilters) {
        _animationFilters = [[NSMutableArray alloc] init];
    }
    return _animationFilters;
}

@end
