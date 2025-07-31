//
//  JSMediaHandler.m
//  XZVientiane
//
//  处理媒体相关的JS调用
//

#import "JSMediaHandler.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import "JHSysAlertUtil.h"
#import "LBPhotoBrowserManager.h"
#import "LBAlbumManager.h"
#import "CFJScanViewController.h"
#import "CustomHybridProcessor.h"

@interface JSMediaHandler ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, weak) UIViewController *currentController;

@end

@implementation JSMediaHandler

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedActions {
    return @[@"previewImage", @"saveImage", @"soundPlay", @"QRScan"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    self.currentController = controller;
    
    // 保存回调（某些操作需要）
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    if ([action isEqualToString:@"previewImage"]) {
        [self handlePreviewImage:data controller:controller];
    } else if ([action isEqualToString:@"saveImage"]) {
        [self handleSaveImage:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"soundPlay"]) {
        [self handleSoundPlay:data controller:controller];
    } else if ([action isEqualToString:@"QRScan"]) {
        [self handleQRScan:controller];
    }
}

#pragma mark - 图片处理

- (void)handlePreviewImage:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSArray *viewImageAry = [dataDic objectForKey:@"urls"];
    NSString *currentUrl = [dataDic objectForKey:@"current"];
    NSInteger currentIndex = [self getIndexByUrl:currentUrl urls:viewImageAry];
    
    // 保存图片数组到控制器
    if ([controller respondsToSelector:@selector(setViewImageAry:)]) {
        [controller setValue:viewImageAry forKey:@"viewImageAry"];
    }
    
    [[LBPhotoBrowserManager defaultManager] showImageWithURLArray:viewImageAry 
                                                fromImageViewFrames:nil 
                                                      selectedIndex:currentIndex 
                                                 imageViewSuperView:controller.view];
    
    [[[LBPhotoBrowserManager.defaultManager addLongPressShowTitles:@[@"保存", @"取消"]] 
      addTitleClickCallbackBlock:^(UIImage *image, NSIndexPath *indexPath, NSString *title, BOOL isGif, NSData *gifImageData) {
        if ([title isEqualToString:@"保存"]) {
            if (!isGif) {
                [[LBAlbumManager shareManager] saveImage:image];
            } else {
                [[LBAlbumManager shareManager] saveGifImageWithData:gifImageData];
            }
        }
    }] addPhotoBrowserWillDismissBlock:^{
        NSLog(@"在局图片浏览器即将销毁");
    }];
}

- (void)handleSaveImage:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    PHAuthorizationStatus author = [PHPhotoLibrary authorizationStatus];
    if (author == kCLAuthorizationStatusRestricted || author == kCLAuthorizationStatusDenied) {
        NSString *tips = @"请在设备的设置-隐私-照片选项中，允许应用访问你的照片";
        [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" message:tips confirmTitle:@"确定" handler:nil];
        return;
    }
    
    NSDictionary *dataDic = (NSDictionary *)data;
    NSString *imageStr = dataDic[@"filePath"];
    UIImage *image = [self getImageFromURL:imageStr];
    
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), (__bridge void *)callback);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    JSActionCallbackBlock callback = (__bridge JSActionCallbackBlock)contextInfo;
    
    if (callback) {
        if (error != NULL) {
            callback(@{
                @"data": @"",
                @"success": @"failure",
                @"errorMessage": @""
            });
        } else {
            callback(@{
                @"data": @"",
                @"success": @"true",
                @"errorMessage": @""
            });
        }
    }
}

#pragma mark - 音频处理

- (void)handleSoundPlay:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSString *urlstr = [dataDic objectForKey:@"data"];
    
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:urlstr]];
    self.player = [[AVPlayer alloc] initWithPlayerItem:item];
    [self.player play];
    
    // 监听播放结束
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(playerItemDidReachEnd) 
                                               name:AVPlayerItemDidPlayToEndTimeNotification 
                                             object:item];
}

- (void)playerItemDidReachEnd {
    if (self.currentController) {
        NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"playEnd" data:nil];
        if ([self.currentController respondsToSelector:@selector(objcCallJs:)]) {
            [self.currentController performSelector:@selector(objcCallJs:) withObject:callJsDic];
        }
    }
}

#pragma mark - 扫码处理

- (void)handleQRScan:(UIViewController *)controller {
    CFJScanViewController *qrVC = [[CFJScanViewController alloc] init];
    qrVC.hidesBottomBarWhenPushed = YES;
    [controller.navigationController pushViewController:qrVC animated:YES];
}

#pragma mark - 工具方法

- (NSInteger)getIndexByUrl:(NSString *)currentUrl urls:(NSArray *)urls {
    NSUInteger index = [urls indexOfObject:currentUrl];
    return index != NSNotFound ? index : 0;
}

- (UIImage *)getImageFromURL:(NSString *)fileURL {
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:fileURL]];
    return [UIImage imageWithData:data];
}

@end