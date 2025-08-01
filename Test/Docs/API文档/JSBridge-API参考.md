# JSBridge Handler API 参考文档

## 概述

本文档详细介绍了在局APP中所有JSBridge Handler支持的API接口。所有API通过统一的`window.xzBridge.callHandler`方法调用。

## 调用格式

### 基本调用方式
```javascript
window.xzBridge.callHandler('xzBridge', {
    action: 'actionName',
    data: {
        // 参数
    }
}, function(response) {
    // 回调处理
});
```

### 使用封装的webViewCall方法
```javascript
webViewCall('actionName', {
    // 参数
    success: function(res) {
        // 成功回调
    },
    fail: function(err) {
        // 失败回调
    }
});
```

## 统一响应格式

### 成功响应
```json
{
    "code": 0,
    "data": {}, // 返回数据
    "msg": "success"
}
```

### 错误响应
```json
{
    "code": -1, // 错误码
    "msg": "错误描述",
    "data": {} // 可选的错误详情
}
```

### 错误码说明
| 错误码 | 说明 |
|-------|------|
| 0 | 成功 |
| -1 | 参数错误 |
| -2 | 网络错误 |
| -3 | 未知action |
| -4 | 权限拒绝 |
| -5 | 超时 |
| -6 | 用户取消 |
| -7 | 不支持的功能 |
| -99 | 系统错误 |

---

## JSUIHandler - UI相关API

### showToast
显示提示信息

**参数：**
```javascript
{
    message: String,     // 必填，提示内容
    duration: Number,    // 可选，显示时长（毫秒），默认2000
    type: String        // 可选，类型：'success'/'error'/'info'，默认'info'
}
```

**示例：**
```javascript
webViewCall('showToast', {
    message: '操作成功',
    duration: 3000,
    type: 'success'
});
```

### showLoading
显示加载框

**参数：**
```javascript
{
    title: String,      // 可选，加载文字，默认"加载中..."
    mask: Boolean       // 可选，是否显示遮罩，默认true
}
```

**示例：**
```javascript
webViewCall('showLoading', {
    title: '正在处理...',
    mask: true
});
```

### hideLoading
隐藏加载框

**参数：** 无

**示例：**
```javascript
webViewCall('hideLoading');
```

### showModal
显示模态对话框

**参数：**
```javascript
{
    title: String,          // 可选，标题
    content: String,        // 必填，内容
    showCancel: Boolean,    // 可选，是否显示取消按钮，默认true
    cancelText: String,     // 可选，取消按钮文字，默认"取消"
    confirmText: String,    // 可选，确认按钮文字，默认"确定"
    confirmColor: String    // 可选，确认按钮颜色
}
```

**返回值：**
```javascript
{
    confirm: Boolean,   // 是否点击了确认
    cancel: Boolean     // 是否点击了取消
}
```

**示例：**
```javascript
webViewCall('showModal', {
    title: '提示',
    content: '确定要删除吗？',
    confirmText: '删除',
    confirmColor: '#ff0000',
    success: function(res) {
        if (res.confirm) {
            console.log('用户点击确定');
        }
    }
});
```

### showActionSheet
显示操作菜单

**参数：**
```javascript
{
    itemList: Array,    // 必填，按钮文字数组
    itemColor: String   // 可选，按钮文字颜色
}
```

**返回值：**
```javascript
{
    tapIndex: Number    // 用户点击的按钮索引
}
```

**示例：**
```javascript
webViewCall('showActionSheet', {
    itemList: ['拍照', '从相册选择'],
    success: function(res) {
        console.log('选择了：' + res.tapIndex);
    }
});
```

### setNavigationBarTitle
设置导航栏标题

**参数：**
```javascript
{
    title: String       // 必填，标题文字
}
```

**示例：**
```javascript
webViewCall('setNavigationBarTitle', {
    title: '新标题'
});
```

### setNavigationBarColor
设置导航栏颜色

**参数：**
```javascript
{
    frontColor: String,     // 必填，前景颜色值（#ffffff 或 #000000）
    backgroundColor: String, // 必填，背景颜色值
    animation: Object       // 可选，动画效果
}
```

**示例：**
```javascript
webViewCall('setNavigationBarColor', {
    frontColor: '#ffffff',
    backgroundColor: '#ff0000',
    animation: {
        duration: 400,
        timingFunc: 'easeIn'
    }
});
```

