# 在局APP文档中心

## 文档目录结构

本文档中心包含了在局APP的所有技术文档，按照功能和用途进行了分类整理。

### 📁 架构文档
- **[项目架构概览](架构文档/项目架构概览.md)** - 项目整体架构说明，包括控制器体系、JSBridge架构等

### 📁 API文档
- **[JSBridge-API参考](API文档/JSBridge-API参考.md)** - 详细的JSBridge API接口文档，包含所有Handler的使用说明
- **[统一管理器使用指南](API文档/统一管理器使用指南.md)** - iOS版本管理器、错误码管理器等统一管理器的使用指南

### 📁 功能文档
- **[WebView功能](功能文档/WebView功能.md)** - WebView核心功能说明（已更新JSBridge新架构）
- **[定位功能](功能文档/定位功能.md)** - 定位相关功能实现
- **[支付功能](功能文档/支付功能.md)** - 微信、支付宝支付集成
- **[分享功能](功能文档/分享功能.md)** - 社交分享功能实现
- **[扫码功能](功能文档/扫码功能.md)** - 二维码扫描功能
- **[图片处理功能](功能文档/图片处理功能.md)** - 图片选择、裁剪、上传等
- **[用户登录功能](功能文档/用户登录功能.md)** - 登录认证相关功能

### 📁 代码解释
- **[CFJClientH5Controller方法说明](代码解释/CFJClientH5Controller方法说明.md)** - 核心H5控制器详解（已更新）
- **[XZViewController方法说明](代码解释/XZViewController方法说明.md)** - 基础视图控制器说明
- **[XZWKWebViewBaseController方法说明](代码解释/XZWKWebViewBaseController方法说明.md)** - WebView基类说明
- **[XZNavigationController方法说明](代码解释/XZNavigationController方法说明.md)** - 自定义导航控制器
- **[XZTabBarController方法说明](代码解释/XZTabBarController方法说明.md)** - TabBar控制器说明
- **[WebView控制器类](代码解释/WebView控制器类.md)** - WebView相关控制器汇总

### 📁 代码规范
- **[JSBridge重构说明](代码规范/JSBridge重构说明.md)** - JSBridge模块化架构说明
- **[导航栏样式规范](代码规范/导航栏样式规范.md)** - 导航栏UI规范

### 📁 优化文档
- **[2025年优化记录](优化文档/2025年优化记录.md)** - 2025年项目优化详细记录
- **[CFJClientH5Controller-JSBridge优化文档](优化文档/CFJClientH5Controller-JSBridge优化文档.md)** - JSBridge优化过程
- **[完善优化](优化文档/完善优化.md)** - 其他优化内容

### 📁 代码优化记录
- **[iOS项目重构优化记录](代码优化记录/iOS项目重构优化记录.md)** - 项目重构过程记录

### 📁 任务文档
- **[优化项目](任务文档/优化项目.md)** - 项目优化任务清单

### 📁 修复文档
记录了项目中各种问题的修复过程，按时间顺序排列：
- 2025-01-08: WebView相关编译错误修复
- 2025-08-01: 网络请求、数据显示等问题修复

### 📁 其他文档
- **[JavaScript桥接修复报告](JavaScript桥接修复报告.md)**
- **[JavaScript集成操作总结](JavaScript集成操作总结.md)**
- **[Universal-Links-部署说明](Universal-Links-部署说明.md)**
- **[友盟分享和推送分析报告](友盟分享和推送分析报告.md)**
- **[添加新文件到项目说明](添加新文件到项目说明.md)**
- **[自定义转场动画使用说明](自定义转场动画使用说明.md)**

### 📁 日志示例
- **log/** - 包含应用运行的日志示例

## 文档使用指南

### 新手入门
1. 首先阅读 **[项目架构概览](架构文档/项目架构概览.md)** 了解整体架构
2. 查看 **[WebView功能](功能文档/WebView功能.md)** 了解核心功能
3. 参考 **[JSBridge-API参考](API文档/JSBridge-API参考.md)** 进行开发

### 开发参考
- 添加新功能时，参考 **[JSBridge重构说明](代码规范/JSBridge重构说明.md)**
- 使用统一管理器时，查看 **[统一管理器使用指南](API文档/统一管理器使用指南.md)**
- 遇到问题时，查看 **修复文档** 目录中的相关记录

### 文档维护
- 修复问题后，在 **修复文档** 目录创建记录文档
- 格式：`[YYYY-MM-DD HH:mm]问题描述.md`
- 重大架构变更需要更新相关文档

## 重要更新

### 2025年1月优化
- ✅ JSBridge模块化重构完成
- ✅ 统一管理器实现（iOS版本、错误码、WebView性能、认证）
- ✅ 文档体系重新整理
- ✅ 代码规范统一

## 相关资源

- **CLAUDE.md** - AI助手使用指南
- **Test/Scripts/** - 构建和测试脚本
- **manifest/** - H5资源文件

## 联系方式

如有文档相关问题，请联系项目维护人员。