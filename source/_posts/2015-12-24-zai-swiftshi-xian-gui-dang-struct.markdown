---
layout: post
title: "在Swift实现Struct归档"
date: 2015-12-24 15:08:29 +0800
comments: true
categories: 
---
```swift
struct AboutMe {
    var detail: String
    var links: [[String : String]]
}
```

在Swift中，Struct类型是无法进行归档操作的，只有继承自NSObject并且遵守了NSCoding协议的类才可以进行相应的归档操作。也就是将上面结构体改成类：

```
class AboutMe: NSObject, NSCoding {
    var detail: String
    var links: [[String : String]]
    required init?(coder aDecoder: NSCoder) {
        aDecoder.decodeObjectForKey("detail")
        aDecoder.decodeObjectForKey("links")
    }
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(detail)
        aCoder.encodeObject(links)
    }
}
```

但是如果要对Struct进行归档，可以转换思维，使用按照以下步骤实现。
<!--more-->
###### 实现一个归档、解档协议：

```
public protocol Archivable {
    func archive() -> NSDictionary
    init?(unarchive: NSDictionary?)
}
```
因为NSKeyedArchiver可以直接对Foundation类进行操作，所以可以将结构体中的属性都转换成字典，然后进行后续操作；archive函数返回一个归档好的字典，而可失败构造函数传入一个需要解档的字典。

###### 让AboutMe遵守并实现以上声明的协议

```
extension AboutMe: Archivable{
    func archive() -> NSDictionary {
        return ["detail" : detail, "links" : links]
    }
    
    init?(unarchive: NSDictionary?) {
        guard let values = unarchive else { return nil }
        if let detail = values["detail"] as? String,
            links = values["links"] as? [[String : String]] {
                self.detail = detail
                self.links = links
        } else {
            return nil
        }
    }
}
```
这里使用扩展进行归解档方法的添加，可以看到，原先结构体的属性在接口上都是以字典的形势在传输。

###### 实现归解档函数

```
public func unarchiveObjectWithFile<T: Archivable>(path: String) -> T? {
    return T(unarchive: NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? NSDictionary)
}

public func archiveObject<T: Archivable>(object: T, toFile path: String) {
    NSKeyedArchiver.archiveRootObject(object.archive(), toFile: path)
}
```
对AboutMe进行字典化后，NSKeyedArchiver可以直接对其进行操作，所以这个实现并不复杂。<br>


完成以上步骤，就可以对Struct进行归档和接档操作了：

```
let path = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true).first! + "/Person"
let aboutMe = AboutMe(detail: "tripleCC", links: [["github" : "https://github.com/tripleCC"], ["gitblog" : "http://triplecc.github.io/"]])
archiveObject(aboutMe, toFile: path)
let unAboutMe: AboutMe? = unarchiveObjectWithFile(path)
debugPrint(unAboutMe)
```
如果要进行集合操作，可以添加以下函数：

```
public func archiveObjectLists<T: Archivable>(lists: [T], toFile path: String) {
    let encodedLists = lists.map{ $0.archive() }
    NSKeyedArchiver.archiveRootObject(encodedLists, toFile: path)
}

public func unarchiveObjectListsWithFile<T: Archivable>(path: String) -> [T]? {
    guard let decodedLists = NSKeyedUnarchiver.unarchiveObjectWithFile(path) as? [NSDictionary] else { return nil }
    return decodedLists.flatMap{ T(unarchive: $0) }
}
```

### 参考博客
1.[NSCoding And Swift Structs](http://swiftandpainless.com/nscoding-and-swift-structs/)<br>
2.[Property Lists And User Defaults in Swift](http://redqueencoder.com/property-lists-and-user-defaults-in-swift/)
