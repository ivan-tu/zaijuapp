//
//  XZTabBarController.m
//  XZVientiane
//
//  Created by 崔逢举 on 2017/12/11.
//  Copyright © 2017年 崔逢举. All rights reserved.
//

#import "XZTabBarController.h"
#import "AppDelegate.h"
//model
#import "ClientSettingModel.h"
//view
#import "LoadingView.h"
//tool
#import "SDWebImageManager.h"
#import "ClientJsonRequestManager.h"
#import "ClientNetInterface.h"
#import "HTMLCache.h"
#import <UMShare/UMShare.h>
#import <UMCommon/UMCommon.h>
#import "CustomTabBar.h"
#import <UserNotifications/UserNotifications.h>
#import "CustomHybridProcessor.h"
#import <objc/runtime.h>

//VC
#import "CFJClientH5Controller.h"
#import "XZNavigationController.h"
#import "XZBaseHead.h"
#import "UIColor+addition.h"

#define Scale  [UIScreen mainScreen].scale

@interface XZTabBarController ()<CustomTabBarDelegate,UITabBarControllerDelegate>
{
    NSUInteger KselectedIndex;
}

@property (strong, nonatomic) NSDictionary *dataDic;
@property (nonatomic,strong)NSMutableArray *sortList;

@end

@implementation XZTabBarController
- (NSMutableArray *)sortList {
    if (_sortList == nil) {
        _sortList = [NSMutableArray arrayWithCapacity:0];
    }
    return _sortList;
}
- (void)addNotif {
    WEAK_SELF;
    //HideTabBarNotif   ShowTabBarNotif  上滑显示下滑隐藏tabbar
    [[NSNotificationCenter defaultCenter] addObserverForName:@"HideTabBarNotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [UIView animateWithDuration:0.5 animations:^{
            NSNumber *scrollHide = [[NSUserDefaults standardUserDefaults] objectForKey:@"TabBarHideWhenScroll"];
            if (scrollHide.integerValue == 1) {
                self.tabBar.frame = CGRectMake(self.tabBar.frame.origin.x, [UIScreen mainScreen].bounds.size.height, self.tabBar.frame.size.width, self.tabBar.frame.size.height);
            }
        }];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"ShowTabBarNotif" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        [UIView animateWithDuration:0.5 animations:^{
            NSNumber *scrollHide = [[NSUserDefaults standardUserDefaults] objectForKey:@"TabBarHideWhenScroll"];
            if (scrollHide.integerValue == 1) {
                self.tabBar.frame = CGRectMake(self.tabBar.frame.origin.x, [UIScreen mainScreen].bounds.size.height - 49, self.tabBar.frame.size.width, self.tabBar.frame.size.height);
            }
        }];
    }];
    
    //首页加载完成后移除LoadingView
    [[NSNotificationCenter defaultCenter] addObserverForName:@"showTabviewController" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        STRONG_SELF;
        NSLog(@"在局 🎯 [XZTabBarController] 收到showTabviewController通知");
        
        // 检查网络权限状态
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        if (appDelegate.networkRestricted) {
            NSLog(@"在局 ⚠️ [XZTabBarController] 网络权限受限，不移除LoadingView");
            return;
        }
        
        // 使用统一的LoadingView管理器移除
        [appDelegate removeGlobalLoadingViewWithReason:@"首页pageReady完成"];
        
        // TabBar已经显示，无需再设置hidden
    }];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    KselectedIndex = 0;
    [self addNotif];
    self.delegate = self;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    // 移除初始隐藏，让TabBar立即显示
    // self.view.hidden = YES;  // 注释掉，不再隐藏
    NSLog(@"在局 🎯 [XZTabBarController] viewDidLoad - TabBar将立即显示");
    
    // 添加应用生命周期通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // 延迟初始化sortList，避免影响启动性能
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self initializeSortList];
    });
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //    CustomTabBar *tabBar = [[CustomTabBar alloc] init];
    //    tabBar.tabbardelegate = self;
    //    // KVC：如果要修系统的某些属性，但被设为readOnly，就是用KVC，即setValue：forKey：。
    //    [self setValue:tabBar forKey:@"tabBar"];
    //    UINavigationController *navi = self.viewControllers[self.selectedIndex];
    //    if(navi && navi.viewControllers.count > 1) {
    //        tabBar.hidden = YES;
    //    }
    //    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"tabbarBgColor"]) {
    //        self.tabBar.barTintColor = [UIColor colorWithHexString:[[NSUserDefaults standardUserDefaults] objectForKey:@"tabbarBgColor"]];
    //    }
}

