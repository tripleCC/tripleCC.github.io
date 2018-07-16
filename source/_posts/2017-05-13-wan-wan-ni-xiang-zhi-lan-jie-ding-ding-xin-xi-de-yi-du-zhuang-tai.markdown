---
layout: post
title: "玩玩逆向之拦截钉钉消息已读状态"
date: 2017-05-13 16:54:37 +0800
comments: true
styles: [data-table]
categories: 逆向
---

> 流光容易把人抛，红了樱桃，绿了芭蕉

一个月前的某一天，百无聊赖的我在整理房间的时候，偶然翻开了一本积灰的“小黄书”，看到首页作者的赠语，眼前不禁浮现两年前，几经波折辗转到上海的我兴致勃勃勃勃地拜托[小锅](http://www.swiftyper.com/about/)让他的直属老大狗神 (本书作者之一) ，给刚买的这本《iOS应用逆向工程》签名的场景，百味杂陈。说来惭愧，我一直都没有好好地看过这本书，等回过头来，不知不觉已经过去两年了。这篇文章致那个曾经那个能够静心看书的少年。

<!--more-->
## 灵感

钉钉是一款针对企业日常工作交流的 App ，因为是针对企业协作，所以不同于一般的 IM 软件，比如微信，钉钉增加了对消息读取状态的监控。简单来说就是同事发送一条消息后，如果我打开 App ，进入聊天界面查看了这条消息，那么该同事就会在这条消息旁边看到“已读”字样，如下图：

![](/images/Snip20170513_1.png)
![](/images/Snip20170513_4.png)

这个已读功能在工作的时候还是挺有作用的，能够知道同事是否已经知晓的相关事务。不过总会存在某些时候，我们不希望让对方知道消息已经被读取了。这就需要对 App 进行一些处理了。

## 准备工作
因为逆向基本工具在《iOS应用逆向工程》中罗列地非常清楚，所以对于一些基本环境的配置，这里就略过了，只简单介绍下这次逆向需要的工具。

| 工具          |    本次逆向作用     |
| ------------- |:-------------:|
| dumpdecrypted <br> Clutch           | 对 App 进行砸壳，使之可进行反汇编及 dump |
| class-dump           | 获取 App 的 class 信息 （ Xcode 打开方便查看） |
| Hopper Disassembler    | 反汇编器，查看 App 的汇编代码 |
| usbmuxd    | [映射使用 USB 连接的逆向设备端口到本地](http://localhost:4000/blog/2017-04-09-shi-yong-usbmuxdlian-jie-iphone/) |
| OpenSSH         | 让越狱设备上具备 ssh 服务 |
| cycript         | 在目标 App 进程中测试函数，也可用来定位感兴趣对象 |
| debugserver         | 调试服务器，可让 lldb 连接 iOS 进行远程调试 |
| lldb <br> chisel           | lldb 调试器，不多说 <br> FB 出品的 lldb 调试插件，不仅在 Xcode 正向开发中很有用，逆向也酸爽至极 |
| theos           | 编写Tweak，可对逆向代码进行编译打包，并以 dylib 的形式安装到越狱设备中 |

接下来记录下整个逆向工作流程。

### 对 App 进行砸壳

本次砸壳采用的工具是书中演示的 dumpdecrypted。

1、首先通过 ssh 连接到 iOS 设备

```objc
➜  dumpdecrypted git:(master) ✗ iproxy 2223 22 &
➜  dumpdecrypted git:(master) ✗ ssh root@localhost -p 2223
```

2、使用 ps 和 grep 找出目标 App 可执行文件路径

```objc
iPhone:~ root# ps -A | grep Application
 1774 ??         1:06.02 /Applications/InCallService.app/InCallService
 4147 ??         1:04.34 /var/containers/Bundle/Application/60B29D5D-2360-4C01-A49F-8CA87C752EFE/DingTalk.app/DingTalk
 4217 ??         0:04.58 /Applications/Weather.app/PlugIns/WeatherAppTodayWidget.appex/WeatherAppTodayWidget
 4220 ??         0:02.39 /Applications/Maps.app/PlugIns/MapsWidget.appex/MapsWidget
 4223 ??         0:02.50 /private/var/containers/Bundle/Application/D4438959-3D50-4D5B-AFD5-635BAE010F57/Pin.app/PlugIns/PinToday.appex/PinToday
 4233 ??         0:00.78 /private/var/containers/Bundle/Application/D4438959-3D50-4D5B-AFD5-635BAE010F57/Pin.app/PlugIns/PinCleaner.appex/PinCleaner
 4316 ??         0:01.70 /Applications/MobileCal.app/PlugIns/CalendarWidget.appex/CalendarWidget
 4319 ??         0:01.99 /private/var/containers/Bundle/Application/61C2E8D7-4C2D-4323-A357-7FAB9AE33339/WizIPhone.app/PlugIns/WizNoteIPhoneToday.appex/WizNoteIPhoneToday
 4322 ??         0:01.28 /private/var/containers/Bundle/Application/F576BB21-A1F2-42B8-A18F-D2AFCE9E78D8/AlipayWallet.app/PlugIns/APTodayWidget.appex/APTodayWidget
 4418 ??         0:28.22 /var/containers/Bundle/Application/3654E1CC-CEE2-44DB-A7E6-B4268A59F3C6/WeChat.app/WeChat
 4429 ??         0:08.09 /var/containers/Bundle/Application/F576BB21-A1F2-42B8-A18F-D2AFCE9E78D8/AlipayWallet.app/AlipayWallet
```
这里由于先前并不知道钉钉的可执行文件名，所以直接用 Application 关键字对所有进程进行过滤，知道后就可以直接用 DingTalk 进行过滤了 。包含钉钉可执行文件路径的一行为

```objc
 4147 ??         1:04.34 /var/containers/Bundle/Application/60B29D5D-2360-4C01-A49F-8CA87C752EFE/DingTalk.app/DingTalk
```
3、使用 cycript 获取钉钉 Document 文件夹路径

```objc
iPhone:~ root# cycript -p  4147
cy# NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
@"/var/mobile/Containers/Data/Application/93BEEF52-2DE2-4687-9986-E50CBD961BB2/Documents"
```
使用 `cycript -p + pid / 可执行文件名 ` 就可以在目标 App 的进程下运行方法了。在这一步顺便把钉钉的 Bundle ID 给打印出来，后面 thoes 会用到

```
cy# [[NSBundle mainBundle] bundleIdentifier]
@"com.laiwang.DingTalk"

```

4、将 dumpdecrypted.dylib 拷贝到 Documents 目录下

```objc
➜  dumpdecrypted git:(master) ✗ scp -P 2223  dumpdecrypted.dylib root@localhost:/var/mobile/Containers/Data/Application/93BEEF52-2DE2-4687-9986-E50CBD961BB2/Documents

```
5、开始砸壳

```objc
iPhone:~ root# cd /var/mobile/Containers/Data/Application/93BEEF52-2DE2-4687-9986-E50CBD961BB2/Documents
iPhone:/var/mobile/Containers/Data/Application/93BEEF52-2DE2-4687-9986-E50CBD961BB2/Documents root# DYLD_INSERT_LIBRARIES=dumpdecrypted.dylib /var/containers/Bundle/Application/60B29D5D-2360-4C01-A49F-8CA87C752EFE/DingTalk.app/DingTalk
```
砸壳后，当前目录下会有一个 DingTalk.decrypted 文件，将这个砸壳之后的文件拷贝到电脑上进行反汇编及 class-dump 。

### 进行 class-dump 及反汇编

1、进入 DingTalk.decrypted 所在目录，执行 class-dump

```objc
➜  DingTalk class-dump -S -s  -H -o DTClassDump  DingTalk.decrypted
```
可以看到目录下多了 DTClassDump 文件夹，打开这个文件夹，全选里面的头文件，用 Xcode 打开。

2、打开 Hopper Disassembler 并将 DingTalk.decrypted 拖进面板中，Hopper Disassembler 会自动识别 DingTalk.decrypted 对应的 CPU 体系结构。确定进行后续操作后，Hopper Disassembler就开始进行反汇编了。反汇编的时间可能会**有点长**，所以最好把反汇编之后的 hop 文件保存一下，这样下次就可以直接打开了（不过即使这样打开也要挺久的，8G 内存也有点吃紧，老是转菊花 _(°:з」∠)_ ）。

## 逆向过程
### 定位消息控制器

如果是从视图切入的话，使用 FLEXLoader （ Cydia 商店可下载 ） 是个不错的选择，它可以很方便地调试当前界面上的元素。当然，Revel 这种利器就不用多介绍了，用起来也是很舒畅。不过这里我使用了另外两种方式：

1、首先是使用 cycript。进入钉钉的聊天界面后，执行下面代码：

```objc
cy# [[[[[UIApplication sharedApplication] keyWindow] rootViewController] viewControllers][0] topViewController]
#"<DTMessageOTOViewController: 0x104217c00>"
```
由于大体知道钉钉界面的层级关系，使用代码获取当前界面的信息还是比较容易的。

2、第二种是使用 lldb 来打印控制器层级列表。<br>
这里涉及到 lldb 的远程调试，首先映射越狱设备 1234 端口到 Mac 本地 1234 端口：

```
➜  DTClassDump iproxy 1234 1234 &
```
然后在越狱设备上开启 debugserver：

```objc
iPhone:~ root# debugserver *:1234 -a DingTalk
debugserver-@(#)PROGRAM:debugserver  PROJECT:debugserver-360.0.26.1
 for arm64.
Listening to port 1234 for a connection from *...
```
接着执行一下命令，让 lldb 连接上 debugserver：

```objc
➜  DTClassDump lldb
(lldb) process connect connect://localhost:1234

* thread #1: tid = 0xb7f8b, 0x000000018e18816c libsystem_kernel.dylib`mach_msg_trap + 8, name ='505', queue = 'com.apple.main-thread', stop reason = signal SIGSTOP
    frame #0: 0x000000018e18816c libsystem_kernel.dylib`mach_msg_trap + 8
libsystem_kernel.dylib`mach_msg_trap:
->  0x18e18816c <+8>: ret

libsystem_kernel.dylib`mach_msg_overwrite_trap:
    0x18e188170 <+0>: movn   x16, #0x1f
    0x18e188174 <+4>: svc    #0x80
    0x18e188178 <+8>: ret
(lldb)

```
最后我们就可以进行调试了。***注：下面的 lldb 操作会用到 [chisel](https://github.com/facebook/chisel) 插件的一些命令***。<br>

首先，导入 chisel 部分命令需要的 UIKit 框架：

```objc
(lldb) process interrupt
Process 4600 stopped
* thread #1: tid = 0xb7f8b, 0x000000018e18816c libsystem_kernel.dylib`mach_msg_trap + 8, name = '505', stop reason = signal SIGSTOP
    frame #0: 0x000000018e18816c libsystem_kernel.dylib`mach_msg_trap + 8
libsystem_kernel.dylib`mach_msg_trap:
->  0x18e18816c <+8>: ret

libsystem_kernel.dylib`mach_msg_overwrite_trap:
    0x18e188170 <+0>: movn   x16, #0x1f
    0x18e188174 <+4>: svc    #0x80
    0x18e188178 <+8>: ret
(lldb) expr @import UIKit
(lldb)
```
接着还是进入到聊天界面：

```objc
(lldb) pvc
<DTTabBarController 0x13bd4cb00>, state: appeared, view: <UILayoutContainerView 0x13be75310>
   | <DTNavigationController 0x13c8dda00>, state: appeared, view: <UILayoutContainerView 0x13be7dee0>
   |    | <DTConversationListController 0x13c02ee00>, state: disappeared, view: <UIView 0x13bd7ab40> not in the window
   |    | <DTMessageOTOViewController 0x13c830400>, state: appeared, view: <UIView 0x13d2291f0>
   | <DTNavigationController 0x13c0e0c00>, state: disappeared, view: <UILayoutContainerView 0x13bd66b30> not in the window
   |    | <DTDingTableViewController 0x13c0b7e00>, state: disappeared, view:  (view not loaded)
   | <DTNavigationController 0x13c985200>, state: disappeared, view: <UILayoutContainerView 0x13be9d110> not in the window
   |    | <DTWorkViewController 0x13be9ba00>, state: disappeared, view:  (view not loaded)
   | <DTNavigationController 0x13c0f8c00>, state: disappeared, view: <UILayoutContainerView 0x13bd6dae0> not in the window
   |    | <DTContactViewController 0x13bd6bf80>, state: disappeared, view: <UIView 0x13d120ee0> not in the window
   | <DTNavigationController 0x13c104c00>, state: disappeared, view: <UILayoutContainerView 0x13bd733c0> not in the window
   |    | <DTSettingViewController 0x13bd71cc0>, state: disappeared, view:  (view not loaded)

(lldb)
```
可以看到 chisel 不仅把目标控制器 `<DTMessageOTOViewController 0x13c830400>` 打印出来了，还顺带把当前整个控制器层级都给拉了出来。

### 定位接受消息方法
将消息标为已读的前提是钉钉接收到了该消息，进而可以推测是不是在接收消息后，钉钉发送了已读标志，所以我们先找出接收消息的回调方法。在不知道确切方法的情况下，浏览下下 class-dump 出来的 `DTMessageOTOViewController` 类信息多少会有收获的：

```objc
//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "DTMessageBaseViewController.h"

#import "DTCEmailTransitionViewDelegate.h"

@class DTBadgeView, DTCEmailTransitionView, DTCMailMode, DTTypingManager, NSString, UIButton;

@interface DTMessageOTOViewController : DTMessageBaseViewController <DTCEmailTransitionViewDelegate>
...
- (void)handleNotificationMessage:(id)arg1;
- (void)receivedMessageListNotification:(id)arg1;
- (void)receivedMessageNotification:(id)arg1;
...
@end
```

结合方法命名，我只关注了上方的三个方法。接下来可以逐个测试上面的方法，找出处理消息的回调了。

在 Hopper Disassembler 中， `DTMessageOTOViewController` 的 `handleNotificationMessage:` 的方法如下：

```
        ; ================ B E G I N N I N G   O F   P R O C E D U R E ================


                     -[DTMessageOTOViewController handleNotificationMessage:]:
0000000100466820         stp        x26, x25, [sp, #-0x50]!                     ; Objective C Implementation defined at 0x1030ddb30 (instance method), DATA XREF=0x1030ddb30
...
```

如上所示，我们可以知道 `handleNotificationMessage:` 的相对地址是 0x0000000100466820，打开 lldb 进行调试：

1、获取 DingTalk 的 ASLR (地址空间配置随机加载) 偏移量

```objc
(lldb) image list -o -f | grep DingTalk
[  0] 0x0000000000004000 /var/containers/Bundle/Application/60B29D5D-2360-4C01-A49F-8CA87C752EFE/DingTalk.app/DingTalk(0x0000000100004000)
```

2、设置 `handleNotificationMessage:` 断点信息。不过在设置前，得先明确下参数和返回值的传递规则。
<br>

参数传递规则：前四个参数存放在 R0 - R3 中，剩余的通过栈进行传递。<br>
返回值传递规则：通过 R0 传递给调用者。

众所周知，Objective-C 的方法调用是通过 `objc_msgSend` 函数实现的，`objc_msgSend` 定义如下：

```
id objc_msgSend(id self, SEL	_cmd,...);
```
所以我们可以通过 R0 / arg0 获取消息接受者， R1 / arg1 获取发送的方法名。综上，可添加断点信息如下：

```
(lldb) br set -a 0x0000000000004000+0x0000000100466820
Breakpoint 1: where = DingTalk`_mh_execute_header + 4588940, address = 0x000000010046a820
(lldb) br command add 1
Enter your debugger command(s).  Type 'DONE' to end.
> po $x0
> p (char *)$x1
> po $x2
> DONE
```

3、向越狱设备的钉钉发送消息，触发断点

```
(lldb)  po $x0
<DTMessageOTOViewController: 0x11e2edc00>
(lldb)  p (char *)$x1
(char *) $2 = 0x000000010296e9ba "handleNotificationMessage:"
(lldb)  po $x2
<__NSArrayM 0x170853e00>(
senderId = 72938616
localMid = (null)
mId = 21530513660
attachmentsType = 1
sendStatus = 0
type = 1
isDecrypt = 0
)

Process 4918 stopped
* thread #1: tid = 0xd51a3, 0x000000010046a820 DingTalk`_mh_execute_header + 4614176, name = '709', queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
    frame #0: 0x000000010046a820 DingTalk`_mh_execute_header + 4614176
DingTalk`_mh_execute_header:
->  0x10046a820 <+4614176>: stp    x26, x25, [sp, #-80]!
    0x10046a824 <+4614180>: stp    x24, x23, [sp, #16]
    0x10046a828 <+4614184>: stp    x22, x21, [sp, #32]
    0x10046a82c <+4614188>: stp    x20, x19, [sp, #48]
(lldb)
```
可以看到接收消息后，的确进入了 `handleNotificationMessage:` 方法。并且通过 LR （保存函数返回地址寄存器），我们可以定位到是 `receivedMessageListNotification:` 方法调用了 `handleNotificationMessage:` ：

```
(lldb) p/x $lr - 0x0000000000004000
(unsigned long) $6 = 0x00000001004667d0
```
Hopper Disassembler ：

```
        ; ================ B E G I N N I N G   O F   P R O C E D U R E ================


                     -[DTMessageOTOViewController receivedMessageListNotification:]:
...
00000001004667c0         ldr        x1, [x8, #0xc58]                            ; "handleNotificationMessage:",@selector(handleNotificationMessage:)
00000001004667c4         mov        x0, x20
00000001004667c8         mov        x2, x22
00000001004667cc         bl         imp___stubs__objc_msgSend
00000001004667d0         mov        x0, x22
...
```
进而，我们可以知道新消息到来时，钉钉会广播 `DTPushReceivedMessageListNotification` 通知：

```
NSConcreteNotification 0x170854430 {name = DTPushReceivedMessageListNotification; object = <DTReconnectedHandler: 0x170015990>; userInfo = {
    DTPushReceivedInfoKey =     (
        "senderId = 72938616\nlocalMid = (null)\nmId = 21526791314\nattachmentsType = 1\nsendStatus = 0\ntype = 1\nisDecrypt = 0\n"
    );
}}
```

4、从反汇编代码中寻找线索

虽然定位到了 `handleNotificationMessage:` 方法，但最终发现这个方法并没有给我想要的信息，不过它的调用者 `receivedMessageListNotification:` 方法却提供了一些有用的线索：

```
        ; ================ B E G I N N I N G   O F   P R O C E D U R E ================


                     -[DTMessageOTOViewController receivedMessageListNotification:]:
...
0000000100466754         cbz        x20, loc_1004667e0

0000000100466758         str        x20, [sp, #0x8]
000000010046675c         adrp       x8, #0x1035bf000
0000000100466760         ldr        x8, [x8, #0x5a0]                            ; 0x1035bf5a0,__objc_class_DTMessageOTOViewController_class
0000000100466764         str        x8, [sp, #0x10]
0000000100466768         adrp       x8, #0x103568000                            ; @selector(cname)
000000010046676c         ldr        x1, [x8, #0x378]                            ; "receivedMessageListNotification:",@selector(receivedMessageListNotification:)
0000000100466770         add        x0, sp, #0x8
0000000100466774         mov        x2, x19
0000000100466778         bl         imp___stubs__objc_msgSendSuper2
...
```
`DTMessageOTOViewController` 对象的 `receivedMessageListNotification:` 方法有效信息并不多，但它在调用 `handleNotificationMessage:` 方法前，调用了父类的 `receivedMessageListNotification:` 方法：

```
 ; ================ B E G I N N I N G   O F   P R O C E D U R E ================


                     -[DTMessageBaseViewController receivedMessageListNotification:]:
...
ldr        x24, [x8, #0xd58] ; "dataSource",@selector(dataSource)
mov        x0, x20
mov        x1, x24
bl         imp___stubs__objc_msgSend
mov        x29, x29
bl         imp___stubs__objc_retainAutoreleasedReturnValue
mov        x25, x0
adrp       x8, #0x103568000 ; @selector(cname)
ldr        x1, [x8, #0xc00] ; "noRepeatSortMessagesWithNotificationMessageList:",@selector(noRepeatSortMessagesWithNotificationMessageList:)
mov        x2, x22
bl         imp___stubs__objc_msgSend
...
adrp       x8, #0x103568000 ; @selector(cname)
ldr        x1, [x8, #0xc10] ; "dealMessageListWithNoRepeatSortArray:finishBlock:",@selector(dealMessageListWithNoRepeatSortArray:finishBlock:)
add        x3, sp, #0x8
mov        x0, x26
mov        x2, x25
bl         imp___stubs__objc_msgSend
...
```

通过反汇编代码可以看出，这个 `dataSource` 先后调用了 `noRepeatSortMessagesWithNotificationMessageList:` 和 `dealMessageListWithNoRepeatSortArray:finishBlock:` 方法，会不会在后一个方法发送已读标志呢？在确认之前，我们先看下 `dataSource` 这个方法：

```
@property(retain, nonatomic) DTMessageControllerDataSource *dataSource; // @synthesize dataSource=_dataSource;
```

数据源被剥离到一个独立的对象了，这种做法在界面比较复杂的情况中很常见，能有效减少控制器中的代码。那么 `DTMessageControllerDataSource` 里面会有什么有用的信息么？


### 定位发送已读标志方法

上文说到了 DTMessageControllerDataSource 这个类，这个类定义如下：

```
@interface DTMessageControllerDataSource : NSObject <UIViewControllerPreviewingDelegate, DTMessageCollectionViewCellDataSource, EGORefreshTableHeaderDelegate, DTMessageConllectionViewDataSource, DTMessageControllerDataSourceProtocal>
...
- (_Bool)needSendReadStatusInCellForRowWithMessage:(id)arg1;
...
- (void)sendMessageReadStatusWithMessage:(id)arg1;
...

@end
```

结合命名方法，我注意到了上面两个方法。和上文步骤一样，我先使用 lldb 调试了 `needSendReadStatusInCellForRowWithMessage: ` 方法：

```
        ; ================ B E G I N N I N G   O F   P R O C E D U R E ================


                     -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]:
...
00000001001a070c         mov        x0, x20
00000001001a0710         ldp        x29, x30, [sp, #0x20]
00000001001a0714         ldp        x20, x19, [sp, #0x10]
00000001001a0718         ldp        x22, x21, [sp]!, #0x30
00000001001a071c         ret
...
```
不过这次因为要改变返回值，我直接把断点打在了 `0x00000001001a070c` 这个地方：

```
Process 4961 stopped
* thread #1: tid = 0xdc358, 0x00000001001d070c DingTalk`_mh_execute_header + 1705740, name = '137', queue = 'com.apple.main-thread', stop reason = instruction step over
    frame #0: 0x00000001001d070c DingTalk`_mh_execute_header + 1705740
DingTalk`_mh_execute_header:
->  0x1001d070c <+1705740>: mov    x0, x20
    0x1001d0710 <+1705744>: ldp    x29, x30, [sp, #32]
    0x1001d0714 <+1705748>: ldp    x20, x19, [sp, #16]
    0x1001d0718 <+1705752>: ldp    x22, x21, [sp], #48
(lldb) ni
Process 4961 stopped
* thread #1: tid = 0xdc358, 0x00000001001d0710 DingTalk`_mh_execute_header + 1705744, name = '137', queue = 'com.apple.main-thread', stop reason = instruction step over
    frame #0: 0x00000001001d0710 DingTalk`_mh_execute_header + 1705744
DingTalk`_mh_execute_header:
->  0x1001d0710 <+1705744>: ldp    x29, x30, [sp, #32]
    0x1001d0714 <+1705748>: ldp    x20, x19, [sp, #16]
    0x1001d0718 <+1705752>: ldp    x22, x21, [sp], #48
    0x1001d071c <+1705756>: ret
(lldb) p $x0
(unsigned long) $6 = 1
(lldb) register write $x0 0
(lldb) c
```
改写 R0 (返回值) 为 0 并让进程继续运行后，消息发送方的已读标志果然没有出现，始终是处于未读状态，而接收方也看到了这条消息。那么 `needSendUnreadStatusWithMessage:` 方法是如何判断该返回YES或NO呢？除去了部分对结果不产生影响的分支后，其汇编代码如下：

```
00000001001a05c8         stp        x22, x21, [sp, #-0x30]!                     ; Objective C Implementation defined at 0x103088d78 (instance method), DATA XREF=0x103088d78
00000001001a05cc         stp        x20, x19, [sp, #0x10]
00000001001a05d0         stp        x29, x30, [sp, #0x20]
00000001001a05d4         add        x29, sp, #0x20
00000001001a05d8         mov        x20, x0
00000001001a05dc         mov        x0, x2
00000001001a05e0         bl         imp___stubs__objc_retain
00000001001a05e4         mov        x19, x0
00000001001a05e8         adrp       x8, #0x10355d000                            ; @selector(filteredImageUsingContrastFilterOnImage:)
00000001001a05ec         ldr        x1, [x8, #0x4b0]                            ; "collectionView",@selector(collectionView)
00000001001a05f0         mov        x0, x20
00000001001a05f4         bl         imp___stubs__objc_msgSend
00000001001a05f8         mov        x29, x29
00000001001a05fc         bl         imp___stubs__objc_retainAutoreleasedReturnValue
00000001001a0600         mov        x20, x0
00000001001a0604         adrp       x8, #0x103559000
00000001001a0608         ldr        x1, [x8, #0xd58]                            ; "dataSource",@selector(dataSource)
00000001001a060c         bl         imp___stubs__objc_msgSend
00000001001a0610         mov        x29, x29
00000001001a0614         bl         imp___stubs__objc_retainAutoreleasedReturnValue
00000001001a0618         mov        x21, x0
00000001001a061c         adrp       x8, #0x103563000                            ; @selector(updateConversationClientExtension:message:wkBizConversation:needSaveToDB:)
00000001001a0620         ldr        x1, [x8, #0x660]                            ; "needSendUnreadStatusWithMessage:",@selector(needSendUnreadStatusWithMessage:)
00000001001a0624         mov        x2, x19
00000001001a0628         bl         imp___stubs__objc_msgSend
00000001001a062c         mov        x22, x0
00000001001a0630         mov        x0, x21
00000001001a0634         bl         imp___stubs__objc_release
00000001001a0638         mov        x0, x20
00000001001a063c         bl         imp___stubs__objc_release
00000001001a0640         cbz        w22, loc_1001a0700

00000001001a0644         adrp       x8, #0x10355b000                            ; @selector(DT_S13_normal)
00000001001a0648         ldr        x20, [x8, #0x740]                           ; "attachmentsType",@selector(attachmentsType)
00000001001a064c         mov        x0, x19
00000001001a0650         mov        x1, x20
00000001001a0654         bl         imp___stubs__objc_msgSend
00000001001a0658         cmp        x0, #0x67
00000001001a065c         b.eq       loc_1001a0700

00000001001a0660         mov        x0, x19
00000001001a0664         mov        x1, x20
00000001001a0668         bl         imp___stubs__objc_msgSend
00000001001a066c         cmp        x0, #0xca
00000001001a0670         b.eq       loc_1001a0700

00000001001a0674         mov        x0, x19
00000001001a0678         mov        x1, x20
00000001001a067c         bl         imp___stubs__objc_msgSend
00000001001a0680         cmp        x0, #0x4
00000001001a0684         b.eq       loc_1001a0700

00000001001a0688         mov        x0, x19
00000001001a068c         mov        x1, x20
00000001001a0690         bl         imp___stubs__objc_msgSend
00000001001a0694         cmp        x0, #0x2
00000001001a0698         b.eq       loc_1001a0700

00000001001a069c         mov        x0, x19
00000001001a06a0         mov        x1, x20
00000001001a06a4         bl         imp___stubs__objc_msgSend
00000001001a06a8         cmp        x0, #0x66
00000001001a06ac         b.eq       loc_1001a0700

00000001001a06b0         mov        x0, x19
00000001001a06b4         mov        x1, x20
00000001001a06b8         bl         imp___stubs__objc_msgSend
00000001001a06bc         cmp        x0, #0x10
00000001001a06c0         b.eq       loc_1001a0700

00000001001a06c4         adrp       x8, #0x103563000                            ; @selector(updateConversationClientExtension:message:wkBizConversation:needSaveToDB:)
00000001001a06c8         ldr        x1, [x8, #0x640]                            ; "isMsgNeedShowFullWidth",@selector(isMsgNeedShowFullWidth)
00000001001a06cc         mov        x0, x19
00000001001a06d0         bl         imp___stubs__objc_msgSend
00000001001a06d4         tbnz       w0, 0x0, loc_1001a0700

00000001001a06d8         mov        x0, x19
00000001001a06dc         mov        x1, x20
00000001001a06e0         bl         imp___stubs__objc_msgSend
00000001001a06e4         cmp        x0, #0x1f4
00000001001a06e8         b.eq       loc_1001a0700

00000001001a06ec         mov        x0, x19
00000001001a06f0         mov        x1, x20
00000001001a06f4         bl         imp___stubs__objc_msgSend
00000001001a06f8         cmp        x0, #0x1f5
00000001001a06fc         b.ne       loc_1001a0720

                     loc_1001a0700:
00000001001a0700         movz       w20, #0x0                                   ; CODE XREF=-[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+120, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+148, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+168, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+188, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+208, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+228, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+248, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+268, -[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+288

                     loc_1001a0704:
00000001001a0704         mov        x0, x19                                     ; CODE XREF=-[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+372
00000001001a0708         bl         imp___stubs__objc_release
00000001001a070c         mov        x0, x20
00000001001a0710         ldp        x29, x30, [sp, #0x20]
00000001001a0714         ldp        x20, x19, [sp, #0x10]
00000001001a0718         ldp        x22, x21, [sp]!, #0x30
00000001001a071c         ret
                        ; endp

                     loc_1001a0720:
00000001001a0720         adrp       x8, #0x1035b5000                            ; CODE XREF=-[DTMessageControllerDataSource needSendReadStatusInCellForRowWithMessage:]+308
00000001001a0724         ldr        x0, [x8, #0xdd0]                            ; objc_cls_ref_DTMessageServiceV2,__objc_class_DTMessageServiceV2_class
00000001001a0728         adrp       x8, #0x103563000                            ; @selector(updateConversationClientExtension:message:wkBizConversation:needSaveToDB:)
00000001001a072c         ldr        x1, [x8, #0x668]                            ; "isEncryptSpaceType:",@selector(isEncryptSpaceType:)
00000001001a0730         mov        x2, x19
00000001001a0734         bl         imp___stubs__objc_msgSend
00000001001a0738         eor        w20, w0, #0x1
00000001001a073c         b          loc_1001a0704
```
整理一下，可以用以下 Objective-C 代码进行表示：

```objc
- (BOOL)needSendUnreadStatusWithMessage:(DTBizMessage *)message {
    
    if (!message) return NO;
    
    return message.creatorType == 1 && !message.isMine && !message.readStatus;
}
```

既然知道了这块的代码逻辑，改变其行为也就不在话下了。

### 编写安装 Tweak 

1、创建一个 Tweak 工程模版：

```objc
➜  DingTalk nic.pl
NIC 2.0 - New Instance Creator
------------------------------
  [1.] iphone/activator_event
  [2.] iphone/activator_event
  [3.] iphone/activator_listener
  ...
  [26.] iphone/tweak
  ...
Choose a Template (required): 26
Project Name (required): DingTalkRecallBarrier
Package Name [com.yourcompany.dingtalkrecallbarrier]: com.tripleCC.dingtalkrecallbarrier
Author/Maintainer Name [tripleCC]: tripleCC
[iphone/tweak] MobileSubstrate Bundle filter [com.apple.springboard]: com.laiwang.DingTalk
[iphone/tweak] List of applications to terminate upon installation (space-separated, '-' for none) [SpringBoard]: DingTalk
Instantiating iphone/tweak in dingtalkrecallbarrier/...
Done.
```
2、编写 Tweak.m 和 Makefile 文件了：

Tweak.m：
 
```
%hook DTMessageControllerDataSource
- (BOOL)needSendReadStatusInCellForRowWithMessage:(id)arg1 {
  return NO;
}
%end
```
Makefile：

```
ARCHS = arm64
TARGET = iphone:latest:8.0
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DingTalkRecallBarrier
DingTalkRecallBarrier_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
        install.exec "killall -9 DingTalk"
```

这里的 `needSendReadStatusInCellForRowWithMessage:` 直接返回 NO ，因为即使不执行原来的方法，也不会影响 App 的正常运行。

3、将 Tweak 编译打包安装到越狱设备上：

```

➜  dingtalkrecallbarrier export THEOS_DEVICE_IP=localhost
➜  dingtalkrecallbarrier export THEOS_DEVICE_PORT=2223
➜  dingtalkrecallbarrier make package install
> Making all for tweak DingTalkRecallBarrier…
make[2]: Nothing to be done for `internal-library-compile'.
> Making stage for tweak DingTalkRecallBarrier…
#Filter plist
#PreferenceLoader plist
dm.pl: building package `com.triplecc.dingtalkrecallbarrier:iphoneos-arm' in `./packages/com.triplecc.dingtalkrecallbarrier_0.0.1-13+debug_iphoneos-arm.deb'
==> Installing…
Selecting previously unselected package com.triplecc.dingtalkrecallbarrier.
(Reading database ... 1230 files and directories currently installed.)
Preparing to unpack /tmp/_theos_install.deb ...
Unpacking com.triplecc.dingtalkrecallbarrier (0.0.1-13+debug) ...
Setting up com.triplecc.dingtalkrecallbarrier (0.0.1-13+debug) ...
install.exec "killall -9 DingTalk"
```

## 小结
第一次逆向实践，虽说编写的 Tweak 代码才几行，但其定位过程却是一波三折，可能因为经验不足导致定位不准确吧，不过逆向需要很好的耐心倒不假。因为以前做过即时通讯，所以对钉钉消息收发流程多少还是会有点自己的理解，这无形中也推进了我逆向的进度。

最后，这次逆向让我时隔三年之后，再一次有机会利用终端调试程序，还记得以前是做 Linux 应用程序时在嵌入式设备中使用 gdb 进行调试。决定以后在 Xcode 中也要多用命令行进行调试了，实在是舒畅。
## 参考
[iOS应用逆向工程](https://book.douban.com/subject/26363333/)<br>
[iOS 逆向实战 - 钉钉签到远程“打卡”](http://www.swiftyper.com/2017/02/15/dingtalk-fake-gps/)<br>
[ARM 64 常用汇编指令](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0802b/CSET_CSINC.html)<br>
[The LLDB Debugger Tutorial](https://lldb.llvm.org/tutorial.html)<br>

