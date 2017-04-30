---
layout: post
title: "给 APP 添加悬浮助手"
date: 2017-04-28 19:08:23 +0800
comments: true
categories: 
---

自组内力推业务组件化以来，项目组的业务组件数量也渐具规模。虽然在版本依赖和个别组件独立性等细节上略有欠缺，但是在一定程度上还是提升了开发效率。

既然是业务组件，在某些场景下就需要登录获取相关权限后才能进一步操作。由于项目中登录模块并没有重构过，代码风格和书写逻辑极差，加上针对 B 端的 APP 登录逻辑较为复杂，包括切店等一系列操作，导致给客户使用的登录逻辑界面，在开发阶段难以接入业务组件，即使接入了，使用体验（没错，开发时也讲究一个体验）和开发效率也是会打一定折扣。

那么问题来了，在开发阶段，怎样做才能让业务模块更加简便、优雅、无侵入地接入登录功能呢？进一步讲，如果不局限于登录功能，如何给业务模块提供通用工具入口？

<!--more-->

## 灵感

在找到答案之前，我注意到了越狱设备上的一款强大的调试插件 --- FLEXLoader。

FLEXLoader，其在 GitHub 上的项目名为 [FLEX](https://github.com/Flipboard/FLEX)，它不仅可以集成进自家项目中，对开发的 APP 进行视图、内存级别上的调试，而且在越狱设备上，通过 FLEXLoader 可以查看安装的其它 APP 。 在这里就不对 FLEXLoader 强大的功能做过多介绍了，主要借鉴其 ToolBar 的展示方法来解决上面的疑问。

在越狱设备中，开启想要观察 APP 的 FLEXLoader 功能，然后打开 APP ，就会看到有如下工具栏悬浮于界面之上：

![](/images/Snip20170430_4.PNG)

接下来，对 FLEX 这部分功能进行简略地解读。

## FLEX 工具栏
 
首先， FLEXLoader 为了能让工具栏悬浮于 APP 所有界面之上，独立创建了一个高 windowLevel 的 FLEXWindow ：

```objc
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        // Some apps have windows at UIWindowLevelStatusBar + n.
        // If we make the window level too high, we block out UIAlertViews.
        // There's a balance between staying above the app's windows and staying below alerts.
        // UIWindowLevelStatusBar + 100 seems to hit that balance.
        self.windowLevel = UIWindowLevelStatusBar + 100.0;
    }
    return self;
}
```

这个 window 是 FLEXLoader 上所有视图得以展示的基础。因为这个 window 的层级比状态栏还高，会对 APP 原本的事件响应产生影响，所以就有如下代码对事件进行过滤 ：

```objc
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL pointInside = NO;
    if ([self.eventDelegate shouldHandleTouchAtPoint:point]) {
        pointInside = [super pointInside:point withEvent:event];
    }
    return pointInside;
}
```
通过 `shouldHandleTouchAtPoint:point` 决定是否应该让 FLEXWindow 响应当前触点。而这部分逻辑是根据悬浮工具栏来编写的，对于我目前的需求来说，如果触点在工具栏视图上，就响应点击事件，否则让系统传递给 APP 自身的 window。

FLEXWindow 中还有一个比较重要的是：

```objc
- (BOOL)canBecomeKeyWindow
{
    return [self.eventDelegate canBecomeKeyWindow];
}

其实就是：

- (BOOL)_canBecomeKeyWindow
{
    return [self.eventDelegate canBecomeKeyWindow];
}
```

虽然这里涉及到了私有 API `_canBecomeKeyWindow`，但是悬浮助手本身就是在开发环境中使用的，所以并没有太大影响。而且这一句非常重要，在 APP 悬浮助手中，我直接返回了 NO ，这样能够减少意外情况的发生。特别是项目中很多跳转使用到了 `[UIApplication sharedApplication].keyWindow.rootViewController` （原项目中是个 UINavigationController），可能会出现 keyWindow 指向不正确而导致崩溃的情况。

这里插个题外话，NSWindow 有一个 `canBecomeKey` 的公开方法，功能和 UIWindow `_canBecomeKeyWindow`一样，UIWindow 却把它设为了私有方法。或许是因为 Mac 上常常通过创建 window 来展示新内容，而 iOS 更多的是改变 window 中的视图吧。还有 keyWindow 和普通 window 相比，优势是能接收当前的键盘和非触摸事件，而触摸事件则是先传递到当前触摸到的 window 上，windowLevel 越高，在响应链中就越靠前。所以在悬浮助手中，我让 `_canBecomeKeyWindow` 直接返回了 NO 。

窗口创建完毕，接下来需要展示工具栏了。 FLEXLoader 创建了一个 FLEXExplorerViewController 作为FLEXWindow 的 rootViewController 来展示内容。由于工具栏在 APP 的整个生命周期中都会存在，FLEXLoader 还创建了 FLEXManager 单例来管理工具窗口，这样就能通过下面代码控制工具栏显示与否：

```objc
- (void)showExplorer
{
    self.explorerWindow.hidden = NO;
}

- (void)hideExplorer
{
    self.explorerWindow.hidden = YES;
}
```
FLEX 工具栏差不多就是以上诉方式实现的，接下来就可以着手开发自己的悬浮助手了。

## 悬浮助手

悬浮助手，顾名思义，只是一个助手，因此即便去除这部分代码，工程应该依然能编译通过。用组件化开发的语言来描述，悬浮助手只是一个 Pod ，添加和去除应该只需要在 Podfile 中增删一行代码。

不侵入业务的话，使用 swizzling method 是个不错的选择。在这个需求中，我对 UIViewController 的 `viewDidAppear` 进行了替换，然后初始化悬浮助手窗口管理者：

```
- (void)tpc_viewDidAppear:(BOOL)animated {
    [self tpc_viewDidAppear:animated];
    
    if (已经初始化过)  return;
    
  	 初始化悬浮助手管理者，展示界面
}
```

只要把基础的悬浮做好，后面添加功能就比较方便了。下面是我自己的悬浮助手界面：

![](/images/Snip20170430_5.png)

目前为止，这个助手具备以下功能：

- 单击，出现功能入口，选择对应功能
- 双击，登录入口，输入手机、密码，点击登录
- 三击，出现切店入口，点击黄色/绿色条目，切换至对应店铺
- 四击，切换网络环境
- 长按拖动

并且在启动工程后，悬浮助手会默认登录一次，获取用户信息，这样的话开发需要登录权限的业务组件就非常方便了。

## 参考

[Understanding Windows and Screens](https://developer.apple.com/library/content/documentation/WindowsViews/Conceptual/WindowAndScreenGuide/WindowScreenRolesinApp/WindowScreenRolesinApp.html#//apple_ref/doc/uid/TP40012555-CH4-SW3)

[UIKit-UIWindow](https://developer.apple.com/reference/uikit/uiwindow)