//更新Tabbar界面
- (void)reloadTabbarInterface {
    // 确保TabBar立即显示
    dispatch_async(dispatch_get_main_queue(), ^{
        self.view.hidden = NO;
    });
    
    WEAK_SELF;
    [CustomHybridProcessor custom_reloadTabbarInterfaceSuccess:^(NSArray * _Nullable tabs, NSString * _Nullable tabItemTitleSelectColor, NSString * _Nullable tabbarBgColor) {
        STRONG_SELF;
        NSMutableArray *tabbarItems = [NSMutableArray arrayWithCapacity:2];
        
        // 存储tab配置信息，延迟创建ViewController
        NSMutableArray *tabConfigs = [NSMutableArray array];
        
        for (NSInteger index = 0; index < tabs.count; index++) {
            NSDictionary *dic = tabs[index];
            [tabConfigs addObject:dic];
            
            // 只为第一个tab创建ViewController，其他的延迟创建
            UIViewController *rootVC = nil;
            if (index == 0) {
                CFJClientH5Controller *homeVC = [[CFJClientH5Controller alloc] init];
                if ([[dic objectForKey:@"isCheck"] isEqualToString:@"1"]) {
                    homeVC.isCheck = YES;
                }
                homeVC.isTabbarShow = YES;
                homeVC.pinUrl = [dic objectForKey:@"url"];
                rootVC = homeVC;
            } else {
                // 创建一个轻量级的占位ViewController
                UIViewController *placeholderVC = [[UIViewController alloc] init];
                placeholderVC.view.backgroundColor = [UIColor whiteColor];
                // 将配置信息存储在占位ViewController中
                objc_setAssociatedObject(placeholderVC, @"tabConfig", dic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(placeholderVC, @"tabIndex", @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                rootVC = placeholderVC;
            }
            
            XZNavigationController *nav = [[XZNavigationController alloc] initWithRootViewController:rootVC];
            nav.navigationBar.translucent = NO;
            
            // 设置TabBarItem的图标和标题
            UIImage *image = [UIImage imageNamed:[dic objectForKey:@"icon"]];
            image = [image scaleToSize:CGSizeMake(45, 45)];
            [nav.tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName :[UIColor colorWithHexString:tabItemTitleSelectColor]} forState:UIControlStateSelected];
            UIImage *tabImage = [UIImage imageWithCGImage:image.CGImage scale:2.0 orientation:UIImageOrientationUp];
            nav.tabBarItem.image = [tabImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            UIImage *selectedImage = [UIImage imageNamed:[dic objectForKey:@"activeIcon"]];
            selectedImage = [selectedImage scaleToSize:CGSizeMake(45, 45)];
            UIImage *selectedTabImage = [UIImage imageWithCGImage:selectedImage.CGImage scale:2.0 orientation:UIImageOrientationUp];
            nav.tabBarItem.selectedImage = [selectedTabImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            nav.tabBarItem.title = [dic objectForKey:@"name"];
            [tabbarItems addObject:nav];
        }
        
        // 存储tab配置信息供后续使用
        objc_setAssociatedObject(self, @"tabConfigs", tabConfigs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @"tabItemTitleSelectColor", tabItemTitleSelectColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        self.tabBar.translucent = NO;
        self.tabBar.barTintColor = [UIColor colorWithHexString:tabbarBgColor];
        self.viewControllers = tabbarItems;
        
        // 第一个tab会在viewDidLoad时自动加载，但需要确保触发
        if (tabbarItems.count > 0) {
            // 确保第一个tab的视图控制器被创建
            dispatch_async(dispatch_get_main_queue(), ^{
                UINavigationController *firstNav = tabbarItems[0];
                if (firstNav.viewControllers.count > 0) {
                    CFJClientH5Controller *firstVC = (CFJClientH5Controller *)firstNav.viewControllers[0];
                    // 触发视图加载
                    [firstVC view];
                    
                    // 修复真机权限授予后首页空白问题 - 延迟检查并主动触发加载
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (!firstVC.isWebViewLoading && !firstVC.isLoading && firstVC.pinUrl) {
                            // 添加节流机制，防止重复调用
                            static NSDate *lastTabTriggerTime = nil;
                            NSDate *now = [NSDate date];
                            if (!lastTabTriggerTime || [now timeIntervalSinceDate:lastTabTriggerTime] > 3.0) {
                                [firstVC domainOperate];
                                lastTabTriggerTime = now;
                            }
                        }
                    });
                }
            });
        }
        
        // 延迟移除LoadingView，给页面加载一些时间
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 检查网络权限状态
            AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
            if (appDelegate.networkRestricted) {
                return;
            }
            
            // 移除LoadingView - 搜索所有可能的窗口
            UIView *loadingView = [[UIApplication sharedApplication].keyWindow viewWithTag:2001];
            if (!loadingView) {
                // 从AppDelegate的window中查找
                UIWindow *mainWindow = [UIApplication sharedApplication].delegate.window;
                loadingView = [mainWindow viewWithTag:2001];
            }
            if (!loadingView) {
                // 从当前视图中查找
                loadingView = [self.view viewWithTag:2001];
            }
            
            if (loadingView) {
                [UIView animateWithDuration:0.3 animations:^{
                    loadingView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [loadingView removeFromSuperview];
                }];
            }
        });
    }];
}
#pragma mark - <UITabBarControllerDelegate>

