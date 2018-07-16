---
layout: post
title: "RxSwift实现初探"
date: 2016-10-01 16:08:36 +0800
comments: true
categories: 
---

和ReactiveCocoa的实现类似，RxSwift也是通过不停地订阅上游的Observable来实现数据的流动。<br>
Rx操作大体分为两种：

- 创建: create、just、of、from等
- 处理: map、flatMap、do等

接下来通过下面的操作来简单分析下代码执行过程：

```swift
let _ = Observable.just(1)
    .map { $0 }
    .subscribe(onNext: {
    print($0)
})
```

<!--More-->

以下是执行过程中创建实例的过程:

- just操作创建Just实例（Just类是一个Observable）
- map操作创建Map实例，Map实例保存了上游的Observable，这里是Just（Map类是一个Observable）
- Map实例的subscribe操作创建了AnonymousObserver实例（AnonymousObserver是一个Observer）

以下是执行Map实例执行subscribe后，代码的执行过程：

- AnonymousObserver通过Map实例的subscribeSafe方法订阅了Map实例
- Map实例通过subscribe方法间接调用了自身的run方法
- run方法创建了MapSink实例，MapSink保存了下游的Observer，即AnonymousObserver（MapSink是一个Observer）；同时run方法让MapSink订阅Map实例保存的上游Observable，即Just。
- Just执行subscribe方法，在其中直接调用`observer.on(.next(_element))`向下游的Observer，即MapSink发送消息
- MapSink接收到消息进行处理，然后向下游的Observer发送消息，即AnonymousObserver
- AnonymousObserver执行最终处理

上面就是Rx操作执行过程的全部内容，可以总结两点：

- 创建操作的subscribe方法会直接向下游Observer发送消息
- 处理操作一般会创建两个实例，一个是Observable，一个是Observer。Observable用来保存上游Observable并且让下游Observer可以进行订阅，而Observer则用来保存下游的Observer以及订阅上游的Observable

接下来结合代码分析下实现。<br>

```
public func subscribe(file: String = #file, line: UInt = #line, function: String = #function, onNext: ((E) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, onCompleted: (() -> Void)? = nil, onDisposed: (() -> Void)? = nil)
    -> Disposable {

    let disposable: Disposable

    if let disposed = onDisposed {
        disposable = Disposables.create(with: disposed)
    }
    else {
        disposable = Disposables.create()
    }
	// 创建匿名Observer
    let observer = AnonymousObserver<E> { e in
        switch e {
        // 调用对应的回调函数
        case .next(let value):        
            onNext?(value)
        case .error(let e):
            if let onError = onError {
                onError(e)
            }
            else {
                print("Received unhandled error: \(file):\(line):\(function) -> \(e)")
            }
            disposable.dispose()
        case .completed:
            onCompleted?()
            disposable.dispose()
        }
    }
    return Disposables.create(
        self.subscribeSafe(observer),
        disposable
    )
}

func subscribeSafe<O: ObserverType>(_ observer: O) -> Disposable where O.E == E {
	// 让observer订阅自身
    return self.asObservable().subscribe(observer)
}
```
Observable可以调用subscribe方法来设置对应的回调。其内部实现是创建一个匿名的Observer，然后
让这个匿名Observer订阅Observable。

```swift
class Producer<Element> : Observable<Element> {
    override init() {
        super.init()
    }
    
    override func subscribe<O : ObserverType>(_ observer: O) -> Disposable where O.E == Element {
    	// 执行子类的run方法，在run方法中，一般会保存传入的Observer
        if !CurrentThreadScheduler.isScheduleRequired {
            return run(observer)
        }
        else {
            return CurrentThreadScheduler.instance.schedule(()) { _ in
                return self.run(observer)
            }
        }
    }
    
    func run<O : ObserverType>(_ observer: O) -> Disposable where O.E == Element {
        abstractMethod()
    }
}

```
Producer是Just和Map的父类，同时也是一个Observable。通过调用subscribe方法来设置对应的Observer。

