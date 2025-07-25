//
//  main.m
//  XZVientiane
//
//  Created by 崔逢举 on 2017/11/13.
//  Copyright © 2017年 崔逢举. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[]) {
    NSLog(@"在局🎬🎬🎬 [main] ========== 应用程序入口 ==========");
    NSLog(@"在局🎬 [main] argc: %d", argc);
    for (int i = 0; i < argc; i++) {
        NSLog(@"在局🎬 [main] argv[%d]: %s", i, argv[i]);
    }
    NSLog(@"在局🎬 [main] 准备启动UIApplication...");
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
