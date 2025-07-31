# XZWKWebViewBaseController 方法说明文档

## 文件信息
- **文件路径**: XZVientiane/XZBase/BaseController/XZWKWebViewBaseController.h/.m
- **作用**: WebView页面的新基类，提供WKWebView的创建、配置和JavaScript桥接功能
- **创建时间**: 2024年12月19日（新增类）

## 类继承关系
```
UIViewController
    └── XZViewController
            └── XZWKWebViewBaseController
```

## 属性说明

### 公开属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| webView | WKWebView* | WebView实例 |
| urlString | NSString* | 当前加载的URL |
| webViewTitle | NSString* | WebView标题 |
| showProgressBar | BOOL | 是否显示进度条 |
| hasDelayedUIOperations | BOOL | 是否有延迟的UI操作 |

### 私有属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| bridge | WKWebViewJavascriptBridge* | JS-Native桥接对象 |
| progressView | UIProgressView* | 进度条视图 |
| preCreatedWebView | WKWebView* | 预创建的WebView实例 |
| hasLoadedWebView | BOOL | 是否已加载WebView |

## 方法详解

### 类方法

#### preloadHTMLTemplates
```objc
+ (void)preloadHTMLTemplates
```
**作用**: 预加载HTML模板到内存缓存
**实现逻辑**:
1. 使用dispatch_once确保只执行一次
2. 在后台队列异步加载app.html模板
3. 将模板缓存到NSCache中
4. 提高首次加载速度

### 初始化方法

#### init
```objc
- (instancetype)init
```
**作用**: 初始化控制器
**实现逻辑**:
1. 调用父类init
2. 设置showProgressBar默认为YES
3. 设置hasDelayedUIOperations默认为NO
4. 返回self

### 生命周期方法

#### viewDidLoad
```objc
- (void)viewDidLoad
```
**作用**: 视图加载完成后的初始化
**实现逻辑**:
1. 调用父类方法
2. 设置视图背景色
3. 创建并配置进度条（如果showProgressBar为YES）
4. 添加通知观察者（网络可用、支付结果、登录结果等）
5. 检查并执行延迟的UI操作（iOS 16-18特殊处理）

#### viewWillAppear:
```objc
- (void)viewWillAppear:(BOOL)animated
```
**作用**: 视图即将显示
**实现逻辑**:
1. 调用父类方法
2. 更新导航栏标题（如果有webViewTitle）
3. 通知JavaScript页面即将显示

#### viewDidAppear:
```objc
- (void)viewDidAppear:(BOOL)animated
```
**作用**: 视图已经显示
**实现逻辑**:
1. 调用父类方法
2. 首次显示时创建WebView并加载内容
3. 非首次显示时通知JavaScript页面显示
4. 检查并执行延迟的UI操作

#### viewDidDisappear:
```objc
- (void)viewDidDisappear:(BOOL)animated
```
**作用**: 视图已经消失
**实现逻辑**:
1. 调用父类方法
2. 通知JavaScript页面隐藏

#### dealloc
```objc
- (void)dealloc
```
**作用**: 对象销毁时的清理
**实现逻辑**:
1. 移除所有通知观察者
2. 移除KVO观察者（进度条、标题）
3. 停止WebView加载
4. 清理WebView的delegate
5. 从父视图移除WebView
6. 打印调试日志

### WebView创建和配置

#### createWebView
```objc
- (void)createWebView
```
**作用**: 创建和配置WKWebView
**实现逻辑**:
1. 创建WKWebViewConfiguration
2. 设置JavaScript启用、内联播放等偏好
3. 创建WKWebView实例
4. 设置导航代理和UI代理
5. 启用侧滑返回手势
6. 添加到视图并设置约束
7. 设置JavaScript桥接
8. 添加KVO观察（进度、标题）

#### preCreateWebViewIfNeeded
```objc
- (void)preCreateWebViewIfNeeded
```
**作用**: 预创建WebView以提高性能
**实现逻辑**:
1. 检查是否已预创建
2. 在主线程异步创建WebView
3. 使用零大小frame减少内存占用

#### createWebViewConfiguration
```objc
- (WKWebViewConfiguration *)createWebViewConfiguration
```
**作用**: 创建WebView配置
**返回值**: 配置好的WKWebViewConfiguration对象
**实现逻辑**:
1. 创建配置对象
2. 设置JavaScript相关偏好
3. 配置媒体播放选项
4. 创建进程池

### JavaScript桥接

#### setupJavaScriptBridge
```objc
- (void)setupJavaScriptBridge
```
**作用**: 设置JavaScript与Native的通信桥接
**实现逻辑**:
1. 启用调试日志（DEBUG模式）
2. 创建桥接对象
3. 注册统一消息处理器"xzBridge"
4. 注册其他特定处理器

#### jsCallObjc:jsCallBack:
```objc
- (void)jsCallObjc:(id)jsData jsCallBack:(WVJBResponseCallback)jsCallBack
```
**作用**: 处理JavaScript调用Native的请求
**参数**:
- jsData: JavaScript传递的数据
- jsCallBack: 回调函数
**实现**: 子类需要重写此方法实现具体功能

#### objcCallJs:
```objc
- (void)objcCallJs:(NSDictionary *)dic
```
**作用**: Native调用JavaScript函数
**参数**: dic - 包含函数名和参数的字典
**实现逻辑**:
1. 提取函数名和参数
2. 确保在主线程执行
3. 通过桥接调用JavaScript函数

