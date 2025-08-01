//
//  XZiOSVersionManager.m
//  XZVientiane
//
//  iOS版本统一管理器 - 解决项目中分散的版本判断问题
//

#import "XZiOSVersionManager.h"

@interface XZiOSVersionManager ()

@property (nonatomic, assign) CGFloat systemVersion;
@property (nonatomic, assign) BOOL isiOS11Later;
@property (nonatomic, assign) BOOL isiOS13Later;
@property (nonatomic, assign) BOOL isiOS14Later;
@property (nonatomic, assign) BOOL isiOS15Later;
@property (nonatomic, assign) BOOL isiOS16Later;
@property (nonatomic, assign) BOOL isiOS17Later;
@property (nonatomic, assign) BOOL isiOS18Later;
@property (nonatomic, assign) BOOL isIPhoneXSeries;
@property (nonatomic, assign) BOOL isIPad;
@property (nonatomic, assign) CGFloat safeAreaBottomHeight;
@property (nonatomic, assign) CGFloat statusBarHeight;
@property (nonatomic, assign) CGFloat navigationBarHeight;
@property (nonatomic, assign) CGFloat tabBarHeight;

@end

@implementation XZiOSVersionManager

+ (instancetype)sharedManager {
    static XZiOSVersionManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XZiOSVersionManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initializeVersionProperties];
        [self initializeDeviceProperties];
        [self initializeLayoutProperties];
        
    }
    return self;
}

#pragma mark - Private Methods

- (void)initializeVersionProperties {
    // 获取系统版本号
    NSString *systemVersionString = [[UIDevice currentDevice] systemVersion];
    _systemVersion = [systemVersionString floatValue];
    
    // 计算各版本标志
    _isiOS11Later = [self isSystemVersionGreaterThanOrEqualTo:11.0];
    _isiOS13Later = [self isSystemVersionGreaterThanOrEqualTo:13.0];
    _isiOS14Later = [self isSystemVersionGreaterThanOrEqualTo:14.0];
    _isiOS15Later = [self isSystemVersionGreaterThanOrEqualTo:15.0];
    _isiOS16Later = [self isSystemVersionGreaterThanOrEqualTo:16.0];
    _isiOS17Later = [self isSystemVersionGreaterThanOrEqualTo:17.0];
    _isiOS18Later = [self isSystemVersionGreaterThanOrEqualTo:18.0];
}

- (void)initializeDeviceProperties {
    // 判断是否为iPad
    // 在局Claude Code[修复UI_USER_INTERFACE_IDIOM弃用警告]+使用现代方式获取设备类型
    if (@available(iOS 13.0, *)) {
        _isIPad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#pragma clang diagnostic pop
    }
    
    // 判断是否为iPhone X系列（有刘海的机型）
    _isIPhoneXSeries = NO;
    if (!_isIPad) {
        if (@available(iOS 11.0, *)) {
            // 通过安全区域判断是否为iPhone X系列
            UIWindow *mainWindow = [UIApplication sharedApplication].delegate.window;
            if (mainWindow && mainWindow.safeAreaInsets.bottom > 0.0) {
                _isIPhoneXSeries = YES;
            }
        }
    }
}

- (void)initializeLayoutProperties {
    // 计算各种高度
    _navigationBarHeight = 44.0; // 标准导航栏高度
    
    // 状态栏高度（动态获取）
    if (@available(iOS 13.0, *)) {
        // iOS 13+ 使用场景获取
        UIWindowScene *windowScene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.anyObject;
        if (windowScene && [windowScene isKindOfClass:[UIWindowScene class]]) {
            _statusBarHeight = windowScene.statusBarManager.statusBarFrame.size.height;
        } else {
            _statusBarHeight = _isIPhoneXSeries ? 44.0 : 20.0;
        }
    } else {
        // iOS 13以下使用传统方式
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
#pragma clang diagnostic pop
        if (_statusBarHeight <= 0) {
            _statusBarHeight = _isIPhoneXSeries ? 44.0 : 20.0;
        }
    }
    
    // 安全区域底部高度
    _safeAreaBottomHeight = _isIPhoneXSeries ? 34.0 : 0.0;
    
    // TabBar高度
    _tabBarHeight = _isIPhoneXSeries ? 83.0 : 49.0;
}

#pragma mark - Public Methods

- (BOOL)isSystemVersionGreaterThanOrEqualTo:(CGFloat)version {
    return _systemVersion >= version;
}

#pragma mark - Readonly Properties

- (CGFloat)systemVersion {
    return _systemVersion;
}

- (BOOL)isiOS11Later {
    return _isiOS11Later;
}

- (BOOL)isiOS13Later {
    return _isiOS13Later;
}

- (BOOL)isiOS14Later {
    return _isiOS14Later;
}

- (BOOL)isiOS15Later {
    return _isiOS15Later;
}

- (BOOL)isiOS16Later {
    return _isiOS16Later;
}

- (BOOL)isiOS17Later {
    return _isiOS17Later;
}

- (BOOL)isiOS18Later {
    return _isiOS18Later;
}

- (BOOL)isIPhoneXSeries {
    return _isIPhoneXSeries;
}

- (BOOL)isIPad {
    return _isIPad;
}

- (CGFloat)safeAreaBottomHeight {
    return _safeAreaBottomHeight;
}

- (CGFloat)statusBarHeight {
    return _statusBarHeight;
}

- (CGFloat)navigationBarHeight {
    return _navigationBarHeight;
}

- (CGFloat)tabBarHeight {
    return _tabBarHeight;
}

@end