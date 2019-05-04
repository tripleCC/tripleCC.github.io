### autorelease 对象什么时候释放

根据**是否为手动创建的自动释放池**，分以下两种情况：

- 在主线程 RunLoop 即将进入休眠以及即将退出 RunLoop 时释放
  - 主线程在 App 启动后，在主线程 RunLoop 中注册了两个 Observer，一个监听**准备进入 RunLoop** ，在回调中创建自动释放池；一个监听**即将进入休眠和即将退出 RunLoop** ，在即将进入休眠时，释放旧池创建新池，在即将退出 RunLoop 时，释放旧池
- 在 @autoreleasepool 作用域结束时释放



### 自动释放池 @autoreleasepool

编译器利用**局部变量以及类的构造析构函数特性**实现 @autoreleasepool 。

在构造函数中调用 objc_autoreleasePoolPush ，在析构函数中调用 objc_autoreleasePoolPop 。

AutoreleasePool 并没有单独的结构，而是以**若干个 AutoreleasePoolPage 以双向链表**的形式组合而成，**双向链表的访问入口保存在 TLS （线程局部存储中）**。当新建 AutoreleasePool 时，会向 AutoreleasePoolPage push 一个哨兵对象，并在释放 AutoreleasePool 以这个哨兵对象为参照点，释放顺序和栈结构一致，先入后出。

每个 AutoreleasePoolPage 节点占用 4096 字节内存（一页虚拟内存大小），除了 AutoreleasePoolPage 对象实际占用的空间外，剩余空间全部用来保存 autorelease 对象地址。当一个 AutoreleasePoolPage 节点已满时，会新建一个 AutoreleasePoolPage 节点，并将 autorelease 对象地址加入新的节点中。

下面两种操作都是往 AutoreleasePoolPage  push 对象地址：

- AutoreleasePool 的创建
  - 向 AutoreleasePoolPage push nil 对象（哨兵对象），后续 pop 时，以哨兵对象为参照点，将晚于此对象插入的所有 autorelease 对象都发送一个 release 消息，这一动作可以**跨越多个 AutoreleasePoolPage 节点**。
- 对象调用 autorelease
  - 向 AutoreleasePoolPage push autorelease 的对象地址



### 资料

[Objective-C Autorelease Pool 的实现原理](<http://blog.leichunfeng.com/blog/2015/05/31/objective-c-autorelease-pool-implementation-principle/>)

