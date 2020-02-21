## iOS 热更新

> 核心点：**使用什么方式执行下发的更新逻辑，更新逻辑所处运行环境如何和 native 端交互**

目前针对 iOS 应用的动态修复大致有四种方案：

1. 使用率最高的JSPatch/wax/rollout是先把OC手动翻译成脚本语言，通过服务端下发后，在运行时阶段利用OC的动态特性去调用和替换OC方法，实现实时修复bug。
2. 游戏客户端开发中常用的通过服务端下发lua脚本，动态执行并调用游戏引擎提供的函数。这种与ReactNative、Weex以及微信小程序类似，只能执行引擎（框架）已经封装的函数，并不能动态调用到iOS系统的任意API。
3. 滴滴的DynamicCocoa是从编译阶段入手，通过Clang把OC代码编译成自己定制的JS格式，再动态下发去执行，做到直接用原生OC编写补丁代码，动态运行，主打动态添加功能。
4. 手机QQ的OCS是定义了一套描述OC语义的字节码指令集(OCScript)，开发了一套基于Clang的全自动编译器（OCSCompiler），实现了一个高性能的虚拟机（OCSVM）以及一个可以跟底层对接的桥接器(OCSBridge)。首先使用OCS编译器把OC源码转化成OCS字节码，然后通过OCS桥接器实现OCS虚拟机与Native运行时的互联，最后使用OCS虚拟机对OCS字节码进行解释运算，并驱动Native运行时完成逻辑的执行，以此达到Native代码动态化的效果。

执行端：

- 脚本语言: lua / js + 脚本对应的 vm
  - lua 执行需要外部集成 luavm 提供运行环境
  - js 执行由内部 JavaScriptCore.framework 提供运行环境
- bitcode + llvm 中的 vm
- 自定义字节码指令集 + vm
  - QQ 的 OCScript + OCSVM

发布端：

- 直接写中间语言，这里一般指脚本文件
  - 最常见的 JSPatch / WaxPatch 等 ，开发者直接写脚本文件
- 直接写 OC 代码，自定义 clang 编译器，将 OC 转换成中间语言，这里的中间语言可以是脚本语言、bitcode、或者自定义字节码指令集
  - 滴滴的 DynamicCocoa 自定义编译器将 OC 转换为 JS / bitcode 
  - QQ 基于 clang 开发了 OCSCompiler 将 OC 转换为自定义的字节码指令集(OCScript)



发布端直接写中间语言存在一个问题：

- 如果某个方法其中的一行存在 bug 需要改动，那么开发人员需要手动将此方法翻译成中间语言，然后在这个中间语言表示的方法中去改这一行代码，这一翻译的过程是比较费力的，要通过两种不同语言的两段代码表示同一逻辑，可能因为语义的细微差别，执行起来并没有那么方便直观。比如：

  ```lua
  // OC
  1 / 2 => 0
  
  // js
  1 / 2 => 0.5
  
  // lua
  1 / 2 => 0.5
  ```




