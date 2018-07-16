---
layout: post
title: "Octopress因为Ruby版本出现push不生效问题"
date: 2015-11-01 15:51:24 +0800
comments: true
categories: blog
---
使用Octopress提交改的博客配置，但是发现配置并没有生效，然后本地预览也报以下错误：

```
Errno::ENOENT: No Such File or Directory - Jekyll 
```
上网搜了下资料，已经有人遇到过了[Errno::ENOENT: No Such File or Directory - Jekyll ~ Octopress and El Capitan](http://schalkneethling.github.io/blog/2015/10/16/errno-enoent-no-such-file-or-directory-jekyll-octopress-el-capitan/)

原因是OS-X升级到10.11，需要的ruby版本已经不是2.0.0了。执行`ruby -v`查看ruby版本：

```
tripleCC:~ songruiwang$ ruby -v
ruby 2.0.0p645 (2015-04-13 revision 50299) [universal.x86_64-darwin15]
```
下载2.2.3即可以解决问题。
<!--more-->
总体的步骤如下：<br>

```
// 下载homebrow
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
// 下载rbenv
brew update
brew install rbenv ruby-build
// 下载ruby2.2.3版本
rbenv install 2.2.3
```

然后参考的博客中执行以下命令

```
// 在Octopress的根目录下执行，会生成.ruby-version 
rbenv local 2.2.3
// 然后查看ruby版本
ruby --version
```
这里我显示的还是2.0.0，但是博客作者就直接显示2.2.3了。可能是更新的ruby没有直接替换掉原来的ruby版本。我进入ruby的安装目录看下，的确还是2.0.0版本。<br>

最后我就修改了`.bash_profile `（没有的话需要创建，MAC系统本来时没有这个文件的，Linux本身就有），直接指定下载的ruby版本可执行文件路径:

```
PATH=/Users/songruiwang/.rbenv/versions/2.2.3/bin:$PATH  
```
把下载的ruby执行路径放在系统环境变量之前，这样执行对应命令时，就会先去指定的目录中查找bin文件了，而不是系统老的ruby版本。<br>
接下来执行以下命令：

```
gem install bundler
rbenv rehash
bundle install
```
我在执行上面命令时，还出现了一个错误，改一下Gemfile的source即可：

```
// http改成https了
source "http://ruby.taobao.org" =>
source "https://ruby.taobao.org"
```
然后就可以正常使用博客了。

