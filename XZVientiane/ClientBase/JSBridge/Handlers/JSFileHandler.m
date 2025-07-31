//
//  JSFileHandler.m
//  XZVientiane
//
//  处理文件相关的JS调用
//

#import "JSFileHandler.h"
#import "CFJClientH5Controller.h"
#import "TZImagePickerController.h"
#import <Photos/Photos.h>
#import <QiniuSDK.h>
#import "CustomHybridProcessor.h"
#import "UIImage+tool.h"

@interface JSFileHandler () <TZImagePickerControllerDelegate>

@property (nonatomic, weak) UIViewController *currentController;
@property (nonatomic, copy) JSActionCallbackBlock fileCallback;

@end

@implementation JSFileHandler

- (NSArray<NSString *> *)supportedActions {
    return @[@"chooseFile", @"uploadFile"];
}

- (void)handleAction:(NSString *)action 
              data:(id)data 
        controller:(UIViewController *)controller
          callback:(JSActionCallbackBlock)callback {
    
    self.currentController = controller;
    
    // 保存回调
    if ([controller respondsToSelector:@selector(setWebviewBackCallBack:)]) {
        [controller performSelector:@selector(setWebviewBackCallBack:) withObject:callback];
    }
    
    if ([action isEqualToString:@"chooseFile"]) {
        [self handleChooseFile:data controller:controller];
    } else if ([action isEqualToString:@"uploadFile"]) {
        [self handleUploadFile:data controller:controller];
    }
}

#pragma mark - 文件选择处理

- (void)handleChooseFile:(id)data controller:(UIViewController *)controller {
    NSDictionary *dataDic = (NSDictionary *)data;
    
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController pushTZImagePickerControllerWithDic:dataDic];
    }
}

- (void)handleUploadFile:(id)data controller:(UIViewController *)controller {
    if ([controller isKindOfClass:[CFJClientH5Controller class]]) {
        CFJClientH5Controller *cfController = (CFJClientH5Controller *)controller;
        [cfController QiNiuUploadImageWithData:data];
    }
}

@end