[关于iOS热修复（HotPatch）技术的使用总结](https://www.bbsmax.com/A/rV57129zPD/)



[JSPatch 实现原理详解](https://github.com/bang590/JSPatch/wiki/JSPatch-%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86%E8%AF%A6%E8%A7%A3)

[OCS ——史上最疯狂的 iOS 动态化方案](https://www.jianshu.com/p/0f99d106d93a)

[iOS/flutter动态化杂谈](https://segmentfault.com/a/1190000021331416)

[轻量级低风险 iOS Hotfix 方案](https://limboy.me/tech/2018/03/04/ios-lightweight-hotfix.html?hmsr=toutiao.io&utm_medium=toutiao.io&utm_source=toutiao.io)

[滴滴 iOS 动态化方案 DynamicCocoa 的诞生与起航](http://www.cocoachina.com/articles/18400)

### iOS 不支持 JIT

> 3.3.2 An Application may not download or install executable code. Interpreted code may only be used in an Application if all scripts, code and interpreters are packaged in the Application and not downloaded. The only exception to the foregoing is scripts and code downloaded and run by Apple's built-in WebKit framework.

iOS 禁止了开发者应用中堆的执行权限，所以在堆中的机器码无法运行，也就无法实现 JIT

[Is JavaScriptCore framework on iOS 7 using JIT compilation?](https://stackoverflow.com/questions/22281265/is-javascriptcore-framework-on-ios-7-using-jit-compilation)

iOS 不支持 JavaScriptCore 的 JIT模式，只有指定的 App 或服务才允许使用 JIT 模式，比如 MobileSafari.app, Web.app 等，WKWebView （在独立进程中运行）允许使用 JIT ，所以会比 UIWebView 以及直接使用 JSContext 快。

### wax

调用 env

```lua
waxClass{"C"} 

-- class 是 c 类 cu
-- class[key] or (_G[key] or wax.class[key])
function viewDidLoad(self)

	-- class[key] or (_G[key] or wax.class[key])
	print("viewDidLoad")
	
	-- self 是 c 实例 iu
	-- self[key] 
  self:ORIGviewDidLoad()
end

-- 这里如果 C 实现了 print 类方法，上面的 print 就不会调用 _G 里面的 print，而是调用 C 类方法 print
```

userdata 对应类 / 实例

```lua
env
	-> 方法操作的环境，用来记录额外的操作信息，如替换的方法对应的 lua 回调
metatable
	-> 元表，用来接管 lua 对类 / 实例的进行操作，如 self:viewDidiLoad()，会把索引信息 viewDidLoad 传给注册的 __index 函数（注意是索引信息，native 不能直接执行，不然 lua 层无法执行，而是要通过返回 cclosure 来让 lua 层执行调用，再在 cclosure 实体里面设置返回给 lua 的结果，closure 实体通过 upvalue 获取参数）; function viewDidLoad() end，会把索引信息 viewDidLoad 传给注册的 __newindex 函数 
```

native 层根据类 / 实例访问 userdata

```lua
__wax_userdata 
	-> 为了能通过类/实例索引到对应的 userdata，需要在全局有一份表，以类/实例地址为 key，userdata 地址为 value，并且这个表对 value 需要是 weak 的
	-> 在 wax.instance 元表下创建了 __wax_userdata 表，并且设置自身为元表，设置 __mode 字段标志为 v （value weak）
```

构造类操作环境

```lua
waxClass{"C"} 
	-> wax.class("C")
		-> 1 触发 class 表的 __call 构建 class userdata (cu) 并返回
		-> 2 创建元表，设为调用者 env , 用来触发对 cu 的操作
			—> 2.1 元表 __newindex 用来触发 cu 的 __newindex 函数 (对应一个 C 函数)，构建方法操作环境时使用
			—> 2.2 元表 __index 用来触发 cu 的 __index 函数 (对应一个 C 函数)，索引类方法?/类时使用，如果为 nil , 则继续访问 _G 及其元表，后者的 __index 会触发 wax.class[name] , 触发 class 表的 __index , 查找构建 cu
```

原生方法的替换与回调

```lua
waxClass{"C"} 
function viewDidLoad(self)
  self:ORIGviewDidLoad()
end

接上述 2.1
	-> 1 触发 cu 的 __newindex 回调, 获取 cu + 方法名 + lua 回调(lua 重写的方法实体)
	-> 2 根据 1 信息替换 forwardInvocation，将方法名和 lua 回调保存在 cu 的 env 中 (native 触发后需要调用回调)
	-> 3 native 方法被触发，走到 forwardInvocation，创建 instance userdata (iu) (或者根据对象从 __wax_userdata 表里面拿 iu)，获取 iu 对应的 env ，根据方法名从 env 中拿 lua 回调，压入参数后调用，iu 需要作为第一个参数，成为 lua 函数中的 self
	-> 4 self:ORIGviewDidLoad() 会把索引信息 viewDidLoad 传给注册的 __index 函数，在函数中返回 cclosure 来让 lua 层执行调用，通过在 cclosure 实体里面设置 lua 调用的返回结果
```



### Lua

lua 有块级作用域，js 只有函数级作用域，所以 lua 的闭包接近 oc 的 block

[Lua 在移动平台上的应用](https://www.ibm.com/developerworks/cn/opensource/os-cn-LUAScript/index.html)

[Lua C API 的正确用法](https://blog.codingnow.com/2015/05/lua_c_api.html)

[Lua 虚拟机的封装](https://blog.codingnow.com/2018/08/luavm_bootstrap.html)

[Lua 中写 C 扩展库时用到的一些技巧](https://blog.codingnow.com/2006/11/lua_c.html)

[Lua二进制chunk](https://www.jianshu.com/p/28589560d41f)



[Lua 5.3 Reference Manual](http://www.lua.org/manual/5.3/manual.html) (注意 C API 是否会抛出异常)

[lua 5.0 实现](https://www.codingnow.com/2000/download/The Implementation of Lua5.0.pdf)

[从零开始实现 Lua 虚拟机 ( UniLua 开发过程 )](https://zhuanlan.zhihu.com/p/22476315)

[Lua 和各种语言的对比](http://lua-users.org/wiki/LuaComparison)



[深入理解Lua与C数据通信的栈](https://blog.csdn.net/MaximusZhou/article/details/21331819)

[Lua中的全局变量与环境](http://www.qlee.in/openresty/2017/03/13/lua-global-variable-environment/)

[Lua中的weak表——weak table](https://www.cnblogs.com/sifenkesi/p/3850760.html)

[Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/manual.html#lua_rawget)

[Lua 5.1 手册中文](https://www.codingnow.com/2000/download/lua_manual.html)

[Lua 5.3 参考手册](https://cloudwu.github.io/lua53doc/manual.html)

[Lua Userdata 的元表 (Metatable)](https://blog.csdn.net/Kiritow/article/details/85012879)

[Lua中的userdata](https://blog.csdn.net/Adam040606/article/details/56484488)

[为 lua 封装 C 对象的生存期管理问题](https://blog.codingnow.com/2009/03/lua_c_wrapper.html)

[向 lua 虚拟机传递信息](https://blog.codingnow.com/2006/01/_lua.html)

[去掉 full userdata 的 GC 元方法](https://blog.codingnow.com/2013/08/full_userdata_gc.html)

[Lua 与 C 交互之UserData（4）](https://www.cnblogs.com/zsb517/p/6420885.html)



[MMPatch基础用法](https://mln.immomo.com/zh-cn/docs/MMPatch基础用法.html)

[CeleDev Lua 开发 iOS 应用框架](https://www.celedev.com/en/documentation/doc/celedev-object-framework/)

### LuaJIT

[用好Lua+Unity，让性能飞起来—LuaJIT性能坑详解](https://blog.uwa4d.com/archives/usparkle_luajit.html)

[FFI Library](http://luajit.org/ext_ffi.html)

[FFI](https://moonbingbing.gitbooks.io/openresty-best-practices/content/lua/FFI.html)

[LuaJIT FFI 介绍，及其在 OpenResty 中的应用](https://segmentfault.com/a/1190000015802547)

### Lua DSL

[Writing a DSL in Lua](https://leafo.net/guides/dsl-in-lua.html)

### LLVM 动态执行 bitcode

[LLVM Bitcode File Format](https://llvm.org/docs/BitCodeFormat.html#abstract)

[lli - directly execute programs from LLVM bitcode](https://llvm.org/docs/CommandGuide/lli.html)

[an LLVM bitcode interpreter on the Graal VM with Matthias Grimmer ](https://www.youtube.com/watch?v=yyDD_KRdQQU)



### libffi

[libffi 文档](https://github.com/libffi/libffi)

[Stinger是一个实现Objective-C AOP功能的库](https://github.com/eleme/Stinger)

[Hook方法的新姿势--Stinger (使用libffi实现AOP )](https://juejin.im/post/5a600d20518825732c539622)

[如何动态调用 C 函数](http://blog.cnbang.net/tech/3219/)

### 字节码虚拟机相关

[Java为什么解释执行时不直接解释源码？](https://www.zhihu.com/question/34345694/answer/59407625)

[为什么大多数解释器都将AST转化成字节码再用虚拟机执行，而不是直接解释AST？](https://www.zhihu.com/question/29126804/answer/43274994)

[虚拟机随谈（一）：解释器，树遍历解释器，基于栈与基于寄存器，大杂烩](http://iteye.com/blog/rednaxelafx-492667)



### Unity 相关(主要看在 iOS 平台上热更的思路)

[热更新大乱斗，腾讯正式开源面向Unity项目的Bug修复神器InjectFix](https://www.ithome.com/0/444/969.htm)

[ILRuntime项目为基于C#的平台（例如Unity）提供了一个`纯C#实现`，`快速`、`方便`且`可靠`的IL运行时，使得能够在不支持JIT的硬件环境（如iOS）能够实现代码的热更新](https://ourpalm.github.io/ILRuntime/public/v1/guide/index.html)

[InjectFix Unity代码逻辑热修复](https://github.com/Tencent/InjectFix)

[IL是什么，它又不是什么？那么汇编呢？](http://blog.zhaojie.me/2009/06/my-view-of-il-1-il-and-asm.html)

