### #import<>和@import

[@import vs #import - iOS 7](https://stackoverflow.com/questions/18947516/import-vs-import-ios-7) 和 [Advances in Objective-C](<https://developer.apple.com/videos/play/wwdc2013/404/>) 中对 `@import`  有比较详细的说明。

**`@import` 主要是使用 module 的方式引用库，并且可以自动添加引用的库，不需要手动添加。**

这里结合 `pod lib lint` 过程中遇到的未定义类问题，说明下 `#import<>` 与 `@import` 的转换。

首先我们需要知道的是，预编译 `.m` 文件时，编译器会将 `.m` 文件中对 `.h` 的引用替换成头文件实际的内容，如果只有 `.h` 文件没有 `.m`，那么编译动作默认是不会发生的，`.h` 更多的是被 `.m` 引用而不是作为一个独立的编译单元（参考 [Do I need to compile the header files in a C program?](https://stackoverflow.com/questions/17416719/do-i-need-to-compile-the-header-files-in-a-c-program)）。

假设有组件 TDFCore ，它的内容如下：

```objective-c
// TDFCore.h
#import <AVKit/AVKit.h>

// TDFCore.m
#import "TDFCore.h"
void player() {
    [AVPlayer new];
}
```

即使我们没有在 podspec 中显式指明依赖 `s.dependency 'AVKit'` ，TDFCore 的源码 lint 也会成功，因为在编译 `TDFCore.m` 时，我们可以知道引入了 `#import <AVKit/AVKit.h>` ，并且会被自动映射为 `@import AVKit;` ，根据上文的介绍，AVKit 库会被自动添加，所以链接时不会报 AVPlayer 未定义。

但是当我们将 TDFCore 打包成 .framework / .a 时，不指明 `s.dependency 'AVKit'` 就会报 AVPlayer 未定义错误，即使  `source_files` 中指定了 `TDFCore.h` ，此组件还是不会执行编译，也就不会用到 `TDFCore.h`，不知道 `#import <AVKit/AVKit.h>` ，最终导致 AVKit 库不会被自动添加，链接失败。

