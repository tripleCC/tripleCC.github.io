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



https://stackoverflow.com/questions/30228847/what-are-difference-between-a-and-a-in-objective-c-object

https://stackoverflow.com/questions/16252343/are-all-objects-in-objective-c-basically-pointers

**OC 对象实际是 struct 结构体，但因为在堆上创建（实际上一种特殊的对象也能在栈上创建，就是指向类的指针变量，其实也是一个对象），只能通过对象指针访问（发消息只能通过对象指针），所以一般也说将指向对象的指针描述为对象**(实际上就是 struct 指针)

**OC 对象实际是 struct 结构体，只能通过对象指针即结构体指针，向 OC 对象发送消息**

**如果一片连续内存中的首个指针大小的内存片段指向类(元类)，则此连续内存中所保存的结构可视为实例对象（单例类对象）**

内存片段指向类————内存片段内容为类地址

比如：

```
struct objc_object *classObjc = (__bridge void *)[A class]; (返回 objc_class 结构体指针)
// classObjc 指向的内存地址中首个指针大小连续内存片段指向了 A 的元类
// 所以 *classObjc 是一个单例类对象，可以通过 classObjc 指针对其发消息（类方法）

struct objc_object *instanceObjc = &classObjc
// instanceObjc 指向的内存地址中的首个指针大小连续内存片段(内容就是 classObjc 的值)指向了 A 类
// 所以 classObjc 是一个实例对象，可以通过 &clsObjc 指针对其发消息（对象方法）

所以 classObjc 既可以视为实例对象，又是指向单例类对象的指针
```





每个 OC 对象实例都是指向某块内存数据的指针（objc_object 只是描述对象的结构）

Objective-C 对象: 一块连续的内存，其首地址指向类：

```objective-c
id cls = [NSObject class];
//（这里的 cls 指针变量，严格意义上就可以作为 NSObject 的实例对象，然后取 cls 的地址访问实例对象）
void *obj = &cls;   
NSLog(@"%@", [(__bridge id)obj description]);
```



block 捕获变量是对象，会自动保留它（不然可能就被释放了，导致访问失败）

__block 如果修饰的是基本类型，则会将其转化成对象

block 辅助函数负责捕获对象的管理



定义 block 时，内存区域分配在栈中 （在栈上创建结构体，没有 malloc），copy 后，从栈拷贝到了堆，在没有 copy 前，block **只在定义的范围内有效**



block 使代码变得紧凑，delegate 则会分散代码（适合步骤分明的场景，比如 TableViewDataSource）



需要循环依赖场景：需要等网络请求执行完成之后，才清除数据加载器，执行完回调后，需要清除回调 block



队列 -> 按照任务加入顺序触发-> 串行、并行，是否要等上一个任务执行完再触发下个任务

同步异步->是否需要等加入的任务返回再执行当前任务（是否立即返回）



preformSelector 容易造成内存泄露，编译器不知道将要调用的选择子，无法用 ARC 内存管理规则判断是否需要释放返回值



NSOperation 

- 取消某个操纵
- 指定操作间的依赖关系
- KVO 监测对象属性（isCancelled、isFinished）
- 指定操作的优先级，GCD 的优先级针对整个队列，非单个任务
- 重用NSOperation 对象



group-wait 阻塞，notify 非阻塞



死锁，在自己的串行队列任务中，同步派发任务给此串行队列



解决任务不可重入代码引发的死锁，可使用队列特定数据（dispatch_get_specific）解决



toll-free bridge

- __bridge 不变更所有权
- __bridge_retained  OC -> C 由 C 持有所有权，需要手动 free
- __bridge_transfer C -> OC 由 OC 持有所有权



NSCache 提供自动删减功能（size 满了），线程安全，不会拷贝键， NSDictionary 则相反



load

- 父类->子类->分类
- 系统框架会在自定义类的 load 方法执行前就加载到内存
- load 会加优先调用依赖库的 load，但在 load 中使用同个库的其他类是不安全的，调用顺序不确定
- load 方法不会继承，没实现就不会调用，并且不调用 super 父类就会自动调用 load

initialize

- 父类->分类->子类（分类的 initialize 会覆盖子类的方法，和普通的方法调用一样）

- 首次使用类时，仅调用一次
- initialize 会继承

initialize 线程安全？？？