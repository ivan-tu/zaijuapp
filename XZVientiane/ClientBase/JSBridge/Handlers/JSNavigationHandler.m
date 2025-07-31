//
//  JSNavigationHandler.m
//  XZVientiane
//
//  处理导航相关的JS调用
//

#import "JSNavigationHandler.h"
#import "CFJClientH5Controller.h"
#import "HTMLWebViewController.h"
#import "CustomHybridProcessor.h"
#import "JHSysAlertUtil.h"
#import "XZPackageH5.h"

@implementation JSNavigationHandler

- (NSArray<NSString *> *)supportedActions {
    return @[
        @"navigateTo",
        @"navigateBack", 
        @"reLaunch",
        @"switchTab",
        @"closeCurrentTab",
        @"setNavigationBarTitle",
        @"hideNavationbar",
        @"showNavationbar"
    ];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    if ([action isEqualToString:@"navigateTo"]) {
        [self handleNavigateTo:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"navigateBack"]) {
        [self handleNavigateBack:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"reLaunch"]) {
        [self handleReLaunch:controller callback:callback];
    } else if ([action isEqualToString:@"switchTab"]) {
        [self handleSwitchTab:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"closeCurrentTab"]) {
        [self handleCloseCurrentTab:controller callback:callback];
    } else if ([action isEqualToString:@"setNavigationBarTitle"]) {
        [self handleSetNavigationBarTitle:data controller:controller callback:callback];
    } else if ([action isEqualToString:@"hideNavationbar"]) {
        [self handleHideNavationbar:controller callback:callback];
    } else if ([action isEqualToString:@"showNavationbar"]) {
        [self handleShowNavationbar:controller callback:callback];
    }
}

#pragma mark - 导航操作

- (void)handleNavigateTo:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *url = nil;
        
        // 处理不同的数据格式
        if ([data isKindOfClass:[NSString class]]) {
            // 如果data本身就是字符串URL
            url = (NSString *)data;
            NSLog(@"在局🔧 [JSNavigationHandler navigateTo] 接收到字符串格式URL: %@", url);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            // 如果data是字典，从中提取url
            url = [(NSDictionary *)data objectForKey:@"url"];
            NSLog(@"在局🔧 [JSNavigationHandler navigateTo] 从字典中提取URL: %@", url);
        } else {
            NSLog(@"在局❌ [JSNavigationHandler navigateTo] 未知的数据格式: %@", [data class]);
        }
        
        if (!url || url.length == 0) {
            NSLog(@"在局❌ [JSNavigationHandler navigateTo] URL为空或无效");
            return;
        }
        
        NSString *domain = [[NSUserDefaults standardUserDefaults] objectForKey:@"kUserDefaults_domainStr"];
        NSString *JDomain = [NSString stringWithFormat:@"https://%@", domain];
        
        if (![url containsString:@"https://"]) {
            url = [NSString stringWithFormat:@"%@%@", JDomain, url];
        }
        
        // 检查是否为配置域名的内部链接
        NSString *configuredDomain = domain ?: @"zaiju.com";
        BOOL isInternalLink = [url containsString:configuredDomain];
        
        if (!isInternalLink) {
            // 外部链接
            HTMLWebViewController *htmlWebVC = [[HTMLWebViewController alloc] init];
            htmlWebVC.webViewDomain = url;
            htmlWebVC.hidesBottomBarWhenPushed = YES;
            [controller.navigationController pushViewController:htmlWebVC animated:YES];
            return;
        }
        
        // 内部链接处理
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [CustomHybridProcessor custom_LocialPathByUrlStr:url
                                            templateDic:cfController.templateDic
                                       componentJsAndCs:cfController.ComponentJsAndCs
                                           componentDic:cfController.ComponentDic
                                                success:^(NSString *filePath, NSString *templateStr, NSString *title, BOOL isFileExsit) {
            if (isFileExsit) {
                CFJClientH5Controller *appH5VC = [[CFJClientH5Controller alloc] init];
                appH5VC.hidesBottomBarWhenPushed = YES;
                appH5VC.pinUrl = url;
                appH5VC.replaceUrl = url;
                appH5VC.pinDataStr = templateStr;
                appH5VC.pagetitle = title;
                appH5VC.templateStr = templateStr;
                
                [controller.navigationController pushViewController:appH5VC animated:YES];
                
                __weak typeof(cfController) weakController = cfController;
                appH5VC.nextPageDataBlock = ^(NSDictionary *dic) {
                    __strong typeof(weakController) strongController = weakController;
                    strongController.nextPageData = dic;
                    NSDictionary *callJsDic = [CustomHybridProcessor custom_objcCallJsWithFn:@"dialogBridge" data:dic];
                    [strongController objcCallJs:callJsDic];
                };
            } else {
                if ([filePath containsString:@"http"]) {
                    HTMLWebViewController *htmlWebVC = [[HTMLWebViewController alloc] init];
                    htmlWebVC.webViewDomain = url;
                    htmlWebVC.hidesBottomBarWhenPushed = YES;
                    [controller.navigationController pushViewController:htmlWebVC animated:YES];
                } else {
                    [JHSysAlertUtil presentAlertViewWithTitle:@"温馨提示" message:@"正在开发中" confirmTitle:@"确定" handler:nil];
                }
            }
        }];
    });
}

