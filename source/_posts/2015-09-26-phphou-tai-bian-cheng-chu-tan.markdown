---
layout: post
title: "PHP后台编程初探"
date: 2015-09-26 20:40:04 +0800
comments: true
categories: 
---
这一个星期主要需要理解的代码主要是实现这样的一个功能：<br>

![](/images/2015-09-27 10_07_51.gif)

这是一个分类网站的雏形，主要针对的是面向对象的应用和思想。
<!--more-->
##业务
分类业务主要包括以下几点：

- 核心信息是`广告`
- 将广告按照类目、地区、用户进行了分类
- 广告具有所属类目、所属地区、所属用户以及对应评论特性
- 也可以从类目、地区、用户中获取对应的所有广告信息

##核心代码层级构建
- 创建一个单例，管理数据库的连接（DataConnection）
- 根据表结构，创建一个共同的父类（Data），一个父类对象对应每个表中的特定行（table、key），这个父类提供主键查询（load），字段查询（find）功能。另外一点技巧是根据PHP动态创建属性的特性，创建一个数组属性，供外界传入各自拥有的字段映射（关联数组）
- 数据库中的部分表中存在父子节点关系，所以创建一个管理父子节点的子类（Tree），提供常用的树操作：查询子节点（children）、查询父节点（parent）、查询父族（getTree）
- 各个不同的表创建一个子类，并根据不同的字段，在构造时传入不同的`初始值`和`需要动态创建的属性及对应的查询字段`

##核心代码剖析
####PHP部分基础语法

变量：<br>
PHP是类型松散语言，会根据右边的数值决定左边的类型.

```php
$color 	$符号表示变量
```

数组：

```php
// 创建数组
$a = array("a", "b", "c");

// 关联数组
$a = array("a"=>"1", "b"=>"b");

// 添加数组
$o = new Object();
$a[] = $o;

// 关联数组的遍历(as)
foreach ($this->columns as $key => $value) {
	echo "键:" . $key . "  ";
	echo "值:" . $value . "  ";
}

// 普通数组的另一种遍历方式
$a = array("1", "2");
for ($i = 0; $i < 10; $i++) {
	echo $a[$i];
}
```

字符串的基本运算：<br>

```php
.   	串接
.=  	串接赋值
```

clone对象复制（新对象）：<br>
对对象内的基本数值类型进行传值复制，对对象内对象型的成员变量，如果不重写__clone函数，显示clone这个对象成员变量，那么这个成员变量就是进行引用复制，不是生成一个新的对象

继承使用extends。<br>

this、self、parent为分别指向当前对象、当前类、父类的指针。<br>


####数据连接单例

```php
	class DataConnection {
         private static $dataConnection;
         public $connection;
 
         function __construct() {
             // 连接数据库
             $this->connection = mysql_connect('localhost', 'root', '') or die(mysql_error());
             // 选取chaoge数据库
             mysql_select_db("chaoge", $this->connection) or die(mysql_error());;
             // 向数据库执行SET NAMES UTF8命令(执行数据库命令，设置字符集编码格式)
             mysql_query("SET NAMES UTF8", $this->connection) or die(mysql_error());;
         }
 
         public static function getInstance() {
             // 为空创建
             if (is_null(self::$dataConnection)) {
                 self::$dataConnection = new DataConnection();
             }
 
             return self::$dataConnection;
         }
     }
```

####共同父类Data