```swift
class Map<SourceType, ResultType>: Producer<ResultType> {
    typealias Selector = (SourceType) throws -> ResultType
	// 上游的Obervable
    private let _source: Observable<SourceType>

    private let _selector: Selector

    init(source: Observable<SourceType>, selector: @escaping Selector) {
        _source = source
        _selector = selector

#if TRACE_RESOURCES
        let _ = AtomicIncrement(&numberOfMapOperators)
#endif
    }

    override func composeMap<R>(_ selector: @escaping (ResultType) throws -> R) -> Observable<R> {
        let originalSelector = _selector
        return Map<SourceType, R>(source: _source, selector: { (s: SourceType) throws -> R in
            let r: ResultType = try originalSelector(s)
            return try selector(r)
        })
    }
    
    override func run<O: ObserverType>(_ observer: O) -> Disposable where O.E == ResultType {
        let sink = MapSink(selector: _selector, observer: observer)
        sink.disposable = _source.subscribe(sink)
        return sink
    }

    #if TRACE_RESOURCES
    deinit {
        let _ = AtomicDecrement(&numberOfMapOperators)
    }
    #endif
}
```
其中的_source表示上游的Observable。run方法的实现如下：

```swift
override func run<O: ObserverType>(_ observer: O) -> Disposable where O.E == ResultType {
	// 创建Observer，并且保存下游的Observer
    let sink = MapSink(selector: _selector, observer: observer)
    // 订阅上游的Observable
    sink.disposable = _source.subscribe(sink)
    return sink
}
```
先是创建了MapSink，并保存了下游的Observer，然后让sink去订阅上游的Observable。

MapSink的实现如下：

```swift
class MapSink<SourceType, O : ObserverType> : Sink<O>, ObserverType {
    typealias Selector = (SourceType) throws -> ResultType

    typealias ResultType = O.E
    typealias Element = SourceType

    private let _selector: Selector
    
    init(selector: @escaping Selector, observer: O) {
        _selector = selector
        super.init(observer: observer)
    }
	
	// 这里由上游进行调用，Observable或者Observer都可以
	// 不过在流的源头还是需要Observable手动调用_observer.on
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try _selector(element)
                forwardOn(.next(mappedElement))
            }
            catch let e {
                forwardOn(.error(e))
                dispose()
            }
        case .error(let error):
            forwardOn(.error(error))
            dispose()
        case .completed:
            forwardOn(.completed)
            dispose()
        }
    }
}
```
MapSink继承自Sink，Sink的实现如下：

```swift
class Sink<O : ObserverType> : SingleAssignmentDisposable {
	// 保存的下游Observer
    fileprivate let _observer: O

    init(observer: O) {
#if TRACE_RESOURCES
        let _ = AtomicIncrement(&resourceCount)
#endif
        _observer = observer
    }
    
    final func forwardOn(_ event: Event<O.E>) {
        if isDisposed {
            return
        }
        // 调用子类的on方法时，会调用Sink的forwardOn方法，从而把事件传递到下游的Observer
        _observer.on(event)
    }
    
    final func forwarder() -> SinkForward<O> {
        return SinkForward(forward: self)
    }

    deinit {
#if TRACE_RESOURCES
       let _ =  AtomicDecrement(&resourceCount)
#endif
    }
}
```
一旦上游调用了Observer的on方法，Observer会调用保存的下游Observer的on方法，从而触发一个链式调用。

Just的实现如下：

```
class Just<Element> : Producer<Element> {
    private let _element: Element
    
    init(element: Element) {
        _element = element
    }
    
    override func subscribe<O : ObserverType>(_ observer: O) -> Disposable where O.E == Element {
        observer.on(.next(_element))
        observer.on(.completed)
        return Disposables.create()
    }
}
```
很明显，Just是流的源头，所以它直接重载了subscribe方法，通过主动调用Observer的on方法，让数据能向下游流动。

---
### 总结
从just到subscribe，方法的调用方向大致如下：

![](/images/Snip20161007_1.png)

首先是通过`.`的方法调用，期间创建了各类Observable。<br>
直到外部调用了subscribe，即订阅了Observable，在(1)中创建的Observable开始依次调用subscribe，期间创建了各类Observer。<br>
最后subscribe到达源头，源头调用Observer的on方法，在(2)中创建的Observer开始依次调用on，最终把结果输出到subscribe回调中。

---
### 参考
[RACSignal的Subscription深入分析](http://tech.meituan.com/RACSignalSubscription.html)