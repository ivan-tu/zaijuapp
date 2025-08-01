//
//  XZTransitionTestViewController.m
//  XZVientiane
//
//  Created by Assistant on 2024/12/19.
//  Copyright © 2024年 TuWeiA. All rights reserved.
//

#import "XZTransitionTestViewController.h"
#import "CFJClientH5Controller.h"
#import "XZBaseHead.h"

@interface XZTransitionTestViewController ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *pushButton;
@property (nonatomic, strong) UIButton *popButton;
@property (nonatomic, strong) UIButton *toggleAnimationButton;
@property (nonatomic, strong) UITextView *logTextView;

@end

@implementation XZTransitionTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置默认值
    if (!self.pageIdentifier) {
        self.pageIdentifier = @"测试页面";
    }
    if (!self.pageBackgroundColor) {
        self.pageBackgroundColor = [UIColor whiteColor];
    }
    
    [self setupUI];
    [self setupConstraints];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.view.backgroundColor = self.pageBackgroundColor;
    self.navigationItem.title = self.pageIdentifier;
    
    // 标题标签
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = [NSString stringWithFormat:@"转场动画测试页面\n%@", self.pageIdentifier];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textColor = [UIColor blackColor];
    [self.view addSubview:self.titleLabel];
    
    // Push按钮
    self.pushButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.pushButton setTitle:@"推入新页面 (WebView)" forState:UIControlStateNormal];
    [self.pushButton setBackgroundColor:[UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0]];
    [self.pushButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.pushButton.layer.cornerRadius = 8;
    [self.pushButton addTarget:self action:@selector(pushNewPage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.pushButton];
    
    // Pop按钮
    self.popButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.popButton setTitle:@"返回上级页面" forState:UIControlStateNormal];
    [self.popButton setBackgroundColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0]];
    [self.popButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.popButton.layer.cornerRadius = 8;
    [self.popButton addTarget:self action:@selector(popCurrentPage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.popButton];
    
    // 切换动画按钮
    self.toggleAnimationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.toggleAnimationButton setTitle:@"切换动画开关" forState:UIControlStateNormal];
    [self.toggleAnimationButton setBackgroundColor:[UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:1.0]];
    [self.toggleAnimationButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.toggleAnimationButton.layer.cornerRadius = 8;
    [self.toggleAnimationButton addTarget:self action:@selector(toggleCustomAnimation) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.toggleAnimationButton];
    
    // 日志文本视图
    self.logTextView = [[UITextView alloc] init];
    self.logTextView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    self.logTextView.textColor = [UIColor darkGrayColor];
    self.logTextView.font = [UIFont systemFontOfSize:12];
    self.logTextView.editable = NO;
    self.logTextView.layer.cornerRadius = 8;
    self.logTextView.text = @"转场动画测试日志:\n";
    [self.view addSubview:self.logTextView];
}

- (void)setupConstraints {
    // 禁用自动调整大小
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.pushButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.popButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.toggleAnimationButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.logTextView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题标签
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        
        // Push按钮
        [self.pushButton.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:30],
        [self.pushButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.pushButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.pushButton.heightAnchor constraintEqualToConstant:50],
        
        // Pop按钮
        [self.popButton.topAnchor constraintEqualToAnchor:self.pushButton.bottomAnchor constant:15],
        [self.popButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.popButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.popButton.heightAnchor constraintEqualToConstant:50],
        
        // 切换动画按钮
        [self.toggleAnimationButton.topAnchor constraintEqualToAnchor:self.popButton.bottomAnchor constant:15],
        [self.toggleAnimationButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.toggleAnimationButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.toggleAnimationButton.heightAnchor constraintEqualToConstant:50],
        
        // 日志文本视图
        [self.logTextView.topAnchor constraintEqualToAnchor:self.toggleAnimationButton.bottomAnchor constant:20],
        [self.logTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.logTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.logTextView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
    ]];
}

#pragma mark - Actions

- (void)pushNewPage {
    [self addLog:@"点击推入新页面按钮"];
    
    // 创建一个CFJClientH5Controller来测试WebView转场动画
    CFJClientH5Controller *webVC = [[CFJClientH5Controller alloc] init];
    webVC.pinUrl = @"test://transition/page";
    webVC.pagetitle = [NSString stringWithFormat:@"WebView页面 %d", (int)self.navigationController.viewControllers.count + 1];
    
    // 设置一些测试数据
    webVC.pinDataStr = @"<div style='padding:20px; text-align:center; font-size:18px;'><h2>这是一个测试WebView页面</h2><p>用于测试自定义转场动画效果</p><button onclick='history.back()'>返回</button></div>";
    
    [self addLog:@"开始推入WebView页面"];
    [self.navigationController pushViewController:webVC animated:YES];
}

- (void)popCurrentPage {
    [self addLog:@"点击返回按钮"];
    
    if (self.navigationController.viewControllers.count > 1) {
        [self addLog:@"开始执行返回操作"];
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self addLog:@"已经是根页面，无法返回"];
    }
}

- (void)toggleCustomAnimation {
    if ([self.navigationController isKindOfClass:NSClassFromString(@"XZNavigationController")]) {
        id navController = self.navigationController;
        BOOL currentState = [[navController valueForKey:@"enableCustomTransition"] boolValue];
        [navController setValue:@(!currentState) forKey:@"enableCustomTransition"];
        
        NSString *statusText = currentState ? @"已禁用" : @"已启用";
        [self addLog:[NSString stringWithFormat:@"自定义转场动画%@", statusText]];
        
        [self.toggleAnimationButton setTitle:[NSString stringWithFormat:@"自定义动画: %@", statusText] 
                                    forState:UIControlStateNormal];
    } else {
        [self addLog:@"当前导航控制器不支持自定义转场动画"];
    }
}

#pragma mark - Helper Methods

- (void)addLog:(NSString *)logMessage {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *fullLog = [NSString stringWithFormat:@"[%@] %@\n", timestamp, logMessage];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logTextView.text stringByAppendingString:fullLog];
        
        // 滚动到底部
        NSRange range = NSMakeRange(self.logTextView.text.length, 0);
        [self.logTextView scrollRangeToVisible:range];
    });
    
}

@end