---
title: CocoaPods 二进制化插件
tags:
---

> 是否需要切换单个组件的依赖方式 ？

1. N，个人认为，最简单的方式为创建两个 source ，分别保存源码和二进制 specification 。当需要切换全部组件的依赖方式时，直接更改 source（或切换 source 顺序）即可。同理 lint 时也可以通过 --sources options，指定使用何种依赖方式进行 lint。
2. Y，需要切换的情况下，需要考虑的情况就比较多了


