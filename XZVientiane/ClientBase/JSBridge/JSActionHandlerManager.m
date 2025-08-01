//
//  JSActionHandlerManager.m
//  XZVientiane
//
//  JS动作处理器管理器
//

#import "JSActionHandlerManager.h"
#import "Handlers/JSNavigationHandler.h"
#import "Handlers/JSUIHandler.h"
#import "Handlers/JSPaymentHandler.h"
#import "Handlers/JSShareHandler.h"
#import "Handlers/JSUserHandler.h"
#import "Handlers/JSDeviceHandler.h"
#import "Handlers/JSLocationHandler.h"
#import "Handlers/JSMediaHandler.h"
#import "Handlers/JSFileHandler.h"
#import "Handlers/JSMessageHandler.h"
#import "Handlers/JSMiscHandler.h"
#import "Handlers/JSNetworkHandler.h"
#import "Handlers/JSPageLifecycleHandler.h"

@interface JSActionHandlerManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, JSActionHandler *> *handlers;
@property (nonatomic, strong) dispatch_queue_t handlerQueue;

@end

@implementation JSActionHandlerManager

+ (instancetype)sharedManager {
    static JSActionHandlerManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[JSActionHandlerManager alloc] init];
        [instance registerDefaultHandlers];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _handlers = [NSMutableDictionary dictionary];
        _handlerQueue = dispatch_queue_create("com.zaiju.jshandler", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)registerDefaultHandlers {
    // 注册所有默认处理器
    [self registerHandler:[[JSNavigationHandler alloc] init]];
    [self registerHandler:[[JSUIHandler alloc] init]];
    [self registerHandler:[[JSPaymentHandler alloc] init]];
    [self registerHandler:[[JSShareHandler alloc] init]];
    [self registerHandler:[[JSUserHandler alloc] init]];
    [self registerHandler:[[JSDeviceHandler alloc] init]];
    [self registerHandler:[[JSLocationHandler alloc] init]];
    [self registerHandler:[[JSMediaHandler alloc] init]];
    [self registerHandler:[[JSFileHandler alloc] init]];
    [self registerHandler:[[JSMessageHandler alloc] init]];
    [self registerHandler:[[JSMiscHandler alloc] init]];
    [self registerHandler:[[JSNetworkHandler alloc] init]];
    [self registerHandler:[[JSPageLifecycleHandler alloc] init]];
}

- (void)registerHandler:(JSActionHandler *)handler {
    if (!handler) return;
    
    NSArray *actions = [handler supportedActions];
    for (NSString *action in actions) {
        dispatch_sync(self.handlerQueue, ^{
            self.handlers[action] = handler;
        });
    }
}

- (void)handleJavaScriptCall:(NSDictionary *)data 
                  controller:(UIViewController *)controller
                  completion:(JSActionCallbackBlock)completion {
    
    NSString *action = [data objectForKey:@"action"];
    id actionData = [data objectForKey:@"data"];
    
    if (!action || action.length == 0) {
        if (completion) {
            completion(@{
                @"success": @"false",
                @"errorMessage": @"No action specified",
                @"data": @{}
            });
        }
        return;
    }
    
    __block JSActionHandler *handler = nil;
    dispatch_sync(self.handlerQueue, ^{
        handler = self.handlers[action];
    });
    
    if (handler) {
        // 在主线程执行处理
        dispatch_async(dispatch_get_main_queue(), ^{
            [handler handleAction:action 
                           data:actionData 
                     controller:controller 
                       callback:completion];
        });
    } else {
        if (completion) {
            completion(@{
                @"success": @"false",
                @"errorMessage": [NSString stringWithFormat:@"Unknown action: %@", action],
                @"data": @{}
            });
        }
    }
}

- (BOOL)canHandleAction:(NSString *)action {
    if (!action) return NO;
    
    __block BOOL canHandle = NO;
    dispatch_sync(self.handlerQueue, ^{
        canHandle = (self.handlers[action] != nil);
    });
    
    return canHandle;
}

@end