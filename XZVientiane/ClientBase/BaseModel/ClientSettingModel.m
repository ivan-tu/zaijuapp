//
//  SettingModel.m
//  TuWeiAApp
//
//  Created by CFJ on 15/12/21.
//  Copyright © 2015年 hans. All rights reserved.
//

#import "ClientSettingModel.h"

@interface ClientSettingModel ()

@property (nonatomic, strong) NSDictionary *settingDic;

@end

@implementation ClientSettingModel

DEF_SINGLETON(ClientSettingModel)

- (instancetype) init {
    if (self = [super init]) {
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"ClientSetting" ofType:@"plist"];
        self.settingDic = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        NSLog(@"在局Claude Code[配置加载]+ClientSetting.plist路径: %@", plistPath);
        NSLog(@"在局Claude Code[配置加载]+加载的配置内容: %@", self.settingDic);
    }
    return self;
}

- (NSString *)isDebug {
    return [self.settingDic objectForKey:@"kIsDebug"];
}

- (NSString *)mainWebSiteId {
    if (!_mainWebSiteId) {
        _mainWebSiteId = [self.settingDic objectForKey:@"WebSiteId"];
    }
    return _mainWebSiteId;
}
- (NSString *)AppSiteId {
    if (!_AppSiteId) {
        if (ISIPAD) {
            _AppSiteId = [self.settingDic objectForKey:@"PadAppId"];
        }
        else {
            _AppSiteId = [self.settingDic objectForKey:@"PhoneAppId"];
        }
    }
    return _AppSiteId;
}

- (NSString *)domain {
    NSString *domain = nil;
    if ([[self isDebug] intValue] == 1) {
        domain = [self.settingDic objectForKey:@"Domain"];
    } else {
        domain = [self.settingDic objectForKey:@"formalDomain"];
    }
    return domain;
}

//响站请求id
- (NSString *)appId {
    NSString *appId = nil;
    if ([[self isDebug] intValue] == 1) {
        appId = [self.settingDic objectForKey:@"AppId"];
        NSLog(@"在局Claude Code[配置读取]+调试模式AppId: %@", appId);
    }
    else {
        appId = [self.settingDic objectForKey:@"formalAppId"];
        NSLog(@"在局Claude Code[配置读取]+正式模式AppId: %@", appId);
    }
    return appId;
}
//app配置参数id
- (NSString *)appSeparateId {
    if ([[self isDebug] intValue] == 1) {
        return [self.settingDic objectForKey:@"AppSeparateId"];
    }
    else {
        return [self.settingDic objectForKey:@"formalAppSeparateId"];
    }
}
- (NSString *)appSecret {
    NSString *appSecret = nil;
    if ([[self isDebug] intValue] == 1) {
        appSecret = [self.settingDic objectForKey:@"AppSecret"];
        NSLog(@"在局Claude Code[配置读取]+调试模式AppSecret: %@", appSecret);
    }
    else {
        appSecret = [self.settingDic objectForKey:@"formalAppSecret"];
        NSLog(@"在局Claude Code[配置读取]+正式模式AppSecret: %@", appSecret);
    }
    return appSecret;
}

- (NSString *)appH5Version {
    if ([[self isDebug] intValue] == 1) {
        return [self.settingDic objectForKey:@"AppH5Version"];
    }
    else {
        return [self.settingDic objectForKey:@"formalAppH5Version"];
    }
}

- (NSString *)mainDomain {
    if ([[self isDebug] intValue] == 1) {
        return [self.settingDic objectForKey:@"MainDomain"];
    }
    else {
        return [self.settingDic objectForKey:@"formalMainDomain"];
    }
}
- (NSString *)appMainDomain{
    if ([[self isDebug] intValue] == 1) {
        return [self.settingDic objectForKey:@"AppMainDomain"];
    }
    else {
        return [self.settingDic objectForKey:@"formalAppMainDomain"];
    }
}

@end