### showNavigationBar/hideNavigationBar
显示/隐藏导航栏

**参数：**
```javascript
{
    animation: Boolean  // 可选，是否需要动画，默认true
}
```

**示例：**
```javascript
webViewCall('hideNavigationBar', {
    animation: true
});
```

---

## JSNavigationHandler - 导航API

### navigateTo
保留当前页面，跳转到应用内的某个页面

**参数：**
```javascript
{
    url: String,    // 必填，页面路径
    title: String   // 可选，页面标题
}
```

**示例：**
```javascript
webViewCall('navigateTo', {
    url: '/pages/detail',
    title: '详情页'
});
```

### navigateBack
关闭当前页面，返回上一页面或多级页面

**参数：**
```javascript
{
    delta: Number   // 可选，返回的页面数，默认1
}
```

**示例：**
```javascript
webViewCall('navigateBack', {
    delta: 2  // 返回上上个页面
});
```

### redirectTo
关闭当前页面，跳转到应用内的某个页面

**参数：**
```javascript
{
    url: String,    // 必填，页面路径
    title: String   // 可选，页面标题
}
```

**示例：**
```javascript
webViewCall('redirectTo', {
    url: '/pages/home'
});
```

### reLaunch
关闭所有页面，打开到应用内的某个页面

**参数：**
```javascript
{
    url: String     // 必填，页面路径
}
```

**示例：**
```javascript
webViewCall('reLaunch', {
    url: '/pages/index'
});
```

### switchTab
跳转到 tabBar 页面

**参数：**
```javascript
{
    url: String     // 必填，tabBar页面路径
}
```

**示例：**
```javascript
webViewCall('switchTab', {
    url: '/pages/home'
});
```

---

## JSLocationHandler - 定位API

### getLocation
获取当前的地理位置

**参数：**
```javascript
{
    type: String,       // 可选，坐标类型：'wgs84'/'gcj02'，默认'gcj02'
    altitude: Boolean   // 可选，是否返回高度信息，默认false
}
```

**返回值：**
```javascript
{
    latitude: Number,       // 纬度
    longitude: Number,      // 经度
    speed: Number,         // 速度，单位m/s
    accuracy: Number,      // 位置精度
    altitude: Number,      // 高度，单位m
    verticalAccuracy: Number, // 垂直精度，单位m（iOS）
    horizontalAccuracy: Number, // 水平精度，单位m（iOS）
    address: String        // 地址信息
}
```

**示例：**
```javascript
webViewCall('getLocation', {
    type: 'gcj02',
    success: function(res) {
        console.log('当前位置：', res.latitude, res.longitude);
        console.log('地址：', res.address);
    }
});
```

### openLocation
使用内置地图查看位置

**参数：**
```javascript
{
    latitude: Number,   // 必填，纬度
    longitude: Number,  // 必填，经度
    scale: Number,      // 可选，缩放比例，范围5~18，默认18
    name: String,       // 可选，位置名
    address: String     // 可选，地址的详细说明
}
```

**示例：**
```javascript
webViewCall('openLocation', {
    latitude: 39.90469,
    longitude: 116.40717,
    scale: 18,
    name: '天安门',
    address: '北京市东城区东长安街'
});
```

### chooseLocation
打开地图选择位置

**返回值：**
```javascript
{
    name: String,       // 位置名称
    address: String,    // 详细地址
    latitude: Number,   // 纬度
    longitude: Number   // 经度
}
```

**示例：**
```javascript
webViewCall('chooseLocation', {
    success: function(res) {
        console.log('选择的位置：', res.name);
        console.log('详细地址：', res.address);
    }
});
```

### startLocationUpdate
开启位置更新

**参数：**
```javascript
{
    interval: Number    // 可选，更新间隔（秒），默认5
}
```

**示例：**
```javascript
webViewCall('startLocationUpdate', {
    interval: 10,
    success: function(res) {
        console.log('位置更新已开启');
    }
});
```

### stopLocationUpdate
停止位置更新

**参数：** 无

**示例：**
```javascript
webViewCall('stopLocationUpdate');
```

---

## JSMediaHandler - 媒体API

