# CFJClientH5Controller 方法说明文档

## 文件信息
- **文件路径**: XZVientiane/ClientBase/BaseController/CFJClientH5Controller.h/.m
- **作用**: 具体的H5页面控制器，实现所有JavaScript与Native的交互功能
- **文件大小**: 4353行（需要重构）
- **创建时间**: 2016年

## 类继承关系
```
UIViewController
    └── XZViewController
            └── XZWKWebViewBaseController
                    └── CFJClientH5Controller
```

## 属性说明

### 公开属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| pageTitle | NSString* | 页面标题 |
| canShare | NSString* | 是否可以分享 |
| showRedpacket | NSString* | 是否显示红包 |
| uid | NSString* | 用户ID |

### 私有属性（部分重要）
| 属性名 | 类型 | 说明 |
|-------|------|------|
| locationManager | AMapLocationManager* | 高德定位管理器 |
| jsCallPayCallback | WVJBResponseCallback | 支付回调 |
| jsWeiXinLoginCallback | WVJBResponseCallback | 微信登录回调 |
| jsAppleLoginCallback | WVJBResponseCallback | Apple登录回调 |
| getLocationCallBack | WVJBResponseCallback | 定位回调 |
| nextPageData | NSDictionary* | 下一页数据 |
| locationInfo | CLLocation* | 位置信息 |

## 核心方法分类

### 1. JavaScript桥接处理（核心方法）

#### jsCallObjc:jsCallBack:
```objc
- (void)jsCallObjc:(id)jsData jsCallBack:(WVJBResponseCallback)jsCallBack
```
**作用**: 处理所有JavaScript调用Native的请求
**参数**:
- jsData: JS传递的数据字典
- jsCallBack: 回调函数
**实现逻辑**: 根据action字段分发到不同的处理方法（超过50个分支）

**主要action分类**:
- **页面导航**: navigateTo, navigateBack, redirectTo
- **UI交互**: showToast, showLoading, showModal, setNavigationBarTitle
- **支付功能**: payWeiXin, payAlipay
- **登录功能**: loginWeixin, loginApple, logout
- **分享功能**: shareToWeiXin
- **定位功能**: getLocation, startLocationUpdate, stopLocationUpdate
- **图片功能**: selectImage, uploadImage, saveImageToPhotosAlbum
- **扫码功能**: scanCode
- **网络请求**: request
- **存储功能**: setStorage, getStorage, removeStorage
- **系统功能**: makePhoneCall, setClipboardData, getSystemInfo

### 2. 页面导航相关

#### handleNavigateTo:callback:
```objc
- (void)handleNavigateTo:(NSDictionary *)params callback:(WVJBResponseCallback)callback
```
**作用**: 跳转到新页面
**实现**:
1. 解析URL参数
2. 创建新的CFJClientH5Controller实例
3. 使用pushViewController跳转

#### handleNavigateBack:callback:
```objc
- (void)handleNavigateBack:(NSDictionary *)params callback:(WVJBResponseCallback)callback
```
**作用**: 返回上一页或指定页数
**参数**: delta - 返回的页面数

#### handleRedirectTo:callback:
```objc
- (void)handleRedirectTo:(NSDictionary *)params callback:(WVJBResponseCallback)callback
```
**作用**: 重定向当前页面
**实现**: 更新URL并重新加载

### 3. 支付功能

#### 微信支付
```objc
// 处理微信支付请求
if ([function isEqualToString:@"payWeiXin"]) {
    self.jsCallPayCallback = jsCallBack;
    
    // 1. 检查微信是否安装
    if (![WXApi isWXAppInstalled]) {
        [self showToast:@"请先安装微信"];
        jsCallBack(@{@"code": @(-1), @"msg": @"请先安装微信"});
        return;
    }
    
    // 2. 获取支付参数
    NSString *orderId = [dataDic objectForKey:@"orderId"];
    
    // 3. 向服务器请求支付参数
    [self requestWeixinPayParams:orderId completion:^(NSDictionary *payParams) {
        // 4. 构建支付请求
        PayReq *request = [[PayReq alloc] init];
        // ... 设置参数
        
        // 5. 发起支付
        [WXApi sendReq:request completion:nil];
    }];
}
```

