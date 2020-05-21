`NSError * __autoreleasing  *` （NSError ** 默认也是 __autoreleasing 的）



autorelease 是在 *error = 错误对象后调用用，并不是在方法返回之后。



[隐藏__autoreleasing属性变量(NSError **)引起的EXC_BAD_ACCESS崩溃](https://www.jianshu.com/p/b16f36e98baf)

