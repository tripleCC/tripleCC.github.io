---
layout: post
title: "使用RxSwift+Moya+ObjectMapper接入模型"
date: 2016-10-15 11:40:37 +0800
comments: true
categories: 
---
一般情况下，从业务方从API中请求JSON数据时，一般都会经过以下三步：

```
--------1------------2----------
原始数据 -> JSON/字典  -> Model
```
当然，大部分情况下，原始数据就是JSON，所以第一步基本上只是对接受数据的一个类型转换。一般在网络层中，由组件方提供1步骤，而业务方往往在网络组件的回调中提供步骤2。简单的转换逻辑明了了，接下来就可以试下用Moya实现步骤1，ObjectMapper实现步骤2。

在结合RxSwift+Moya+ObjectMapper三者之后，常规JSON数据的获取与解析变得更加精简。以近期编写的一个V2ex API为例，获取个人信息接口如下：
	
```swift
func fetchMemberInfo(_ username: String? = V2exAppContext.shared.currentUsername,
                     _ id: Int? = nil) -> Observable<V2exMember> {
    return V2exProvider
        .request(.ShowMembers(username: username, id: id))
        .mapObject()
        .shareReplay(1)
}
```
嗯，没错，最终的调用就是这么简单明了！<br>
<!--more-->

那么，上述函数的内部是如何实现的呢？<br>

首先说下Moya。Moya是针对网络的一层封装，并且Moya在较为后期的版本中，还提供了RxSwift以及ReactiveCocoa的接口。针对RxSwift，Moya提供了以下两个好用的扩展：

```swift
open func request(_ token: Target) -> Observable<Response>
public func mapJSON(failsOnEmptyData: Bool = true) -> Observable<Any>
```
前者用来请求原始数据，后者则将原始数据转化成json。当然，Moya还提供了其他Rx扩展，比如`filterStatus`系列方法，这里就不展开了。

有了上面两个方法，业务方请求数据时，就可以这样调用：

```swift
let V2exProvider = RxMoyaProvider<V2ex>()

let json = V2exProvider
    .request(.ShowMembers(username: username, id: nil))
    .mapJSON()
```
上面`json`即为解析完成的JSON数据流。<br>
得到JSON数据流之后，就可以执行步骤2了，这里选用的是ObjectMapper。ObjectMapper是一个Swift编写的模型<->JSON转换库，应用代码非常简单，只要模型遵守Mappable协议，并且实现对应的方法就可以了：

```swift
init?(map: Map)
mutating func mapping(map: Map)
```
然后在模型中设置对应属性的值，这里以V2ex的Member为例：

```swift
struct V2exMember: Mappable {
    var status: String?
    var id: Int?
    var url: String?
    var username: String?
    var website: String?
    var twitter: String?
    var psn: String?
    var github: String?
    var btc: String?
    var location: String?
    var tagline: String?
    var bio: String?
    var created: Int?
    var avatar: V2exAvatar?
    
    init?(map: Map) {
        
    }
    
    mutating func mapping(map: Map) {
        status      <- map["status"]
        id          <- map["id"]
        url         <- map["url"]
        username    <- map["username"]
        website     <- map["username"]
        twitter     <- map["twitter"]
        psn         <- map["psn"]
        github      <- map["github"]
        btc         <- map["btc"]
        location    <- map["location"]
        tagline     <- map["tagline"]
        bio         <- map["bio"]
        created     <- map["created"]
        avatar = V2exAvatar(JSON: map.JSON)
    }
}
```
可以看到，对于struct类型的模型，这种转换方式还是很优雅的。生成模型的话，也只需要很简单的代码就可以完成：

```swift
Mapper<V2exMember>().map(JSONObject: $0)
```

到这里为止，步骤2也完成了，接下就可以将步骤1、2连接起来：

```swift
extension ObservableType where E == Response {
    public func mapObject<T: Mappable>() -> RxSwift.Observable<T> {
        return mapJSON()
            .observeOn(ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: .background))
            .flatMap {
                return Mapper<T>().map(JSONObject: $0)
                    .flatMap{ Observable.just($0) } ??
                    Observable.error(NSError(domain: "V2ex",
                                             code: -1,
                                             userInfo: ["Error" : "failed to map object"]))
            }
            .observeOn(MainScheduler.instance)
    }
    
    public func mapObjectArray<T: Mappable>() -> RxSwift.Observable<[T]> {
        return mapJSON()
            .observeOn(ConcurrentDispatchQueueScheduler(globalConcurrentQueueQOS: .background))
            .flatMap { array -> Observable<[T]> in
                if let array = array as? [Any] {
                    return Observable.just(array.flatMap { Mapper<T>().map(JSONObject: $0) })
                }
                return Observable.error(NSError(domain: "V2ex",
                                                code: -1,
                                                userInfo: ["Error" : "failed to map object array"]))
            }
            .observeOn(MainScheduler.instance)
    }
}
```
`mapObject`将原始数据转换成单个模型，而`mapObjectArray`将原始数据转换成模型数组。使用Rx.flatMap是为了方便抛出错误，终止正常数据流的流动。<br>

总的来说，这三者结合后写出来的代码给人一种畅快淋漓的感觉。不过在很多项目中，从后台获取的JSON也许不会那么规范，或者说层次分明，这样一来，需要处理的情况就复杂多了，对于上面的Rx扩展能否保持这个精简的体量还待观察。

文中提到的代码可以在这里[这里](https://github.com/tobevoid/V2exLogin)找到。

---
### 参考
[ObjectMapper](https://github.com/Hearst-DD/ObjectMapper)<br>
[Moya](https://github.com/Moya/Moya)<br>
[通过 Moya+RxSwift+Argo 完成网络请求](http://blog.callmewhy.com/2015/11/01/moya-rxswift-argo-lets-go/)<br>