### chooseImage
从本地相册选择图片或使用相机拍照

**参数：**
```javascript
{
    count: Number,          // 可选，最多可选择的图片张数，默认9
    sizeType: Array,        // 可选，['original', 'compressed']，默认两者都有
    sourceType: Array,      // 可选，['album', 'camera']，默认两者都有
    needCompress: Boolean   // 可选，是否压缩，默认true
}
```

**返回值：**
```javascript
{
    tempFilePaths: Array,   // 图片的本地临时文件路径列表
    tempFiles: Array        // 图片的本地临时文件列表
}
```

**示例：**
```javascript
webViewCall('chooseImage', {
    count: 3,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: function(res) {
        console.log('选择的图片：', res.tempFilePaths);
    }
});
```

### previewImage
预览图片

**参数：**
```javascript
{
    current: String,    // 可选，当前显示图片的链接
    urls: Array        // 必填，需要预览的图片链接列表
}
```

**示例：**
```javascript
webViewCall('previewImage', {
    current: 'http://example.com/1.jpg',
    urls: [
        'http://example.com/1.jpg',
        'http://example.com/2.jpg',
        'http://example.com/3.jpg'
    ]
});
```

### saveImageToPhotosAlbum
保存图片到系统相册

**参数：**
```javascript
{
    filePath: String    // 必填，图片文件路径
}
```

**示例：**
```javascript
webViewCall('saveImageToPhotosAlbum', {
    filePath: tempFilePath,
    success: function() {
        console.log('保存成功');
    }
});
```

### chooseVideo
拍摄视频或从手机相册中选视频

**参数：**
```javascript
{
    sourceType: Array,      // 可选，['album', 'camera']
    compressed: Boolean,    // 可选，是否压缩
    maxDuration: Number     // 可选，拍摄视频最长拍摄时间，单位秒
}
```

**返回值：**
```javascript
{
    tempFilePath: String,   // 选定视频的临时文件路径
    duration: Number,       // 选定视频的时间长度
    size: Number,          // 选定视频的数据量大小
    height: Number,        // 返回选定视频的高度
    width: Number          // 返回选定视频的宽度
}
```

**示例：**
```javascript
webViewCall('chooseVideo', {
    sourceType: ['camera'],
    maxDuration: 60,
    success: function(res) {
        console.log('视频路径：', res.tempFilePath);
    }
});
```

### getImageInfo
获取图片信息

**参数：**
```javascript
{
    src: String     // 必填，图片的路径
}
```

**返回值：**
```javascript
{
    width: Number,      // 图片原始宽度
    height: Number,     // 图片原始高度
    path: String,       // 图片的本地路径
    orientation: String, // 拍照时设备方向
    type: String        // 图片格式
}
```

**示例：**
```javascript
webViewCall('getImageInfo', {
    src: imagePath,
    success: function(res) {
        console.log('图片宽度：', res.width);
        console.log('图片高度：', res.height);
    }
});
```

### compressImage
压缩图片

**参数：**
```javascript
{
    src: String,        // 必填，图片路径
    quality: Number     // 可选，压缩质量，范围0～100，默认80
}
```

**返回值：**
```javascript
{
    tempFilePath: String    // 压缩后图片的临时文件路径
}
```

**示例：**
```javascript
webViewCall('compressImage', {
    src: originalPath,
    quality: 50,
    success: function(res) {
        console.log('压缩后路径：', res.tempFilePath);
    }
});
```

---

## JSNetworkHandler - 网络API

### request
发起网络请求

**参数：**
```javascript
{
    url: String,            // 必填，请求地址
    data: Object/String,    // 可选，请求参数
    header: Object,         // 可选，请求头
    method: String,         // 可选，HTTP方法，默认GET
    dataType: String,       // 可选，返回数据格式，默认json
    timeout: Number         // 可选，超时时间，单位毫秒
}
```

**返回值：**
```javascript
{
    data: Any,          // 服务器返回的数据
    statusCode: Number, // HTTP状态码
    header: Object      // 服务器响应头
}
```

**示例：**
```javascript
webViewCall('request', {
    url: 'https://api.example.com/user',
    method: 'POST',
    data: {
        name: '张三',
        age: 25
    },
    header: {
        'content-type': 'application/json'
    },
    success: function(res) {
        console.log('返回数据：', res.data);
    }
});
```

