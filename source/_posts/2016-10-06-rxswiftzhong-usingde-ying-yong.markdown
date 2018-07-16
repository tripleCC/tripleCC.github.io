---
layout: post
title: "ReactiveX中Using操作的应用"
date: 2016-10-06 23:22:34 +0800
comments: true
categories: 
---
`create a disposable resource that has the same lifespan as the Observable`，即创建一个和Observable具有相同生命周期的disposable资源。<br>
这是ReactiveX对于Using的描述。

![](/images/2016-10-06-using.png)

可以看出，当一个ObserverA订阅Using返回的Observable时，Using会使用调用者传入的Resource工厂方法[resourceFactory]创建对应的资源，并且使用Observable工厂方法[observableFactory]创建ObserverA实际上想要订阅的Observable。当ObserverA终止时，对应的Resource也会被释放[dispose]。
<!--more-->

下面是一个简单的例子(以下的代码都基于RxSwift)：

```swift
class MyDisposables: Disposable {
    func dispose() {
        print("dispose")
    }
}

......

let _ = Observable
    .using({ () -> MyDisposables in
        return MyDisposables()
    }) { _ in
        return Observable<Int>
            .interval(1, scheduler: MainScheduler.instance)
            .take(5)
    }
    .subscribe(onNext: {
        print($0)
    })
```
代码段对应的输出：

```swift
0
1
2
3
4
dispose
```
可以看到，当AnonymousObserver[匿名观察者]订阅using返回的Observable时，using内部创建了定期输出Int值的ObservableA，以及资源MyDisposables。在发送5个消息之后，ObservableA被终止，与此同时，MyDisposables资源被using释放。<br>

理解起来还是比较简单的，但是在什么场景中会使用到这个操作呢？<br>

---

### 监听Obervable
先看下RxSwift官方Demo中的一段关于GitHub登陆的代码：

```swift
let signingIn = ActivityIndicator()
self.signingIn = signingIn.asObservable()

let usernameAndPassword = Observable.combineLatest(input.username, input.password) { ($0, $1) }

signedIn = input.loginTaps.withLatestFrom(usernameAndPassword)
    .flatMapLatest { (username, password) in
        return API.signup(username, password: password)
            .observeOn(MainScheduler.instance)
            .catchErrorJustReturn(false)
            .trackActivity(signingIn)
    }
    .flatMapLatest { loggedIn -> Observable<Bool> in
        let message = loggedIn ? "Mock: Signed in to GitHub." : "Mock: Sign in to GitHub failed"
        return wireframe.promptFor(message, cancelAction: "OK", actions: [])
            // propagate original value
            .map { _ in
                loggedIn
            }
    }
    .shareReplay(1)
```
signingIn是当前是否正在登陆Observable；signedIn是当前登陆动作Observable。<br>
signedIn体现的事件流如下:

- 按下登陆按钮
- 使用当前用户名及密码进行登陆
- 展示登陆结果

