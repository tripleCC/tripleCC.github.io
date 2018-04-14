---
layout: post
title: "让CocoaPods组件支持Carthage打包"
date: 2018-04-07 19:24:40 +0800
comments: true
categories: 
---

虽说 CocoaPods 有 [cocoapods-packager](https://github.com/CocoaPods/cocoapods-packager) 这个插件可以生成二进制版本，但这个库的维护者似乎并不活跃，很多 issue 和 pr 过了一两年还堆积着没处理。于是我决定试试 Carthage ，不过不利用 Cartfile 生成依赖，还是用的 CocoaPods 那一套。

要让组件支持 Carthage ，工程里只需要有一个 `shared framework target` 即可。针对 CocoaPods 生成的工程，我们先在 Podfile 里面设置  `use_frameworks!` ，来满足  `framework target` 。

<!--more-->

对于剩下的 `share` 部分，可以用 [Add share schemes for development pods](https://github.com/CocoaPods/CocoaPods/pull/5254) 这个 pr 里面的方法解决：

```
install! 'cocoapods', :share_schemes_for_development_pods => false
```
不过上面的那种方式把所有的 `development pods` 对应的 target 都 share 了，这里我们可以这样设置特定的 `development pods` ：

```
install! 'cocoapods', :share_schemes_for_development_pods => ['PodA']
```

在 CocoaPods 1.4.0 版本中，`share_schemes_for_development_pods` 默认是 false 的，所以需要手动在 Podfile 里面去添加这一句。

最后执行一下 `pod install` ，然后再执行 `carthage build --no-skip-current --platform ios` 就可以打出 ios 版本的 dynamic framework 了。想利用 Carthage 打出 static framework 的可以查看 [Build static frameworks to speed up your app’s launch times](https://github.com/Carthage/Carthage/blob/master/Documentation/StaticFrameworks.md)。


再进一步，我们可以把这个默认设置写入团队专有的 CocoaPods 插件中，比如 `cocoapods-xxx-plugin`：

```ruby
Pod::HooksManager.register('cocoapods-xxx-plugin', :pre_install) do |context, _|
	first_target_definition = context.podfile.target_definition_list.select{ |d| d.name != 'Pods' }.first
	development_pod = first_target_definition.name.split('_').first unless first_target_definition.nil?
	    
	Pod::UI.section("Auto set share scheme for development pod: \'#{development_pod}\'") do
		# carthage 需要 shared scheme 构建 framework
		context.podfile.install!('cocoapods', :share_schemes_for_development_pods => [development_pod])
	end unless development_pod.nil?
end
```
在 Podfile 添加以下代码，让插件生效：

```
plugin 'cocoapods-xxx-plugin'
```

好处就是以后有更多相似配置的话都可以通过更改这个插件解决，而不用每次都去 Podfile 里面改 `pre_install`。