### HTML加载

#### domainOperate
```objc
- (void)domainOperate
```
**作用**: 加载HTML内容
**实现逻辑**:
1. 读取app.html模板
2. 获取页面具体内容
3. 替换模板中的{{body}}占位符
4. 设置baseURL为manifest目录
5. 加载HTML字符串

#### optimizedLoadHTMLContent
```objc
- (void)optimizedLoadHTMLContent
```
**作用**: 优化的HTML内容加载
**实现逻辑**:
1. 从缓存获取HTML模板
2. 如果缓存不存在则读取文件
3. 替换占位符并加载

### UI操作

#### performDelayedUIOperations
```objc
- (void)performDelayedUIOperations
```
**作用**: 执行延迟的UI操作（iOS 16-18兼容性处理）
**实现逻辑**:
1. 打印检测日志
2. 设置导航栏默认颜色
3. 设置状态已执行标记

#### checkAndPerformDelayedUIOperations
```objc
- (void)checkAndPerformDelayedUIOperations
```
**作用**: 检查并执行延迟的UI操作
**实现逻辑**:
1. 仅在iOS 16及以上版本执行
2. 检查是否有未执行的UI操作
3. 调用performDelayedUIOperations

### KVO处理

#### observeValueForKeyPath:ofObject:change:context:
```objc
- (void)observeValueForKeyPath:ofObject:change:context:
```
**作用**: 处理KVO通知
**监听内容**:
1. estimatedProgress: 更新进度条
2. title: 更新导航栏标题

### WKNavigationDelegate方法

#### webView:didStartProvisionalNavigation:
```objc
- (void)webView:didStartProvisionalNavigation:
```
**作用**: 页面开始加载
**实现**: 显示进度条

#### webView:didFinishNavigation:
```objc
- (void)webView:didFinishNavigation:
```
**作用**: 页面加载完成
**实现**: 隐藏进度条

#### webView:didFailProvisionalNavigation:withError:
```objc
- (void)webView:didFailProvisionalNavigation:withError:
```
**作用**: 页面加载失败
**实现**:
1. 隐藏进度条
2. 记录错误日志

#### webView:decidePolicyForNavigationAction:decisionHandler:
```objc
- (void)webView:decidePolicyForNavigationAction:decisionHandler:
```
**作用**: 决定是否允许导航
**实现**: 默认允许所有导航

### WKUIDelegate方法

#### webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:
```objc
- (void)webView:runJavaScriptAlertPanelWithMessage:initiatedByFrame:completionHandler:
```
**作用**: 处理JavaScript的alert弹窗
**实现**: 显示原生UIAlertController

#### webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:
```objc
- (void)webView:runJavaScriptConfirmPanelWithMessage:initiatedByFrame:completionHandler:
```
**作用**: 处理JavaScript的confirm弹窗
**实现**: 显示带确认/取消按钮的UIAlertController

#### webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:
```objc
- (void)webView:runJavaScriptTextInputPanelWithPrompt:defaultText:initiatedByFrame:completionHandler:
```
**作用**: 处理JavaScript的prompt弹窗
**实现**: 显示带输入框的UIAlertController

### 通知处理

#### handleNetworkAvailable:
```objc
- (void)handleNetworkAvailable:(NSNotification *)notification
```
**作用**: 处理网络恢复通知
**实现**: 通知JavaScript网络已恢复

#### handlePaymentResult:
```objc
- (void)handlePaymentResult:(NSNotification *)notification
```
**作用**: 处理支付结果通知
**实现**: 子类需要重写

#### handleLoginResult:
```objc
- (void)handleLoginResult:(NSNotification *)notification
```
**作用**: 处理登录结果通知
**实现**: 子类需要重写

## 使用示例

```objc
// 创建子类
@interface MyH5ViewController : XZWKWebViewBaseController
@end

@implementation MyH5ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置URL
    self.urlString = @"https://zaiju.com/home";
    
    // 设置标题
    self.webViewTitle = @"首页";
    
    // 是否显示进度条
    self.showProgressBar = YES;
}

// 实现JS调用Native的处理
- (void)jsCallObjc:(id)jsData jsCallBack:(WVJBResponseCallback)jsCallBack {
    NSDictionary *data = (NSDictionary *)jsData;
    NSString *action = data[@"action"];
    
    if ([action isEqualToString:@"showToast"]) {
        NSString *message = data[@"message"];
        [self showToast:message];
        jsCallBack(@{@"code": @(0)});
    }
}

@end
```

## 注意事项

1. **WebView创建时机**: 在viewDidAppear中创建，避免阻塞UI
2. **内存管理**: dealloc中必须正确清理所有观察者和代理
3. **JavaScript桥接**: 确保在WebView创建后立即设置
4. **iOS兼容性**: 特别注意iOS 16-18的UI操作延迟问题
5. **性能优化**: 使用预加载和缓存提高加载速度

## 已知问题

1. iOS 18上viewDidAppear可能多次调用
2. 延迟UI操作的实现较为复杂
3. 进度条在某些情况下可能不准确

## 优化建议

1. 考虑使用WKWebView的配置共享池
2. 优化HTML模板缓存策略
3. 增加WebView预热机制
4. 完善错误处理和重试机制