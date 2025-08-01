//
//  JHSysAlertUtil.m
//  JHSystemUtility
//
//  Created by 流痕 on 16/8/9.
//  Copyright © 2016年 FLZC. All rights reserved.
//

#import "JHSysAlertUtil.h"


#define kRootViewController [UIApplication sharedApplication].keyWindow.rootViewController

@implementation JHSysAlertUtil

/** 单个按键的 alertView */
+ (void)presentAlertViewWithTitle:(NSString *)title message:(NSString *)message confirmTitle:(NSString *)confirmTitle handler:(void(^)(void))handler {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    // creat action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:confirmTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
        if (handler) {
            handler();
        }
    }];
    
    // add acton
    [alert addAction:cancelAction];
    
    // present alertView on rootViewController
    dispatch_async(dispatch_get_main_queue(), ^{
        [kRootViewController presentViewController:alert animated:YES completion:nil];
    });
}

/** 双按键的 alertView */
+ (void)presentAlertViewWithTitle:(NSString *)title message:(NSString *)message cancelTitle:(NSString *)cancelTitle defaultTitle:(NSString *)defaultTitle distinct:(BOOL)distinct cancel:(void(^)(void))cancel confirm:(void(^)(void))confirm {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    // distinct : YES - 左浅右深
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:(distinct ? UIAlertActionStyleCancel : UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
        if (cancel) {
            cancel();
        }
    }];
    [alert addAction:cancelAction];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:defaultTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (confirm) {
            confirm();
        };
    }];
    
    [alert addAction:defaultAction];
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [kRootViewController presentViewController:alert animated:YES completion:nil];
    });    
}

/** Alert  任意多个按键 返回选中的 buttonIndex 和 buttonTitle */
+ (void)presentAlertWithTitle:(NSString *)title message:(NSString *)message actionTitles:(NSArray *)actionTitles  preferredStyle:(UIAlertControllerStyle)preferredStyle handler:(void(^)(NSUInteger buttonIndex, NSString *buttonTitle))handler {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:preferredStyle];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        handler(0, @"取消");
    }];
    [alert addAction:cancelAction];
    
    for (int i = 0; i < actionTitles.count; i ++) {
        
        UIAlertAction *confimAction = [UIAlertAction actionWithTitle:actionTitles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            handler((i + 1), actionTitles[i]);
        }];
        [alert addAction:confimAction];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [kRootViewController presentViewController:alert animated:YES completion:nil];
    });
}




@end
