# JavaScript Bridge Release版本修复方案

## 问题描述
Release版本安装到真机后，JavaScript桥接无法正常工作，导致pageReady回调不触发，页面加载超时。

## 修复方案

### 1. 启用Release版本的WebViewJavascriptBridge日志
文件：`XZVientiane/XZBase/BaseController/XZWKWebViewBaseController.m`

修改前：
```objc
#ifdef DEBUG
[WKWebViewJavascriptBridge enableLogging];
#endif
```

修改后：
```objc
// 在Release版本也启用日志，以确保桥接正常工作
[WKWebViewJavascriptBridge enableLogging];
```

### 2. 添加页面加载监控机制
文件：`XZVientiane/XZBase/BaseController/XZWKWebViewBaseController.m`

新增方法：
- `startPageLoadMonitor` - 启动3秒超时监控器
- `checkPageLoadStatus` - 检查页面加载状态，如果pageReady未触发则手动触发

主要功能：
1. 在loadHTMLString后启动3秒监控
2. 如果3秒后仍未收到pageReady，手动触发
3. 支持多种触发方式：
   - 通过webViewCall直接触发
   - 通过WebViewJavascriptBridge.callHandler触发
   - 重新初始化wx.app.connect

### 3. 在适当位置调用监控
- 在直接数据模式加载后调用`startPageLoadMonitor`
- 在CustomHybridProcessor加载后调用`startPageLoadMonitor`
- 在didFinishNavigation中取消监控器（页面正常加载）

### 4. 增强JavaScript端的标记
文件：`XZVientiane/manifest/static/app/webviewbridge.js`

添加全局标记：
- `window._wxAppConnecting` - 标记connect正在初始化
- `window._wxAppConnected` - 标记connect已完成

## 测试验证

### Debug版本测试
1. 构建Debug版本安装到真机
2. 查看Xcode控制台日志，确认pageReady正常触发
3. 验证首页能正常显示

### Release版本测试
1. 构建Release版本安装到真机
2. 查看控制台日志，观察页面加载监控是否生效
3. 确认3秒后手动触发pageReady
4. 验证首页能正常显示

## 后续优化建议

1. **优化JavaScript初始化时机**
   - 考虑在app.html中添加更早的初始化逻辑
   - 确保wx.app.connect在DOM ready时就执行

2. **增加更多调试信息**
   - 在关键步骤添加console.log
   - 记录JavaScript环境初始化的各个阶段

3. **考虑降级方案**
   - 如果桥接完全失败，提供基础的功能保证
   - 添加错误页面或重试机制

## 相关文件
- `/Users/ivan/工作/Tuweia/app/在局/app/XZVientiane/XZBase/BaseController/XZWKWebViewBaseController.m`
- `/Users/ivan/工作/Tuweia/app/在局/app/XZVientiane/manifest/static/app/webviewbridge.js`
- `/Users/ivan/工作/Tuweia/app/在局/app/XZVientiane/manifest/app.html`