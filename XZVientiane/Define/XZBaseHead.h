//
//  XZBaseHead.h
//  XZBase
//
//  Created by tuweia on 17/12/11.
//  Copyright © 2017年 TuWeiA. All rights reserved.
//

//测试环境宏定义 测试时为1 正式为0
#define kIsDebug 0
//银联支付的环境 "00"代表正式环境，"01"代表测试环境
#define kMode_Development @"00"

// 条件编译NSLog - Release版本禁用调试日志
#ifdef DEBUG
    #define ZJLog(...) NSLog(__VA_ARGS__)
#else
    // Release版本不输出日志，使用do-while避免空语句警告
    #define ZJLog(...) do {} while(0)
#endif

// 如果需要在Release版本中也输出某些重要日志，使用ZJLogAlways
#define ZJLogAlways(...) NSLog(__VA_ARGS__)

//内外网设置
#if kIsDebug==1

#define Domain @"https://zaiju.com"
#define UploadDomain @"https://zaiju.com"
//响站请求id
#define AppId @"xiangzhan$ios$g8u9t60p"
#define AppSecret @"$yas6WwyP7By9agE"
#define XiangJianAppH5Version @"1.8.5.9"
#define XiangZhanAppH5Version @"1.0.3"
#define MainDomain @"xfuwu.com"
#define AppMainDomain @".app.xfuwu.com"
#define Appid @"1422958968"
#define MY_APP_URL [NSString stringWithFormat:@"http://itunes.apple.com/lookup?id=%@",Appid]
//七牛头
#define QiNiuChace @"static.mendianquan.com"
#else

#define Domain @"https://zaiju.com"
#define UploadDomain @"https://zaiju.com"
//响站请求id
#define AppId @"xiangzhan$ios$g8u9t60p"
#define AppSecret @"$yas6WwyP7By9agE"
#define XiangJianAppH5Version @"1.8.5.9"
#define XiangZhanAppH5Version @"1.0.2"
#define MainDomain @"xfuwu.cn"
#define WebPage @"https://zaiju.com"
#define AppPage @"https://zaiju.com/p/checkTicket/check/check?id="
#define AppMainDomain @".app.xfuwu.cn"
#define Appid @"1485561849"
#define MY_APP_URL [NSString stringWithFormat:@"http://itunes.apple.com/lookup?id=%@",Appid]
//七牛头
#define QiNiuChace @"https://statics.tuiya.cc/"
//小程序原始id
#define Xiaochengxu @"gh_4a817d503791"
#endif