// iOS 18修复：实现shouldSelectViewController代理方法
- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    // iOS 18修复：在切换前确保当前视图控制器的转场已完成
    if (@available(iOS 13.0, *)) {
        // 取消任何正在进行的转场
        if (self.transitionCoordinator && self.transitionCoordinator.isAnimated) {
            [self.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
                // 转场完成
            }];
        }
    }
    
    // 懒加载逻辑 - 检查是否为NavigationController
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)viewController;
        if (nav.viewControllers.count > 0) {
            UIViewController *rootVC = nav.viewControllers[0];
            
            // 检查是否为占位ViewController
            if (![rootVC isKindOfClass:[CFJClientH5Controller class]]) {
                // 获取存储的配置信息
                NSDictionary *tabConfig = objc_getAssociatedObject(rootVC, @"tabConfig");
                NSNumber *tabIndex = objc_getAssociatedObject(rootVC, @"tabIndex");
                
                if (tabConfig) {
                    // 创建真实的CFJClientH5Controller
                    CFJClientH5Controller *homeVC = [[CFJClientH5Controller alloc] init];
                    if ([[tabConfig objectForKey:@"isCheck"] isEqualToString:@"1"]) {
                        homeVC.isCheck = YES;
                    }
                    homeVC.isTabbarShow = YES;
                    homeVC.pinUrl = [tabConfig objectForKey:@"url"];
                    
                    // 替换占位ViewController
                    [nav setViewControllers:@[homeVC] animated:NO];
                }
            }
        }
    }
    
    return YES;
}

//tabarController 代理
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    // iOS 18 修复：避免转场协调器导致的阻塞
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)viewController;
        if (nav.viewControllers.count > 0) {
            UIViewController *rootVC = nav.viewControllers[0];
            
            // iOS 18修复：强制触发视图生命周期
            if (@available(iOS 16.0, *)) {
                // iOS 16+需要特殊处理
                if (![rootVC isViewLoaded] || !rootVC.view.window) {
                    // 触发viewDidLoad
                    [rootVC view];
                    // 强制布局
                    [rootVC.view setNeedsLayout];
                    [rootVC.view layoutIfNeeded];
                }
            }
        }
    }
    
    // iOS 18修复：简化转场处理，避免使用transitionCoordinator
    dispatch_async(dispatch_get_main_queue(), ^{
        // 发送刷新通知
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateActive) {
            [self sendRefreshNotification];
        }
        
        // 延迟执行TabBar动画，确保不影响视图转场
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIControl *button = [self getTabBarButton];
            if (button) {
                [self tabBarButtonClick:button];
            }
        });
    });
}

- (void)sendRefreshNotification {
    // 再次检查应用状态
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive) {
        [[NSNotificationCenter defaultCenter]postNotificationName:@"refreshCurrentViewController" object:nil];
    }
}
//获取当前选中tab
- (UIControl *)getTabBarButton{
    // 添加安全检查，避免在转场过程中执行复杂操作
    if (!self.tabBar || self.tabBar.subviews.count == 0) {
        return nil;
    }
    
    if (self.sortList.count == 0) {
        // 使用performSelector延迟初始化，避免阻塞转场
        [self performSelector:@selector(initializeSortList) withObject:nil afterDelay:0.1];
        return nil;
    }
    
    UIControl *tabBarButton = [self.sortList safeObjectAtIndex:self.selectedIndex];
    return tabBarButton;
}

