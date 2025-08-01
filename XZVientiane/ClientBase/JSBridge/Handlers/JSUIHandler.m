//
//  JSUIHandler.m
//  XZVientiane
//
//  处理UI相关的JS调用
//

#import "JSUIHandler.h"
#import "ShowAlertView.h"
#import "SVStatusHUD.h"
#import "MOFSPickerManager.h"
#import "UITabBar+badge.h"
#import "JFCityViewController.h"

@interface JSUIHandler ()
@property (nonatomic, copy) JSActionCallbackBlock currentAreaSelectCallback;
@end

@implementation JSUIHandler

- (NSArray<NSString *> *)supportedActions {
    return @[
        @"showModal",
        @"showToast",
        @"showActionSheet",
        @"setTabBarBadge",
        @"removeTabBarBadge",
        @"showTabBarRedDot",
        @"hideTabBarRedDot",
        @"stopPullDownRefresh",
        @"fancySelect",
        @"areaSelect",
        @"areaSecondarySelect",
        @"dateSelect",
        @"dateAndTimeSelect",
        @"timeSelect"
    ];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"showModal"]) {
        [self handleShowModal:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"showToast"]) {
        [self handleShowToast:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"showActionSheet"]) {
        [self handleShowActionSheet:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"setTabBarBadge"]) {
        [self handleSetTabBarBadge:controller callback:callback];
    } else if ([action isEqualToString:@"removeTabBarBadge"]) {
        [self handleRemoveTabBarBadge:controller callback:callback];
    } else if ([action isEqualToString:@"showTabBarRedDot"]) {
        [self handleShowTabBarRedDot:controller callback:callback];
    } else if ([action isEqualToString:@"hideTabBarRedDot"]) {
        [self handleHideTabBarRedDot:controller callback:callback];
    } else if ([action isEqualToString:@"stopPullDownRefresh"]) {
        [self handleStopPullDownRefresh:controller callback:callback];
    } else if ([action isEqualToString:@"fancySelect"]) {
        [self handleFancySelect:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"areaSelect"]) {
        [self handleAreaSelect:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"areaSecondarySelect"]) {
        [self handleAreaSecondarySelect:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"dateSelect"]) {
        [self handleDateSelect:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"dateAndTimeSelect"]) {
        [self handleDateAndTimeSelect:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"timeSelect"]) {
        [self handleTimeSelect:data controller:controller callback:callback];
    }
}

#pragma mark - UI操作

- (void)handleShowModal:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSString *title = [[dataDic objectForKey:@"title"] length] ? [dataDic objectForKey:@"title"] : @"";
    NSString *cancelText = [[dataDic objectForKey:@"cancelText"] length] ? [dataDic objectForKey:@"cancelText"] : @"取消";
    NSString *confirmText = [[dataDic objectForKey:@"confirmText"] length] ? [dataDic objectForKey:@"confirmText"] : @"确认";
    
    ShowAlertView *alert = [ShowAlertView showAlertWithTitle:title message:[dataDic objectForKey:@"content"]];
    
    __weak typeof(self) weakSelf = self;
    [alert addItemWithTitle:cancelText itemType:(ShowAlertItemTypeBlack) callback:^(ShowAlertView *showview) {
        if (callback) {
            NSDictionary *response = [weakSelf formatCallbackResponse:@"showModal" 
                                                                data:@{@"cancel": @"true"} 
                                                             success:YES 
                                                        errorMessage:nil];
            callback(response);
        }
    }];
    
    [alert addItemWithTitle:confirmText itemType:(ShowStatusTextTypeCustom) callback:^(ShowAlertView *showview) {
        if (callback) {
            NSDictionary *response = [weakSelf formatCallbackResponse:@"showModal" 
                                                                data:@{@"confirm": @"true"} 
                                                             success:YES 
                                                        errorMessage:nil];
            callback(response);
        }
    }];
    
    [alert show];
}

