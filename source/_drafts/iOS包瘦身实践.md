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
32 位图片转 8 位图

- 8 位 -> 2 ^ 8 颜色
- 32 位 -> 2 ^ 24 颜色 + Alpha透明度 (真彩色)

tiny png

原图32位PNG - 新8位PNG ，压缩后尺寸减少较多；原图非32PNG 如8位PNG、4位、2位PNG ，压缩后尺寸变化不大.   负面效果：对渐变PNG不友好，原图32位PNG渐变图转为8位PNG后，色域减少，部分PNG放大2-3倍后会出现失真情况，主要梯度很明显. 


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

### 字符串

`__FILE__` => `__FILE_NAME__`

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
		- macho objc 元数据 section 取差集

- 线上检测方式
	- 判断对象的 initialized flag
	- 进入后台，异步扫描所有 image

### 无用方法

### `__text` section 重命名

`__TEXT __text` section 移动到 `__RODATA __text` ，减少 iOS 12 及以下系统下载大小，保持加密前大小

重命名大小限制 128M，需拆若干个小的 framework


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
	- 雪碧图合并问题，无法统计具体文件大小
		- iOS9 之后才支持雪碧图，配制对资源文件的编译版本改成 iOS8
### LinkMap

- 获取信息

## 其他

- lto
	- 关于 `-Oz` ，[On Optimization Flags](http://events17.linuxfoundation.org/sites/events/files/slides/GCC%252FClang%20Optimizations%20for%20Embedded%20Linux.pdf) 显示这个参数会禁止 loop vectorization ，而 [Auto-Vectorization in LLVM](https://llvm.org/docs/Vectorizers.html) 显示，开启 vectorization 的性能明显比未开启高 3 倍以上。关于什么是 [Automatic vectorization](https://en.wikipedia.org/wiki/Automatic_vectorization) 。

关于 `--gc-sections`，[xcode 不支持这个链接选项](https://stackoverflow.com/questions/24734409/make-error-in-mac-clang-ld-unknown-option-gc-sections)，替代选项为 `-dead_strip`。

- llvm-strip
    - 最终可执行文件中， symbol table 的内容是无用的，rebase/binding，导出符号等信息，都在 Dynamic Loader Info 中，symbol table 的符号都是给静态链接器使用的，所以最终生成产物后，就可以 strip 掉
		- Dynamic Loader Info 中的数据，基本都会有一个需要修改的地址 + 符号名 (后者可以通过 string table 的 index 表示)
		- 所以其和 symbol table 是相互独立的，即使去除掉 symbol table，也不会影响 dyld 加载时的处理
	- 目前已知 `_OBJC_` 的 UNDEF 符号去除不影响实际加载
		- 非 `_OBJC_` 的 UNDEF，包括 lazy、non-lazy 的符号指针对应的 symbol table / indirect symbol 内容是否可以去除，待考证（需要看 dyld 代码）【如果只是做binding，Dynamic Loader Info 里提供的内容已经足够了】
		- 如果没有在 ld64 做处理，需要对最终产物进行重签名

## 参考

[Reducing the size of my App](https://developer.apple.com/library/archive/qa/qa1795/_index.html)

[Code Size Performance Guidelines](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/CompilerOptions.html)