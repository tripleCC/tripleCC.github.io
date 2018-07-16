---
layout: post
title: "Git开发流程"
date: 2015-11-05 18:44:59 +0800
comments: true
categories: git
---
## 使用Git开发总结

现在很多互联网公司都是通过分布式的Git进行代码管理，SVN则逐渐被淘汰了。以下就是自己在Git开发中的流程与注意点：<br>
1、所有人fork一份 project, 在自己的repository上开发，开发完成后向 project 提 pull request.

2、如果遇到需要多人共同开发的比较大的项目，可以细分为个人完成的小项目，在各自 repository 上完成后 pull request.

3、尽量保持每天至少 pull request 一次。如果功能一天不能完成，则每天抓取 project最新的版本 merge 并解决冲突，保证每次最终 pull request 的冲突减到最少。

4、尽量保证提交前能看一遍每行改动 (如果使用 SourceTree, 可以看到对于每一行的改动，并选择是否提交/回滚这行的改动)，确保每行都是必要的。

5、另外，iOS 项目中有一些 .gitignore 也无法忽略的文件，比如 project.pbxproj 和 *.xcodecheckout，需要每次手动来忽略其中的改动，务必确保这些文件内所有改动的行都是必要的，除非特殊情况不要提交其中的 PROVISIONING_PROFILE 和 Build Settings 相关的改动。
<!--more-->

## 默认工作流程

- 把 project fork 一份到 yourname/project,并clone到本地

	```
	cd ~/git/
	git clone https://github.com/yourname/project.git
	```
	保持代码是和主线同步的，假设主线名称为main

	```
	git remote add upstream https://github.com/main/matcha-ios.git
	git checkout master
	git fetch upstream 
	git merge upstream/master
	```

	在项目目录新建一个 .gitignore 来忽略一些不该提交的东西 [gitignore参考](https://github.com/github/gitignore.git)

- 提交一次修改

	```
	git add new.m git add new.h
	git diff
	git commit -m ‘add Class new’
	```
	```
	git push origin
	```
- 解决可能有的冲突：

	务必在这个阶段解决各种可能的冲突，减少 pull request merge 到 main/project 时的成本。SourceTree 的处理过程也是类似的。(这里命令行可以执行 git mergetool 来调用冲突处理工具来处理，用 SourceTree 可以直接打开 Xcode 自带的冲突处理工具处理)

	```
	git checkout master
	git fetch upstream && git merge upstream/master
	```
	```
	// 解决冲突后
	git commit -m "XXXX"
	git push origin
	```
- 提交Pull Request

	最后你需要做的，就是打开 https://github.com/yourname/project ，提交一个Pull Request，并assign给某人帮你review.Pull Request的名称尽量取的有意义，比如`优化cell性能`等词语

## Git学习资料

基本操作和概念： Try Git： http://try.github.com/
图解Git 了解Git的一些特性：http://marklodato.github.com/visual-git-guide/index-zh-cn.html
[推荐]一堆实用技巧，让你爱上命令行： http://blog.jobbole.com/25808/

## Git操作备忘

```
git diff <branch1> <branch2> -- <file> 比较不同分支同一个文件
git push origin :refs/tags/<tagname> 删除远程tag
```

## Git关于rebase资料
(可以保持History的整洁，把新的修改作为标签打入要合并的commit, 么有merge from xxxx记录)

注意：

```
在git push之前，先git fetch，再git rebase。(一定要先rebase再push！)

git fetch origin master
git rebase origin/master
git push

等价：
git pull --rebase
```

[团队开发里频繁使用 git rebase 来保持树的整洁好吗?](https://segmentfault.com/q/1010000000430041)

[Git-分支-分支的衍合](https://git-scm.com/book/zh/v1/Git-分支-分支的衍合)

## 找回commit
rebase掉的commit通过以下方式找回：

- 进入**.git/logs/refs/heads/**，打开对应分支文件，查看提交记录。

- 获得所要提交记录的sha1

- 根据sha1，新开一个分支

```

git checkout -b branch-recovery sha1

```

这样这个branch-recovery就有所有提交记录了。
