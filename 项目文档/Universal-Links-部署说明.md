# Universal Links 部署说明

## 📋 配置概览

### 1. iOS App 配置 ✅ 已完成
- **Entitlements**: 已配置 `applinks:zaiju.com` 和 `applinks:hi3.tuiya.cc`
- **URL Schemes**: 已配置 `zaiju.com` 自定义协议
- **AppDelegate**: 已添加完整的 Universal Links 处理逻辑
- **Bundle IDs**: 同时支持测试环境 (`cc.tuiya.hi3`) 和正式环境 (`com.zaiju`)

### 2. 服务器端配置 🔧 需要部署

#### 主域名配置
需要将 `apple-app-site-association` 文件部署到以下位置：

```
https://zaiju.com/.well-known/apple-app-site-association
https://zaiju.com/apple-app-site-association
```

#### 备用域名配置（如果使用）
```
https://hi3.tuiya.cc/.well-known/apple-app-site-association
https://hi3.tuiya.cc/apple-app-site-association
```

#### 文件要求
- **Content-Type**: `application/json`
- **无文件扩展名**: 文件名就是 `apple-app-site-association`
- **HTTPS**: 必须通过HTTPS访问
- **证书**: 需要有效的SSL证书

## 🚀 部署步骤

### 步骤1: 上传配置文件
将项目根目录下的 `apple-app-site-association` 文件上传到服务器：

```bash
# 上传到服务器根目录
scp apple-app-site-association user@zaiju.com:/var/www/html/

# 创建.well-known目录并复制文件
mkdir -p /var/www/html/.well-known/
cp /var/www/html/apple-app-site-association /var/www/html/.well-known/
```

### 步骤2: 配置Nginx/Apache
确保服务器正确返回JSON content-type：

**Nginx 配置**:
```nginx
location = /apple-app-site-association {
    add_header Content-Type application/json;
}

location = /.well-known/apple-app-site-association {
    add_header Content-Type application/json;
}
```

**Apache 配置**:
```apache
<Files "apple-app-site-association">
    Header set Content-Type application/json
</Files>
```

### 步骤3: 验证部署
使用以下命令验证配置：

```bash
# 检查文件是否可访问
curl -I https://zaiju.com/apple-app-site-association
curl -I https://zaiju.com/.well-known/apple-app-site-association

# 检查内容和Bundle IDs
curl https://zaiju.com/apple-app-site-association

# 验证JSON格式是否正确
curl -s https://zaiju.com/apple-app-site-association | jq .

# 验证包含的Bundle IDs
curl -s https://zaiju.com/apple-app-site-association | jq '.applinks.details[0].appIDs'
```

**期望输出应包含**:
```json
[
  "PCRMMV2NNZ.cc.tuiya.hi3",
  "PCRMMV2NNZ.com.zaiju"  
]
```

## 🧪 测试方法

### 方法1: Safari测试
1. 在iPhone的Safari中输入: `https://zaiju.com/app/test`
2. **重要**: 如果显示404或网页内容是正常的！Universal Links的工作原理如下：
   - **首次访问**: Safari会先尝试加载网页
   - **已安装App**: 如果检测到App已安装且支持该链接，会在页面顶部显示"在App中打开"横幅
   - **点击横幅**: 用户点击横幅后才会跳转到App
3. **注意**: 直接在地址栏输入URL不会触发Universal Links，需要通过链接点击

### 方法2: 备忘录测试
1. 在iPhone备忘录中输入: `https://zaiju.com/app/user/123`
2. 点击链接应该直接打开App

### 方法3: 消息测试
1. 通过短信或其他App分享链接: `https://zaiju.com/app/circle/456`
2. 点击应该直接打开App而不是Safari

### ⚠️ Universal Links测试要点

#### 为什么Safari输入URL显示404是正常的？

**Universal Links ≠ 网页存在**
- Universal Links是一种**深度链接技术**，不要求对应的网页真实存在
- `/app/test` 路径在你的网站上可能确实不存在（404），这是正常的
- 重要的是`apple-app-site-association`文件告诉iOS这些URL应该打开App

#### 正确的测试方法：

1. **不要直接在Safari地址栏输入**
   - 直接输入地址栏 = 手动导航 = 不触发Universal Links
   - 必须通过**点击链接**的方式访问

2. **使用备忘录测试**（推荐）：
   ```
   1. 打开iPhone备忘录
   2. 输入: https://zaiju.com/app/test
   3. 点击这个链接
   4. 应该直接打开App（如果App已安装且配置正确）
   ```

