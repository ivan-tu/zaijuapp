//
//  CFJClientH5Controller.h
//  XiangZhanClient
//
//  Created by cuifengju on 2017/10/13.
//  Copyright © 2017年 TuWeiA. All rights reserved.
//

#import "XZWKWebViewBaseController.h"
#import "../JSBridge/Handlers/JSPaymentHandler.h"

typedef void(^CallBackToNative)(id aResponseObject,NSString *function);

// 在局Claude Code[修复未声明选择器警告]+实现支付回调协议
// 在局Claude Code[iPad照片选择器]+添加系统照片选择器协议
@interface CFJClientH5Controller : XZWKWebViewBaseController <JSPaymentCallbackSupport, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, assign) BOOL imVC;//判断是不是从聊天模块过来的，是的话不要显示messageBtn
@property (nonatomic, assign) BOOL isCheck;//是否需要检查版本更新和初始化定位

@property (nonatomic, copy) CallBackToNative callBackToNative;//回调给原生页面

@property (nonatomic, copy) NSString *removePage;//移除页面

// WebView相关属性
@property (nonatomic, strong) NSString *webViewDomain;
@property (nonatomic, strong) NSDictionary *navDic;

// 兼容性属性 - 用于JavaScript回调
// 在局Claude Code[修复空指针传递警告]+支持nullable属性
@property (nonatomic, copy, nullable) XZWebViewJSCallbackBlock webviewBackCallBack;

// 导航栏按钮标识属性
@property (assign, nonatomic) BOOL leftMessage;
@property (assign, nonatomic) BOOL rightMessage;
@property (assign, nonatomic) BOOL leftShop;
@property (assign, nonatomic) BOOL rightShop;

// JSBridge需要调用的方法
- (void)RequestWithJsDic:(NSDictionary *)dataDic type:(NSString *)type;
- (void)resetAllTabsToInitialState;
- (void)performWechatDirectLogin;
- (void)shareContent:(NSDictionary *)dic presentedVC:(UIViewController *)vc;
// 在局Claude Code[修复未声明选择器警告]+声明登录状态检测方法
- (void)detectAndHandleLoginStateChange:(void(^)(NSDictionary*))completion;

// 导航栏控制方法
// 在局Claude Code[修复未声明选择器警告]+声明导航栏方法
- (void)hideNavatinBar;
- (void)showNavatinBar;

// 文件处理方法
- (void)pushTZImagePickerControllerWithDic:(NSDictionary *)dataDic;
- (void)QiNiuUploadImageWithData:(NSDictionary *)dataDic;

@end