### uploadFile
上传文件

**参数：**
```javascript
{
    url: String,        // 必填，上传地址
    filePath: String,   // 必填，要上传文件资源的路径
    name: String,       // 必填，文件对应的 key
    header: Object,     // 可选，HTTP请求Header
    formData: Object    // 可选，HTTP请求中其他额外的form data
}
```

**返回值：**
```javascript
{
    data: String,       // 服务器返回的数据
    statusCode: Number  // HTTP状态码
}
```

**示例：**
```javascript
webViewCall('uploadFile', {
    url: 'https://api.example.com/upload',
    filePath: tempFilePath,
    name: 'file',
    formData: {
        'user': 'test'
    },
    success: function(res) {
        console.log('上传成功');
    }
});
```

### downloadFile
下载文件

**参数：**
```javascript
{
    url: String,        // 必填，下载资源的url
    header: Object,     // 可选，HTTP请求的Header
    filePath: String    // 可选，指定文件下载后存储的路径
}
```

**返回值：**
```javascript
{
    tempFilePath: String,   // 临时文件路径
    statusCode: Number      // HTTP状态码
}
```

**示例：**
```javascript
webViewCall('downloadFile', {
    url: 'https://example.com/file.pdf',
    success: function(res) {
        console.log('文件已下载到：', res.tempFilePath);
    }
});
```

### getNetworkType
获取网络类型

**参数：** 无

**返回值：**
```javascript
{
    networkType: String     // 网络类型：wifi/2g/3g/4g/5g/unknown/none
}
```

**示例：**
```javascript
webViewCall('getNetworkType', {
    success: function(res) {
        console.log('网络类型：', res.networkType);
    }
});
```

---

## JSPaymentHandler - 支付API

### requestPayment
发起支付

**参数：**
```javascript
{
    payType: String,        // 必填，支付类型：'wechat'/'alipay'
    orderId: String,        // 必填，订单ID
    orderInfo: Object       // 可选，订单信息（支付宝使用）
}
```

**返回值：**
```javascript
{
    code: Number,           // 支付结果码
    msg: String            // 结果描述
}
```

**示例：**
```javascript
// 微信支付
webViewCall('requestPayment', {
    payType: 'wechat',
    orderId: '1234567890',
    success: function(res) {
        console.log('支付成功');
    },
    fail: function(err) {
        console.log('支付失败：', err.msg);
    }
});

// 支付宝支付
webViewCall('requestPayment', {
    payType: 'alipay',
    orderId: '1234567890',
    success: function(res) {
        console.log('支付成功');
    }
});
```

### getPaymentStatus
获取支付状态

**参数：**
```javascript
{
    orderId: String     // 必填，订单ID
}
```

**返回值：**
```javascript
{
    status: String,     // 支付状态：pending/success/failed
    payTime: String     // 支付时间（成功时返回）
}
```

---

## JSShareHandler - 分享API

### shareToTimeline
分享到朋友圈

**参数：**
```javascript
{
    title: String,      // 必填，分享标题
    desc: String,       // 可选，分享描述
    link: String,       // 可选，分享链接
    imgUrl: String      // 可选，分享图标
}
```

**示例：**
```javascript
webViewCall('shareToTimeline', {
    title: '这是一个分享标题',
    desc: '这是分享描述',
    link: 'https://example.com',
    imgUrl: 'https://example.com/icon.png',
    success: function() {
        console.log('分享成功');
    }
});
```

### shareToSession
分享给微信好友

**参数：** 同shareToTimeline

### shareToQQ
分享到QQ

**参数：** 同shareToTimeline

### shareToWeibo
分享到微博

**参数：**
```javascript
{
    title: String,      // 必填，分享标题
    desc: String,       // 可选，分享描述
    imgUrl: String      // 可选，分享图片
}
```

---

## JSUserHandler - 用户API

### login
用户登录

**参数：**
```javascript
{
    type: String        // 必填，登录类型：'wechat'/'apple'/'phone'
}
```

**返回值：**
```javascript
{
    token: String,      // 登录token
    userInfo: Object    // 用户信息
}
```

**示例：**
```javascript
webViewCall('login', {
    type: 'wechat',
    success: function(res) {
        console.log('登录成功，token：', res.token);
    }
});
```