- (void)handleShowToast:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    
    // 兼容多种字段名：title, message, text, content
    NSString *message = dataDic[@"title"] ?: dataDic[@"message"] ?: dataDic[@"text"] ?: dataDic[@"content"];
    
    // 获取显示时长，默认2秒
    NSNumber *durationNumber = dataDic[@"duration"];
    NSTimeInterval duration = durationNumber ? [durationNumber doubleValue] / 1000.0 : 2.0; // JS传毫秒，转换为秒
    
    // 获取Toast类型
    NSString *icon = dataDic[@"icon"];
    
    if (message && message.length > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([icon isEqualToString:@"success"]) {
                // 成功图标 - 使用绿色对勾图标
                UIImage *successImage = [UIImage imageNamed:@"success"] ?: [self createSuccessIcon];
                [SVStatusHUD showWithImage:successImage status:message duration:duration];
            } else if ([icon isEqualToString:@"error"] || [icon isEqualToString:@"fail"]) {
                // 错误图标 - 使用红色错误图标
                UIImage *errorImage = [UIImage imageNamed:@"error"] ?: [self createErrorIcon];
                [SVStatusHUD showWithImage:errorImage status:message duration:duration];
            } else if ([icon isEqualToString:@"loading"]) {
                // 加载状态 - 只显示文字，不需要图标
                [SVStatusHUD showWithMessage:message];
                // 加载状态需要手动关闭，设置定时器
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // SVStatusHUD没有dismiss方法，显示空消息来清除
                    [SVStatusHUD showWithMessage:@""];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // 通过显示空白来隐藏
                        [SVStatusHUD showWithImage:nil status:@"" duration:0.1];
                    });
                });
            } else {
                // 默认显示普通消息 - 由于没有duration参数的方法，显示后延时隐藏
                [SVStatusHUD showWithMessage:message];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [SVStatusHUD showWithImage:nil status:@"" duration:0.1];
                });
            }
        });
        
        if (callback) {
            callback([self formatCallbackResponse:@"showToast" data:@{} success:YES errorMessage:nil]);
        }
    } else {
        if (callback) {
            callback([self formatCallbackResponse:@"showToast" data:@{} success:NO errorMessage:@"Toast消息不能为空"]);
        }
    }
}

- (void)handleShowActionSheet:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    ShowAlertView *alert = [ShowAlertView showActionSheet];
    NSArray *items = [dataDic objectForKey:@"itemList"];
    
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < items.count; i++) {
        [alert addItemWithTitle:items[i] itemType:(ShowAlertItemTypeBlack) callback:^(ShowAlertView *showview) {
            if (callback) {
                NSDictionary *response = [weakSelf formatCallbackResponse:@"showActionSheet" 
                                                                    data:@{@"tapIndex": @(i)} 
                                                                 success:YES 
                                                            errorMessage:nil];
                callback(response);
            }
        }];
    }
    
    [alert addItemWithTitle:@"取消" itemType:(ShowStatusTextTypeCustom) callback:nil];
    [alert show];
}

- (void)handleSetTabBarBadge:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller.tabBarController.tabBar showBadgeOnItemIndex:3 withNum:1];
    });
}

- (void)handleRemoveTabBarBadge:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller.tabBarController.tabBar hideBadgeOnItemIndex:3];
    });
}

- (void)handleShowTabBarRedDot:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller.tabBarController.tabBar showRedDotOnItemIndex:1];
    });
}

- (void)handleHideTabBarRedDot:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller.tabBarController.tabBar hideRedDotOnItemIndex:1];
    });
}

- (void)handleStopPullDownRefresh:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if ([controller respondsToSelector:@selector(webView)]) {
                id webView = [controller performSelector:@selector(webView)];
                if ([webView respondsToSelector:@selector(scrollView)]) {
                    UIScrollView *scrollView = [webView performSelector:@selector(scrollView)];
                    
                    if ([scrollView respondsToSelector:@selector(mj_header)]) {
                        id mj_header = [scrollView valueForKey:@"mj_header"];
                        if (mj_header) {
                            NSNumber *isRefreshing = [mj_header valueForKey:@"isRefreshing"];
                            if (isRefreshing && [isRefreshing boolValue]) {
                                [mj_header performSelector:@selector(endRefreshing) withObject:nil];
                            }
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
        }
    });
    
    if (callback) {
        callback(@{
            @"success": @"true",
            @"data": @{},
            @"errorMessage": @""
        });
    }
}

#pragma mark - 选择器相关

- (void)handleFancySelect:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSArray *array = [dataDic objectForKey:@"value"];
    
    __weak typeof(self) weakSelf = self;
    [[MOFSPickerManager shareManger] showPickerViewWithData:array 
                                                        tag:1 
                                                      title:@"" 
                                                cancelTitle:@"取消" 
                                                commitTitle:@"确认" 
                                                commitBlock:^(NSString *string) {
        NSArray *indexArr = [string componentsSeparatedByString:@","];
        NSDictionary *response = [weakSelf formatCallbackResponse:@"fancySelect" 
                                                             data:@{@"value": indexArr[0]} 
                                                          success:YES 
                                                     errorMessage:nil];
        callback(response);
    } cancelBlock:^{
        NSDictionary *response = [weakSelf formatCallbackResponse:@"fancySelect" 
                                                             data:@{@"value": @""} 
                                                          success:NO 
                                                     errorMessage:@"用户取消"];
        callback(response);
    }];
}

