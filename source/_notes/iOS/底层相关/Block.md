基本原理： [Block 技巧与底层解析](<https://triplecc.github.io/2015/07/19/2015-08-27-blockji-qiao-yu-di-ceng-jie-xi/>)

### 什么是 Block

block 实例是一个**对象**，这个对象包含了**实现函数**以及一些**捕获变量**的信息，一般情况下，其 isa 指向常见的三个类：

- _NSConcreteGlobalBlock （全局）
- **_NSConcreteStackBlock**（栈）
- _NSConcreteMallocBlock（堆）

通常我们使用最多的是栈 block ，上方所说的全局、栈、堆表示对应的 **block 对象内存所在区域**。

### Block 拷贝

**因为栈中的变量会随着栈帧销毁**，为了增强栈 block 的可用性，我们通常会在栈 block 销毁前将其拷贝为堆 block。

 为什么不直接使用堆 block 呢？因为每次都在堆上直接为 block 开辟新的内存空间会影响程序性能。

### 对象的捕获

重写后的 block 结构中，会有一个字段对应着捕获的变量，反应到内存中，就是 **block 内存片段中有一块内存保存着捕获变量的值**。

在 block 进行拷贝时，会有辅助函数负责拷贝捕获变量字段的值，如果捕获的变量为对象指针，辅助函数还会去 retain / release 指针指向的对象。

### __block 修饰的变量

> 包装对象：__block 修饰的变量被包装后的结构
>
>  block 拷贝到堆后，包装对象也会通过 block 辅助函数从栈拷贝到堆

为什么不让所有的变量都默认 `__block`？因为 `__block` 修饰的变量需要额外的开销。

由于 `__block` 修饰的变量可以在 block 中被赋值 ，为了实现栈和堆中捕获变量访问的一致性，`__block` 修饰后的变量会被包装成一个对象结构。所有的访问都通过这个结构中的 `forwording` 字段，并且栈和堆中包装对象的 `forwording` 字段值相同，都指向堆中的包装对象。



![block___block_variable](https://github.com/tripleCC/tripleCC.github.io/raw/hexo/source/images/block___block_variable.png)





从设计者角度看，为什么 block 要这么做

包括对象的捕获， ，为什么要在 block copy 时也一并 copy 掉，



现在的问题是**__block 修饰对象指针变量时，如何处理指针变量指向的对象**

从代码上看，copy helper 函数并不会 retain 这个对象

<https://www.mikeash.com/pyblog/friday-qa-2009-08-14-practical-blocks.html>

<https://stackoverflow.com/questions/17384599/why-are-block-variables-not-retained-in-non-arc-environments>

<https://stackoverflow.com/questions/36993379/confusion-on-block-nsobject-obj-and-block-runtime>

<https://stackoverflow.com/questions/10429857/is-it-possible-to-see-the-code-generated-by-arc-at-compile-time/10434310#10434310>

```

// ARC
___Block_byref_object_copy_:            ## @__Block_byref_object_copy_
Lfunc_begin1:
	.loc	1 89 0                  ## /Users/songruiwang/GitHub/objc-runtime/debug-objc/main.m:89:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	subq	$32, %rsp
	movq	%rdi, -8(%rbp)
	movq	%rsi, -16(%rbp)
Ltmp10:
	.loc	1 89 20 prologue_end    ## /Users/songruiwang/GitHub/objc-runtime/debug-objc/main.m:89:20
	movq	-8(%rbp), %rsi
	movq	%rsi, %rdi
	addq	$40, %rdi
	movq	-16(%rbp), %rax
	movq	%rax, %rcx
	addq	$40, %rcx
	movq	40(%rax), %rax
	movq	$0, 40(%rsi)
	movq	%rax, %rsi
	movq	%rcx, -24(%rbp)         ## 8-byte Spill
	callq	_objc_storeStrong
	xorl	%edx, %edx
	movl	%edx, %esi
	movq	-24(%rbp), %rdi         ## 8-byte Reload
	callq	_objc_storeStrong
	addq	$32, %rsp
	popq	%rbp
	retq
Ltmp11:
Lfunc_end1:
	.cfi_endproc

// MRC
	.p2align	4, 0x90         ## -- Begin function __Block_byref_object_copy_
___Block_byref_object_copy_:            ## @__Block_byref_object_copy_
Lfunc_begin1:
	.loc	1 89 0                  ## /Users/songruiwang/GitHub/objc-runtime/debug-objc/main.m:89:0
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	subq	$32, %rsp
	movl	$131, %edx
	movq	%rdi, -8(%rbp)
	movq	%rsi, -16(%rbp)
Ltmp10:
	.loc	1 89 20 prologue_end    ## /Users/songruiwang/GitHub/objc-runtime/debug-objc/main.m:89:20
	movq	-8(%rbp), %rsi
	addq	$40, %rsi
	movq	-16(%rbp), %rdi
	movq	40(%rdi), %rdi
	movq	%rdi, -24(%rbp)         ## 8-byte Spill
	movq	%rsi, %rdi
	movq	-24(%rbp), %rsi         ## 8-byte Reload
	callq	__Block_object_assign
	addq	$32, %rsp
	popq	%rbp
	retq
Ltmp11:
Lfunc_end1:
	.cfi_endproc
                                        ## -- End function
```