### logout
退出登录

**参数：** 无

**示例：**
```javascript
webViewCall('logout', {
    success: function() {
        console.log('已退出登录');
    }
});
```

### getUserInfo
获取用户信息

**参数：** 无

**返回值：**
```javascript
{
    uid: String,        // 用户ID
    nickname: String,   // 昵称
    avatar: String,     // 头像
    phone: String       // 手机号
}
```

**示例：**
```javascript
webViewCall('getUserInfo', {
    success: function(res) {
        console.log('用户信息：', res);
    }
});
```

### updateUserInfo
更新用户信息

**参数：**
```javascript
{
    nickname: String,   // 可选，昵称
    avatar: String      // 可选，头像
}
```

**示例：**
```javascript
webViewCall('updateUserInfo', {
    nickname: '新昵称',
    success: function() {
        console.log('更新成功');
    }
});
```

### checkSession
检查登录态是否过期

**参数：** 无

**返回值：**
```javascript
{
    isValid: Boolean    // 登录态是否有效
}
```

**示例：**
```javascript
webViewCall('checkSession', {
    success: function(res) {
        if (!res.isValid) {
            console.log('登录态已过期，需要重新登录');
        }
    }
});
```

---

## JSSystemHandler - 系统API

### makePhoneCall
拨打电话

**参数：**
```javascript
{
    phoneNumber: String     // 必填，电话号码
}
```

**示例：**
```javascript
webViewCall('makePhoneCall', {
    phoneNumber: '10086'
});
```

### scanCode
调起客户端扫码界面

**参数：**
```javascript
{
    onlyFromCamera: Boolean,    // 可选，是否只能从相机扫码，不允许从相册选择图片
    scanType: Array            // 可选，扫码类型：['barCode', 'qrCode']
}
```

**返回值：**
```javascript
{
    result: String,     // 扫码内容
    scanType: String,   // 扫码类型
    charSet: String     // 字符集
}
```

**示例：**
```javascript
webViewCall('scanCode', {
    onlyFromCamera: true,
    scanType: ['qrCode'],
    success: function(res) {
        console.log('扫码结果：', res.result);
    }
});
```

### setClipboardData
设置系统剪贴板的内容

**参数：**
```javascript
{
    data: String        // 必填，剪贴板内容
}
```

**示例：**
```javascript
webViewCall('setClipboardData', {
    data: '这是要复制的内容',
    success: function() {
        console.log('复制成功');
    }
});
```

### getClipboardData
获取系统剪贴板的内容

**参数：** 无

**返回值：**
```javascript
{
    data: String        // 剪贴板内容
}
```

**示例：**
```javascript
webViewCall('getClipboardData', {
    success: function(res) {
        console.log('剪贴板内容：', res.data);
    }
});
```

### openSetting
调起客户端设置界面

**参数：** 无

**示例：**
```javascript
webViewCall('openSetting', {
    success: function() {
        console.log('设置已打开');
    }
});
```

### getSystemInfo
获取系统信息

**参数：** 无

**返回值：**
```javascript
{
    brand: String,          // 设备品牌
    model: String,          // 设备型号
    system: String,         // 操作系统及版本
    platform: String,       // 客户端平台
    version: String,        // 客户端版本号
    SDKVersion: String,     // SDK版本号
    screenWidth: Number,    // 屏幕宽度
    screenHeight: Number,   // 屏幕高度
    windowWidth: Number,    // 可使用窗口宽度
    windowHeight: Number,   // 可使用窗口高度
    statusBarHeight: Number,// 状态栏高度
    language: String,       // 系统语言
    fontSizeSetting: Number // 用户字体大小设置
}
```

**示例：**
```javascript
webViewCall('getSystemInfo', {
    success: function(res) {
        console.log('系统信息：', res);
    }
});
```

### vibrate
使手机发生振动

**参数：**
```javascript
{
    type: String        // 可选，振动类型：'short'/'long'，默认'short'
}
```

**示例：**
```javascript
webViewCall('vibrate', {
    type: 'short'
});
```

---

## JSFileHandler - 文件API

### saveFile
保存文件到本地

**参数：**
```javascript
{
    tempFilePath: String,   // 必填，临时文件路径
    fileName: String        // 可选，文件名
}
```

