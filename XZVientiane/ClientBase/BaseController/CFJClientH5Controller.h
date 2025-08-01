//
//  CFJClientH5Controller.h
//  XiangZhanClient
//
//  Created by cuifengju on 2017/10/13.
//  Copyright © 2017年 TuWeiA. All rights reserved.
//

#import "XZWKWebViewBaseController.h"
typedef void(^CallBackToNative)(id aResponseObject,NSString *function);

@interface CFJClientH5Controller : XZWKWebViewBaseController

@property (nonatomic, assign) BOOL imVC;//判断是不是从聊天模块过来的，是的话不要显示messageBtn
@property (nonatomic, assign) BOOL isCheck;//是否需要检查版本更新和初始化定位

@property (nonatomic, copy) CallBackToNative callBackToNative;//回调给原生页面

@property (nonatomic, copy) NSString *removePage;//移除页面

// WebView相关属性
@property (nonatomic, strong) NSString *webViewDomain;
@property (nonatomic, strong) NSDictionary *navDic;

// 兼容性属性 - 用于JavaScript回调
@property (nonatomic, copy) XZWebViewJSCallbackBlock webviewBackCallBack;

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

// 文件处理方法
- (void)pushTZImagePickerControllerWithDic:(NSDictionary *)dataDic;
- (void)QiNiuUploadImageWithData:(NSDictionary *)dataDic;

@end
