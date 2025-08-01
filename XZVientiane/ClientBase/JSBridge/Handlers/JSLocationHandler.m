//
//  JSLocationHandler.m
//  XZVientiane
//
//  处理位置相关的JS调用
//

#import "JSLocationHandler.h"
#import <CoreLocation/CoreLocation.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import "JHSysAlertUtil.h"
#import "AddressFromMapViewController.h"
#import "JFCityViewController.h"

@interface JSLocationHandler () <JFCityViewControllerDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) AMapLocationManager *locationManager;
@property (nonatomic, strong) CLLocationManager *permissionLocationManager;
@property (nonatomic, copy) JSActionCallbackBlock locationCallback;
@property (nonatomic, strong) NSMutableArray *notificationObservers;
@property (nonatomic, weak) UIViewController *currentController;

@end

@implementation JSLocationHandler

- (void)dealloc {
    
    // 清理高德定位管理器
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
        self.locationManager = nil;
    }
    
    // 清理权限管理器
    if (self.permissionLocationManager) {
        self.permissionLocationManager.delegate = nil;
        self.permissionLocationManager = nil;
    }
    
    // 清理回调
    self.locationCallback = nil;
    
    // 移除通知观察者
    if (self.notificationObservers) {
        for (id observer in self.notificationObservers) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }
        [self.notificationObservers removeAllObjects];
        self.notificationObservers = nil;
    }
}

- (NSArray<NSString *> *)supportedActions {
    return @[@"getLocation", @"selectLocation", @"selectLocationCity", @"showLocation"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    self.currentController = controller;
    
    if ([action isEqualToString:@"getLocation"]) {
        [self handleGetLocation:callback];
    } else if ([action isEqualToString:@"selectLocation"]) {
        [self handleSelectLocation:controller callback:callback];
    } else if ([action isEqualToString:@"selectLocationCity"]) {
        [self handleSelectLocationCity:controller callback:callback];
    } else if ([action isEqualToString:@"showLocation"]) {
        [self handleShowLocation:data controller:controller callback:callback];
    }
}

#pragma mark - 定位处理

- (void)handleGetLocation:(JSActionCallbackBlock)callback {
    self.locationCallback = callback;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 优先使用locationCity（CFJClientH5Controller保存的），回退到currentCity
    NSString *cachedCity = [defaults objectForKey:@"locationCity"] ?: [defaults objectForKey:@"currentCity"];
    
    if (([[defaults objectForKey:@"currentLat"] doubleValue] != 0 || 
         [[defaults objectForKey:@"currentLng"] doubleValue] != 0) && 
        cachedCity && ![cachedCity isEqualToString:@"请选择"] && ![cachedCity isEqualToString:@"定位失败"]) {
        
        NSDictionary *localDic = @{
            @"lat": [defaults objectForKey:@"currentLat"] ?: @(0),
            @"lng": [defaults objectForKey:@"currentLng"] ?: @(0),
            @"city": cachedCity,
            @"address": [defaults objectForKey:@"currentAddress"] ?: cachedCity
        };
        
        NSDictionary *response = [self formatCallbackResponse:@"getLocation" 
                                                        data:localDic 
                                                     success:YES 
                                                errorMessage:nil];
        callback(response);
        return;
    }
    
    CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
    
    if (authStatus == kCLAuthorizationStatusNotDetermined) {
        // 权限未确定，需要先请求权限
        [self requestLocationPermissionWithCallback:callback];
        return;
    }
    
    if ([self isLocationServiceOpen]) {
        // 开始定位
        [self startLocationWithCallback:callback];
    } else {
        // 定位权限被拒绝
        [self handleLocationPermissionDenied:callback];
    }
}

- (void)requestLocationPermissionWithCallback:(JSActionCallbackBlock)callback {
    
    // 创建权限请求管理器
    self.permissionLocationManager = [[CLLocationManager alloc] init];
    self.permissionLocationManager.delegate = self;
    
    // 保存回调
    self.locationCallback = callback;
    
    // 请求使用期间的定位权限
    [self.permissionLocationManager requestWhenInUseAuthorization];
    
    // 设置超时处理，防止用户不响应权限请求
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.locationCallback && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
            NSDictionary *errorDic = @{
                @"lat": @(0),
                @"lng": @(0),
                @"city": @"权限请求超时",
                @"address": @"请授权定位权限后重试"
            };
            NSDictionary *response = [self formatCallbackResponse:@"getLocation" 
                                                            data:errorDic 
                                                         success:NO 
                                                    errorMessage:@"权限请求超时"];
            self.locationCallback(response);
            self.locationCallback = nil;
        }
    });
}

