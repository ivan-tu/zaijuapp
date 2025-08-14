# 常用命令指南

## 依赖管理
```bash
# 安装/更新CocoaPods依赖
pod install

# 清理并重新安装依赖
pod deintegrate && pod install
```

## 构建和运行
```bash
# 在Xcode中打开项目
open XZVientiane.xcworkspace

# 构建Archive (用于分发)
cd Test/Scripts && ./build.sh

# 清理构建
xcodebuild clean -workspace XZVientiane.xcworkspace -scheme XZVientiane

# 清理派生数据
rm -rf ~/Library/Developer/Xcode/DerivedData/XZVientiane-*

# 运行单元测试
xcodebuild test -workspace XZVientiane.xcworkspace -scheme XZVientiane -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 代码检查（任务完成后需要执行）
```bash
# 没有配置自动化的lint工具，需要在Xcode中手动检查：
# 1. 打开Xcode: open XZVientiane.xcworkspace
# 2. Product > Build (⌘B) 检查编译错误
# 3. Product > Analyze (⌘⇧B) 进行静态分析
```

## Git操作
```bash
# 查看状态
git status

# 查看差异
git diff

# 添加文件
git add .

# 提交（禁止自动提交，需要用户确认）
# git commit -m "提交信息"

# 查看提交历史
git log --oneline -10
```

## 系统工具 (macOS/Darwin)
```bash
# 文件操作
ls -la              # 列出文件
find . -name "*.m"  # 查找文件
grep -r "关键词" .   # 搜索内容

# 目录操作
cd 路径             # 切换目录
pwd                # 显示当前路径
mkdir -p 目录名     # 创建目录

# 文件查看
cat 文件名          # 查看文件内容
head -n 20 文件名   # 查看文件前20行
tail -n 20 文件名   # 查看文件后20行
```

## 特殊命令
- 检测到/success时，执行success.md中的命令
- 检测到/update时，执行update.md中的命令