---
layout: post
title: "使用usbmuxd连接iPhone"
date: 2017-04-09 14:28:11 +0800
comments: true
styles: [data-table]
categories: 
---

最近通过 WIFI ssh 到越狱设备上时，出了个奇怪的问题： ssh 一直不结束，没提示成功，也没有提示失败。下面是自己对越狱设备进行“自测”的过程：

| 操作           |    结果     |
| ------------- |:-------------:|
| iOS ssh mac ip          | 成功 |
| iOS ssh localhost          | 成功 (sshd 是跑起来的)|
| iOS ssh 自身 ip          | 失败 |
| mac ssh iOS ip           | 失败 |

上面的失败是指没有返回 ssh 的结果，一直卡在连接阶段。

<!--more-->

谷歌了很多资料，后来重装了 openSSH，也试过重置网络设置，最终还是不了了之，找不出越狱设备哪里出了问题。这样就只剩下利用 usbmuxd 进行连接的方式了。

首先是安装 usbmuxd ：

```
brew list usbmuxd
```

然后看下 iproxy 的使用说明：

```
iproxy LOCAL_TCP_PORT DEVICE_TCP_PORT [UDID]
```

也就是执行 `iproxy 2223 22 &` 后，会将越狱设备的 22 端口 (ssh用) 映射到本地的 2223 端口。 <br>
这样我就可以通过 `ssh root@localhost -p 2223` 连接越狱设备了。

假如找不到 iproxy 命令，可以执行 `brew list usbmuxd` 找下可执行文件的路径，添加到 $PATH 。

使用 theos 的 `make package install` 命令时，需要添加下面两个环境变量 ：

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

