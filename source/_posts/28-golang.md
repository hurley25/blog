title: Go 语言简明教程
date: 2014-01-17 14:00:00
tags:
- Golang
categories: Golang
---

### Go语言简介

Go语言(golang)是Google推出的一种全新的编程语言，可以在不损失应用程序性能的情况下降低代码的复杂性。Google首席软件工程师罗布派克(Rob Pike)说：我们之所以开发Go，是因为过去10多年间软件开发的难度令人沮丧。

Go语言的主要特性：

- 编译型语言，执行效率接近c/c++
- 自动垃圾回收
- 更丰富的内置类型和自动类型推导(类似c++11的auto)
- 函数可以返回多个值
- 拥有更好的错误处理
- 匿名函数和闭包
- 支持类型和接口
- 并发编程
- 支持反射机制
- 语言交互性强
- 工程依赖自动推导
- 打包和部署容易
- ……

就我个人而言，感觉Go语言是对像是对c语言的修补和延伸。这个由一群工程师们设计出的语言实在太符合我的口味了，所有的特性都是为了解决实际问题而存在的。但是新增加的特性并没有给语言带来额外的负担，相反，Go的语法反而很简单。大道至简，这是我喜欢Go的原因。

### Go语言开发环境部署

这个相信大家很容易在网上就能获取到下载和安装的教程，就不赘述了。

<!-- more -->

### Go语言基本语法简介

先来看一个Go语言版的”Hello world”程序：

```go
package main         // 声明本文件的包名是main
import "fmt"         // 导入fmt包
    
func main() {        // 入口函数
    fmt.Println("Hello, Go语言!")   // 打印文字
}
```

使用 go run hello.go 编译运行后输出了结果。Go语言里默认的编码是UTF-8，所以很自然的支持中文。

第一感觉看上去Go好像是Java或者python和c语言的杂交吧？这里package和import还真的类似Java或者python中的含义。Go语言没有继续背负c语言的头文件这个沉重的包袱，而是采用了更好的机制。

