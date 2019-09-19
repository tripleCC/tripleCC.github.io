加载过程在内核部分负责新进程的基本设置——分配虚拟内存，创建主线程，以及处理任何可能的代码签名/加密工作。然而对于动态链接的可执行文件来说（大部分可执行文件都是动态链接的），真正的库加载和符号解析的工作都是通过 LC_LOAD_DYLINKER 命令指定的动态链接器在用户态完成的。控制权会转交给链接器，链接器进而接着处理文件头中的其他加载命令。



简单来说，链接器的工作就是解析未定义的符号引用，将目标文件中的占位符替换为符号地址。链接器还要完成程序中各目标文件的地址空间组织，这可能涉及到重定位工作。[wiki]([https://zh.wikipedia.org/wiki/%E9%93%BE%E6%8E%A5%E5%99%A8](https://zh.wikipedia.org/wiki/链接器))



LC_LAZY_LOAD_DYLIB，和 LC_LOAD_DYLIB 功能一样，但是将实际的加载工作延迟到第一次使用这个库中的符号时。（ld 的 -lazy_framework ？）



如果二进制文件中使用了外部定义的函数和符号，那么在他们的文本段中会有一个名为`__stubs`（桩）的区，在在这个区中存放的是这些本地未定义符号的占位符。编译器生成代码时会创建对符号桩区的调用，链接器在运行时会解决对桩的这些调用。链接器解决的方法是在被调用的地址处放置一条 JMP 指令。 JMP 指令将控制权转交给真实的函数体，但是不会以任何方式修改栈。因此，真实的函数可以正常返回，就好像直接调用一样。



dyld 的函数拦截（function interposing） 需要在动态库中编写拦截代码才有效，然后利用 dyld 动态注入到可执行文件中。直接在可执行文件中编写拦截代码，则无效。主要关注 `__DATA` 段的 `__interpose`  节。

```c

/*
 *  Example:
 *
 *  static
 *  int
 *  my_open(const char* path, int flags, mode_t mode)
 *  {
 *    int value;
 *    // do stuff before open (including changing the arguments)
 *    value = open(path, flags, mode);
 *    // do stuff after open (including changing the return value(s))
 *    return value;
 *  }
 *  DYLD_INTERPOSE(my_open, open)
 */

#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
            __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };
```





如果能想到在 i-设备上没有交换空间，那么这种很低的限制（进程可用内存空间）就很容易理解了。交换空间和闪存不能很好地匹配，因为前者需要大量的写删除操作，而后者则对这种操作有限制。因此，在使用基于硬盘的交换空间上不会有问题（出了性能损失），在移动设备上却不能使用交换空间。



`__PAGEZERO`:在32位的系统中，这是内存中单独的一个页面（4kb），而且这个页面所有的访问权限都被撤销了。在64位系统上，这个段对应了一个完整的32位地址空间——即千4GB。这个段有助于捕捉空指针饮用（因为空指针实际上就是0），或捕捉将整数当作指针饮用。由于这个范围内所有访问权限——读写执行，都被撤销了所以在这个范围内的任何解引用都会引发来自MMU的硬件页错误，进而产生一个内核可以捕捉的陷阱。内核将这个陷阱转换为C++异常或表示总线错误的POSIX信号（SIGBUS）。