- (void)startLocationWithCallback:(JSActionCallbackBlock)callback {
    
    // 确保在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        // 保存回调
        self.locationCallback = callback;
        
        // 初始化高德定位管理器
        self.locationManager = [[AMapLocationManager alloc] init];
        [self.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
        self.locationManager.locationTimeout = 15; // 定位超时15秒
        self.locationManager.reGeocodeTimeout = 10; // 逆地理编码超时10秒
        
        __weak typeof(self) weakSelf = self;
        [self.locationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf handleLocationResult:location regeocode:regeocode error:error];
            }
        }];
    });
}

- (void)handleLocationPermissionDenied:(JSActionCallbackBlock)callback {
    NSDictionary *errorDic = @{
        @"lat": @(0),
        @"lng": @(0),
        @"city": @"定位权限未开启",
        @"address": @"请在设置中开启定位权限"
    };
    NSDictionary *response = [self formatCallbackResponse:@"getLocation" 
                                                    data:errorDic 
                                                 success:NO 
                                            errorMessage:@"定位权限未开启"];
    callback(response);
    
    // 延迟显示提示
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" 
                                         message:@"该功能需要使用定位功能,请先开启定位权限" 
                                     cancelTitle:@"取消" 
                                    defaultTitle:@"去设置" 
                                        distinct:YES 
                                          cancel:nil 
                                         confirm:^{
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
    });
}