// 新增方法：初始化sortList
- (void)initializeSortList {
    if (self.sortList.count > 0) {
        return;
    }
    
    NSMutableArray *tabBarButtons = [[NSMutableArray alloc]initWithCapacity:0];
    for (UIView *child in self.tabBar.subviews) {
        Class class = NSClassFromString(@"UITabBarButton");
        if ([child isKindOfClass:class]) {
            [tabBarButtons addObject:child];
        }
    }
    
    if (tabBarButtons.count > 0) {
        int number = (int)tabBarButtons.count;
        self.sortList = [self QuickSort:tabBarButtons StartIndex:0 EndIndex: number- 1];
    }
}
#pragma mark - 点击动画
- (void)tabBarButtonClick:(UIControl *)tabBarButton
{
    // 添加安全检查
    if (!tabBarButton || !tabBarButton.subviews) {
        return;
    }
    
    // 延迟执行动画，避免与转场动画冲突
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (UIView *imageView in tabBarButton.subviews) {
            if ([imageView isKindOfClass:NSClassFromString(@"UITabBarSwappableImageView")]) {
                // 移除之前的动画，避免动画冲突
                [imageView.layer removeAllAnimations];
                
                //需要实现的帧动画,这里根据自己需求改动
                CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
                animation.keyPath = @"transform.scale";
                animation.values = @[@1.0,@1.1,@1.3,@0.9,@1.0];
                animation.duration = 0.3;
                animation.calculationMode = kCAAnimationCubic;
                animation.fillMode = kCAFillModeForwards;
                animation.removedOnCompletion = YES;
                
                //添加动画
                [imageView.layer addAnimation:animation forKey:@"tabBarAnimation"];
            }
        }
    });
}
- (void)tabBarDidClickPlusButton:(CustomTabBar *)tabBar {
    [[NSNotificationCenter defaultCenter]postNotificationName:@"openServiceCenter" object:nil];
}
//快速排序
-(NSMutableArray *)QuickSort:(NSMutableArray *)list StartIndex:(int)startIndex EndIndex:(int)endIndex{
    
    if(startIndex >= endIndex)return nil;
    
    UIView * temp = [list objectAtIndex:startIndex];
    int tempIndex = startIndex; //临时索引 处理交换位置(即下一个交换的对象的位置)
    
    for(int i = startIndex + 1 ; i <= endIndex ; i++){
        
        UIView *t = [list objectAtIndex:i];
        
        if(temp.frame.origin.x > t.frame.origin.x){
            
            tempIndex = tempIndex + 1;
            
            [list exchangeObjectAtIndex:tempIndex withObjectAtIndex:i];
        }
    }
    [list exchangeObjectAtIndex:tempIndex withObjectAtIndex:startIndex];
    [self QuickSort:list StartIndex:startIndex EndIndex:tempIndex -1];
    [self QuickSort:list StartIndex:tempIndex+1 EndIndex:endIndex];
    return list;
}

#pragma mark - App Lifecycle

- (void)appWillResignActive:(NSNotification *)notification {
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)appDidEnterBackground:(NSNotification *)notification {
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (UIView *)findLoadingViewInAllWindows {
    NSLog(@"在局 🔍 [XZTabBarController] 开始在所有窗口中查找LoadingView");
    
    // 1. 首先在keyWindow中查找
    UIView *loadingView = [[UIApplication sharedApplication].keyWindow viewWithTag:2001];
    if (loadingView) {
        NSLog(@"在局 ✅ [XZTabBarController] 在keyWindow中找到LoadingView");
        return loadingView;
    }
    
    // 2. 在delegate的window中查找
    UIWindow *mainWindow = [UIApplication sharedApplication].delegate.window;
    loadingView = [mainWindow viewWithTag:2001];
    if (loadingView) {
        NSLog(@"在局 ✅ [XZTabBarController] 在delegate.window中找到LoadingView");
        return loadingView;
    }
    
    // 3. 在所有window中查找
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        loadingView = [window viewWithTag:2001];
        if (loadingView) {
            NSLog(@"在局 ✅ [XZTabBarController] 在window %@ 中找到LoadingView", window);
            return loadingView;
        }
    }
    
    // 4. 在当前TabBarController的视图层级中查找
    loadingView = [self.view viewWithTag:2001];
    if (loadingView) {
        NSLog(@"在局 ✅ [XZTabBarController] 在TabBarController.view中找到LoadingView");
        return loadingView;
    }
    
    // 5. 递归查找所有子视图
    loadingView = [self recursiveFindViewWithTag:2001 inView:[UIApplication sharedApplication].keyWindow];
    if (loadingView) {
        NSLog(@"在局 ✅ [XZTabBarController] 通过递归查找找到LoadingView");
        return loadingView;
    }
    
    NSLog(@"在局 ❌ [XZTabBarController] 在所有位置都未找到LoadingView");
    return nil;
}

- (UIView *)recursiveFindViewWithTag:(NSInteger)tag inView:(UIView *)parentView {
    if (!parentView) return nil;
    
    // 检查当前视图
    if (parentView.tag == tag) {
        return parentView;
    }
    
    // 递归检查所有子视图
    for (UIView *subview in parentView.subviews) {
        UIView *found = [self recursiveFindViewWithTag:tag inView:subview];
        if (found) {
            return found;
        }
    }
    
    return nil;
}

- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

@end