main函数的原型就是这样，没有参数和返回值，至于命令行参数使用其他的机制传递。有意思的是main()后面的左括号 { 是不可以另起一行的。这在c语言里只是个人习惯的问题，而在Go语言里却是硬性规定，写在下面的话直接就是一个编译器错误。

打印语句的这一行结尾是可以没有分号的，编译器会自动加上的。正因为支持可以不写分号的做法，所以Go语言不允许将左括号另起一行，否则编译器就不知道这一行结尾是否应该加上分号了。

**变量的声明和初始化**

Go语言引入了 var 关键字来定义变量，和c语言最大的不同就是变量的类型写在变量后面。下面是几个例子：

```go
var i int = 5               // 定义了一个整型变量i=5
var str string = "Go语言"   // 对，string是内置类型
var pInt *int = &i          // 没错，指针
var array [10]int           // 有10个元素的数组
var ArrayPart []int         // 数组切片，很python吧
var Info struct {           // 结构体，和c语言的没啥太大区别
    name string
    age int
}
var NumToName map[int] string // map是内置类型，这里int是key，string是value
```

甚至Go语言的发明者们认为多写几个var都是不好的：

```go
var (
    a int = 1
    b int = 2
    c string = "简化的变量定义"
)
```

还是略麻烦吗？那么你也可以这样：

```go
i := 10
str := "hello"
```

i会被创建并初始化为10，类型自动推导为int；同理，str会推导为string类型并初始化，这个语法糖不错吧。

还有更厉害的，c语言中的交换变量是需要一个中间变量的，但是Go语言不需要！只需要像下面这样：

```go
array[i], array[j] = array[j], array[i]
```

这样两个变量就交换了，简单吧？

Go语言的内置类型还有很多，下面简单的列出来一些：

- 布尔类型 bool
- 整型 int8 byte int16 int uint int32 int64 uintptr…
- 浮点类型 float32 float64
- 字符类型 rune
- 字符串 string
- 复数类型 complex64 complex128
- 错误类型 error

还有一些复合类型:

- 指针 pointer
- 数组 array
- 数组切片 slice
- 字典 map
- 结构体 struct (貌似没有c语言里的union了)
- 通道 chan
- 接口 interface

类型不再赘述，请参阅Go语言文档或者其它资料(Go的文档中示例代码确实太少了…)。

**常量定义**

和c语言一样使用 const 关键字来定义常量：

```go
const PI float64 = 3.141592653      // 这里的float64和c语言的double差不多
```

不过Go语言的常量可以不写类型，即支持无类型常量。

Go语言预定义了true、false等常量，其含义相信大家懂的。

####流程控制

Go语言的流程控制和c语言的很相似，其实无非就是选择和循环结构的写法。

先来看选择，和c语言的差不多：

```go
if condition {
    // ...
} else {
    // ...
}
```

唯一需要注意的是左括号的位置，左括号另起一行可是编译不过的哦～Go语言在语法的层面上限制了代码风格，我表示喜欢这种做法…

和c语言唯一不一样的恐怕就是if后的条件不用括号括起来。

然后是switch语句，这个和c语言的区别有点大了：

```go
i := 2
switch i {
    case 1:
        // ...
    // 不需要break，Go语言的case不会下穿的。
    case 2:
        // ...
}
 
// case还可以是字符串:
str := "hello"
switch str {
    case "hello":
        // ...
    case "world":
        // ...
    default:
        // ...
}
 
// 甚至switch都可以取代if-else if 结构了：
i := 5
switch {
    case i > 0 && i < 10:
	    fmt.Println("> 0 && < 10")
    case i > 10:
	    fmt.Println("> 10")
    default:
	    fmt.Println("= 10")
}
```

那如果想要c语言中的case下穿的功能怎么办呢？很简单，在case后语句里写fallthrough就可以了(会跳过下一个case的测试直接执行其代码)。

接下来是循环了，Go语言的循环只有for一个关键字，没有c语言的while和do-while了。不过Go语言的for很灵活，有以下几种写法：

```go
// 接近c的写法：
for i := 0; i < 5; i++ {
    	fmt.Println("i =" , i)  // Go语言打印函数的各种写法都很好玩哦
}
 
// 类似c语言while的写法：
i := 0
for i < 5 {
    fmt.Println("i =" , i)
    i++
}
 
// 死循环的写法，是不是很清爽呢？
i := 0
for {
    if i < 5 {
        fmt.Println("i =" , i)
        i++
    } else {
        break
    }
}
```

这是最基本的用法了，本文的定位是简明教程，range的用法请参考其他资料。

**函数定义**

因为Go语言的类型要写在后面，所以函数的定义差异比较大。

定义函数使用func关键字：

```go
func Add(a int, b int) int {    // 注意返回值类型写的位置
    return a + b
}
 
// 还可以写成这样
func Add(a, b int) int {    // Go的编译器知道a，b都是int类型
    return a + b
}
 
// 有意思的是Go语言的函数可以返回多个值(返回值可以有名字，error是内置的错误类型)
func Add(a, b int) (ret int, err error) {
    if a + b > 10000 {     // 假设一个错误条件，不要在意这个傻逼条件...
        err = error.New("Too big number...")
    }
    return a + b, nil      // nil 表示空，有些类似c的NULL...
}
```
函数如何调用呢？因为有包的概念，所以本包内部的函数直接调用就行了(函数定义位置无所谓的，不再是c语言里必须先声明再调用了)。

```go
sum, err := Add(10, 20)
if err == nil {
    // ok, sum is right...
}
    
// 如果只是想知道有没有错，不在乎结果，可以用下划线占位而忽略掉...
_, err := Add(a, b)
```

不在一个包里的话，先得import包，然后调用函数的时候前面要加包名和小数点，就像调用fmt包里的Println函数似的。这里需要注意的是，如果一个函数或者变量对包外可见，那么其首字母必须大写(Go语言又在用语法来限制代码格式了…)。

不定参数、匿名函数和闭包就不介绍了。

**错误处理**

上面已经简单的示范过错误处理的方法了，因为Go语言的多返回值的支持，错误处理代码可以写的很漂亮。更高级的错误处理超出了本文科普范围，请自行查阅资料。虽然话是这么说，但是我还是忍不住想简单介绍一下defer机制，示例如下(这个例子来自文档)：


```go
func CopyFile(dstName, srcName string) (written int64, err error) {
    src, err := os.Open(srcName)
    if err != nil {
        return
    }
    defer src.Close()
 
    dst, err := os.Create(dstName)
    if err != nil {
        return
    }
    defer dst.Close()
 
    return io.Copy(dst, src)
}
```

defer做了什么呢？简单的说当离开这个函数的时候，defer后面的操作会被执行。这样的话在诸如临界区域加锁的代码时，通过defer语句，就不用时时刻刻劳心临界区返回的时候有没有忘记写解锁操作了，只需要在函数内使用defer写上解锁操作就可以了。Note:可以有多个defer语句，feder后的函数以后进先出（LIFO）的顺行执行。

### 面向对象机制

**基本的面向对象特性**

以c++作为对比，首先在Go语言中没有隐藏的this指针，没有c++那种构造函数和虚构函数。

这里所谓的没有隐藏this指针意思是”this指针”显式的进行声明和传递。同时Go语言的结构体和其它语言的类具有同等地位，但是Go语言的面向对象机制放弃了其它所谓的面向对象的语言基本具有的大量特征，只保留了组合(composition)这个基础特性。

我不想在这里就这个问题来讨论Go语言面向对象特征的优劣，因为很容易引发口水仗。不过我还是表明下态度，我支持Go语言目前的做法，面向对象的核心是消息传递，而不是”构造类继承树”。

下面简单的以一个例子来说明Go的结构体以及如何在结构体上定义方法(c++程序员可能更喜欢成员函数这个术语，不过要记得Go中没有类，只有struct类型)：

```go
type Circle struct {
    r float64
}
 
func (c *Circle) Area() float64 {
    return c.r * c.r * 3.14
}
```

type有些类似于C语言里typedef的意思。关键是下面的函数，相信结合函数名前边的声明，你已经理解了Go语言定义结构体的成员函数的语法。这里我传入的是Circle的指针类型，参数名叫c(当然，这里参数名称随意)。至于传入的类型并不一定得是指针类型，也可以传入值类型(编译器自行识别)。

Go语言里也没有public和private等关键字，而直接由这个函数的首字母决定。大写字母开始的函数是可以在包外被访问的(注意是包外不是结构体外，小写开始的函数在包内的其它函数也可以调用!)。这又是一个Go语言直接用语法格式来表明语义的例子，不知道这么做是好是坏(起码项目内部代码风格统一了…)。

Go语言没有c++那种构造函数，但也提供了另外一种初始化结构体类型的方法：一个取名为New后面加类型名的全局创建函数。比如上面的Circle这个结构体的”构造函数”如下：

```go
func NewCircle(r float64) *Circle {
    return &Circle{r}
}
```

如何定义对象并且调用呢？定义的方法如下：

```go
c1 := new(Circle)
c2 := &Circle{}
c3 := &Circle{2}
c4 := &Circle{r:2}
```

一直没有强调过，Go语言中所有的变量都是默认初始化为0的，所以如果对c1、c2、c3、c4调用GetArea函数的话，得到的结果就是0，0，12.56，12.56

上面谈到Go语言不支持继承其实有点问题，Go语言实际上提供了”继承”，不过是以”组合”的文法来提供的：

```go
type Father struct {
    Name string
}
 
func (fath *Father) PrintClassName() {
    fmt.Println("Father")
}
 
type Child struct {
    Father
    Age int
}
```

此时如果Child结构体没有重写/覆写PrintClassName函数的话，定义Child结构体的对象child后执行child.PrintClassName()输出的就是”Father”，如果添加以下代码输出的就是”Chlild”：

```go
func (ch *Child) PrintClassName() {
    fmt.Println("Child")
}
```

也可以这样进行组合：

```go
type Child struct {
    *Father
    Age int
}
```

这样做的话，初始化Child结构体的对象时就需要一个外部的Father结构体的对象指针了。

**接口**

接口这个概念对于熟悉Java的人来说并不陌生，c++中的虚基类和这个概念也类似。不过Go语言这里的接口是非侵入性的接口，并不需要从这个接口来继承(别忘了，Go没有通常意义上的”继承”)

在Go语言中，只要一个结构体上实现了接口所要求的所有函数，就认为实现了该接口。所以在Go语言中，不存在继承树。至于Go采用的非侵入式接口的原因，这超出了本文的科普范围，请参考Go设计者发表的博文。

下面是一个接口定义(来自)：

```go
type IFile interface { 
    Open(filename string) (pfile *File, err error)
    Close() error
    Read(buf []byte) (n int, err error)
    Write(buf []byte) (n int, err error)
}
 
type IReader interface {
    Read(buf []byte) (n int, err error)
}
 
type IWriter interface {
    Write(buf []byte) (n int, err error)
}
```

此时若有一个结构体TextFile实现了Open，Close，Read，Write这四个函数。不需要从这些接口继承，便可以进行赋值，例如：

```go
var f1 IFile = new(File)
var f2 IReader = new(File)
var f3 IWriter = new(File)
```

空接口interface{}即Any类型，可以指向任意的类型。

接口查询，类型查询等特性进一步的学习请参阅Go语言文档。