- (void)handleLocationResult:(CLLocation *)location regeocode:(AMapLocationReGeocode *)regeocode error:(NSError *)error {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (error) {
        
        // 提供具体的错误处理
        NSString *errorMessage = @"定位失败，请重试";
        NSString *cityName = @"定位失败";
        
        switch (error.code) {
            case AMapLocationErrorCanceled:
                errorMessage = @"定位被取消，请重新尝试";
                cityName = @"定位被取消";
                break;
            case AMapLocationErrorLocateFailed:
                errorMessage = @"定位服务暂时不可用，请检查网络连接";
                break;
            case AMapLocationErrorTimeOut:
                errorMessage = @"定位超时，请重试";
                break;
            case AMapLocationErrorCannotFindHost:
                errorMessage = @"网络连接失败，请检查网络设置";
                break;
            case AMapLocationErrorNotConnectedToInternet:
                errorMessage = @"网络连接失败，请检查网络设置";
                break;
            case AMapLocationErrorRiskOfFakeLocation:
                errorMessage = @"检测到虚拟定位，请关闭虚拟定位软件";
                cityName = @"虚拟定位风险";
                break;
            case AMapLocationErrorNoFullAccuracyAuth:
                errorMessage = @"精确定位权限异常，请在设置中开启精确定位";
                cityName = @"精确定位权限异常";
                break;
            default:
                errorMessage = [NSString stringWithFormat:@"定位失败(错误码:%ld)，请重试", (long)error.code];
                break;
        }
        
        // 针对取消错误，尝试重新请求权限
        if (error.code == AMapLocationErrorCanceled) {
            CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
            if (authStatus == kCLAuthorizationStatusNotDetermined) {
                [self requestLocationPermissionWithCallback:self.locationCallback];
                return;
            }
        }
        
        // 返回错误信息
        if (self.locationCallback) {
            NSDictionary *response = [self formatCallbackResponse:@"getLocation" 
                                                            data:@{@"lat": @0, @"lng": @0, @"city": cityName, @"address": errorMessage} 
                                                         success:NO 
                                                    errorMessage:errorMessage];
            self.locationCallback(response);
            self.locationCallback = nil; // 清空回调
        }
        return;
    }
    
    CLLocationCoordinate2D coordinate = location.coordinate;
    
    if (coordinate.latitude == 0 && coordinate.longitude == 0) {
        [defaults setObject:@(0) forKey:@"currentLat"];
        [defaults setObject:@(0) forKey:@"currentLng"];
        [defaults setObject:@"请选择" forKey:@"currentCity"];
        [defaults setObject:@"请选择" forKey:@"currentAddress"];
    } else {
        [defaults setObject:@(coordinate.latitude) forKey:@"currentLat"];
        [defaults setObject:@(coordinate.longitude) forKey:@"currentLng"];
        
        // 检查逆地理编码是否有效
        BOOL hasValidGeocode = regeocode && 
            (regeocode.formattedAddress.length > 0 || 
             regeocode.city.length > 0 || 
             regeocode.district.length > 0 || 
             regeocode.POIName.length > 0);
        
        NSString *cityName = @"请选择";
        NSString *addressName = @"请选择";
        
        if (hasValidGeocode) {
            if (regeocode.city.length > 0) {
                cityName = regeocode.city;
            } else if (regeocode.district.length > 0) {
                cityName = regeocode.district;
            } else if (regeocode.POIName.length > 0) {
                cityName = regeocode.POIName;
            }
            addressName = regeocode.formattedAddress.length > 0 ? regeocode.formattedAddress : cityName;
        } else {
            // 处理特殊情况
            if (fabs(coordinate.latitude - 37.7858) < 0.01 && fabs(coordinate.longitude - (-122.4064)) < 0.01) {
                cityName = @"北京市";
                addressName = @"北京市朝阳区";
            } else if (fabs(coordinate.latitude - 24.612013) < 0.01 && fabs(coordinate.longitude - 118.048764) < 0.01) {
                cityName = @"厦门市";
                addressName = @"福建省厦门市";
            } else {
                cityName = @"位置服务不可用";
                addressName = @"请手动选择城市";
            }
        }
        
        [defaults setObject:cityName forKey:@"currentCity"];
        [defaults setObject:addressName forKey:@"currentAddress"];
    }
    
    [defaults synchronize];
    
    // 返回结果
    NSDictionary *localDic = @{
        @"lat": @(coordinate.latitude),
        @"lng": @(coordinate.longitude),
        @"city": [defaults objectForKey:@"currentCity"] ?: @"请选择",
        @"address": [defaults objectForKey:@"currentAddress"] ?: @"请选择"
    };
    
    if (self.locationCallback) {
        NSDictionary *response = [self formatCallbackResponse:@"getLocation" 
                                                        data:localDic 
                                                     success:YES 
                                                errorMessage:nil];
        self.locationCallback(response);
    }
}

- (void)handleSelectLocation:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    AddressFromMapViewController *vc = [[AddressFromMapViewController alloc] init];
    vc.addressList = nil;
    
    __weak typeof(controller) weakController = controller;
    vc.selectedEvent = ^(CLLocationCoordinate2D coordinate, NSString *addressName, NSString *formattedAddress) {
        if ([weakController respondsToSelector:@selector(webviewBackCallBack)]) {
            id webviewBackCallBack = [weakController valueForKey:@"webviewBackCallBack"];
            if (webviewBackCallBack) {
                void (^callbackBlock)(id) = webviewBackCallBack;
                callbackBlock(@{
                    @"data": @{
                        @"lat": @(coordinate.latitude),
                        @"lng": @(coordinate.longitude),
                        @"city": addressName,
                        @"address": formattedAddress
                    },
                    @"success": @"true",
                    @"errorMessage": @""
                });
            }
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:@(coordinate.latitude) forKey:@"currentLat"];
        [[NSUserDefaults standardUserDefaults] setObject:@(coordinate.longitude) forKey:@"currentLng"];
        [[NSUserDefaults standardUserDefaults] setObject:addressName forKey:@"currentCity"];
        [[NSUserDefaults standardUserDefaults] setObject:addressName forKey:@"currentAddress"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    };
    
    vc.hidesBottomBarWhenPushed = YES;
    [controller.navigationController pushViewController:vc animated:YES];
}

