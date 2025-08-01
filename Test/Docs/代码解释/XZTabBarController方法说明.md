# XZTabBarController 方法说明文档

## 文件信息
- **文件路径**: XZVientiane/XZBase/BaseController/XZTabBarController.h/.m
- **作用**: 自定义TabBar控制器，管理应用的主要Tab页面，实现Tab的懒加载
- **创建时间**: 2016年

## 类继承关系
```
UITabBarController
    └── XZTabBarController
            └── 实现 UITabBarControllerDelegate
```

## 属性说明

### 私有属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| messageRedDot | UIView* | 消息Tab的红点视图 |
| messageLabel | UILabel* | 消息数量标签 |
| appInfoDic | NSDictionary* | App配置信息 |
| isFromScan | BOOL | 是否从扫码进入 |

## 方法详解

### 初始化方法

#### init
```objc
- (instancetype)init
```
**作用**: 初始化TabBarController
**实现逻辑**:
1. 调用父类init
2. 设置代理为self
3. 获取网络权限状态（iOS 10+）
4. 调用reloadTabbarInterface加载Tab配置

### 网络权限处理（iOS 10+）

#### 权限检查流程
```objc
if (@available(iOS 10.0, *)) {
    CTCellularData *cellularData = [[CTCellularData alloc] init];
    
    // 获取当前权限状态
    CTCellularDataRestrictedState state = cellularData.restrictedState;
    
    switch (state) {
        case kCTCellularDataRestricted:
            NSLog(@"网络权限：Restricted");
            break;
            
        case kCTCellularDataNotRestricted:
            NSLog(@"网络权限：NotRestricted");
            [self performSelectorOnMainThread:@selector(reloadTabbarInterface) 
                withObject:nil 
                waitUntilDone:YES];
            break;
            
        case kCTCellularDataRestrictedStateUnknown:
            NSLog(@"网络权限：Unknown");
            // 监听权限变化
            cellularData.cellularDataRestrictionDidUpdateNotifier = 
                ^(CTCellularDataRestrictedState state) {
                    [self handleNetworkPermissionChange:state];
                };
            break;
    }
}
```

### Tab配置加载

#### reloadTabbarInterface
```objc
- (void)reloadTabbarInterface
```
**作用**: 加载TabBar配置并创建Tab
**实现逻辑**:
1. 读取appInfo.json配置文件
2. 解析Tab配置数组
3. 遍历创建各个Tab
4. 实现懒加载机制（只创建第一个Tab的实际控制器）

**关键实现**:
```objc
// 读取配置
NSString *appInfoPath = [[NSBundle mainBundle] pathForResource:@"appInfo" ofType:@"json"];
NSData *appInfoData = [NSData dataWithContentsOfFile:appInfoPath];
NSDictionary *appInfo = [NSJSONSerialization JSONObjectWithData:appInfoData options:0 error:nil];

NSArray *tabConfigArray = appInfo[@"app"][@"tabBar"];

NSMutableArray *viewControllers = [NSMutableArray array];

for (int i = 0; i < tabConfigArray.count; i++) {
    NSDictionary *tabConfig = tabConfigArray[i];
    
    if (i == 0) {
        // 第一个Tab立即创建
        CFJClientH5Controller *h5VC = [self createH5ControllerWithConfig:tabConfig];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:h5VC];
        [viewControllers addObject:nav];
    } else {
        // 其他Tab使用占位符，实现懒加载
        UIViewController *placeholderVC = [[UIViewController alloc] init];
        // 保存配置信息
        objc_setAssociatedObject(placeholderVC, @"tabConfig", tabConfig, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:placeholderVC];
        [self configureTabBarItem:nav.tabBarItem withConfig:tabConfig];
        [viewControllers addObject:nav];
    }
}

self.viewControllers = viewControllers;
```

### Tab创建辅助方法

#### createH5ControllerWithConfig:
```objc
- (CFJClientH5Controller *)createH5ControllerWithConfig:(NSDictionary *)config
```
**作用**: 根据配置创建H5控制器
**参数**: config - Tab配置字典
**返回**: 配置好的CFJClientH5Controller实例
**实现**:
```objc
CFJClientH5Controller *h5VC = [[CFJClientH5Controller alloc] init];

// 设置URL
NSString *pagePath = config[@"pagePath"];
if (![pagePath hasPrefix:@"http"]) {
    pagePath = [NSString stringWithFormat:@"%@%@", JDomain, pagePath];
}
h5VC.urlString = pagePath;

// 设置TabBar
[self configureTabBarItem:h5VC.tabBarItem withConfig:config];

// 设置其他属性
h5VC.canShare = config[@"canShare"];
h5VC.uid = config[@"uid"];

return h5VC;
```

#### configureTabBarItem:withConfig:
```objc
- (void)configureTabBarItem:(UITabBarItem *)tabBarItem withConfig:(NSDictionary *)config
```
**作用**: 配置TabBarItem的图标和文字
**参数**:
- tabBarItem: 要配置的TabBarItem
- config: 配置信息
**实现**:
```objc
// 设置标题
tabBarItem.title = config[@"text"];

// 设置图标
NSString *iconPath = config[@"iconPath"];
NSString *selectedIconPath = config[@"selectedIconPath"];

UIImage *normalImage = [UIImage imageNamed:iconPath];
UIImage *selectedImage = [UIImage imageNamed:selectedIconPath];

tabBarItem.image = [normalImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
tabBarItem.selectedImage = [selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

// 设置文字颜色
[tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor grayColor]} 
                          forState:UIControlStateNormal];
[tabBarItem setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blueColor]} 
                          forState:UIControlStateSelected];
```