其中涉及到的Rx相关操作（[详细图示](http://rxmarbles.com)）：

- combineLatest: 合并最后的username和password，形成一个新的Observable
- withLatestFrom: 形成一个以loginTaps发送事件时间为采样时间点，发送usernameAndPassword内容的Observable

---

### 困惑点
接下来当时比较困扰我的一个点：这段代码是如何做到监听当前是否正在登陆的？<br>
其中涉及到记录开始登陆的操作如下：

```swift
......

API.signup(username, password: password)
.observeOn(MainScheduler.instance)
.catchErrorJustReturn(false)
.trackActivity(signingIn)

......

public extension ObservableConvertibleType {
    public func trackActivity(_ activityIndicator: ActivityIndicator) -> Observable<E> {
        return activityIndicator.trackActivityOfObservable(self)
    }
}
```

重点关注`.trackActivity(signingIn)`这个调用。当时我的困惑是这样的：

- `.trackActivity(signingIn)`是在`signup(username, password: password)`后调用的，也就是说登陆事件已经结束了，程序才开始监听登陆动作？（这个理解是错误的）

上面的假设当然是错误的。那么，要想获得正确的结果，事件流应该是一个怎么样的执行顺序呢？<br>
最直白的想法应该就是下面三步：

- 设置当前状态为正在执行登陆
- 执行登陆操作
- 设置当前状态为没有执行登陆


那么问题来了。首先，`signup(username, password: password)`生成了登陆动作Observable，当有Observer订阅这个Observable时，Observable就会执行登陆操作，并发送对应的结果。这就造成了`.trackActivity(signingIn)` 不能直接返回上游传递过来的事件流，因为这样做的话，刚好切合了上面的那个假设。所以`.trackActivity(signingIn)`应该做到以下几件事情：

- A1、保留登陆动作ObservableA，返回自定义的一个ObservableB           
- A2、当外部Observer订阅ObservableB时，设置当前状态为正在执行登陆
- A3、设置当前状态为正在执行登陆，然后让外部的Observer重新订阅到ObservableA
- A4、登陆操作执行完毕后，设置当前状态为没有执行登陆

---
### 解惑
下面时signingIn所属类ActivityIndicator的实现：

```swift
public class ActivityIndicator : DriverConvertibleType {
    public typealias E = Bool

    private let _lock = NSRecursiveLock()
    private let _variable = Variable(0)
    private let _loading: Driver<Bool>

    public init() {
        _loading = _variable.asDriver()
            .map { $0 > 0 }
            .distinctUntilChanged()
    }

    fileprivate func trackActivityOfObservable<O: ObservableConvertibleType>(_ source: O) -> Observable<O.E> {
        return Observable.using({ () -> ActivityToken<O.E> in
            self.increment()
            return ActivityToken(source: source.asObservable(), disposeAction: self.decrement)
        }) { t in
            return t.asObservable()
        }
    }

    private func increment() {
        _lock.lock()
        _variable.value = _variable.value + 1
        _lock.unlock()
    }

    private func decrement() {
        _lock.lock()
        _variable.value = _variable.value - 1
        _lock.unlock()
    }

    public func asDriver() -> Driver<E> {
        return _loading
    }
}
```
先看下`_variable`对应的Variable类型。<br>
Variable实际上是BehaviorSubject的一层包装，不同的是它只暴露数据，不会被终止或者失败。<br>
BehaviorSubject会在订阅者订阅时，发送一个最近或初始数据，并且订阅者可以接收BehaviorSubject随后发送的所有数据。<br>
下面是一个Variable的例子：

```swift
let v = Variable(0)
v.asObservable()
    .subscribe(onNext: {
        print($0)
    })

v.value = 1
v.value = 2
```
代码段对应的输出：

```swift
0
1
2
```
现在回过头来看下`_variable`、`_loading`这两个属性。<br>
`_loading`在ActivityIndicator的初始化方法中的赋值如下：

```swift
_loading = _variable.asDriver()
	.map { $0 > 0 }
	.distinctUntilChanged()
```
其中`_variable`的初始值为0。所以这部分的逻辑很容易理解：`_loading`通过`_variable`发送的值是否大于0来判断当前是否在执行动作，并且通过increment、decrement方法来设置`_variable`发送的值（改变当前正在执行的动作数）。<br>

重点还是在trackActivityOfObservable方法：

```swift
fileprivate func trackActivityOfObservable<O: ObservableConvertibleType>(_ source: O) -> Observable<O.E> {
    return Observable.using({ () -> ActivityToken<O.E> in
        self.increment()
        return ActivityToken(source: source.asObservable(), disposeAction: self.decrement)
    }) { t in
        return t.asObservable()
    }
}
```
其中对应的resourceFactory：

```swift
{ () -> ActivityToken<O.E> in
        self.increment()
        return ActivityToken(source: source.asObservable(), disposeAction: self.decrement)
    }
```
observableFactory：

```swift
{ t in
        return t.asObservable()
    }
```
ActivityToken的实现如下：

```swift
private struct ActivityToken<E> : ObservableConvertibleType, Disposable {
    private let _source: Observable<E>
    private let _dispose: Cancelable

    init(source: Observable<E>, disposeAction: @escaping () -> ()) {
        _source = source
        _dispose = Disposables.create(with: disposeAction)
    }

    func dispose() {
        _dispose.dispose()
    }

    func asObservable() -> Observable<E> {
        return _source
    }
}
```
可以看到，ActivityToken就是一个保存了当前需要监听的Observable的资源。<br>
当外部Observer订阅trackActivityOfObservable返回的ObservableB时，using调用resourceFactory做了以下操作：

- 增加当前正在执行的动作数
- 使用ActivityToken保存需要监听的ObservableA，并且在ActivityToken释放时，恢复当前正在执行的动作数

接下来在调用observableFactory时，using把在resourceFactory中保存的ObservableA重新暴露给Observer。<br>
通过这种方式，就能在ObservableA发送数据之前，执行额外的操作`self.increment()`，也就是上面`.trackActivity(signingIn)`应该做到的A2。并且因为using会在observableFactory返回的ObservableA终止时释放resourceFactory创建的资源，所以当ObservableA终止时，会执行`self.decrement`，也就是A4。<br>
嗯，目前为止，上面的疑惑算是解决了。<br>
总结一下，就是通过using操作hold主需要监听的Observable，然后在执行了想要的额外动作后，重新暴露Observable给外部的Observer。

---
### using内部实现
最后，研究下using的内部实现：

```swift
public static func using<R: Disposable>(_ resourceFactory: @escaping () throws -> R, observableFactory: @escaping (R) throws -> Observable<E>) -> Observable<E> {
        return Using(resourceFactory: resourceFactory, observableFactory: observableFactory)
    }
```
using实际上返回的是一个Using类：

```swift
class Using<SourceType, ResourceType: Disposable>: Producer<SourceType> {
    
    typealias E = SourceType
    
    typealias ResourceFactory = () throws -> ResourceType
    typealias ObservableFactory = (ResourceType) throws -> Observable<SourceType>
    
    fileprivate let _resourceFactory: ResourceFactory
    fileprivate let _observableFactory: ObservableFactory
    
    
    init(resourceFactory: @escaping ResourceFactory, observableFactory: @escaping ObservableFactory) {
        _resourceFactory = resourceFactory
        _observableFactory = observableFactory
    }
    
    override func run<O : ObserverType>(_ observer: O) -> Disposable where O.E == E {
        let sink = UsingSink(parent: self, observer: observer)
        sink.disposable = sink.run()
        return sink
    }
}
```
Using为Producer的子类，并且重载了run方法。<br>
再看下Producer的实现：

```swift
class Producer<Element> : Observable<Element> {
    override init() {
        super.init()
    }
    
    override func subscribe<O : ObserverType>(_ observer: O) -> Disposable where O.E == Element {
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
Producer调用subscribe时，会调用子类的run，并传入当前的Oberver。回到Using的实现，Producer的run方法中创建了UsingSink实例，并调用它的run方法。那么来看下最关键的UsingSink：

```swift
class UsingSink<SourceType, ResourceType: Disposable, O: ObserverType> : Sink<O>, ObserverType where O.E == SourceType {

    typealias Parent = Using<SourceType, ResourceType>
    typealias E = O.E

    private let _parent: Parent
    
    init(parent: Parent, observer: O) {
        _parent = parent
        super.init(observer: observer)
    }
    
    func run() -> Disposable {
        var disposable = Disposables.create()
        
        do {
            let resource = try _parent._resourceFactory()
            disposable = resource
            let source = try _parent._observableFactory(resource)
            
            return Disposables.create(
                source.subscribe(self),
                disposable
            )
        } catch let error {
            return Disposables.create(
                Observable.error(error).subscribe(self),
                disposable
            )
        }
    }
    
    func on(_ event: Event<E>) {
        switch event {
        case let .next(value):
            forwardOn(.next(value))
        case let .error(error):
            forwardOn(.error(error))
            dispose()
        case .completed:
            forwardOn(.completed)
            dispose()
        }
    }
}
```
可以看到，在run方法中，UsingSink先是调用`_resourceFactory()`创建了资源resource，然后以resource为参数调用`_observableFactory()`来创建想要的Obervable。并且通过`Disposables.create(source.subscribe(self),disposable)`让resource的生命周期和Obervable一致。<br>
实际上UsingSink只是在run中做了两件特殊的事情：

- 在让source订阅自身前，创建了resource（一般会在这里做额外的操作）
- 使用的source不是由上游给的，而是通过`_observableFactory`创建的（一般的操作比如map、flatMap等，都是由上游给的）

---

### 参考
[.Net中关于Using的例子](http://www.introtorx.com/Content/v1.0.10621.0/11_AdvancedErrorHandling.html#Using)<br>
[Rx操作图示](http://rxmarbles.com)<br>
[官方文档中对于using的说明](http://reactivex.io/documentation/operators/using.html)