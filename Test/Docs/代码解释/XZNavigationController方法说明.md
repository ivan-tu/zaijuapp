# XZNavigationController 方法说明文档

## 文件信息
- **文件路径**: XZVientiane/XZBase/BaseController/XZNavigationController.h/.m
- **作用**: 自定义导航控制器，实现自定义的push/pop转场动画和交互式返回手势
- **创建时间**: 2016年

## 类继承关系
```
UINavigationController
    └── XZNavigationController
```

## 内部类说明

### XZInlineSlideAnimator
**作用**: 内联定义的转场动画类，避免链接问题
**继承**: NSObject <UIViewControllerAnimatedTransitioning>
**功能**: 实现自定义的滑动转场动画

## 属性说明

### 私有属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| interactiveTransition | UIPercentDrivenInteractiveTransition* | 交互式转场控制器 |
| panGestureRecognizer | UIPanGestureRecognizer* | 滑动返回手势 |

## 方法详解

### 生命周期方法

#### viewDidLoad
```objc
- (void)viewDidLoad
```
**作用**: 视图加载完成后的初始化
**实现逻辑**:
1. 调用父类方法
2. 设置导航栏为不透明
3. 添加全局配置的背景图片
4. 设置自身为导航代理
5. 添加边缘滑动返回手势

### 手势处理

#### setupPanGestureRecognizer
```objc
- (void)setupPanGestureRecognizer
```
**作用**: 设置滑动返回手势
**实现逻辑**:
1. 创建UIPanGestureRecognizer
2. 添加到视图上
3. 设置手势代理

#### handlePanGesture:
```objc
- (void)handlePanGesture:(UIPanGestureRecognizer *)recognizer
```
**作用**: 处理滑动手势
**参数**: recognizer - 手势识别器
**实现逻辑**:
1. 获取手势在视图中的位置和速度
2. 计算滑动进度（0-1）
3. 根据手势状态处理：
   - **开始**: 创建交互式转场，执行pop操作
   - **改变**: 更新转场进度
   - **结束/取消**: 根据进度和速度决定完成或取消

**关键代码**:
```objc
CGFloat progress = translation.x / recognizer.view.bounds.size.width;
progress = MIN(1.0, MAX(0.0, progress)); // 限制在0-1之间

if (recognizer.state == UIGestureRecognizerStateBegan) {
    self.interactiveTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
    [self popViewControllerAnimated:YES];
} else if (recognizer.state == UIGestureRecognizerStateChanged) {
    [self.interactiveTransition updateInteractiveTransition:progress];
} else if (recognizer.state == UIGestureRecognizerStateEnded || 
           recognizer.state == UIGestureRecognizerStateCancelled) {
    if (progress > 0.5 || velocity.x > 500) {
        [self.interactiveTransition finishInteractiveTransition];
    } else {
        [self.interactiveTransition cancelInteractiveTransition];
    }
    self.interactiveTransition = nil;
}
```

### UIGestureRecognizerDelegate

#### gestureRecognizerShouldBegin:
```objc
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
```
**作用**: 决定手势是否应该开始
**返回值**: 
- YES: 允许手势开始
- NO: 禁止手势
**判断逻辑**:
1. 如果不是滑动手势，返回YES
2. 如果只有一个视图控制器（根控制器），返回NO
3. 检查顶部控制器的tyInteractivePopDisabled属性
4. 检查手势方向是否为向右滑动

### UINavigationControllerDelegate

#### navigationController:animationControllerForOperation:fromViewController:toViewController:
```objc
- (id<UIViewControllerAnimatedTransitioning>)navigationController:animationControllerForOperation:fromViewController:toViewController:
```
**作用**: 返回自定义的转场动画控制器
**参数**:
- operation: 导航操作类型（push/pop）
- fromVC: 源控制器
- toVC: 目标控制器
**返回值**: 
- Push/Pop操作: 返回XZInlineSlideAnimator实例
- 其他: 返回nil使用默认动画

#### navigationController:interactionControllerForAnimationController:
```objc
- (id<UIViewControllerInteractiveTransitioning>)navigationController:interactionControllerForAnimationController:
```
**作用**: 返回交互式转场控制器
**返回值**: 当前的interactiveTransition（如果正在进行交互式转场）

#### navigationController:didShowViewController:animated:
```objc
- (void)navigationController:didShowViewController:animated:
```
**作用**: 导航完成后的处理
**实现逻辑**:
1. 检查是否是pop操作且被取消
2. 如果取消，恢复目标控制器的WebView状态
3. 清理交互式转场对象

**重要修复**:
```objc
// 修复pop取消后WebView不显示的问题
if (operation == UINavigationControllerOperationPop && 
    self.interactiveTransition && 
    self.interactiveTransition.percentComplete < 1.0) {
    
    // 恢复WebView的显示状态
    if ([toVC respondsToSelector:@selector(webView)]) {
        UIView *webView = [toVC valueForKey:@"webView"];
        if (webView) {
            webView.hidden = NO;
            webView.alpha = 1.0;
            webView.userInteractionEnabled = YES;
        }
    }
}
```

### 状态栏和屏幕旋转

#### childViewControllerForStatusBarStyle
```objc
- (UIViewController *)childViewControllerForStatusBarStyle
```
**作用**: 决定状态栏样式的控制器
**返回值**: 顶部视图控制器

#### childViewControllerForStatusBarHidden
```objc
- (UIViewController *)childViewControllerForStatusBarHidden  
```
**作用**: 决定状态栏是否隐藏的控制器
**返回值**: 顶部视图控制器

## XZInlineSlideAnimator 实现

### 属性
| 属性名 | 类型 | 说明 |
|-------|------|------|
| operation | UINavigationControllerOperation | 导航操作类型 |

### 动画时长
```objc
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.3; // 300毫秒
}
```

### 动画实现
```objc
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
```
**Push动画**:
1. 获取fromView和toView
2. 将toView添加到容器视图
3. 设置初始位置（屏幕右侧）
4. 动画移动到最终位置
5. fromView向左移动1/3宽度

**Pop动画**:
1. 获取fromView和toView
2. 将toView插入到fromView下方
3. 设置toView初始位置（左侧1/3）
4. 动画：fromView向右移出，toView移到中心
5. 完成后调用completeTransition

## 使用示例

```objc
// 在需要禁用滑动返回的控制器中
@interface MyViewController : XZViewController
@end

@implementation MyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 禁用滑动返回
    self.tyInteractivePopDisabled = YES;
}

@end

// 使用自定义导航控制器
XZNavigationController *nav = [[XZNavigationController alloc] 
    initWithRootViewController:rootVC];
```

## 注意事项

1. **手势冲突**: 滑动手势可能与页面内的其他手势冲突
2. **性能**: 转场动画需要注意性能，避免卡顿
3. **WebView问题**: 特别注意转场取消时WebView的状态恢复
4. **内存管理**: 确保转场完成后正确清理资源

## 已知问题

1. 快速连续操作可能导致动画异常
2. 某些情况下WebView在转场取消后不显示
3. 与系统手势的冲突处理

## 优化建议

1. **动画优化**:
   - 使用CADisplayLink优化动画流畅度
   - 添加阴影效果增强层次感
   - 支持自定义动画时长

2. **交互优化**:
   - 支持全屏滑动返回
   - 添加滑动返回的视觉反馈
   - 优化手势识别的灵敏度

3. **兼容性**:
   - 处理iOS 13+的模态展示
   - 支持Dark Mode
   - 适配不同屏幕尺寸