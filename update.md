# 更新版本号

这个命令用于更新项目版本号，为发布新版本做准备。

## 更新内容

1. **CURRENT_PROJECT_VERSION**: 更新为当前日期时间（格式：YYYYMMDDHHMM）
2. **CFBundleShortVersionString**: 版本号自动加1
3. **MARKETING_VERSION**: 版本号自动加1（与CFBundleShortVersionString保持一致）

## 执行步骤

首先，我需要检查当前的版本号：

<Task description="查找当前版本号">
<prompt>
在 XZVientiane.xcodeproj/project.pbxproj 文件中搜索 CURRENT_PROJECT_VERSION、CFBundleShortVersionString 和 MARKETING_VERSION 的当前值。
</prompt>
</Task>

根据找到的版本号，执行以下更新：

<Bash description="获取当前日期时间">
date +"%Y%m%d%H%M"
</Bash>

<Grep pattern="CURRENT_PROJECT_VERSION|CFBundleShortVersionString|MARKETING_VERSION" path="XZVientiane.xcodeproj/project.pbxproj" output_mode="content" -n="true" -B="1" -A="1" />

<Task description="更新版本号">
<prompt>
1. 在 XZVientiane.xcodeproj/project.pbxproj 文件中：
   - 将所有 CURRENT_PROJECT_VERSION 的值更新为当前日期时间格式（YYYYMMDDHHMM）
   - 将当前版本号（如 1.0.10）递增到下一个版本（1.0.11）
   - 更新所有 CFBundleShortVersionString 和 MARKETING_VERSION 为新版本号
2. 在 XZVientiane/XZVientiane-Info.plist 文件中：
   - 更新 CFBundleShortVersionString 为新版本号
   - 更新 CFBundleVersion 为当前日期时间
</prompt>
</Task>

完成更新后，提醒用户：

```
版本号已更新：
- 版本号: [旧版本] → [新版本]
- 构建号: [日期时间]

请在 Xcode 中构建项目并准备发布。
```