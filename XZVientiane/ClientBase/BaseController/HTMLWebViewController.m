//
//  HTMLWebViewController.m
//  XiangZhan
//
//  Created by yiliu on 16/6/7.
//  Copyright © 2016年 tuweia. All rights reserved.
//

#import "HTMLWebViewController.h"
#import "SkipSetViewController.h"
#import "XZIcomoonDefine.h"
#import "UIView+addition.h"
#import <WebKit/WebKit.h>
#import <Masonry.h>
#import <UMCommon/MobClick.h>
static inline BOOL isIPhoneXSeries() {
    BOOL iPhoneXSeries = NO;
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
        return iPhoneXSeries;
    }
    
    if (@available(iOS 11.0, *)) {
        UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
        if (mainWindow.safeAreaInsets.bottom > 0.0) {
            iPhoneXSeries = YES;
        }
    }
    
    return iPhoneXSeries;
}
@interface HTMLWebViewController ()<WKNavigationDelegate,UIScrollViewDelegate,WKUIDelegate>
@property (strong, nonatomic) WKWebView *webView;
@property (strong, nonatomic) SkipSetViewController *skipSetVC;
@property (strong, nonatomic) NSURL *requestUrl;
//进度条
@property (weak, nonatomic) CALayer *progresslayer;
@end

@implementation HTMLWebViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //移除监听
    [(WKWebView *)self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    
}
- (void)addNotif {
    WEAK_SELF;
    [[NSNotificationCenter defaultCenter] addObserverForName:@"refreshSkipH5VC" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        STRONG_SELF;
        //        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        //        NSURLRequest *request = [NSURLRequest requestWithURL:self.requestUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60  ];
        [self.webView reload];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"showShareView" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        STRONG_SELF;
        [self shareView];
    }];
}

- (void)viewDidLoad {
    NSLog(@"在局🌐 [HTMLWebViewController] viewDidLoad开始 - URL: %@", self.webViewDomain);
    [super viewDidLoad];
    self.webView.backgroundColor = [UIColor whiteColor];
    self.view.backgroundColor = [UIColor whiteColor];
    [self creatProgressView];
    [self addWebView];
    [self addNotif];
    self.navBar.closeBarButton.hidden = YES;
    [self.navBar.closeBarButton addTarget:self action:@selector(backToLast:) forControlEvents:(UIControlEventTouchUpInside)];
    NSLog(@"在局🌐 [HTMLWebViewController] viewDidLoad完成");
}
-(void)creatProgressView{
    //进度条
    UIView *progress = [[UIView alloc]initWithFrame:CGRectMake(0, isIPhoneXSeries() ? 88 : 64, CGRectGetWidth(self.view.frame), 3)];
    progress.backgroundColor = [UIColor clearColor];
    [self.view addSubview:progress];
    CALayer *layer = [CALayer layer];
    layer.frame = CGRectMake(0, 0, 0, 2);
    layer.backgroundColor = [UIColor colorWithHexString:@"#7BBD28"].CGColor;
    [progress.layer addSublayer:layer];
    self.progresslayer = layer;
}
- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"在局🌐 [HTMLWebViewController] viewWillAppear开始 - animated: %d", animated);
    [super viewWillAppear:animated];
    NSLog(@"在局🌐 [HTMLWebViewController] 准备隐藏导航栏");
    self.navigationController.navigationBarHidden = YES;
    //友盟页面统计
    NSString* cName = [NSString stringWithFormat:@"%@",self.navBar.titleLable.text, nil];
    [MobClick beginLogPageView:cName];
    NSLog(@"在局🌐 [HTMLWebViewController] viewWillAppear完成");
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"在局🌐 [HTMLWebViewController] viewDidAppear开始 - animated: %d", animated);
    [super viewDidAppear:animated];
    NSLog(@"在局🌐 [HTMLWebViewController] viewDidAppear完成 - URL: %@", self.webViewDomain);
    
    // 确保加载WebView内容
    if (!self.webView.URL && self.webViewDomain) {
        NSLog(@"在局🌐 [HTMLWebViewController] WebView未加载，开始加载URL");
        NSURL *url = [NSURL URLWithString:self.webViewDomain];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"在局🌐 [HTMLWebViewController] viewWillDisappear开始");
    [super viewWillDisappear:animated]; // 修复: 应该调用viewWillDisappear而不是viewWillAppear
    //友盟页面统计
    NSString* cName = [NSString stringWithFormat:@"%@",self.navBar.titleLable.text, nil];
    [MobClick endLogPageView:cName];
    NSLog(@"在局🌐 [HTMLWebViewController] viewWillDisappear完成");
}

