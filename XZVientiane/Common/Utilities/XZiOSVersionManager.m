//
//  XZiOSVersionManager.m
//  XZVientiane
//
//  iOS版本统一管理器
//

#import "XZiOSVersionManager.h"

@interface XZiOSVersionManager ()

@property (nonatomic, assign) CGFloat systemVersion;
@property (nonatomic, assign) BOOL iOS11Later;
@property (nonatomic, assign) BOOL iOS13Later;
@property (nonatomic, assign) BOOL iOS14Later;
@property (nonatomic, assign) BOOL iOS15Later;
@property (nonatomic, assign) BOOL iOS16Later;
@property (nonatomic, assign) BOOL iOS17Later;
@property (nonatomic, assign) BOOL iOS18Later;
@property (nonatomic, assign) BOOL isiPhoneXSeries;
@property (nonatomic, assign) BOOL isiPad;

@end

@implementation XZiOSVersionManager

+ (instancetype)sharedManager {
    static XZiOSVersionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZiOSVersionManager alloc] init];
        [instance setupVersionInfo];
    });
    return instance;
}

- (void)setupVersionInfo {
    // 获取系统版本
    self.systemVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    
    // 设置各版本标志
    self.iOS11Later = self.systemVersion >= 11.0;
    self.iOS13Later = self.systemVersion >= 13.0;
    self.iOS14Later = self.systemVersion >= 14.0;
    self.iOS15Later = self.systemVersion >= 15.0;
    self.iOS16Later = self.systemVersion >= 16.0;
    self.iOS17Later = self.systemVersion >= 17.0;
    self.iOS18Later = self.systemVersion >= 18.0;
    
    // 判断设备类型
    self.isiPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    
    // 判断是否为iPhone X系列
    self.isiPhoneXSeries = [self checkIsiPhoneXSeries];
    
    NSLog(@"在局📱 [iOS版本管理器] 系统版本: %.1f, iPhone X系列: %@, iPad: %@", 
          self.systemVersion, 
          self.isiPhoneXSeries ? @"YES" : @"NO",
          self.isiPad ? @"YES" : @"NO");
}

- (BOOL)checkIsiPhoneXSeries {
    BOOL iPhoneXSeries = NO;
    
    if (self.isiPad) {
        return NO;
    }
    
    if (@available(iOS 11.0, *)) {
        // 通过安全区域判断
        UIWindow *mainWindow = nil;
        if (@available(iOS 13.0, *)) {
            // iOS 13+ 使用scene
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    mainWindow = windowScene.windows.firstObject;
                    break;
                }
            }
        } else {
            // iOS 13以下
            mainWindow = [UIApplication sharedApplication].keyWindow;
            if (!mainWindow) {
                mainWindow = [[[UIApplication sharedApplication] delegate] window];
            }
        }
        
        if (mainWindow && mainWindow.safeAreaInsets.bottom > 0.0) {
            iPhoneXSeries = YES;
        }
    }
    
    return iPhoneXSeries;
}

- (BOOL)isSystemVersionGreaterThanOrEqualTo:(CGFloat)version {
    return self.systemVersion >= version;
}

- (CGFloat)safeAreaBottomHeight {
    return self.isiPhoneXSeries ? 34.0 : 0.0;
}

- (CGFloat)statusBarHeight {
    if (@available(iOS 13.0, *)) {
        UIWindow *mainWindow = nil;
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                mainWindow = windowScene.windows.firstObject;
                break;
            }
        }
        if (mainWindow) {
            return mainWindow.windowScene.statusBarManager.statusBarFrame.size.height;
        }
    } else {
        return [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    
    // 默认值
    return self.isiPhoneXSeries ? 44.0 : 20.0;
}

- (CGFloat)navigationBarHeight {
    return 44.0;
}

- (CGFloat)tabBarHeight {
    return self.isiPhoneXSeries ? 83.0 : 49.0;
}

@end