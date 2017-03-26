---
layout: post
title: "iOS知识碎片七"
date: 2016-09-24 10:43:37 +0800
comments: true
categories: 
---
1、Xcode8日志及Pod的Swift3.0问题 <br>
2、UITextFiled使用UITextAlignmentRight输入空格光标不实时跟进

<!--more-->

##Xcode8日志及Pod的Swift3.0问题

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

##UITextFiled使用UITextAlignmentRight输入空格光标不实时跟进

![](/images/Snip20170205_2.png)

在上图箭头处输入空格，光标和文字不会向前移动。

[解决方案](http://stackoverflow.com/questions/19569688/right-aligned-uitextfield-spacebar-does-not-advance-cursor-in-ios-7)