- (void)handleAreaSelect:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    
    
    // 使用原有的MOFSPickerManager地址选择器
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak typeof(self) weakSelf = self;
        MOFSPickerManager *pickerManager = [MOFSPickerManager shareManger];
        
        NSString *defaultAddress = dataDic[@"name"] ?: @"";
        
        [pickerManager showCFJAddressPickerWithDefaultZipcode:@"" 
                                                       title:@"选择地区" 
                                                 cancelTitle:@"取消" 
                                                 commitTitle:@"确定" 
                                                 commitBlock:^(NSString *address, NSString *zipcode) {
            
            // 处理地址字符串，提取城市名称
            NSArray *components = [address componentsSeparatedByString:@"-"];
            NSString *cityName = components.count > 1 ? components[1] : address;
            
            // 保存选择的城市
            [[NSUserDefaults standardUserDefaults] setObject:cityName forKey:@"SelectCity"];
            if (zipcode && zipcode.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:zipcode forKey:@"currentCityCode"];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // 构建返回数据 - 与CFJClientH5Controller保持一致的格式
            NSDictionary *responseData = @{
                @"success": @"true",
                @"data": @{
                    @"value": address,
                    @"code": zipcode ?: @"",
                    @"name": cityName,
                    @"cityTitle": cityName,
                    @"cityCode": zipcode ?: @""
                },
                @"errorMessage": @""
            };
            
            if (callback) {
                callback(responseData);
            }
            
        } cancelBlock:^{
            
            if (callback) {
                NSDictionary *cancelData = @{
                    @"success": @"false",
                    @"data": @{},
                    @"errorMessage": @"用户取消"
                };
                callback(cancelData);
            }
        }];
        
    });
}

- (void)handleAreaSecondarySelect:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSString *string = [dataDic objectForKey:@"id"] ?: @"";
    
    __weak typeof(self) weakSelf = self;
    [[MOFSPickerManager shareManger] showCFJAddressPickerWithDefaultZipcode:string 
                                                                      title:@"" 
                                                                cancelTitle:@"取消" 
                                                                commitTitle:@"确定" 
                                                                commitBlock:^(NSString *address, NSString *zipcode) {
        NSDictionary *response = [weakSelf formatCallbackResponse:@"areaSelect" 
                                                             data:@{@"code": zipcode ?: @"", @"value": address ?: @""} 
                                                          success:YES 
                                                     errorMessage:nil];
        callback(response);
    } cancelBlock:^{
        NSDictionary *response = [weakSelf formatCallbackResponse:@"areaSelect" 
                                                             data:@{@"code": @"-1", @"value": @""} 
                                                          success:NO 
                                                     errorMessage:@"用户取消"];
        callback(response);
    }];
}

- (void)handleDateSelect:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd";
    NSString *string = [dataDic objectForKey:@"value"] ?: @"";
    NSDate *newdate = [self stringToDate:string withDateFormat:@"yyyy-MM-dd"];
    NSDate *min = [NSDate date];
    BOOL isMin = [[dataDic objectForKey:@"future"] boolValue];
    
    __weak typeof(self) weakSelf = self;
    [[MOFSPickerManager shareManger] showDatePickerWithfirstDate:newdate 
                                                          minDate:isMin ? min : nil 
                                                          maxDate:nil 
                                                   datePickerMode:UIDatePickerModeDate 
                                                      commitBlock:^(NSDate *date) {
        NSDictionary *response = [weakSelf formatCallbackResponse:@"dateSelect" 
                                                             data:@{@"value": [df stringFromDate:date]} 
                                                          success:YES 
                                                     errorMessage:nil];
        callback(response);
    } cancelBlock:^{
        NSDictionary *response = [weakSelf formatCallbackResponse:@"dateSelect" 
                                                             data:@{@"value": @""} 
                                                          success:NO 
                                                     errorMessage:@"用户取消"];
        callback(response);
    }];
}

- (void)handleDateAndTimeSelect:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"yyyy-MM-dd HH:mm";
    NSString *string = [dataDic objectForKey:@"value"] ?: @"";
    NSDate *newdate = [self stringToDate:string withDateFormat:@"yyyy-MM-dd"];
    NSDate *min = [NSDate date];
    BOOL isMin = [[dataDic objectForKey:@"future"] boolValue];
    
    __weak typeof(self) weakSelf = self;
    [[MOFSPickerManager shareManger] showDatePickerWithfirstDate:newdate 
                                                          minDate:isMin ? min : nil 
                                                          maxDate:nil 
                                                   datePickerMode:UIDatePickerModeDateAndTime 
                                                      commitBlock:^(NSDate *date) {
        NSDictionary *response = [weakSelf formatCallbackResponse:@"dateAndTimeSelect" 
                                                             data:@{@"value": [df stringFromDate:date]} 
                                                          success:YES 
                                                     errorMessage:nil];
        callback(response);
    } cancelBlock:^{
        NSDictionary *response = [weakSelf formatCallbackResponse:@"dateAndTimeSelect" 
                                                             data:@{@"value": @""} 
                                                          success:NO 
                                                     errorMessage:@"用户取消"];
        callback(response);
    }];
}