- (void)handleNavigateBack:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([data isKindOfClass:[NSString class]]) {
            [controller.navigationController popViewControllerAnimated:NO];
        } else {
            NSDictionary *dataDic = (NSDictionary *)data;
            NSInteger delta = [[dataDic objectForKey:@"delta"] integerValue];
            if (delta != 0) {
                NSInteger count = controller.navigationController.viewControllers.count;
                if (delta < 0) {
                    if ([controller.navigationController.viewControllers[-delta] isKindOfClass:[CFJClientH5Controller class]]) {
                        [controller.navigationController popToViewController:controller.navigationController.viewControllers[-delta] animated:YES];
                    }
                } else {
                    if ([controller.navigationController.viewControllers[count - delta - 1] isKindOfClass:[CFJClientH5Controller class]]) {
                        [controller.navigationController popToViewController:controller.navigationController.viewControllers[count - delta - 1] animated:NO];
                    }
                }
            }
        }
    });
}

- (void)handleReLaunch:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (controller.tabBarController) {
            controller.tabBarController.selectedIndex = 0;
        } else {
            [controller.navigationController popToRootViewControllerAnimated:YES];
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

- (void)handleSwitchTab:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    [controller.navigationController popToRootViewControllerAnimated:YES];
    NSString *number = [[XZPackageH5 sharedInstance] getNumberWithLink:(NSString *)data];
    NSDictionary *setDic = @{@"selectNumber": number};
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"backToHome" object:setDic];
    });
}

- (void)handleCloseCurrentTab:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    if (controller.navigationController.viewControllers.count > 1) {
        [controller.navigationController popViewControllerAnimated:YES];
    } else {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)handleSetNavigationBarTitle:(id)data controller:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    NSDictionary *dataDic = (NSDictionary *)data;
    NSString *newTitle = [dataDic objectForKey:@"title"];
    dispatch_async(dispatch_get_main_queue(), ^{
        controller.navigationItem.title = newTitle;
    });
}

- (void)handleHideNavationbar:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    if ([controller respondsToSelector:@selector(hideNavatinBar)]) {
        [controller performSelector:@selector(hideNavatinBar)];
    }
    if ([controller respondsToSelector:@selector(webView)]) {
        UIScrollView *webView = [controller performSelector:@selector(webView)];
        if ([webView respondsToSelector:@selector(scrollView)]) {
            UIScrollView *scrollView = [webView performSelector:@selector(scrollView)];
            scrollView.bounces = NO;
        }
    }
}

- (void)handleShowNavationbar:(UIViewController *)controller callback:(JSActionCallbackBlock)callback {
    if ([controller respondsToSelector:@selector(showNavatinBar)]) {
        [controller performSelector:@selector(showNavatinBar)];
    }
    if ([controller respondsToSelector:@selector(webView)]) {
        UIScrollView *webView = [controller performSelector:@selector(webView)];
        if ([webView respondsToSelector:@selector(scrollView)]) {
            UIScrollView *scrollView = [webView performSelector:@selector(scrollView)];
            scrollView.bounces = YES;
        }
    }
}

@end