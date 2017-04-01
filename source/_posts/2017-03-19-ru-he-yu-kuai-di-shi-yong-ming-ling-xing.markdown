---
layout: post
title: "如何愉快地使用命令行"
date: 2017-03-19 19:08:33 +0800
comments: true
styles: [data-table]
categories: 
---
古人云：

> 工欲善其事，必先利其器

从进入软件开发这一行业开始算起，我也算是陆陆续续地接触了三大主流操作系统。虽说不是很深入地使用过每个系统，但从自己的个人喜好及以往的使用经历来看， Mac 无疑是对开发者最友好的一个系统。

不过即便如此，作为一个 Vim 爱好者，我还是非常怀念当初在 Ubuntu 字符终端下编写代码的那种畅（zhuang）爽（bi）感，那种双手不需要离开键盘的紧凑感。

好的工具配置，既能极大地促进开发效率的提升，又能让开发者保持一个心情愉悦的状态。下面纪录下自己常用的一些工具软件，这些软件能减少让开发者对触控板 / 鼠标的依赖。

<!--more-->



##Alfred 

Mac 上有一款软件，江湖人称 Mac 神器，多年来没有同类软件出其右，这款软件便是大名鼎鼎的  Alfred 。

Alfred 从 2 代开始，便提供了成熟的 workflow 插件机制，由此这个软件具备了极其强大的扩展性。开发者也利用这个特性，开发了很多天马行空的 workflow ，可以说 Alfred 已经不仅仅是一个简单的工具软件了。

