http://www.dreamingwish.com

- GCD
- Block
- 多线程-RunLoop



App / 控制器 / 视图的生命周期方法可多次调用，都是通过 runloop 触发的么？

看来是的哦 = =，看这些生命周期方法的调用栈，开头都是 runloop 启动的

timer 的 fire 依靠 run loop，不在同一模式的话，不会触发回调，调整回同一模式后，fireDate 会出现断层

run loop 使用场景

- 端口或自定义输入源来和其他线程通信
- 使用线程的定时器
- performSelector 目标线程
- 使线程周期性工作

run loop 必须添加输入源或定时器，否则没有任何源需监视，启动后会立刻退出

run loop 运行可**递归**



run loop 停止方法

- 设置超时时间
- 通知停止
- 不可靠方法（移除输入源和定时器）

run loop 会将所有剩余通知发出后再退出



run loop 本质上就是一个无限循环，在循环中，去 check 并调用 run 之前注册的一些回调函数



**T：实现下自定义 run loop  输入源**



https://blog.ibireme.com/2015/05/18/runloop/



线程和 run loop 之间一一对应，以线程 pthread_t 为 key ，run loop 为 value 保存在全局字典中



pthread_t 在不同操作系统中的定义不一， linux 为 unsigned long int ，darwin 为 struct 指针类型



线程创建时，没有主动获取，则不会有 run loop （run loop 懒加载），run loop 销毁在线程结束时



一个 run loop 包含若干个 mode ，每个 mode 包含若干个 source/timer/observer ，每次调用 run loop  run 函数时，只能指定一个其中一个 mode ，如果需要切换 mode ，只能退出 loop 后重新指定 mode 进入。



如果 run loop 当前 mode 中一个 item （source/timer/observer 统称为 mode item） 都没有，则 run loop 会直接退出



**Q: 那 track 事件时，run loop 会先退出上一个 default mode，在以 track mode 重新 run，其内部流程是怎么样的 ？以什么方式退出？**

run loop 会先退出上一个 default mode，在以 track mode 重新 run ，开新线程监听 drag 事件，通过 source1 （mach_port）传回主线程给 run loop 处理



kCFRunLoopCommonModes  用来操作 common items 或者标记一个 Mode 为 common，run loop 变化时，会把 common items 同步到具有 common 标记的所有 Mode 里，包括 kCFRunLoopDefaultMode 和 UITrackingRunLoopMode 这两个真正的 mode



run loop 休眠时，会释放并新建 AutoreleasePool