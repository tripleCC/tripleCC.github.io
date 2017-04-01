---
layout: post
title: "iOS知识碎片七"
date: 2016-09-24 10:43:37 +0800
comments: true
categories: 
---
1、Xcode8日志及Pod的Swift3.0问题 <br>
2、UITextFiled使用UITextAlignmentRight输入空格光标不实时跟进 <br>
3、解决使用UIAlertController时，Attempt to present vc whose view is not in the window hierarchy! 问题 <br>

<!--more-->

## Xcode8日志及Pod的Swift3.0问题

目前的Xcode8会打印多余的日志，需要进入对应scheme中的enviroment variables设置下：

```
OS_ACTIVITY_MODE    disable
```

如果设置了以上信息后，出现了真机调试不会打印日志的情况的话，去掉`disable`，保留`OS_ACTIVITY_MODE`。

Pod更新Swift三方库后编译，会出现转换语法的错误，需要在podfile中添加以下语句再更新：

```
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
        end
    end
end
```
如果还想使用2.3的话：

```
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
      #### IT IS IMPORTANT TO SET IT TO 2.3
      config.build_settings['SWIFT_VERSION'] = '2.3' 
    end
  end
end
```

## UITextFiled使用UITextAlignmentRight输入空格光标不实时跟进

![](/images/Snip20170205_2.png)

在上图箭头处输入空格，光标和文字不会向前移动。

[解决方案](http://stackoverflow.com/questions/19569688/right-aligned-uitextfield-spacebar-does-not-advance-cursor-in-ios-7)


## 解决使用UIAlertController时，Attempt to present vc whose view is not in the window hierarchy! 问题

假设现有有控制器 A ， present 了控制器 B ，而在控制器 B 还没有 dimiss 完全时，再 present 新的控制器 C 就会出现这个警告，控制器 C 也并不会如预期显示。

把上面的控制器 C 当成 UIAlertController ，就切合某些业务场景了。 结合业务场景，这个问题可以看成：如何让UIAlertController 使用起来和 UIAlertView 一样“万金油” ，并且不用受控制器层级约束。

下面是 stackoverflow 上一个比较详细的解决方案：
[How to present UIAlertController when not in a ViewController](http://stackoverflow.com/questions/26554894/how-to-present-uialertcontroller-when-not-in-a-view-controller)

简单来说，就是创建一个新的 window ( 优先级比当前最高优先级大 1 )， 然后通过这个 window 的根控制器 present UIAlertController，并且在 UIAlertController 被释放的同时，释放此 window。

这个方案本身目前看来并没有问题，问题出现 agilityvision 在 stackoverflow 上给的 demo 上面多了下面代码 ([FFGlobalAlertController](https://github.com/agilityvision/FFGlobalAlertController) 并没有这几句代码)：

```objc
if ([delegate respondsToSelector:@selector(window)]) {
	// we inherit the main window's tintColor
	self.alertWindow.tintColor = delegate.window.tintColor;
}

```

上面代码在以下情况下会造成 alert 按钮文字无法显示：

- 设置 -> 通用 -> 辅助功能 -> 增强对比度 -> 打开加深颜色 。

这个问题挺奇葩的，要不是刚好有测试人员打开了这个开关，基本也发现不了。最终我也不知道为什么会这样，从 Xcode 可视化工具看， alert 按钮上的确是有文字的，颜色也没错。

想要使用 agilityvision 的方案，删除这几句代码就可以不会出现上述问题了。