Alfred 有很多扩展，感兴趣的可以查看 [hzlzh](https://github.com/hzlzh) [收集的AlfredWorkflow站点](http://alfredworkflow.com/)，这里只列举一些基本的用法。

| 功能           |    快捷键     |
| ------------- |:-------------:|
| 呼出           | option + space |
| 打开应用          | 呼出后，输入应用名，选择列觉的应用，回车打开<br> command + 数字 快速打开 |
| 定位文件          | 呼出后，输入 find + 文件名 |
| 打开文件           | 呼出后，输入 open + 文件名 |
| 文件中搜索文本           | 呼出后，输入 in + 文本 |
| 计算器           | 呼出后，输入计算内容 |
| Mac 基本操作           | 呼出后，输入 shutdown、lock 等基本操作 |

<br>
不过仅仅借助这些基本用法，开发者就能够直接通过键盘快速打开程序 / 文件等，再也不需要用触控板 / 鼠标乱点一通了。

##iTerm

iTerm 是一款针对 Mac 用户打造的一款免费终端工具，可以说是 Mac 下最好用的终端工具，没有之一 。对于经常需要和命令行打交道的开发者来说，选一款好用的终端工具是必不可少的。

iTerm 对复制、打开等操作做了优化，开发者可以双击选中单词，三击选中整行，而一旦选中即复制到粘贴板。并且使用 commmand + 光标点击的方式，可打开文件、URL等，这些细节优化，大大减少了开发过程中多余的操作，从而加快日常开发效率。 

翻看 iTerm 的发布文档，其中，iTerm2 2.0 Released 的新特性中有这么一段话：

> Deep tmux integration. iTerm2 can speak directly to tmux and display its virtual windows as native windows or tabs, making tmux much easier to navigate.

也就是说新版的 iTerm 能和 tmux 进行深度集成，开发者可以更加舒适地使用 tmux 了。不过我还是不喜欢集成后的样式，所以并没有使用集成版本。但是直接在 iTerm 下使用 tmux ，会出现一些问题，比如 triggers 的功能异常（执行 clear 可以在一定程度上规避）、调整面板尺寸不方便等（因为 tmux 是重绘屏幕，所以会造成 [多次匹配的问题](https://groups.google.com/forum/#!topic/iterm2-discuss/pHpYJLTKHPQ)），想要了解集成版本的优势和使用方式，可以点击[这里](https://gitlab.com/gnachman/iterm2/wikis/TmuxIntegration)。

如果单独使用 iTerm 时（ tmux 的集成版本也可以），triggers 这个功能还是能在许多地方派上用场的。比如 ssh 连接远程服务时，可以触发 Open Password Manager 动作，直接选择密码；进行一些异步操作时，可以对执行成功的输出文本进行正则匹配，触发 Post Notification 动作。这个 triggers 有较强的定制性，可依个人业务和习惯进行设置。

就拿我自己最近的一个经历来说，因为项目组推进组件化，某些依赖多的工程执行 `pod update` 的时间会比较长，而我又不想每次切回来看更新是否完成。解决方法是，设置 iTerm triggers 匹配更新成功后的文本，并发送一个更新成功的通知，这样在更新 Pods 的那段时间，我就可以先去做后面的事情，等看到成功的通知，再回来处理相关任务。

下面继续列举一些个人比较常用的快捷键。

#####命令行字符操作快捷键：

| 功能           |    快捷键     |
| ------------- |:-------------:|
| 到行首           | ctrl + a |
| 到行尾           | ctrl + e |
| 前进后退           | ctrl + f/b <br> 会和tmux默认的prefix key冲突，基本不用|
| 前向/后向删除字符           | ctrl + d/h |
| 前向/后向删除单词           | ctrl + w/alt + d |
| 清除当前行/到行尾           | ctrl + u/k |
| 交换光标处文本           | ctrl + t |
| 上一条命令           | ctrl + p |
| 搜索历史命令           | ctrl + r <br> 后面默认会和fzf结合 |

<br>
需要留意的是，上面的快捷键不仅仅适用于 iTerm ，其中的绝大多数快捷键也可以在 mac 自带终端以及 Linux 的终端上使用。
<br>
#####功能操作快捷键：

| 功能           |    快捷键     |
| ------------- |:-------------:|
| 清屏           | command + r <br> 对tmux有干扰，基本不用 |
| 回放操作历史           | command + option + b |
| 剪切板历史      | command + shift + h |
| 查看历史命令     | command + ; |
| 搜索内容      | command + f <br> 输入内容后 + (tab / tab + shift = 前向 / 后向推移) <br> 内容会默认拷贝至剪切板 |
| 高亮光标位置     | command + / |
| 展开所有tab     | command + option + e |

<br>
#####分屏操作快捷键

由于后面会使用 tmux 进行分屏，所以这一部分基本不使用。不过如果使用 tmux 集成版本的话，这一部分的使用频率还是比较高的。

更多信息，可以查看  [iTerm 官方文档](https://www.iterm2.com/documentation.html)



##zsh

关于脚本解释器，即 shell ， Mac 提供了以下几种：

```
/bin/bash                                          
/bin/csh                                           
/bin/ksh                                           
/bin/sh                                            
/bin/tcsh                                          
/bin/zsh
```
Mac 默认的 shell 是 bash （ /bin/sh ），那么为什么不用系统默认的 bash，而用 zsh 呢？

主要是因为 zsh 强大的可定制性。即使还没对 zsh 进行配置，它也具备了一些非常实用的功能：

- 可以补全命令 / 路径 / 参数等，tab 可展示所有待选项，并可使用 tab / tab + shift / ctrl + f / ctrl + b / ctrl + n / ctrl + p 进行选择。（如果使用 tmux 默认的 prefix ， ctrl  + bb 才会发送 ctrl + b）
- 不需要输入 cd 跳转，直接输入路径即可。输入 d ，可列出访问过的目录，继续输入相应数字可进入目录。
- 根据前缀查找历史命令，比如输入 git ，按上方向键，查找的是所有用过的 git 命令，而不是全部命令。
- 还有别名，搜索等，更多内容可以查看 [Why zsh?](https://www-s.acm.illinois.edu/workshops/zsh/why.html)。

前面说了， zsh 最大的优势在于定制性强，那么配置起来会不会很复杂？关于这个，开源社区已经有现成的了－－ [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh) 。这个就不展开了， [wiki](https://github.com/robbyrussell/oh-my-zsh/wiki) 上写的非常详细。

#####安装方式

```
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
```

##autojump
autojump 是一个优化目录切换的命令行工具。上文说了，zsh 不仅缩减了 cd 命令，而且优化了切换目录时的体验，那么我还要 autojump 干什么呢？

答案是 autojump 可以用一行命令直达目标，而不需要开发者频繁地敲击 tab 来补全路径。 autojump 会以某种方式纪录使用者访问过的目录的次数，并以次数为基准进行跳转，次数越多的优先级越高。

下面是 autojump 的一些基本用法：

| 功能           |    快捷键     |
| ------------- |:-------------:|
| 跳往目录           | j + 部分目录名 |
| 跳往目录（子目录优先）           | jc + 部分目录名 |
| 在Finder中打开目录      | jo + 目录部分字母 |
| 在Finder中打开目录（子目录优先）    | jco + 部分目录名 |
| 增加当前目录权重    | j -i + 增加数值 |
| 减少当前目录权重    | j -d + 减少数值 |
| 查看所有目录权重    | j -s |
| 移除不存在目录    | j --purge |
| 增加目录    | j -a + 目录路径 |

<br>
更多信息，可以使用万能的 `--help` 查看。

#####安装方式

```
brew install autojump

// .zshrc 中添加以下内容
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
```



##tmux
对于 tmux (terminal multiplexer) ，其自身的 man 手册是这么描述的：

> tmux is a terminal multiplexer: it enables a number of terminals to be created,
     accessed, and controlled from a single screen.  tmux may be detached from a
     screen and continue running in the background, then later reattached.


也就是说 tmux 是一个终端复用工具，它允许在一个物理窗口上运行多个终端会话，所以多用于远程登录时保留操作现场，不过个人也比较喜欢在 Mac Pro 开发机上使用。下面是使用 tmux 后呈现的基本界面：

![](/images/Snip20170329_6.png)

如上图所示，tmux 主要由三种元素构成： session、window、pane。它们之间是从属关系，也就是说 session 可以包含多个 window， window 可以包含多个 pane ，而最终展示在交互界面上可供操作的窗口，其实都是 pane 。

需要注意的是，我在 Mac mini 和 Mac Pro 上都安装了 tmux ，之所以上图底部有两条 bar （对应 work session 和 macmini session），是因为我通过 ssh 远程登录了 Mac mini 并开启了 Mac mini 的 tmux ，上方三个可见的 pane 展示的信息都属于 Mac mini 。

### tmux 常用操作

在开始之前，说明下本人的 tmux 采用的是 [gpakosz 分享的配置文件](https://github.com/gpakosz/.tmux)，并且 tmux 的所有快捷键操作都需要先执行 'C-b' ， 即 CTRL + b。如果在上图的场景下，需要通过快捷键操控 Mac mini 的 pane，那么就按两次 'C-b' 。
<br>

##### Session



> In tmux, a session is displayed on screen by a client and all sessions are
     managed by a single server.  The server and each client are separate pro-
     cesses which communicate through a socket in /tmp.



| 功能           |    快捷键     |
| ------------- |:-------------:|
| 查看当前所有会话           | s <br> tmux list-sessions <br> 方向键 + 回车 进行选择切换 |
| 分离当前会话           | d <br> tmux detach |
| 重命名当前会话      | $ <br> tmux rename-session -t |

<br>
##### Window
| 功能           |    快捷键     |
| ------------- |:-------------:|
| 创建窗口           | c <br> tmux select-window -t |
| 切换到特定窗口           | 数字 <br> tmux select-window -t |
| 关闭当前窗口           | & <br> tmux kill-window -t |
| 列出所有窗口           | w <br> tmux list-windows |
| 重命名当前窗口           | , <br> tmux rename-window -t |

<br>
##### Pane
| 功能           |    快捷键     |
| ------------- |:-------------:|
| 垂直/水平分隔窗格           | % / " <br> tmux split-window -h/v |
| 关闭窗格           | x <br> tmux kill-pane -t |
| 选中特定窗格      | q <br> 出现数字后 + 数字 |
| 切换窗格      | h/j/k/l <br> tmux select-pane -t |
| 交换当前窗格位置      | { / } |
| 分离当前窗格到窗口     | + |

<br>
#####其他操作
| 功能           |    快捷键     |
| ------------- |:-------------:|
| 显示所有快捷键          | ? |
| 加载配置文件      | r |
|   显示所有命令         |  tmux list-commands |
| 清除所有tmux元素并退出      | tmux kill-server |
| 接入已开启的会话      | tmux attach <br> 远程登录恢复环境就靠它了 |


<br>
更多命令可以查看 tmux 的 man 手册。

### tmux 配置文件

[gpakosz 分享的配置文件](https://github.com/gpakosz/.tmux)  默认是没有开启 vi 模式的，需要在 .tmux.conf.local 中打开以下配置开启：

```
set -g mode-keys vi
```

因为我默认使用 zsh，所以继续添加以下配置，以便让新增窗格的 shell 都是 zsh 而不是 sh：

```
set-option -g default-shell /bin/zsh
```

tmux 在默认情况下复制的内容是不会进入系统剪切板的，也就是不能粘贴到任意位置，所以需要安装 reattach-to-user-namespace :

```
brew install reattach-to-user-namespace
```
然后在 .tmux.conf.local 中新增以下配置：

```
bind-key -t vi-copy y copy-pipe "reattach-to-user-namespace pbcopy"
bind-key -t vi-copy Enter copy-pipe "reattach-to-user-namespace pbcopy"
```

### tmux 插件管理器

tmux 还有专门的 [插件管理器](https://github.com/tmux-plugins/tpm.git) ，可以更加简便地配置附加功能。比如 tmux 在关机之后就无法通过 tmux attach 恢复关机前的环境了，需要编写脚本进行恢复，而这个需求可以通过安装现成的 [tmux resurrect](https://github.com/tmux-plugins/tmux-resurrect) 插件实现。

#####安装方式
tmux:

```
brew install tmux
```
.tmux:

```
cd
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .
```


##fzf



[fzf](https://github.com/junegunn/fzf)

##vimium

##shiftlt

##snap

##参考文章

[Tmux - Linux从业者必备利器](http://cenalulu.github.io/linux/tmux/)<br>
[A tmux crash course tips and tweaks](http://tangosource.com/blog/a-tmux-crash-course-tips-and-tweaks/)