#### 支付宝支付
```objc
else if ([function isEqualToString:@"payAlipay"]) {
    self.jsCallPayCallback = jsCallBack;
    
    // 1. 获取订单信息
    NSString *orderId = [dataDic objectForKey:@"orderId"];
    
    // 2. 请求支付串
    [self requestAlipayOrderString:orderId completion:^(NSString *orderString) {
        // 3. 调起支付
        [[AlipaySDK defaultService] payOrder:orderString 
            fromScheme:@"XZVientianeAlipay" 
            callback:^(NSDictionary *resultDic) {
                // 4. 处理支付结果
                [self handleAlipayResult:resultDic];
        }];
    }];
}
```

### 4. 登录功能

#### 微信登录
```objc
else if ([function isEqualToString:@"loginWeixin"]) {
    ZJLog(@"接收到微信登录请求");
    
    if ([WXApi isWXAppInstalled]) {
        SendAuthReq *req = [[SendAuthReq alloc] init];
        req.scope = @"snsapi_userinfo";
        req.state = @"hi3zaiju";
        
        self.jsWeiXinLoginCallback = jsCallBack;
        [WXApi sendReq:req completion:nil];
    } else {
        [self showToast:@"请先安装微信"];
        jsCallBack(@{@"msg": @"请先安装微信", @"code": @(-1)});
    }
}
```

#### Apple登录（iOS 13+）
```objc
else if ([function isEqualToString:@"loginApple"]) {
    if (@available(iOS 13.0, *)) {
        ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
        ASAuthorizationAppleIDRequest *request = [provider createRequest];
        request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
        
        ASAuthorizationController *controller = [[ASAuthorizationController alloc] 
            initWithAuthorizationRequests:@[request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        
        self.jsAppleLoginCallback = jsCallBack;
        [controller performRequests];
    } else {
        jsCallBack(@{@"msg": @"系统版本不支持", @"code": @(-1)});
    }
}
```

### 5. 定位功能

#### 获取单次定位
```objc
else if ([function isEqualToString:@"getLocation"]) {
    self.getLocationCallBack = jsCallBack;
    
    // 1. 检查权限
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusDenied) {
        [self showLocationPermissionAlert];
        return;
    }
    
    // 2. 初始化定位管理器
    if (!self.locationManager) {
        self.locationManager = [[AMapLocationManager alloc] init];
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    
    // 3. 发起定位
    [self.locationManager requestLocationWithReGeocode:YES 
        completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            if (location) {
                // 返回定位结果
                NSDictionary *result = @{
                    @"latitude": @(location.coordinate.latitude),
                    @"longitude": @(location.coordinate.longitude),
                    @"accuracy": @(location.horizontalAccuracy),
                    @"address": regeocode.formattedAddress ?: @""
                };
                jsCallBack(result);
            }
    }];
}
```

### 6. 图片处理

#### 选择图片
```objc
else if ([function isEqualToString:@"selectImage"]) {
    NSInteger count = [[dataDic objectForKey:@"count"] integerValue] ?: 9;
    NSString *sourceType = [dataDic objectForKey:@"sourceType"] ?: @"all";
    
    // 根据sourceType显示不同选项
    if ([sourceType isEqualToString:@"camera"]) {
        [self openCamera:jsCallBack];
    } else if ([sourceType isEqualToString:@"album"]) {
        [self openAlbum:count callback:jsCallBack];
    } else {
        [self showImageSourceActionSheet:count callback:jsCallBack];
    }
}
```

#### 上传图片到七牛
```objc
else if ([function isEqualToString:@"uploadImage"]) {
    NSString *filePath = [dataDic objectForKey:@"filePath"];
    
    // 1. 获取七牛token
    [self getQiniuToken:^(NSString *token) {
        // 2. 读取图片
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *imageData = [self compressImage:image];
        
        // 3. 上传
        QNUploadManager *upManager = [[QNUploadManager alloc] init];
        [upManager putData:imageData 
                      key:[self generateFileName] 
                    token:token 
                 complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
            if (info.isOK) {
                NSString *imageUrl = [NSString stringWithFormat:@"%@%@", QINIU_CDN_URL, key];
                jsCallBack(@{@"code": @(0), @"url": imageUrl});
            }
        } option:nil];
    }];
}
```

### 7. 网络请求代理