- (void)handleTimeSelect:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm";
    NSString *string = [dataDic objectForKey:@"value"] ?: @"";
    NSDate *newdate = [self stringToDate:string withDateFormat:@"HH:mm"];
    
    __weak typeof(self) weakSelf = self;
    [[MOFSPickerManager shareManger] showDatePickerWithfirstDate:newdate 
                                                          minDate:nil 
                                                          maxDate:nil 
                                                   datePickerMode:UIDatePickerModeTime 
                                                      commitBlock:^(NSDate *date) {
        NSDictionary *response = [weakSelf formatCallbackResponse:@"timeSelect" 
                                                             data:@{@"value": [df stringFromDate:date]} 
                                                          success:YES 
                                                     errorMessage:nil];
        callback(response);
    } cancelBlock:^{
        NSDictionary *response = [weakSelf formatCallbackResponse:@"timeSelect" 
                                                             data:@{@"value": @""} 
                                                          success:NO 
                                                     errorMessage:@"用户取消"];
        callback(response);
    }];
}

#pragma mark - 工具方法

- (NSDate *)stringToDate:(NSString *)dateString withDateFormat:(NSString *)format {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:format];
    NSDate *date = [dateFormatter dateFromString:dateString];
    return date;
}

#pragma mark - 辅助方法：创建图标

- (UIImage *)createSuccessIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 绘制绿色圆形背景
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, 20, 20));
    
    // 绘制白色对勾
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextMoveToPoint(context, 5, 10);
    CGContextAddLineToPoint(context, 8, 13);
    CGContextAddLineToPoint(context, 15, 6);
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)createErrorIcon {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // 绘制红色圆形背景
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, 20, 20));
    
    // 绘制白色X
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextMoveToPoint(context, 6, 6);
    CGContextAddLineToPoint(context, 14, 14);
    CGContextMoveToPoint(context, 14, 6);
    CGContextAddLineToPoint(context, 6, 14);
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - JFCityViewControllerDelegate

- (void)cityName:(NSString *)name cityCode:(id)code {
    // 类型安全检查和转换
    NSString *safeCode = nil;
    if (code) {
        if ([code isKindOfClass:[NSString class]]) {
            safeCode = (NSString *)code;
        } else if ([code isKindOfClass:[NSNumber class]]) {
            safeCode = [(NSNumber *)code stringValue];
        } else {
            safeCode = [NSString stringWithFormat:@"%@", code];
        }
    }
    
    // 类型安全检查和转换 - 确保name也是字符串类型
    NSString *safeName = nil;
    if (name) {
        if ([name isKindOfClass:[NSString class]]) {
            safeName = name;
        } else {
            safeName = [NSString stringWithFormat:@"%@", name];
        }
    }
    
    // 保存选择的城市到本地存储
    if (safeName && safeName.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:@"SelectCity"];
        [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:@"currentCity"];
        [[NSUserDefaults standardUserDefaults] setObject:safeName forKey:@"locationCity"]; // 同时更新locationCity
        if (safeCode && safeCode.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:safeCode forKey:@"currentCityCode"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if (self.currentAreaSelectCallback) {
        // 为不同的JavaScript调用提供不同的返回格式
        NSDictionary *areaSelectData = @{@"cityTitle": safeName ?: @"", @"cityCode": safeCode ?: @""};
        NSDictionary *citySelectData = @{@"name": safeName ?: @"", @"code": safeCode ?: @"", @"city": safeName ?: @""};
        
        // 默认使用areaSelect格式，同时支持selectLocationCity格式
        NSDictionary *response = [self formatCallbackResponse:@"areaSelect" 
                                                         data:areaSelectData 
                                                      success:YES 
                                                 errorMessage:nil];
        
        // 添加额外的城市信息供兼容
        NSMutableDictionary *mutableResponse = [response mutableCopy];
        NSMutableDictionary *mutableData = [mutableResponse[@"data"] mutableCopy];
        [mutableData addEntriesFromDictionary:citySelectData];
        mutableResponse[@"data"] = mutableData;
        
        self.currentAreaSelectCallback(mutableResponse);
        self.currentAreaSelectCallback = nil;
        
        // 发送城市变更通知
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CityChanged" object:nil userInfo:@{@"cityName": safeName ?: @"", @"cityCode": safeCode ?: @""}];
    }
}

@end