```php
 class Data {
        private $sql;
        private $rs;
		
        public $table;
        public $key;
        public $columns;

        public function init($option) {
            $this->table = $option['table'];
            $this->key = $option['key'];
            $this->columns = $option['columns'];
        }   

        public function fetch() {
            // 取得结果集中的一行作为关联数组
            return mysql_fetch_assoc($this->rs);
        }   

        public function query() {
            $connection = DataConnection::getInstance()->connection;
            // 执行查询语句
            $this->rs = mysql_query($this->sql, $connection);

            // 返回查找到的行数
            // mysql_num_rows返回实际结果集中获取的行数
            return mysql_affected_rows();
        }   

        // 查找主键所在行的数据
        public function load($v=null) {
            // 获取主键字段对应的属性名
            $key = $this->key;

            if (!$v) {
                // 获取主键值
                $v = $this->$key;
            }   

            // 创建数据库查询语句
            $this->sql = "SELECT * FROM {$this->table} WHERE {$this->columns[$key]} = {$v}";
             // 进行数据库查询                                                                                                                                                        
            if ($this->query()) {
                // 获取主键所在行关联数组
                $ar = $this->fetch();

                foreach ($this->columns as $key => $value) {
                    // 设置动态添加属性的值为对应数据库字段读取的值
                    $this->$key = $ar[$value];
                }
                return $this;
            }

            return false;
        }

        // 可以根据columns中的字段来进行查找
        public function find() {
            // 拼接where，WHERE 1=1是减少是否需要添加WHERE的麻烦
            $where = " WHERE 1 = 1 ";
            $limit = " LIMIT 0, 10 ";
            foreach ($this->columns as $key => $value) {
                if (isset($this->$key)) {
                    // 如果对应的动态属性有值，就添加对应的查询条件
                    // $value是数据库字段，$this->$key是模型属性的值
                    $where .= "AND {$value}={$this->$key}";
                }
            }

            // 拼接查询语句
            $this->sql = "SELECT * FROM {$this->table} {$where} {$limit}";

            $ar = array();
            // 进行数据库查询
            if ($this->query()) {
                // 获取查询的一行数据
                while ($a = $this->fetch()) {
                    // 这里进行clone，表示只是想要查询，并不想要改变$this的相关属性值
                    // 实现面向对象编程的方式，使用clone
                    $o = clone $this;
                    foreach ($this->columns as $key => $value) {
                        // 设置动态添加属性的值为对应数据库字段读取的值
                        $o->$key = $a[$value];
                    }
                    // 将设置号查询数据的对象添加到数组中
                    $ar[] = $o;
                }
            }
		// 重写__get方法，获取属性时就先判断属性有没有,没有的话输出null
        public function __get($property_name) {
            // $this有$property_name属性的情况下返回属性值
            return property_exists($this, $property_name) ? $this->$property_name : null;
        }
```
因为一个Data对象对应着数据库中的一行数据，所以需要有以下对应的属性：<br>
1. table	->对应的表<br>
2. key		->对应行主键<br>
3. columns	->对应每个表中各自的私有字段<br>

并且其中涉及到了PHP动态`创建属性`的特性。<br>

动态创建的属性默认是public的，要想动态创建私有的属性，可以这么做：

```php
class foo {
	  
	private $a;
	private $_properties = array();

	public function __set($var, $val = null) {
		  
		$this->_properties[$var] = $val;
	}  
	public function __get($var) {
		  
		return $this->_properties[$var];
	}  
}

$a = new foo();
$a->__set('a','111');
echo $a->__get('a');
```
使用一个private的数组，每次创建时可以往这个数组里面添加元素。<br>

__set当给不可访问或不存在属性赋值时被使用。<br>

__get当读取不可访问或不存在的属性时被调用。<br>

可以在以上函数中设置错误抛出，当访问不存在属性时就抛出错误。<br>

isset是在参数为null或者属性不存在时返回false，否则返回true。<br>
            
其中有两个数据库的函数，我纠结了挺久，是关于执行SELECT返回的数据行数。

- mysql_affected_rows()
  - Retrieves the number of rows from a result set. This command is only valid for statements like SELECT or SHOW that return an actual result set. 
- mysql_num_rows()
  - Get the number of affected rows by the last INSERT, UPDATE, REPLACE or DELETE query associated with link_identifier.
  
但是实际使用的时候，两者返回的值是一样的，个人感觉和手册上面说的有点不一样。最后在stackoverflow问了下，得出以下结论：

- mysql_affected_rows()返回查询到的数据行数
- mysql_num_rows()返回实际返回的数据行数（结果集中）