### 懒加载实现

#### tabBarController:shouldSelectViewController:
```objc
- (BOOL)tabBarController:(UITabBarController *)tabBarController 
shouldSelectViewController:(UIViewController *)viewController
```
**作用**: Tab切换前的拦截，实现懒加载
**返回值**: YES允许切换，NO禁止切换
**实现逻辑**:
1. 检查是否是导航控制器
2. 获取根视图控制器
3. 判断是否是占位符控制器
4. 如果是占位符，创建真实控制器并替换
5. 返回YES允许切换

**关键代码**:
```objc
UINavigationController *nav = (UINavigationController *)viewController;
UIViewController *rootVC = nav.viewControllers.firstObject;

// 检查是否是占位符
if (![rootVC isKindOfClass:[CFJClientH5Controller class]]) {
    // 获取保存的配置
    NSDictionary *config = objc_getAssociatedObject(rootVC, @"tabConfig");
    
    if (config) {
        // 创建真实的控制器
        CFJClientH5Controller *h5VC = [self createH5ControllerWithConfig:config];
        
        // 替换占位符
        nav.viewControllers = @[h5VC];
        
        // 移除关联对象
        objc_setAssociatedObject(rootVC, @"tabConfig", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

return YES;
```

### 消息红点管理

#### showMessageDot
```objc
- (void)showMessageDot
```
**作用**: 显示消息Tab的红点
**实现逻辑**:
1. 如果红点不存在，创建红点视图
2. 计算红点位置（Tab图标右上角）
3. 添加到TabBar上
4. 显示红点

#### hideMessageDot
```objc
- (void)hideMessageDot
```
**作用**: 隐藏消息Tab的红点
**实现**: 设置红点视图hidden = YES

#### updateMessageCount:
```objc
- (void)updateMessageCount:(NSInteger)count
```
**作用**: 更新消息数量显示
**参数**: count - 消息数量
**实现逻辑**:
1. 如果count > 0，显示红点
2. 如果count > 99，显示"99+"
3. 如果count <= 0，隐藏红点
4. 更新标签文本

### 生命周期方法

#### viewDidAppear:
```objc
- (void)viewDidAppear:(BOOL)animated
```
**作用**: 视图显示完成
**实现逻辑**:
1. 调用父类方法
2. 移除LoadingView（如果存在）

**LoadingView移除**:
```objc
// 查找并移除LoadingView
for (UIWindow *window in [UIApplication sharedApplication].windows) {
    UIView *loadingView = [window viewWithTag:2001];
    if (loadingView) {
        [UIView animateWithDuration:0.3 animations:^{
            loadingView.alpha = 0;
        } completion:^(BOOL finished) {
            [loadingView removeFromSuperview];
        }];
        break;
    }
}
```

### 系统回调

#### didReceiveMemoryWarning
```objc
- (void)didReceiveMemoryWarning
```
**作用**: 内存警告处理
**实现**: 调用父类方法，可扩展清理逻辑

## 配置文件格式 (appInfo.json)

```json
{
    "app": {
        "tabBar": [
            {
                "pagePath": "/home",
                "text": "首页",
                "iconPath": "tab_home",
                "selectedIconPath": "tab_home_selected",
                "canShare": "1",
                "uid": "home"
            },
            {
                "pagePath": "/category",
                "text": "分类",
                "iconPath": "tab_category",
                "selectedIconPath": "tab_category_selected",
                "canShare": "0",
                "uid": "category"
            }
        ]
    }
}
```

## 使用示例

```objc
// 在AppDelegate中使用
- (BOOL)application:(UIApplication *)application 
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    // 创建TabBarController
    XZTabBarController *tabBarController = [[XZTabBarController alloc] init];
    
    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

// 更新消息数量
XZTabBarController *tabBar = (XZTabBarController *)self.window.rootViewController;
[tabBar updateMessageCount:5];
```

## 注意事项

1. **懒加载机制**: 只有第一个Tab会立即创建，其他Tab在首次点击时创建
2. **网络权限**: iOS 10+需要处理网络权限
3. **配置文件**: appInfo.json必须正确配置
4. **内存管理**: 注意关联对象的清理
5. **LoadingView**: 需要在适当时机移除

## 已知问题

1. 快速切换Tab可能导致懒加载异常
2. 消息红点位置可能因机型不同需要调整
3. 网络权限状态变化处理可能延迟

## 优化建议

1. **预加载优化**:
   - 在空闲时预加载其他Tab
   - 缓存Tab配置信息
   - 优化首屏加载速度

2. **红点管理**:
   - 统一的红点管理器
   - 支持不同样式的红点
   - 动画效果优化

3. **配置管理**:
   - 支持远程配置更新
   - 配置文件版本管理
   - 容错处理机制