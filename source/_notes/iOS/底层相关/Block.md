从设计者角度看，为什么 block 要这么做

包括对象的捕获，__block 变量为什么会转换成一个对象结构体，为什么要在 block copy 时也一并 copy 掉，



现在的问题是**__block 修饰对象指针变量时，如何处理指针变量指向的对象**

从代码上看，copy helper 函数并不会 retain 这个对象

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

