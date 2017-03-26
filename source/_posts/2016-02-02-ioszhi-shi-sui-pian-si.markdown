---
layout: post
title: "iOS知识碎片四"
date: 2016-02-02 15:57:22 +0800
comments: true
categories: 
---
1、显示CoreData执行的SQL语句<br>
2、监听UITextView键盘的发送按钮<br>
3、设置CoreData实体唯一约束<br>
4、iOS9关于canOpenURL不生效<br>
5、OC变参函数
<!--more-->

##显示CoreData执行的SQL语句
设置步骤(`-com.apple.CoreData.SQLDebug 1`): <br>
![](/images/Snip20160202_1.png)<br>

![](/images/Snip20160202_2.png)<br>
打印结果：<br>
![](/images/Snip20160202_4.png)<br>
 
在获得对应的表后，可以通过sqlite3命令进行打印：

```
$ sqlite3 /Users/songruiwang/Desktop/1.sqlite 
```
执行help查询对应的命令：

```
sqlite> .help
```
如果要显示表内容的话，可以执行以下命令：

```
sqlite> .mode line
sqlite> select * from tbl1;
  one = hello!
  two = 10

  one = hello!
  two = 200
sqlite> 
```
更多详细的操作可以通过help查看。

##监听UITextView键盘的发送按钮
UITextField有代理方法监听是否点击了发送按钮：

```
- (BOOL)textFieldShouldReturn:(UITextField *)textField;
```
不过UITextView因为可以输入多行的关系，所以没有类似的代理方法。那么在作为聊天输入框的时候，就必须利用其它代理方法来实现：

```
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [self publish];
        return NO;
    } else {
        [self adjustSubviewsWithTextView:textView];
    }
    return YES;
}
```
上面的代码块就是一种实现方式，只是需要去除输入换行的功能，不过作为聊天输入框，舍弃这个功能也是可以接受的。

##设置CoreData实体唯一约束
在iOS9以前，不希望CoreData中出现相同的实体可以通过先查询后判断的形式实现。在iOS9以后，iOS提供了另外的设置，可以直接达到这个目的。设置步骤如下：

首先需要在CoreData配置实体属性中添加作为唯一标识的属性：

![](/images/Snip20160222_1.png)

然后在managedObjectContext上下文中添加合并策略，以便在遇到相同实体时进行更新：

```swift
lazy var managedObjectContext: NSManagedObjectContext = {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
    let coordinator = self.persistentStoreCoordinator
    var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    managedObjectContext.persistentStoreCoordinator = coordinator
    // 添加合并策略（更新为内存中的属性值）
    managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    return managedObjectContext
}()
```
这样当执行以下测试代码时：

```swift
// 模型
class Person: NSManagedObject {
    class var entityName: String {
        return String(Person)
    }
    init(context: NSManagedObjectContext,
        name: String) {
            let entity = NSEntityDescription.entityForName(Person.entityName, inManagedObjectContext: context)!
            super.init(entity: entity, insertIntoManagedObjectContext: context)
            self.name = name
    }
    
    @objc
    private override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
}

// 控制器
var i = 0
var persons: [Person]!
// 按键回调
func add() {
    let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
    delegate.managedObjectContext.performBlock { () -> Void in
        let person = Person(context: delegate.managedObjectContext, name: "\(self.i++ % 4)")
        person.age = self.i % 5
        delegate.saveContext()
        let request = NSFetchRequest(entityName: Person.entityName)
        self.persons = try! delegate.managedObjectContext.executeFetchRequest(request) as! [Person]
        print(self.persons.last?.name, self.persons.count, self.persons.last?.age)
    }
}	
```

会输出：

```swift
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(4)
Optional("3") 4 Optional(3)
Optional("3") 4 Optional(3)
Optional("3") 4 Optional(3)
Optional("3") 4 Optional(3)
Optional("3") 4 Optional(2)
Optional("3") 4 Optional(2)
Optional("3") 4 Optional(2)
```
可以看到最后一个实体在不断地更新，并没有添加新的实体到sqlite中。

不过需要注意的一点是当执行save操作后，`后面创建的约束值相同的实体会被清为default`，即除了第一个person，后面的person实体都会被清为default。

还有唯一约束一般结合NSFetchedResultsController使用，由NSFetchedResultsController来管理实体，就不用担心自己已经存储的有值的实体被清为defalut了（这里可以用先查后创建的方式避免，不过这样的话代码逻辑就和没有用这个约束一样了），因为在约束值相同的情况下，NSFetchedResultsController根本不会将其存入，进而不会触发对应的刷新代理方法。
##iOS9关于canOpenURL不生效
系统在iOS9之后加强了隐私保护，需要在info.plist中设置`LSApplicationQueriesSchemes`来添加要跳转的对应URL scheme，canOpenURL才会生效。

详细地址:

[session 703 privacy and your app](https://developer.apple.com/videos/play/wwdc2015/703/)

##OC变参函数

一个项目中各个API的host可能并不一样，所以最好有一个方法能够预置对应API的host，除了宏，变参函数是个很好的选择，如下：

```
+ (NSString *)jobURLStringWithPath:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2){
    NSString *contents = JOB_HOST;
    va_list args;
    va_start(args, format);
    contents = [contents stringByAppendingString:[[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
    return contents;
}
```

这样就可以进行以下调用来获取url字符串：

```
[BaseAPI jobURLStringWithPath:@"/deliveries.json"]
[BaseAPI jobURLStringWithPath:@"/user/%@/job.json", userId];
```
相对来说还是比较方便的。