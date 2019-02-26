[swift 面试题](https://www.jianshu.com/p/bdaa49f9d1a4)



决定执行代码：

消息结构->运行环境

函数调用->编译器



堆->手动管理

栈->自动管理，栈帧



@dynamic: 不要创建实例变量和存取方法



assign 纯类型

strong 对象引用计数+1

weak 不改变对象引用计数，对象释放置 nil

unsafe_unretained 不改变对象引用计数，对象释放不置 nil

copy 拷贝对象



**Q: 为什么直接访问实例变量，不会触发 KVO** 

看下 KVO 的实现方式

KVO 实现方式对 iOS 埋点的启示

https://tech.glowing.com/cn/implement-kvo/

动态创建 subclass ，只会影响单个对象，而 ms 会影响所有对象



**T: 查看有多少方法 ms**

finish-hook ? -> 只能修改其他 dyld

》 方法参数返回值一致+命名相似



类族-》工厂模式创建



类的映射表-〉类方法 List -》继承体系-〉消息转发



objc_msgSend ––– 结构体、浮点数、超类/父类（_stret, _fpret, Super）



尾递归优化-》最后操作仅仅为调用其他函数，编译器生成跳转指令码，不会向调用栈推新栈帧



动态方法解析 ––– +resolveInstanceMethod: +resolveClassMethod:

​	@dynamic  CoreData

​	本来就**已实现**，运行时插入



备源接收者––– -forwardingTargetForSelector:

​	组合模拟多重继承



完整消息转发 ––– -forwardInvocation:

​	selector、target、参数

​	可修改消息



越后代价越大，可操作空间越大



类对象是单例

ARC 不是 “异常安全的”， 需要 -fobjc-arc-exceptions

ARC 时 NSError ** -> NSError * __autoreleasing* 自动释放 NSError 对象



使用分类规划同个类中不同功能代码

Private 分类，对外不开放，对内开发方法



C++混编，依赖C++关键字的文件都要 .mm



自动释放池，保证对象在跨越方法调用边界后一定存活

当前线程的下一次事件循环释放



返回对象需调用者释放： alloc、new、copy、mutableCopy

ARC通过命名将内存管理规则标准化：

```
+ (A *)newA { // considring of new
    A *a = [[A alloc] init];
    return a; // no retains, releases, or autorelease are required when returning
}

+ (A *)someA { // no new
    A *a = [[A alloc] init];
    return a; // add autorelease when returning
}


```



ARC 返回自动释放对象时，执行 objc_autoreleaseReturnValue 根据调用方是否 retain 了返回值设置标识位（ARC 环境下，可以说实际上事没有 autorelease 了）

objc_retainAutoreleasedReturnValue 查看标志位是否设置来决定是否 retain



ARC 清理 Objective-C  对象实例变量内存 -> C++ 析构函数

dealloc -> 不需要调用 super，生成代码会自动调用



修改局部/实例变量语义：

- __strong 默认，强引用

- __unsafe_unretained 弱引用，对象回收后不清空指针

- __weak 弱引用，对象回收后清空指针

- __autoreleasing 对象 autorelease 自动释放

  

**Q: runloop 时间循环执行时机，怎么知道某个方法已经执行完成，在其执行完成后释放自动释放池中的内存？**



ARC 下捕获异常，应使用 -fobjc-arc-exceptions ，否则易造成内存泄露



主线程 && GCD 创建的线程，都默认有自动释放池； main 函数和自己创建的线程需要自行添加自动释放池

自动释放池为嵌套架构-》栈



自动释放池要等线程执行下一次事件循环时才会清空，这就意味着在执行 for 循环时，会持续有新对象创建并加入到自动释放池。



**Q: 自动释放池和 runloop**



使用 block 版本的枚举器-》内部会添加自动释放池



**Q：继承类和拷贝类，哪个效率高**



tagged pointer 优化小对象，如 NSNumber，NSDate，小的 NSString，其指针值不是地址，而是真正的值

单例对象的引用计数很大，保留及释放操作都是空操作



Objective-C 对象: 一块连续的内存，其首地址为指向类的指针：

```objective-c
id cls = [NSObject class];
void *obj = &cls;
NSLog(@"%@", [(__bridge id)obj description]);
```



block 捕获变量是对象，会自动保留它（不然可能就被释放了，导致访问失败）