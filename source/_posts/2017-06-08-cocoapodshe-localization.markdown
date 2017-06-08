---
layout: post
title: "CocoaPods和Localization"
date: 2017-06-08 09:23:01 +0800
comments: true
categories: 
---

一直没有很好地理清 CocoaPods 对图片、NIB等资源的管理方式，趁着跟进 “智齿” 国际化失效问题，摘录下浏览的相关资料。另外吐槽下 “智齿”， 这家的 iOS SDK 是我目前集成的所有 SDK 中，对开发者最不友好的了。

问题来了：在使用 CocoaPods 集成“智齿”后，“智齿”的国际化信息就一直显示英文版本，即使系统语言设置成中文。但是如果不通过 CocoaPods，直接把 SDK 拉进工程中，国际化信息就又生效了。在咨询其开发人员无果后，只能自己慢慢排雷了。由于问题只在 “CocoaPods 引入 SDK” 这种情况下出现，所以要想彻底解决这个问题，就需要明确 CocoaPods 是如何对国际化资源进行管理的。

<!--more-->
## CocoaPods 如何管理资源

从 [CocoaPods 0.36 的 release 文档](http://blog.cocoapods.org/CocoaPods-0.36/) 看，它对资源的管理方式，取决于是否以 Frameworks 的方式对 CocoaPods 进行集成，从 Podfile 层面看，就是是否使用了 use_frameworks! 。

#### 以 Static Libraries 的方式集成

**CocoaPods 会把所有的资源塞进 app bundle** ，开发者可以使用 `[NSBundle mainBundle]` 访问里面的所有资源，也可以从生成 product 的根目录查看资源（显示包内容后）。由于苹果不允许 Swift 代码被编译成静态库，所以如果 Swift 项目想使用 CocoaPods 管理源码的话，是一定要使用 Dynamic Frameworks 方式进行集成的。一般来说， Objective-C 项目都是使用此方式集成。

#### 以 Dynamic Frameworks 的方式集成

**CocoaPods 会把资源塞进对应的 Frameworks** ，只有通过指定 Frameworks 的 bundle 才能访问到资源：

```
// Objective-C
[NSBundle bundleForClass:<#ClassFromPodspec#>]
// Swift
NSBundle(forClass: <#ClassFromPodspec#>)
```

这种方式对于 Static Libraries 和 Dynamic Frameworks 都是有效的。如果编写的框架包含一些资源的话，内部访问资源时，应该以这种方式指定确切的 bundle ，因为无法确定开发者是以何种方式集成你的框架。


顺带说下，由于没有很好的方式来构建**传递依赖**中含有 static libraries 的 frameworks（如果不是传递依赖，即使存在含有 static libraries 的 Pod ，构建时还是会直接归并入最终的可执行文件中），使用 CocoaPods 时，选择哪种集成方式对于单个 target 来说是一件 “all or  nothing” 的事情，也就是说开发者无法**主动**针对个别 Pod 采用不同的集成方式。（如有需要，可以使用 [carthage](https://github.com/Carthage/Carthage)）

举个例子：假如当前主工程依赖了 PodA 、 PodB ，而 PodA 依赖了 PodB，并且 PodB 中有静态二进制文件(.a / .framework) ，那么在执行 `pod update` 时，就会报 `transitive dependencies that include static binaries` 错误。这样在组件化时，就很难引入使用 Swift 编写的 Pod 了，因为如果项目足够大，就肯定会存在**传递依赖**中含有 static libraries 的情况。

## SobotKit 存在的问题

SobotKit 是“智齿”的 iOS SDK ，下面是 SobotKit podspec 文件的部分代码：

```
s.frameworks =  "AudioToolbox","AssetsLibrary","SystemConfiguration","AVFoundation","MobileCoreServices"
s.library   = 'z.1.2.5'

# s.resource  = "icon.png"
s.resources = 'SobotKit.bundle','ZCEmojiExpression.bundle','en.lproj/SobotLocalizable.strings','zh-Hans.lproj/SobotLocalizable.strings'
s.ios.vendored_frameworks = 'SobotKit.framework'
```

下面是以 Static Libraries 的方式集成进工程后的目录结构：

![](./images/Snip20170608_1.png)
![](./images/Snip20170608_4.png)

构建工程后，进入 product 根目录。可以看到，虽然在目录中，Pod 增加了 en.lproj、zh-Hans 两个文件夹，但是拷贝到 app bundle 后，却并没有这两个文件夹，同名的 .strings 文件相互覆盖了。

![](./images/Snip20170608_5.png)

下面是修改后的 podspec：

```
s.resources = 'SobotKit.bundle','ZCEmojiExpression.bundle','*.lproj'
```

构建工程后，可以看下目录：

![](./images/Snip20170608_3.png)
![](./images/Snip20170608_4.png)

构建后的 product 根目录：

![](./images/Snip20170608_6.png)

最终结果表明， SobotKit 的 podspec 写错了。不过工程的目录结构还是让我迷惑了很久，Pod 目录里面居然有实体文件，着实让我走了点弯路。

## 小结

在明确构建当前工程会将 SobotKit 的相关资源直接塞到 app bundle 后，排查问题就变得简单了。因为在我这个项目的上下文中，直接把 SobotKit 拉进主工程和通过 Pod 集成，其资源最终存放的的位置都是 app bundle ，这也就排除了 SobotKit 内部调用Localizaton宏错误这一猜测。

CocoaPods 推荐以 Dynamic Frameworks 的方式集成，不过要注意的是引用资源时，要指定对应的 bundle 。

## 参考
[给 Pod 添加资源文件](http://blog.xianqu.org/2015/08/pod-resources/)<br>
[CocoaPods 0.36 - Framework and Swift Support](http://blog.cocoapods.org/CocoaPods-0.36/)
