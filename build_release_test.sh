#!/bin/bash

# Release真机测试构建脚本
# 用于修复Tab页切换卡顿问题后的测试

echo "🚀 开始构建Release测试版本..."

# 定义变量
WORKSPACE="XZVientiane.xcworkspace"
SCHEME="XZVientiane"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/XZVientiane_Release_$(date +%Y%m%d_%H%M%S).xcarchive"

# 清理构建
echo "🧹 清理旧的构建..."
xcodebuild clean -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION"

# 构建归档
echo "🔨 开始构建归档..."
xcodebuild archive \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -destination 'generic/platform=iOS'

# 检查构建结果
if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo "📦 归档路径: $ARCHIVE_PATH"
    
    # 打开Xcode Organizer
    echo "📱 正在打开Xcode Organizer..."
    open "$ARCHIVE_PATH"
    
    echo "
📋 测试重点：
1. Tab页切换流畅性 - 从首页切换到其他Tab不应有明显卡顿
2. 主线程阻塞时间 - 不应超过100ms
3. iOS 18设备重点测试 - 确保生命周期正常
4. WebView加载速度 - 虽然会有0.5秒延迟，但不应有9秒卡顿

🔍 如果仍有问题，请提供新的日志文件。
"
else
    echo "❌ 构建失败！请检查错误信息。"
    exit 1
fi