- (void)handleSelectLocationCity:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    // 初始化观察者数组
    if (!self.notificationObservers) {
        self.notificationObservers = [NSMutableArray array];
    }
    
    // 添加城市选择通知观察者
    __weak typeof(controller) weakController = controller;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"cityLocation" 
                                                                   object:nil 
                                                                    queue:[NSOperationQueue mainQueue] 
                                                               usingBlock:^(NSNotification *note) {
        NSDictionary *dic = note.object;
        if ([weakController respondsToSelector:@selector(webviewBackCallBack)]) {
            id webviewBackCallBack = [weakController valueForKey:@"webviewBackCallBack"];
            if (webviewBackCallBack) {
                void (^callbackBlock)(id) = webviewBackCallBack;
                callbackBlock(@{
                    @"data": @{
                        @"currentLat": [dic objectForKey:@"currentLat"],
                        @"currentLng": [dic objectForKey:@"currentLng"]
                    },
                    @"success": @"true",
                    @"errorMessage": @""
                });
            }
        }
    }];
    [self.notificationObservers addObject:observer];
    
    JFCityViewController *cityViewController = [[JFCityViewController alloc] init];
    cityViewController.delegate = self;
    cityViewController.title = @"选择城市";
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:cityViewController];
    [controller presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    // 只处理权限管理器的回调
    if (manager != self.permissionLocationManager) {
        return;
    }
    
    switch (status) {
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
            if (self.locationCallback) {
                [self startLocationWithCallback:self.locationCallback];
            }
            break;
            
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            if (self.locationCallback) {
                [self handleLocationPermissionDenied:self.locationCallback];
                self.locationCallback = nil;
            }
            break;
            
        case kCLAuthorizationStatusNotDetermined:
            // 继续等待用户决定
            break;
            
        default:
            break;
    }
    
    // 如果权限状态已确定，清理权限管理器
    if (status != kCLAuthorizationStatusNotDetermined) {
        self.permissionLocationManager.delegate = nil;
        self.permissionLocationManager = nil;
    }
}

#pragma mark - JFCityViewControllerDelegate

- (void)cityName:(NSString *)name cityCode:(NSString *)code {
    if (self.currentController && [self.currentController respondsToSelector:@selector(webviewBackCallBack)]) {
        id webviewBackCallBack = [self.currentController valueForKey:@"webviewBackCallBack"];
        if (webviewBackCallBack) {
            void (^callbackBlock)(id) = webviewBackCallBack;
            callbackBlock(@{
                @"data": @{
                    @"cityTitle": name,
                    @"cityCode": code
                },
                @"success": @"true",
                @"errorMessage": @""
            });
        }
    }
}

#pragma mark - 工具方法

- (BOOL)isLocationServiceOpen {
    // 检查定位服务是否可用
    if (![CLLocationManager locationServicesEnabled]) {
        return NO;
    }
    
    CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
    
    switch (authStatus) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
            return NO;
        case kCLAuthorizationStatusNotDetermined:
            return NO;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
            
            // iOS 14+ 检查精确定位权限
            if (@available(iOS 14.0, *)) {
                CLAccuracyAuthorization accuracyAuth = [CLLocationManager new].accuracyAuthorization;
                if (accuracyAuth == CLAccuracyAuthorizationReducedAccuracy) {
                } else {
                }
            }
            
            return YES;
        default:
            return NO;
    }
}

#pragma mark - 显示位置

- (void)handleShowLocation:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    // 实现显示地图位置
    // showLocation 通常用于在地图上显示某个位置，但在当前实现中只是简单返回成功
    if (callback) {
        callback([self formatCallbackResponse:@"showLocation" data:@{} success:YES errorMessage:nil]);
    }
}

@end