**返回值：**
```javascript
{
    savedFilePath: String   // 存储后的文件路径
}
```

**示例：**
```javascript
webViewCall('saveFile', {
    tempFilePath: tempPath,
    fileName: 'document.pdf',
    success: function(res) {
        console.log('文件已保存：', res.savedFilePath);
    }
});
```

### getSavedFileList
获取本地已保存的文件列表

**参数：** 无

**返回值：**
```javascript
{
    fileList: Array[{
        filePath: String,   // 文件路径
        size: Number,       // 文件大小，单位B
        createTime: Number  // 文件创建时间
    }]
}
```

**示例：**
```javascript
webViewCall('getSavedFileList', {
    success: function(res) {
        console.log('文件列表：', res.fileList);
    }
});
```

### getSavedFileInfo
获取本地文件的文件信息

**参数：**
```javascript
{
    filePath: String    // 必填，文件路径
}
```

**返回值：**
```javascript
{
    size: Number,       // 文件大小，单位B
    createTime: Number  // 文件创建时间
}
```

### removeSavedFile
删除本地缓存文件

**参数：**
```javascript
{
    filePath: String    // 必填，文件路径
}
```

**示例：**
```javascript
webViewCall('removeSavedFile', {
    filePath: savedPath,
    success: function() {
        console.log('文件已删除');
    }
});
```

### openDocument
新开页面打开文档

**参数：**
```javascript
{
    filePath: String,   // 必填，文件路径
    fileType: String    // 可选，文件类型：doc/xls/ppt/pdf/docx/xlsx/pptx
}
```

**示例：**
```javascript
webViewCall('openDocument', {
    filePath: documentPath,
    fileType: 'pdf',
    success: function() {
        console.log('文档已打开');
    }
});
```

---

## JSPageLifecycleHandler - 生命周期API

这些API通常由Native主动调用，通知H5页面状态变化。

### onPageShow
页面显示时触发

**Native调用JS示例：**
```javascript
// Native会调用
window.xzBridge.callHandler('pageShow', {
    timestamp: 1640995200000
});
```

### onPageHide
页面隐藏时触发

**Native调用JS示例：**
```javascript
// Native会调用
window.xzBridge.callHandler('pageHide', {
    timestamp: 1640995200000
});
```

### onPageReady
页面初次渲染完成时触发

**H5通知Native示例：**
```javascript
webViewCall('onPageReady', {
    readyTime: Date.now()
});
```

### onPageUnload
页面卸载时触发

**H5通知Native示例：**
```javascript
webViewCall('onPageUnload', {
    stayTime: 30000    // 页面停留时间
});
```

---

## 错误处理最佳实践

### 1. 统一错误处理
```javascript
function callNativeAPI(action, params) {
    return new Promise((resolve, reject) => {
        webViewCall(action, {
            ...params,
            success: function(res) {
                resolve(res);
            },
            fail: function(err) {
                console.error(`API调用失败 [${action}]:`, err);
                reject(err);
            }
        });
    });
}
```

### 2. 超时处理
```javascript
function callWithTimeout(action, params, timeout = 5000) {
    return Promise.race([
        callNativeAPI(action, params),
        new Promise((_, reject) => 
            setTimeout(() => reject(new Error('请求超时')), timeout)
        )
    ]);
}
```

### 3. 重试机制
```javascript
async function callWithRetry(action, params, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await callNativeAPI(action, params);
        } catch (err) {
            if (i === maxRetries - 1) throw err;
            await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        }
    }
}
```

## 调试建议

1. **开启日志**：在开发环境开启WKWebViewJavascriptBridge的日志
2. **使用Safari调试**：连接设备后在Safari中调试WebView
3. **模拟错误**：测试各种错误场景，确保错误处理正确
4. **性能监控**：监控API调用耗时，优化性能瓶颈

## 版本兼容性

- 最低支持iOS版本：iOS 15.0
- 部分API需要特定权限（相机、相册、定位等）
- Apple登录需要iOS 13.0+
- 某些功能需要安装对应的第三方应用（如微信）

## 更新记录

- 2025年1月：完成JSBridge模块化重构
- 2025年1月：新增统一错误码管理
- 2025年1月：优化API响应格式统一性