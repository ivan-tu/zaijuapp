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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *dataDic = (NSDictionary *)data;
        NSString *title = [dataDic objectForKey:@"title"] ?: @"";
        NSString *icon = [dataDic objectForKey:@"icon"] ?: @"none";
        NSTimeInterval duration = [[dataDic objectForKey:@"duration"] doubleValue] / 1000.0 ?: 1.0;
        
        if (title.length > 0) {
            if ([icon isEqualToString:@"success"]) {
                UIImage *successImage = [UIImage imageNamed:@"success_icon"] ?: [UIImage systemImageNamed:@"checkmark.circle.fill"];
                [SVStatusHUD showWithImage:successImage status:title duration:duration];
            } else if ([icon isEqualToString:@"loading"]) {
                [SVStatusHUD showWithMessage:title];
            } else {
                [SVStatusHUD showWithMessage:title];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // 自动消失
                });
            }
        }
    });
    
    if (callback) {
        callback(@{
            @"success": @"true",
            @"data": @{},
            @"errorMessage": @"",
            @"code": @0
        });
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
            NSLog(@"在局❌ [stopPullDownRefresh] 处理下拉刷新时发生异常: %@", exception.reason);
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
    NSString *string = [dataDic objectForKey:@"id"] ?: @"";
    
    __weak typeof(self) weakSelf = self;
    [[MOFSPickerManager shareManger] showMOFSAddressPickerWithDefaultZipcode:string 
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

@end