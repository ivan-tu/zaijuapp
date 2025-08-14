# 项目概述

## 基本信息
- **项目名称**: 在局 (zaijuapp)
- **项目类型**: iOS混合开发应用（Native容器 + H5业务）
- **Bundle ID**: com.zaiju
- **最低iOS版本**: iOS 15.0
- **开发语言**: Objective-C
- **包管理**: CocoaPods
- **系统平台**: macOS Darwin

## 核心架构设计
项目采用 **Native容器 + manifest资源包 = 独立应用** 的架构设计：

1. **Native作为容器**: iOS原生代码仅提供WebView容器和基础能力（相机、定位、支付等）
2. **H5承载业务**: 所有业务逻辑、界面展示都由manifest中的H5资源实现
3. **本地资源加载**: 所有H5页面都从本地manifest目录加载，无需网络请求
4. **资源包替换机制**: 通过替换manifest目录即可打包成不同的应用

## 项目目录结构
```
/Users/ivan/工作/Tuweia/app/在局/zaijuapp/
├── XZVientiane/               # 主要源代码目录
│   ├── AppDelegate/          # 应用入口
│   ├── XZBase/              # 基础框架类
│   ├── ClientBase/          # 业务基础组件
│   │   ├── BaseController/  # 基础控制器
│   │   ├── JSBridge/        # JS桥接模块（新架构）
│   │   ├── Network/         # 网络请求封装
│   │   └── Storage/         # 数据存储
│   ├── ThirdParty/          # 第三方SDK集成
│   ├── Module/              # 业务模块
│   ├── Common/              # 公共工具类
│   └── manifest/            # H5资源文件目录
├── Test/                     # 测试和脚本目录
│   ├── Docs/                # 文档
│   └── Scripts/             # 构建脚本
├── XZVientiane.xcworkspace/ # Xcode工作空间
├── podfile                  # CocoaPods配置
└── CLAUDE.md               # 项目说明文档
```

## 技术栈
- **原生开发**: Objective-C
- **UI框架**: UIKit + WKWebView
- **架构模式**: MVC + WebView混合开发
- **包管理**: CocoaPods
- **第三方SDK**:
  - 网络请求: AFNetworking
  - UI布局: Masonry
  - 图片加载: SDWebImage
  - 数据模型: JSONModel
  - 刷新控件: MJRefresh
  - 友盟SDK套件（统计、推送、分享）
  - 支付SDK: 微信支付、支付宝
  - 地图SDK: 高德地图套件
  - 存储安全: SAMKeychain
  - 文件上传: Qiniu

## 关键继承关系
```
UIViewController
  └── XZViewController (提供基础功能)
      └── XZWKWebViewBaseController (WebView基类，处理JS桥接)
          └── CFJClientH5Controller (业务实现)
```