详细的讨论在这里：[mysql_affected_rows()和mysql_num_rows()](http://bytes.com/topic/php/answers/749156-difference-between-mysql_affected_rows-mysql_num_rows)

##管理树操作子类Tree

```php
class Tree extends Data {
        public $pkey;

        public function init($option) {
            $this->pkey = $option['pkey'];
            parent::init($option);
        }

        public function children() {
            // 获取主键字段对应的属性名
            $key = $this->key;
            // 获取父页节点主键对应的属性名
            $pkey = $this->pkey;

            // 这里name属性还没有被创建，试一下__get
            echo "<br>";
            var_dump($this->name);
            echo "<br>";
            $this->table;

            // 获取对象类名
            $class = get_class($this);
            $o = new $class;
            $o->$pkey = $this->$key;
            return $o->find();
        }

        public function parent() {
            // 获取主键字段对应的属性名
            $key = $this->key;
            // 获取父节点主键对应的属性名
            $pkey = $this->pkey;

            $class = get_class($this);
            $o = new $class;
            $o->$key = $this->$pkey;
            return $o->load();
        }
		public function getTree() {
            // 获取父页面主键对应的属性名
            $pkey = $this->pkey;

            $ar = array();
            // clone是产生一个和原来一样的新的对象，没有clone的话是一个对象引用
            // 这里主要是规避$this不能被赋值问题
            // 因为$o中的属性并不会被改变，所以这里也可以不使用clone
			// $o = clone $this;
            $o = $this;
            do {
                // 将从本身开始，到最后层级的父节点添加到数组中
                $ar[] = $o;
                // 获取父节点
                $o = $o->parent();
                // 如果没有父节点对应的主键值，那么表示没有父节点，退出循环
            }while (isset($o->$pkey) && $o->$pkey > 1);

            // 将父节点排在最前面
            return array_reverse($ar);
        }
    }
```

php实现面向对象的编程方式可以使用两种方式：

1. `clone`方式，这样不管实际类是哪种，都可以拷贝一个全新的对象出来。这种方式在这个上下文下需要对clone的类的部分属性进行清空。
2. 使用另一种方式，即以上方式：通过`get_class`获取类名，然后重新创建一个。

##详细子类

```php
   class Category extends Tree {
        function __construct() {
            $option = array(
                // 表格
                'table' => 'babel_node',
                // 主键
                'key' => 'id',
                // 父节点主键
                'pkey' => 'pid',
                // 表格对应的私有字段
                'columns' => array(
                    'id' => 'node_id',
                    'pid' => 'nod_pid',
                    'name' => 'nod_title'
                )
            );
            parent::init($option);
        }

        public function ads() {
            $a = new Ad();
            // 设置分类id
            $a->categoryId = $this->id;
            // 因为分类id被设置了，所以查找的时候就只有分类id这一个过滤条件
            return $a->find();
        }
    }
    class Area extends Tree {
        function __construct() {
            $option = array(
                'table' => 'babel_area',
                'key' => 'id',
                'pkey' => 'pid',
                'columns' => array(
                    'id' => 'area_id',
                    'pid' => 'area_pid',
                    'name' => 'area_title'
                )
            );
            parent::init($option);
        }

        public function ads() {
            $a = new Ad();
            // 设置地区id
            $a->areaId = $this->id;
            // 因为地区id被设置了，所以查找的时候就只有地区id这一个过滤条件
            return $a->find();
        }
    }

    class User extends Data {
        function __construct() {
            $option = array(
                'table' => 'babel_User',
                'key' => 'id',
                'columns' => array(
                    'id' => 'usr_id',
                    'email' => 'usr_email',
                    'name' => 'usr_nick'
                )
            );
            parent::init($option);
        }

        public function ads() {
            $a = new Ad();
            // 设置用户id
            $a->userId = $this->id;
            // 因为用户id被设置了，所以查找的时候就只有用户id这一个过滤条件
            return $a->find();
        }
	class Comment extends Data {
        function __construct() {
            $option = array(
                'table' => 'babel_reply',
                'key' => 'id',
                'columns' => array(
                    'id' => 'rpl_id',
                    'adId' => 'rpl_tpc_id',
                    'userId' => 'rpl_post_usr_id',
                    'userName' => 'rpl_post_nick',
                    'content' => 'rpl_content'
                )
            );
            parent::init($option);
        }
    }

    class Ad extends Data {
        // 广告里面包含了对应所属的分类，用户，地区信息
        public $category;
        public $user;
        public $area;

        function __construct() {
            $option = array(
                'table' => 'babel_topic',
                'key' => 'id',
                'columns' => array(
                    'id' => 'tpc_id',
                    'categoryId' => 'tpc_pid',
                    'userId' => 'tpc_uid',
                    'areaId' => 'tpc_area',
                    'name' => 'tpc_title',
                    'content' => 'tpc_content'
                )
            );
            parent::init($option);
        }

        public function load() {
            parent::load();

            // 设置分类、用户、地区属性对应的主键值
            $this->category = new Category();
            $this->category->id = $this->categoryId;

            $this->user = new User();
            $this->user->id = $this->userId;

            $this->area = new Area();
            $this->area->id = $this->areaId;

            return $this; 
        public function commments() {
            $c = new Comment();
            // 设置评论id
            $c->adId = $this->id;
            // 因为评论id被设置了，所以查找的时候就只有评论id这一个过滤条件
            return $c->find();
        }
    }
```
这几个子类将自身的属性和数据库中的字段进行了映射，这样外部操作就可以脱离数据库了，只需要和模型交互即可。

##主页界面构建

```php
<?php
	// 包含kijiji.php文件                                                                                                                                                                                
    require_once("kijiji.php");

	// 在URL中捕获id参数的值
    $id = $_GET['id']; 
    $c = new Category();
    $c->id = $id;
    $c->load();

    $d = new Data();
    $d->id = $id;
//    $d->load();

//   $d->song = 1;
//    var_dump(get_object_vars($d));
//    var_dump(get_object_vars($c));
//    var_dump(get_class_methods("Category"));
//    var_dump(get_class_vars("Category"));
    foreach ($c->children() as $o) {
        echo "<hr><a href=list.php?id={$o->id}>{$o->name}</a>";
        foreach ($o->children() as $oo) {
            echo "<li><a href=list.php?id={$oo->id}>{$oo->name}</a>";
        }   
    }   
?>
```

##添加
添加功能是后面新增的，主要需要有两点：<br>
1. 界面上需要一个输入框和一个确认键，确认后提交评论<br>
2. 提交的评论存入数据库

这个功能主要分成两部分：界面，数据库<br>
1. 界面使用PHP的表单来进行数据传输<br>
2. 数据库插入在Data类中添加一个无参，返回值为false/数据主键的方法

具体代码如下：<br>
界面代码：

```php
	// 从POST中获取评论数据
	if(isset($_POST['comment'])){
        $comment = new Comment();
        $comment->content = $_POST['comment'];
        $comment->userName = "songruiwang";
        $comment->userId = 2222;
        $comment->adId = $id;
        echo "主键:" . $comment->insert();
    }
    
    // 通过表单实现界面刷新，并且以POST的方式传递数据
echo '<form method="post"><input type="text" name="comment">
<input type="submit"  value="提交"></form>';
```

数据库插入代码：

```php
		// 插入数据
        public function insert() {
            $keys = "";
            $values = "";

            foreach ($this->columns as $key => $value) {
                // 不插入设置主键
                if ($key != $this->key && isset($this->$key)) {
                    $keys .= "{$value},";
                    $values .= "'{$this->$key}',";
                }
            }

            // 去掉最后面的逗号
            $keys = substr($keys, 0, strlen($keys) - 1);
            $values = substr($values, 0, strlen($values) - 1);

            // 构造数据库sql语句
            $databaseName = "chaoge";
            $this->sql = "INSERT INTO {$databaseName} . {$this->table} ({$keys}) VALUES ({$values})";

            // 执行数据库插入语句
            if ($this->query()) {
                // 返回上一步插入后产生的主键
                return mysql_insert_id();
            }

            return false;
        }
```