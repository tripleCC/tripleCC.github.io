---
layout: post
title: "关于RxSwift中的DisposeBag"
date: 2016-10-03 16:08:31 +0800
comments: true
categories: swift
---
在RxSwift中，订阅者都会返回一个Disposable（默认是Disposables），以便使用者可以在后续的操作中，取消此次订阅。<br>
使用者可以调用dispose方法来进行取消订阅：

```swift
let disposables = Observable
    .just(1)
    .delay(2, scheduler: MainScheduler.instance)
    .subscribe { event in
        print(event)
    }
disposables.dispose()
```
关于手动取消订阅后，对应的subscribe回调会不会调用，官方的手册是这么说的：

- 当scheduler是串行调度器，并且使用者在此调度器上调用了dispose，那么回调就不会执行［MainScheduler是在主线程/UI线程的串行调度器］
- 其他情况都不能保证回调的执行与否［并行情况下，执行顺序无法保证］

<!--More-->

所以官方并不推荐手动调用dispose，而是通过DisposeBag、takeUntil或者其他非手动调用dispose途径。
而且官方建议始终使用`.addDisposableTo(disposeBag)`来管理订阅，即使对于一般的订阅，这个操作是没有必要的。

关于DisposeBag，它的行为类似ARC，不过是由RxSwift进行管理的。它会在自身被销毁的时候，对添加到自身的Disposables手动调用dispose：

```swift
private func dispose() {
    let oldDisposables = _dispose()

    for disposable in oldDisposables {
        disposable.dispose()
    }
}

private func _dispose() -> [Disposable] {
    _lock.lock(); defer { _lock.unlock() }

    let disposables = _disposables
    
    _disposables.removeAll(keepingCapacity: false)
    _isDisposed = true
    
    return disposables
}

deinit {
    dispose()
}
```
添加Disposables：

```swift
public func insert(_ disposable: Disposable) {
    _insert(disposable)?.dispose()
}

private func _insert(_ disposable: Disposable) -> Disposable? {
    _lock.lock(); defer { _lock.unlock() }
    if _isDisposed {
        return disposable
    }

    _disposables.append(disposable)

    return nil
}
```
其内部用自旋锁处理多线程的安全问题。关于defer的OC版本，可以看[objc-attribute-cleanup](http://blog.sunnyxx.com/2014/09/15/objc-attribute-cleanup/)。ReactiveCocoa里也是有相应的@onExit实现。<br>
要想DisposeBag中的所有Disposables执行dispose，只要赋一个新的值给disposeBag变量就可以了：

```swift
self.disposeBag = DisposeBag()
```
这样一来，原先的订阅都会被取消掉。

ReactiveCocoa的列表应用中，常常会看到这样的代码：

```objc
RAC(self, contentImageView.image) = [[[viewModel.contentImageSignal
    throttle:0.05]
    takeUntil:self.rac_prepareForReuseSignal]
    map:^id(RACTuple *value) {
        return [value first];
    }];
```
表示在cell复用时，取消对contentImageSignal的订阅。<br>
RxSwift就可以这样实现：

```swift
var disposeBag: DisposeBag = DisposeBag()

......

viewModel.contentImage
    .throttle(0.05, scheduler: MainScheduler.instance)
    .bindTo(contentImageView.rx.image)
    .addDisposableTo(disposeBag)

......

public override func prepareForReuse() {
    super.prepareForReuse()
    self.disposeBag = DisposeBag()
}
```
由于cell有高复用性与重复性特点，所以关于响应式编程在cell中应用最好注意以下几点：

- cell复用时[prepareForReuse]需要取消原先的事务
- 为了避免因用户快速滑动界面，而产生大量创建事务与取消事务的动作，在cell刚进入可见区域时，不立刻执行事务
- 限制事务的并发数

所以，一般一个界面中有非常多的cell时，对其中元素进行绑定最好加上throttle操作，以使界面更加流畅。

---
### 参考
[Warnings](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Warnings.md)<br>
[GettingStarted](https://github.com/ReactiveX/RxSwift/blob/master/Documentation/GettingStarted.md)
