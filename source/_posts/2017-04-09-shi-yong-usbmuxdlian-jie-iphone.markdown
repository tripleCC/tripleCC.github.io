---
layout: post
title: "使用usbmuxd连接越狱设备"
date: 2017-04-09 14:28:11 +0800
comments: true
styles: [data-table]
categories: 
---

最近通过 wifi ssh 到越狱设备上时，出了个奇怪的问题： <br>
ssh 一直不结束，没提示成功，也没有提示失败。<br>

下面是自己对越狱设备进行“自测”的过程：

| 操作           |    结果     |
| ------------- |:-------------:|
| iOS ssh mac ip          | 成功 |
| iOS ssh localhost          | 成功 (sshd 是跑起来的)|
| iOS ssh 自身 ip          | 失败 |
| mac ssh iOS ip           | 失败 |

<br>
上面的失败是指没有返回 ssh 的结果，一直卡在连接阶段。

<!--more-->

谷歌了很多资料，重装了 openSSH，也试过重置网络设置，最终还是不了了之。这样就只能利用 usbmuxd 连接了。

首先是安装 usbmuxd ：

```
brew install usbmuxd
```

然后看下 iproxy 的使用说明：

```
iproxy LOCAL_TCP_PORT DEVICE_TCP_PORT [UDID]
```

也就是执行以下命令后： 

```
iproxy 2223 22 &
```
会将越狱设备的 22 端口 (ssh用) 映射到本地的 2223 端口。 这样就可以通过 `ssh root@localhost -p 2223` 连接越狱设备了。

如果需要用 lldb 调试越狱设备上的进程，需要先将 connect 的端口映射到本地，这里以 1234 端口为例：

```
iproxy 1234 1234 &
```
然后打开 lldb ，输入以下命令：

```
process connect connect://localhost:1234
```

连接越狱设备，输入以下命令：

```
debugserver *:1234 -a 进程名
```

只要越狱设备上的 debugserver （重签名过的）正常运行， 就可以连接通过 lldb 进行远程调试了。

使用 theos 的 `make package install` 命令时，需要先添加下面两个环境变量 ：

```
export THEOS_DEVICE_IP=localhost
export THEOS_DEVICE_PORT=2223
```

还有如果不想每次 ssh 都输入密码，可以进行以下操作 ：

```
brew install ssh-copy-id
ssh-copy-id root@localhost -p 2223
```

这样下次 ssh 相同的设备，就不需要输入密码了。

最后，如果输入 iproxy 时，显示可执行文件不存在，可以执行 `brew list usbmuxd` 找下可执行文件的路径，添加到 $PATH 。