3. **使用短信测试**：
   ```
   1. 发送短信给自己: https://zaiju.com/app/user/123
   2. 点击短信中的链接
   3. 应该打开App而不是Safari
   ```

4. **网页中的链接测试**：
   在任何网页中添加链接，点击时应该跳转到App

## 📱 支持的URL格式

根据当前配置，以下URL格式会触发Universal Links：

```
https://zaiju.com/app/[任意路径]
https://zaiju.com/share/[任意路径]  
https://zaiju.com/user/[任意路径]
https://zaiju.com/circle/[任意路径]
```

### 示例URL
- `https://zaiju.com/app/home` - 打开首页
- `https://zaiju.com/app/user/123` - 打开用户页面
- `https://zaiju.com/app/circle/456?tab=posts` - 打开圈子页面并传递参数

## 🔍 调试信息

App中已添加详细的调试日志，可以通过Xcode控制台查看：

```
在局📱 [Universal Links] 收到用户活动
在局🔗 [Universal Links] 接收到URL
在局🔄 [Universal Links] 开始解析URL
在局📍 [Universal Links] 解析路径
在局🎯 [Universal Links] 处理App路径
在局📝 [Universal Links] 解析查询参数
在局🧭 [Universal Links] 开始导航
在局📡 [Universal Links] 通知WebView处理路径
```

## 📱 Bundle ID配置说明

当前配置支持两个环境的Bundle ID：

### 测试环境
- **Bundle ID**: `cc.tuiya.hi3`
- **Team ID**: `PCRMMV2NNZ`
- **完整App ID**: `PCRMMV2NNZ.cc.tuiya.hi3`
- **用途**: 开发和测试阶段使用

### 正式环境  
- **Bundle ID**: `com.zaiju`
- **Team ID**: `PCRMMV2NNZ`
- **完整App ID**: `PCRMMV2NNZ.com.zaiju`
- **用途**: App Store发布版本

**重要**: 
- 两个Bundle ID都必须在Apple Developer账号中正确配置
- 对应的App ID都需要开启Associated Domains功能
- 如果只使用其中一个环境，可以移除另一个Bundle ID

## ⚠️ 注意事项

1. **首次安装**: 用户首次安装App后，Universal Links可能需要等待一段时间才生效
2. **Safari手动导航**: 如果用户在Safari中手动输入URL并导航，不会触发Universal Links
3. **长按选择**: 长按链接选择"在Safari中打开"后，需要重新安装App才能恢复Universal Links
4. **证书问题**: 服务器SSL证书问题会导致Universal Links失效
5. **Bundle ID匹配**: 确保服务器配置的Bundle ID与实际App的Bundle ID完全匹配

## 🛠️ 故障排除

### 问题1: 链接不跳转App
- 检查服务器配置文件是否正确部署
- 验证SSL证书是否有效
- 确认Bundle ID和Team ID是否正确

### 问题2: App收不到URL
- 检查AppDelegate中的处理逻辑
- 查看控制台日志
- 确认通知机制是否正常

### 问题3: 参数传递异常
- 检查URL编码
- 验证参数解析逻辑
- 查看参数格式是否正确

## 📞 联系支持

如遇到问题，请检查：
1. Xcode控制台的详细日志
2. 服务器访问日志
3. Network条件面板中的请求详情

## 📱 JavaScript处理器集成 ✅ 已完成

JavaScript端的Universal Links处理器已经完全集成到项目中：

### 已完成的集成内容：
1. **文件创建**: `manifest/static/app/universal-links.js`
2. **模板集成**: 已在 `manifest/app.html` 中引入该文件
3. **桥接集成**: 已集成到现有的 `wx.app.on` 系统中

### 处理流程：
```
Native收到Universal Link
    ↓
AppDelegate解析URL
    ↓  
通过NotificationCenter发送通知
    ↓
XZWKWebViewBaseController接收通知
    ↓
调用JavaScript桥接: handleUniversalLinkNavigation
    ↓
universal-links.js处理路由跳转
```

### 支持的路由示例：
- `https://zaiju.com/app/home` → 跳转到首页
- `https://zaiju.com/app/user/123` → 跳转到用户详情页
- `https://zaiju.com/app/circle/456?tab=posts` → 跳转到圈子页面
- `https://zaiju.com/app/post/789` → 跳转到帖子详情

### 自定义路由：
如需添加新的路由，请修改 `universal-links.js` 中的路由处理函数，并根据你的App实际页面结构调整跳转逻辑。

配置完成后，`https://zaiju.com/app/` 路径下的所有链接都将正确跳转到App！