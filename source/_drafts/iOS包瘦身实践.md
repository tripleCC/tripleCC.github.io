---
title: iOS包瘦身实践
tags:
---


20% -> 80% 大小

监控
防劣化

下线无用 AB 
- 不仅仅是 AB 判断的逻辑
- 还要包括逻辑引入的关联代码、资源

## 测量

- 安装大小
- 下载大小

- 本地
- app slice

- 二进制文件加密

- ipa 自行压缩的内容（文本）

## 资源

### 压缩

### 上 CDN

### WebP

- 资源引用问题
	- json
	- oc 代码
		- pathForResource:
		- imageNamed:

- 转换脚本
	- imageset

- 如何正确使用 webp，倍屏问题

### 无用资源

- 脚本扫描
	- 白名单

### 重复资源

## MachO

### 符号裁剪

- debug
- non global
- all

### 限制导出符号
- exported symbols file

- dead code

### 限制 Exception

- objc
- c++

<!-- ####  -->

### 无用类

- 扫描方式
	- 可执行文件扫描

### 无用方法

## 监控

### MR 准入

- base commit 包 对比分支 commit 包
- 增量分析
- 定期全量分析

- 包大小业务线追责，根据 mr 合入作者确定业务线，定期做统计，预先规定增长量

### ipa 包分析

- 压缩比
- car 解压分析
	- assetsutil
	- sudo xcrun --sdk iphoneos assetutil --idiom phone --subtype 570 --scale 3 --display-gamut srgb --graphicsclass MTL2,2 --graphicsclassfallbacks MTL1,2:GLES2,0 --memory 1 --hostedidioms car,watch xxx/Assets.car -o xxx/thinning_assets.car
	- fastlane thinning , xcodebuild -exportArchive 输出特定设备 ipa （os 版本 + 设备类型 -> 实际 ipa 大小，确定了设备类型，还是会生成多个 os 版本的 ipa ，可以取最小的）

### LinkMap

- 获取信息


## 其他

关于 `-Oz` ，[On Optimization Flags](http://events17.linuxfoundation.org/sites/events/files/slides/GCC%252FClang%20Optimizations%20for%20Embedded%20Linux.pdf) 显示这个参数会禁止 loop vectorization ，而 [Auto-Vectorization in LLVM](https://llvm.org/docs/Vectorizers.html) 显示，开启 vectorization 的性能明显比未开启高 3 倍以上。关于什么是 [Automatic vectorization](https://en.wikipedia.org/wiki/Automatic_vectorization) 。

关于 `--gc-sections`，[xcode 不支持这个链接选项](https://stackoverflow.com/questions/24734409/make-error-in-mac-clang-ld-unknown-option-gc-sections)，替代选项为 `-dead_strip`。

## 参考

[Reducing the size of my App](https://developer.apple.com/library/archive/qa/qa1795/_index.html)

[Code Size Performance Guidelines](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/CompilerOptions.html)