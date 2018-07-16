---
layout: post
title: "在Ubuntu下编译Swift"
date: 2016-01-05 22:00:18 +0800
comments: true
categories: swift
tags: [Swift,ubuntu]
---
哎，近半年没有在Ubuntu的字符终端下畅爽地码代码了（那种Ctrl+Alt+F1~F6然后只有不同颜色的字符在屏幕上跳跃的感觉现在想起来还是超爽啊！），今天恰好来试下在Ubuntu下编译Swift，因为要截图，所以只能在图形界面的虚拟终端下码了- -。

##### 下载工具包
首先需要进这[这里](https://swift.org/download/)下载对应的工具包，因为我的系统是去年安装的Ubuntu14.04所以选择最后一个。<br>
![](/images/Snip20160105_8.png)<br>

##### 解压工具包
然后进入下载文件夹解压：<br>
![](/images/Snip20160105_9.png)<br>
可以看到解压后，目录下有下面几个子目录：<br>
![](/images/Snip20160105_10.png)<br>
主要说明三个子目录
```
bin   可执行文件
lib   可执行文件动态库
share man
```
<!--More-->

##### 设置PATH路径
接下来需要设置系统的PATH：<br>

```
// root
$ vim /etc/profile
// 对应的user
$ vim ~/.profile
```
然后在文件的末尾添加以下表达式即可（Shift+g跳到最后一行；Shift+o添加一行）：<br>
![](/images/Snip20160105_12.png)<br>
也可以在当前虚拟终端暂时性的设置PATH，不过退出这个终端在重新开启一个就恢复以前的PATH了：<br>
![](/images/Snip20160105_11.png)<br>
这里我直接把工具包目录下的bin目录以及lib目录中的动态库和可执行文件直接移到/usr/local/bin和/usr/local/lib中，这样就不需要修改PATH路径了。

##### 下载Swift运行的依赖库
因为上星期在运行Swift开源代码的时候，我基本把所有的依赖环境都安装了，所以不需要重新安装，如果没有安装过的话，可以执行以下命令：

```
$ sudo apt-get install clang libicu-dev
```

##### 编写Swift程序
上面步骤执行完成，就可以在Ubuntu上编写运行Swift代码了。
先试用下Swift的REPL，效果如下：<br>
![](/images/Snip20160105_15.png)<br>
然后就可以正式编写Swift代码了，想想都有点小激动＝＝。<br>
新建一个Swift目录，然后创建第一个程序目录HelloWorld。<br>

```
$ cd ~/Study
$ mkdir -p Swift/HelloWorld
$ cd Swift/HelloWorld
```
因为每个包都需要有Package.swift文件，所以执行以下命令进行创建：

```
$ touch package.swift
```
最后需要创建一个包含main.swift的Sources文件夹：

```
$ mkdir Sources
$ touch Sources/main.swift
```
接着开始编辑main.swift：

```
$ vim main.swift
// 插入以下代码
print("Hello, world!")
```
执行以下命令编译并运行文件：

```
$ swift build
$ .build/debug/Swift
```
以下为运行结果 ：

![](/images/Snip20160105_14.png)<br>  

##### THE END
在Ubuntu下写Swift，感觉还是非常不错的，以后有时间可以多玩一玩。