- (void)addWebView {
    self.navBar.hidden = NO;
    self.navBar.titleLable.text = @"加载中";
    self.navBar.rightBarButton.hidden = NO;
    [self.navBar.rightBarButton setTitleImageWith:16 andColor:[UIColor color000000] andText:Icon_more];
    [self.navBar.rightBarButton addTarget:self action:@selector(more:) forControlEvents:UIControlEventTouchUpInside];
    
    self.webView = [[WKWebView alloc] init];
    [self.view insertSubview:self.webView belowSubview:self.navBar];
    if (isIPhoneXSeries()) {
        [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.view.mas_top).offset(88);
            make.left.right.bottom.mas_equalTo(self.view);
        }];
    }
    else {
        [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(self.view.mas_top).offset(64);
            make.left.right.bottom.mas_equalTo(self.view);
        }];
    }
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.scrollView.delegate = self;
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.backgroundColor = [UIColor tyBgViewColor];
    self.webView.scrollView.bounces = NO;
    self.webViewDomain = [self.webViewDomain stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    self.requestUrl = [NSURL URLWithString:self.webViewDomain];
    NSURLRequest *request = [NSURLRequest requestWithURL:self.requestUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    [self.webView loadRequest:request];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    self.skipSetVC = [[SkipSetViewController alloc] init];
    self.skipSetVC.view.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    self.skipSetVC.bgViewBtn.backgroundColor = [UIColor clearColor];
    
    
}
-(void)backToLast:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)more:(UIButton *)sender {
    [self.skipSetVC showInCurrentVC];
}
//返回按钮
- (void)leftNavButtonAction:(UIButton*)sender {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}
- (void)shareView {
//    ShareView *shareView = [[ShareView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, 185)];
//    //    shareView.shareModel = shareModel;
//    shareView.shareTitle = @"分享首页";
//    [self.view addSubview:shareView];
//    [UIView animateWithDuration:0.3 animations:^{
//        shareView.frame = CGRectMake(0, SCREEN_HEIGHT - 185, SCREEN_WIDTH, 185);
//    }];
}

#pragma mark - WebViewDelegate -
#pragma mark = WKNavigationDelegate
//在发送请求之前，决定是否跳转
-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler{
    decisionHandler(WKNavigationActionPolicyAllow);
}
//在响应完成时，调用的方法。如果设置为不允许响应，web内容就不会传过来

-(void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    decisionHandler(WKNavigationResponsePolicyAllow);
}
//接收到服务器跳转请求之后调用
-(void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation{
    
}

//开始加载时调用
-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    
}
//当内容开始返回时调用
-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
    
}
//页面加载完成之后调用
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    self.navBar.titleLable.text = webView.title;
    self.skipSetVC.linkStr = [NSString stringWithFormat:@"%@",webView.URL];
    // 禁用用户选择
    [webView evaluateJavaScript:@"document.documentElement.style.webkitUserSelect='none';" completionHandler:nil];
    // 禁用长按弹出框
    [webView evaluateJavaScript:@"document.documentElement.style.webkitTouchCallout='none';" completionHandler:nil];
    
    if ([self.webView canGoBack]) {
        self.navBar.closeBarButton.hidden = NO;
    }
    else {
        self.navBar.closeBarButton.hidden = YES;
    }
}
// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
{
    
}
#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures{
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
        self.navBar.closeBarButton.hidden = NO;
        
    }
    return nil;
}
#pragma mark - KVO监听函数
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.progresslayer.opacity = 1;
        if ([change[@"new"] floatValue] < [change[@"old"] floatValue]) {
            return;
        }
        self.progresslayer.frame = CGRectMake(0, 0, self.view.bounds.size.width * [change[@"new"] floatValue], 3);
        if ([change[@"new"] floatValue] == 1) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.progresslayer.opacity = 0;
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.progresslayer.frame = CGRectMake(0, 0, 0, 3);
                
            });
        }
    }else{
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -------- 设置状态条
- (UIStatusBarStyle)preferredStatusBarStyle {
    NSString *statusBarTextColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusBarTextColor"];
    if (![statusBarTextColor isEqualToString:@"#000000"] || [statusBarTextColor isEqualToString:@"black"]) {
        return UIStatusBarStyleDefault;
    }
    else {
        return UIStatusBarStyleLightContent;
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
