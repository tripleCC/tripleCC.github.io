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