```objc
else if ([function isEqualToString:@"request"]) {
    NSString *url = [dataDic objectForKey:@"url"];
    NSString *method = [dataDic objectForKey:@"method"] ?: @"GET";
    NSDictionary *data = [dataDic objectForKey:@"data"];
    NSDictionary *header = [dataDic objectForKey:@"header"];
    
    // 使用AFNetworking发送请求
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    // 设置请求头
    [header enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
    }];
    
    // 添加token
    NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
    if (token) {
        [manager.requestSerializer setValue:token forHTTPHeaderField:@"Authorization"];
    }
    
    // 发送请求
    if ([method isEqualToString:@"GET"]) {
        [manager GET:url parameters:data headers:nil progress:nil 
            success:^(NSURLSessionDataTask *task, id responseObject) {
                jsCallBack(@{@"code": @(0), @"data": responseObject});
            } 
            failure:^(NSURLSessionDataTask *task, NSError *error) {
                jsCallBack(@{@"code": @(-1), @"msg": error.localizedDescription});
        }];
    }
}
```

### 8. 本地存储

```objc
// 设置存储
else if ([function isEqualToString:@"setStorage"]) {
    NSString *key = [dataDic objectForKey:@"key"];
    id data = [dataDic objectForKey:@"data"];
    
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    jsCallBack(@{@"code": @(0)});
}

// 获取存储
else if ([function isEqualToString:@"getStorage"]) {
    NSString *key = [dataDic objectForKey:@"key"];
    id data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    jsCallBack(@{@"code": @(0), @"data": data ?: [NSNull null]});
}
```

### 9. 系统功能

```objc
// 拨打电话
else if ([function isEqualToString:@"makePhoneCall"]) {
    NSString *phoneNumber = [dataDic objectForKey:@"phoneNumber"];
    NSString *telUrl = [NSString stringWithFormat:@"tel:%@", phoneNumber];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:telUrl]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:telUrl] 
            options:@{} 
            completionHandler:^(BOOL success) {
                jsCallBack(@{@"code": @(success ? 0 : -1)});
        }];
    }
}

// 复制到剪贴板
else if ([function isEqualToString:@"setClipboardData"]) {
    NSString *data = [dataDic objectForKey:@"data"];
    [UIPasteboard generalPasteboard].string = data;
    
    [self showToast:@"复制成功"];
    jsCallBack(@{@"code": @(0)});
}
```

### 10. 辅助方法

#### formatCallbackResponse:data:success:errorMessage:
```objc
- (NSDictionary *)formatCallbackResponse:(NSString *)apiType 
                                    data:(id)data 
                                 success:(BOOL)success 
                            errorMessage:(NSString *)errorMessage
```
**作用**: 统一格式化回调响应
**参数**:
- apiType: API类型
- data: 返回数据
- success: 是否成功
- errorMessage: 错误信息
**返回**: 格式化的响应字典

#### detectAndHandleLoginStateChange
```objc
- (void)detectAndHandleLoginStateChange
```
**作用**: 检测并处理登录状态变化
**实现**:
1. 获取iOS端登录状态
2. 获取JS端登录状态
3. 比较并同步状态

#### showToast:
```objc
- (void)showToast:(NSString *)message
```
**作用**: 显示提示信息
**实现**: 使用MBProgressHUD显示toast

## 使用注意事项

1. **文件过大**: 4000+行代码，急需拆分重构
2. **内存管理**: 注意各种回调的释放
3. **线程安全**: UI操作必须在主线程
4. **权限处理**: 相机、相册、定位等需要权限
5. **iOS版本兼容**: 注意不同iOS版本的API差异

## 已知问题

1. jsCallObjc方法过于庞大（500+行）
2. 存在内存泄漏风险（通知未移除、定时器未释放）
3. 线程安全问题（UI操作未确保主线程）
4. 错误处理不统一
5. 日志过多影响性能

## 优化建议

1. **模块化拆分**:
   - 将jsCallObjc拆分为多个处理器
   - 使用策略模式或命令模式
   - 每个功能模块独立文件

2. **统一管理**:
   - 创建统一的权限管理器
   - 统一的错误处理机制
   - 统一的回调管理

3. **性能优化**:
   - 减少不必要的日志
   - 优化图片处理流程
   - 使用懒加载和缓存

4. **代码规范**:
   - 统一命名规范
   - 添加详细注释
   - 遵循单一职责原则