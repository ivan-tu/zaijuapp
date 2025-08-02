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
        
        // 检查网络权限状态，但无论如何都要移除LoadingView
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        if (appDelegate.networkRestricted) {
        } else {
        }
        
        // 立即移除LoadingView，因为首页内容已经准备就绪
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
        
        // 确保第一个tab正确加载
        if (tabbarItems.count > 0) {
            [self ensureFirstTabLoaded:tabbarItems];
        }
        
        // 延迟移除LoadingView
        [self scheduleLoadingViewRemoval];
    }];
}
#pragma mark - <UITabBarControllerDelegate>

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
    
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
                    
                    // 在局Claude Code[Tab懒加载修复]+使用正确的API触发视图控制器显示
                    // 使用beginAppearanceTransition和endAppearanceTransition替代直接调用生命周期方法
                    if (!homeVC.isViewLoaded) {
                        // 强制加载视图
                        [homeVC view];
                    }
                    
                    // 使用系统推荐的appearance transition API
                    [homeVC beginAppearanceTransition:YES animated:NO];
                    [homeVC endAppearanceTransition];
                    
                    // 延迟触发WebView加载，确保视图已完全准备就绪
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if ([homeVC respondsToSelector:@selector(domainOperate)]) {
                            [homeVC domainOperate];
                        }
                    });
                }
            }
        }
    }
    
    return YES;
}

//tabarController 代理
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    // 记录当前选中的tab索引
    NSInteger currentIndex = tabBarController.selectedIndex;
    static NSInteger lastSelectedIndex = -1;
    BOOL isRepeatClick = (lastSelectedIndex == currentIndex);
    
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)viewController;
        if (nav.viewControllers.count > 0) {
            UIViewController *rootVC = nav.viewControllers[0];
            
            // 在局Claude Code[Tab空白修复]+检查Tab页面是否需要重新加载
            if ([rootVC isKindOfClass:[CFJClientH5Controller class]]) {
                CFJClientH5Controller *h5Controller = (CFJClientH5Controller *)rootVC;
                
                // 延迟检查，给页面时间完成初始化
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // 检查是否有有效的WebView内容
                    if ([h5Controller respondsToSelector:@selector(hasValidWebViewContent)]) {
                        BOOL hasContent = [h5Controller performSelector:@selector(hasValidWebViewContent)];
                        if (!hasContent) {
                            NSLog(@"在局Claude Code[Tab空白修复]+检测到Tab页面无内容，触发重新加载");
                            // 触发页面加载
                            if ([h5Controller respondsToSelector:@selector(domainOperate)]) {
                                [h5Controller performSelector:@selector(domainOperate)];
                            }
                        } else {
                            NSLog(@"在局Claude Code[Tab空白修复]+Tab页面已有内容，无需重新加载");
                        }
                    }
                });
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 优化：只在重复点击同一个tab时才发送刷新通知
        if (isRepeatClick) {
            // 在局Claude Code[Main Thread Checker修复]+已在主线程中，可以直接访问
            UIApplicationState state = [[UIApplication sharedApplication] applicationState];
            if (state == UIApplicationStateActive) {
                [self sendRefreshNotification];
            }
        } else {
        }
        
        // 更新最后选中的索引
        lastSelectedIndex = currentIndex;
        
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
    // 在局Claude Code[Main Thread Checker修复]+确保在主线程访问UIApplication
    __block UIApplicationState state;
    if ([NSThread isMainThread]) {
        state = [[UIApplication sharedApplication] applicationState];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            state = [[UIApplication sharedApplication] applicationState];
        });
    }
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

#pragma mark - 在局Claude Code[LoadingView管理优化]+LoadingView统一管理

/**
 * 统一的LoadingView查找方法
 */
- (UIView *)findLoadingViewInAllWindows {
    // 按优先级顺序查找LoadingView
    NSArray *searchMethods = @[
        ^UIView *{ return [[UIApplication sharedApplication].keyWindow viewWithTag:2001]; },
        ^UIView *{ return [[UIApplication sharedApplication].delegate.window viewWithTag:2001]; },
        ^UIView *{ return [self.view viewWithTag:2001]; },
        ^UIView *{ return [self searchInAllWindows]; },
        ^UIView *{ return [self recursiveSearchInKeyWindow]; }
    ];
    
    for (UIView *(^searchMethod)(void) in searchMethods) {
        UIView *loadingView = searchMethod();
        if (loadingView) {
            return loadingView;
        }
    }
    
    return nil;
}

/**
 * 在所有window中搜索
 */
- (UIView *)searchInAllWindows {
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *window in windows) {
        UIView *loadingView = [window viewWithTag:2001];
        if (loadingView) {
            return loadingView;
        }
    }
    return nil;
}

/**
 * 在keyWindow中递归搜索
 */
- (UIView *)recursiveSearchInKeyWindow {
    return [self recursiveFindViewWithTag:2001 inView:[UIApplication sharedApplication].keyWindow];
}

/**
 * 递归查找指定tag的视图
 */
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

/**
 * 带动画移除LoadingView
 */
- (void)removeLoadingViewWithAnimation {
    UIView *loadingView = [self findLoadingViewInAllWindows];
    if (loadingView) {
        [UIView animateWithDuration:0.3 animations:^{
            loadingView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [loadingView removeFromSuperview];
        }];
    }
}

#pragma mark - 在局Claude Code[TabBar加载优化]+TabBar初始化优化

/**
 * 确保第一个tab正确加载
 */
- (void)ensureFirstTabLoaded:(NSArray *)tabbarItems {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *firstNav = tabbarItems[0];
        if (firstNav.viewControllers.count > 0) {
            CFJClientH5Controller *firstVC = (CFJClientH5Controller *)firstNav.viewControllers[0];
            
            // 触发视图加载
            [firstVC view];
            
            // 延迟检查并主动触发加载
            [self triggerFirstTabLoadingIfNeeded:firstVC];
        }
    });
}

/**
 * 如果需要，触发第一个tab的加载
 */
- (void)triggerFirstTabLoadingIfNeeded:(CFJClientH5Controller *)firstVC {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self shouldTriggerFirstTabLoading:firstVC]) {
            [self performFirstTabLoadingWithThrottle:firstVC];
        }
    });
}

/**
 * 判断是否应该触发第一个tab的加载
 */
- (BOOL)shouldTriggerFirstTabLoading:(CFJClientH5Controller *)firstVC {
    return !firstVC.isWebViewLoading && 
           !firstVC.isLoading && 
           firstVC.pinUrl && 
           firstVC.pinUrl.length > 0;
}

/**
 * 带节流机制的第一个tab加载
 */
- (void)performFirstTabLoadingWithThrottle:(CFJClientH5Controller *)firstVC {
    static NSDate *lastTabTriggerTime = nil;
    NSDate *now = [NSDate date];
    
    if (!lastTabTriggerTime || [now timeIntervalSinceDate:lastTabTriggerTime] > 3.0) {
        [firstVC domainOperate];
        lastTabTriggerTime = now;
    }
}

/**
 * 安排LoadingView移除
 */
- (void)scheduleLoadingViewRemoval {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performLoadingViewRemovalIfAllowed];
    });
}

/**
 * 如果允许，执行LoadingView移除
 */
- (void)performLoadingViewRemovalIfAllowed {
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if (appDelegate.networkRestricted) {
        return;
    }
    
    [self removeLoadingViewWithAnimation];
}

- (void)dealloc {
    // 移除通知观察者
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 取消所有延迟执行的方法
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

@end
