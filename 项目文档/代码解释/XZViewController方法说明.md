# XZViewController 方法说明文档

## 文件信息
- **文件路径**: XZVientiane/XZBase/BaseController/XZViewController.h/.m
- **作用**: 项目中大部分视图控制器的基类，提供通用功能和UI配置
- **创建时间**: 2016年3月10日

## 类继承关系
```
UIViewController
    └── XZViewController
```

## 属性说明

### 公开属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| navBar | XZNavBar* | 自定义导航栏视图 |
| tyInteractivePopDisabled | BOOL | 是否禁用侧滑返回手势 |
| dataDic | NSDictionary* | 数据字典（未使用） |

## 方法详解

### 生命周期方法

#### viewDidLoad
```objc
- (void)viewDidLoad
```
**作用**: 视图加载完成后的初始化
**实现逻辑**:
1. 调用父类方法
2. 设置背景色为 tyBgViewColor
3. 设置 automaticallyAdjustsScrollViewInsets = NO（防止自动调整滚动视图内边距）
4. 调用 createNavBar 创建自定义导航栏
5. 添加键盘通知监听（仅在 TESTMARK 标记下）
6. 默认隐藏自定义导航栏

#### viewWillAppear:
```objc
- (void)viewWillAppear:(BOOL)animated
```
**作用**: 视图即将显示时的处理
**实现逻辑**:
1. 调用父类方法
2. 友盟页面统计开始（页面名称使用导航栏标题）
3. 注意：此时导航栏标题可能为空，导致统计名称为nil

#### viewWillDisappear:
```objc
- (void)viewWillDisappear:(BOOL)animated
```
**作用**: 视图即将消失时的处理
**实现逻辑**:
1. 调用父类方法
2. 友盟页面统计结束

#### dealloc
```objc
- (void)dealloc
```
**作用**: 对象销毁时的清理
**实现逻辑**:
1. 移除键盘通知观察者（仅在 TESTMARK 标记下）
2. 打印调试日志

### UI创建方法

#### createNavBar
```objc
- (void)createNavBar
```
**作用**: 创建自定义导航栏
**实现逻辑**:
1. 隐藏系统导航栏：self.navigationController.navigationBarHidden = YES
2. 创建 XZNavBar 实例
3. 设置导航栏代理为 self
4. 添加到视图顶部
5. 默认显示返回按钮
6. 使用 Masonry 设置约束（顶部、左右对齐，高度64）

### 导航栏代理方法

#### navBackBtnClicked
```objc
- (void)navBackBtnClicked
```
**作用**: 处理导航栏返回按钮点击
**实现逻辑**:
1. 调用 navigationController 的 popViewControllerAnimated: 方法
2. 返回上一个页面

### 状态栏配置

#### preferredStatusBarStyle
```objc
- (UIStatusBarStyle)preferredStatusBarStyle
```
**作用**: 设置状态栏样式
**返回值**: UIStatusBarStyleDefault（黑色状态栏）

### 屏幕旋转配置

#### supportedInterfaceOrientations
```objc
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
```
**作用**: 设置支持的屏幕方向
**返回值**: UIInterfaceOrientationMaskPortrait（仅支持竖屏）
**注释**: 包含注释掉的 shouldAutorotate 方法，返回 NO

### 键盘处理方法（仅调试模式）

#### keyboardWillShow:
```objc
- (void)keyboardWillShow:(NSNotification *)notif
```
**作用**: 键盘即将显示的处理
**参数**: notif - 包含键盘信息的通知
**实现**: 空方法，子类可重写

#### keyboardWillHide:
```objc
- (void)keyboardWillHide:(NSNotification *)notif
```
**作用**: 键盘即将隐藏的处理
**参数**: notif - 包含键盘信息的通知
**实现**: 空方法，子类可重写

## 使用示例

```objc
// 创建子类
@interface MyViewController : XZViewController
@end

@implementation MyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 显示导航栏
    self.navBar.hidden = NO;
    
    // 设置标题
    self.navBar.titleLabel.text = @"我的页面";
    
    // 自定义返回按钮行为
    // 重写 navBackBtnClicked 方法
}

- (void)navBackBtnClicked {
    // 自定义返回逻辑
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
```

## 注意事项

1. **导航栏管理**: 默认隐藏系统导航栏，使用自定义导航栏
2. **内存管理**: dealloc中需要移除通知观察者
3. **友盟统计**: viewWillAppear时可能获取不到导航栏标题
4. **屏幕方向**: 仅支持竖屏
5. **侧滑返回**: 通过tyInteractivePopDisabled属性控制

## 已知问题

1. dataDic属性声明但未使用
2. 友盟统计页面名称可能为nil
3. 键盘通知仅在TESTMARK下注册，生产环境不可用

## 优化建议

1. 移除未使用的dataDic属性
2. 优化友盟统计时机，确保获取到正确的页面名称
3. 统一键盘处理逻辑，不依赖TESTMARK
4. 考虑使用系统导航栏，减少自定义UI的维护成本