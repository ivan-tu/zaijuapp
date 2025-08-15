# 更新版本号

这个命令用于更新项目版本号，为发布新版本做准备。

## 1.更新时间戳
1.将`XZVientiane.xcodeproj/project.pbxproj`文件中两处CURRENT_PROJECT_VERSION内容更新为当前日期时间（格式：YYYYMMDDHHMM），示例：202508142004
2.将`XZVientiane/Info.plist`文件中的CFBundleVersion内容更新为当前日期时间（格式：YYYYMMDDHHMM），示例：202508142004


## 2.更新版本号
1.将`XZVientiane.xcodeproj/project.pbxproj`文件中两处MARKETING_VERSION版本号内容自动加1，示例：1.0.20=>1.0.21
2.将`XZVientiane/Info.plist`文件中的CFBundleShortVersionString版本号内容自动加1，示例：1.0.20=>1.0.21