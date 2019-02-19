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



## Q: 为什么直接访问实例变量，不会触发 KVO 

看下 KVO 的实现方式

KVO 实现方式对 iOS 埋点的启示

https://tech.glowing.com/cn/implement-kvo/

动态创建 subclass ，只会影响单个对象，而 ms 会影响所有对象



## T: 查看有多少方法 ms

finish-hook ? -> 只能修改其他 dyld

》 方法参数返回值一致+命名相似



类族-》工厂模式创建



