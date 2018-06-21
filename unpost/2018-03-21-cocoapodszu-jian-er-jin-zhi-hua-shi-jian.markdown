---
layout: post
title: "组件二进制化与CocoaPods插件"
date: 2018-03-21 16:45:46 +0800
comments: true
categories: 
---

首先需要说明的是，组件二进制化并非组件化的标配，只有在组件规模达到一定数量后，将组件二进制化才能收到不错的成效，毕竟多维护一套二进制版本也是需要额外精力的。另外，CocoaPods 在 1.3.0 版本做了性能优化  [Performance Improvements](http://blog.cocoapods.org/CocoaPods-1.3.0/)，`install` 或者 `update` 操作后的第一次编译不总是需要全量编译，这个让人诟病已久的缺点几乎已经被消除了。那么为什么还要费时费力地去做组件二进制化？

<!--more-->

答案是**打包时间**，每次打包都是一次全量编译。目前掌柜 App 打包一次大概花费 20 分钟，并且有上升趋势。在需要频繁更新代码打包的提测阶段，这个打包时长不论对开发还是测试，都是不友好的。<br>


<!-- 
1、主工程打包速度。目前一次 20 分钟以上，有上升趋势。<br>
2、主工程没有使用 use_frameworks! ，历史包袱过重，更改老的资源引用方式是一个大工程。希望能用二进制化策略约束新组件，然后逐步改造旧组件。<br>
3、主工程以及组件首次编译速度。<br> -->


开始利用 CocoaPods 插件去做组件二进制化前，需要对自身的项目做一个评估，提前确定实施过程中的一些小方向。

目前掌柜 App 无法直接以动态库的方式构建依赖的组件 ，原因有以下两点：

1、很多业务组件直接从 mainBundle 中获取资源。 <br>
2、有组件间接依赖了静态库。 <br>

所以，在生成目标产物选择上，只剩下 static framework 和 static library 了。首先要了解的是，static framework 和 static library 仅仅只是**打包方式不一样**（static framework 为头文件、资源文件以及静态库的集合），核心都是静态库，都能很好地切合当前项目，不会增加额外的改造工作量。不过为了能慢慢向 `use_frameworks!` 过渡，我们最终还是决定使用 static framework 。CocoaPods 也在 [1.4.0 版本](http://blog.cocoapods.org/CocoaPods-1.4.0/) 正式支持了 static framework ，只需要在 podspec 中添加以下代码即可：

```ruby
s.static_framework = true
```

对于如何让二进制和源码更好地共存，曹俊的 [iOS CocoaPods组件平滑二进制化解决方案
](https://www.jianshu.com/p/5338bc626eaf?utm_campaign=maleskine&utm_content=note&utm_medium=seo_notes&utm_source=recommendation
)一文已经较好地说明，这里就不再赘述了。


## 添加自定义 DSL

得益于 ruby 的 动态性，开发者可以通过以下方式添加自定义 DSL :

```ruby
module Pod
	class Podfile
		module DSL
			def tdfire_use_binary!
			
			end
		end
	end
end
```



以下几个前提：

- 使用 static framework
- 源码

1. static framework、dynamic framework、static library ？
2. 二进制、源码共存方式
1. 两种依赖方式的切换
2. pod cache 缓存干扰
3. 源码、二进制配置同步
4. subspec 依赖处理


## 参考

[iOS CocoaPods组件平滑二进制化解决方案](https://www.jianshu.com/p/5338bc626eaf)<br>
[基于 CocoaPods 进行 iOS 开发](https://blog.dianqk.org/2017/05/01/dev-on-pod/)<br>
[I have a pod, I have a carthage, En...](https://mp.weixin.qq.com/s/wV68OWGB3fiWc1hJW-o59g)

