title: 浅谈缓冲区溢出之栈溢出<上>
date: 2012-12-02 11:02:00
tags:
- Linux
- 基础知识
categories: 基础知识
toc: false
---

有段时间没有用windows了，刚一开机又是系统补丁更新。匆匆瞥了一眼看到了“内核缓冲区溢出漏洞补丁”几个字眼。靠，又是内核补丁。打完这个补丁后MD的内核符号文件又得更新了。于是抱怨了几句，一旁的兄弟问什么是缓冲区溢出。这个…三两句话还真说不清楚。解释这个问题用C语言比较方便，但是单从C代码是看不出来什么的，具体原理要分析机器级代码才能说清楚。既然是浅谈原理，那就从最基本的开始吧。

本文的定位是对此方面一无所知的读者，所以大牛们可以直接飘过...

缓冲区溢出这个名词想必大家并不陌生吧，在微软的系统漏洞补丁里经常可以看到这个词（微软这算是普及计算机知识么？ – -）。从C语言来分析的话，最简单的一种溢出就是向数组中写入数据时超出了预定义的大小，比如定义了长度为10的数组，偏偏写入了10+个数据。C标准告诉我们这种做会产生不可预料的结果，而在信息安全领域看来，缓冲区溢出的艺术就是要让这种“不可预料的结果”变成攻击者想达成的结果。比如远程攻击服务器上的程序，使其返回一个具有管理员权限的shell什么的。千万别觉得这是天方夜谭，印象中微软历史上爆出过不少这样的漏洞，前段时间不就有覆盖微软全版本的MS12-020么（新的也有，但是我没关注 – -）。虽然网上广为流传的只是一个远程让服务器死机的shellcode，但是让远程服务器执行任意代码理论上是可行的。关于漏洞利用这块的东西我不怎么擅长，所以就不敢再多说了。

一般来说关于缓冲区溢出漏洞，官方的描述都是诸如“攻击者通过提交一个精心构造的字符串使得缓冲区溢出从而执行任意代码”之类的。这里的重点词是两个，“精心构造”和“字符串”。精心构造可以理解，那“字符串”呢？我们都知道，一段二进制代码是什么东西取决于机器对其的解释，如果把这段代码当作变量，当作整型是一个值，当作浮点型又是一个值，如果把它当成可执行代码的话，又会是另外一种解释。所以这里的字符串实际上就是一段可执行代码的字符串表现形式。接下来我们的重点就是如何“精心构造”这个“字符串”和如何让机器把我们构造的字符串（也就是数据）当作可执行代码来执行。

必须说明的是，真正意义上的shellcode要解决诸如函数地址重定位，汇编级系统调用，以及应对编译器抵抗此类缓冲区溢出攻击的“栈随机化”等技术，这些东西对于我们这篇“科普性质”的文章来说显然过于艰深，加之作者本人也是一个水货，故不会提及。我们只研究最浅显的原理。

我们先来看一段代码：

![](/images/5/1.png)

<!-- more -->

编译运行后我们看到了什么？

![](/images/5/2.png)

why_it_run函数居然被执行了。可是，我们并没有对该函数进行任何的显式调用啊。代码本身很简单，唯一值得怀疑的地方就在于we_call函数中buff[3] = (int)why_it_run;这一行了。我们定义了一个长度为2的数组，正常的访问范围是应该是buff[0]和buff[1]。但我们却访问了buff[3]这个超出了数组末端4个字节之后的地址，在这里写入了一个函数的地址。（为了便于之后解释变量地址的关系，我们在源代码中加入两句对buf[0]和buf[1]的赋值操作，即buf[0] = 0;与buf[1] = 1;）

为什么这样就能“诱使”系统执行了why_it_run函数呢？这里储存的到底是什么值呢？看来我们的问题越来越多了。一开始我们就说过，单从C代码是看不出任何东西的，所以我们需要研究机器代码的相关实现。那么我们需要基础的汇编指令知识，尤其是关于栈和C语言函数调用时call/ret相关的概念。如果之前没有基础，那么最好先补充一点相关的原理再继续吧，虽然这只是一篇基础文章，会尽量解释一切出现的术语和指令集。但是如果我们再解释这些基本概念的话，就过于偏离主线了。

这里是传送门：百度百科关于堆栈的解释  http://baike.baidu.com/view/93201.htm。

我们可以用gcc输出这段代码的汇编形式，命令是gcc -S overflow.c -o overflow.asm（vc的话可以用cl /Fa overflow.c命令）,gcc默认输出的是AT&T风格的汇编代码，如果更习惯Intel格式的汇编的话，可以在命令行加上 -masm=intel参数，这样gcc就会输出Intel风格的汇编了。不过今天我们采用另外一种方法查看生成的机器指令，即使用objdump命令对最终形成的可执行文件进行反汇编来查看其机器代码。操作指令是objdump -d overflow -M intel，这样我们便得到了why_it_run、we_call以及main函数的执行代码，-M intel的意思是让objdump生成intel风格的汇编，objdump默认是AT&T风格的。我们可以看到输出的结果中有很多我们没定义的函数，它们来自C运行时库，它们才是这个可执行文件真正意义上的入口函数和结束函数。

下面是我们定义的三个函数反汇编的截图：

![](/images/5/3.png)

在这里我们需要关心的是main函数和we_call函数的实现，我们先给出程序运行到这里的时候栈的分布情况：

![](/images/5/4.png)

**关于这里的栈地址并不是一个不变的地址，也就是说程序每次运行的时候栈起始位置都不一定，这是现代编译器采用的一大类技术“线性地址随机化”中的一个子集，一般翻译为“栈地址随机化”的技术。为的便是在一定程度上抵制缓冲区溢出攻击，攻击者暴力抵制的方法有“空操作雪橇”（nop sled）等方法，暴力去探测返回地址。**

额…又扯远了，言归正传，虽然栈地址是随机的，但是并不会影响数据的相对位置。对应着汇编代码，我们来一起分析栈里的数据。

先从main函数里对we_call函数的调用开始吧，调用的语句是call 8048402这一句,objdump贴心的给出了提示，这里正是we_call函数的起始位置。其实call语句执行了两件事，第一，将main函数里调用完we_call函数之后要继续执行的下一条语句的地址0x8048428入栈，接着跳到了we_call函数的地址去执行。其实这里的call指令可以等同为push 0x8048428和jmp 0x8048402两句。我们知道内存里指令是线性排列的，那么当我们去调用函数时，必须先存下我们返回源函数的时候要跳转的地址，否则回哪里去呢？

接下来我们转到we_call函数的代码去看看，代码第一行是在栈里保存main函数之前使用的ebp寄存器的值，因为我们要使用ebp寄存器，同时要在回main之前恢复到原先的ebp的值，所以需要暂存。

各函数对寄存器的使用一般有这样的规则：寄存器分为调用者保存寄存器和被调用者保存寄存器。按照惯例，eax，edx，ecx寄存器是调用者保存，ebx，esi，edi，ebp等寄存器是被调用者负责保存。举个例子，一个函数想使用ebx寄存器那么必须在返回前恢复ebp原先的值，而使用edx寄存器就无需暂存和恢复。因为寄存器就那几个，被调函数要是修改了调用它的函数正在使用的寄存器而没有恢复到以前的话会引起错误。C语言编程我们无需关注这些 ，编译器会为我们打点好这一切，而自己写汇编代码就要注意了。

保存完ebp之后，函数将esp存到了ebp里，此时ebp的值是0xBFF02490。因为每一次的push和pop都会修改esp的值，而我们需要在栈里保存函数的临时变量，所以需要ebp寄存器来保存一个暂时不变的基址便于我们对临时变量进行操作。ebp和esp是一对兄弟寄存器，它们默认的内存段都保存在段寄存器ss里。

再下来是sub esp 0x10这句，其实这等同于四个push语句，程序将栈指针向下移动了16个字节（0x10是16进制），这个减少的值视函数的临时变量尺寸而变。空出来的区域就是保存函数临时变量的地方了。必须强调的是，我们要一直记得栈的增长方向是从高地址到低地址。所以开辟新的栈空间是给esp寄存器减少某个值。而我们在使用临时变量区域的时候，是从下向上使用的。我们继续看，接下来是buf[0] = 0;与buf[1] = 1;两条语句了。我们可以看到，栈里0xBFF02488是buff[0]的地址，我们存入了0，后面的0xBFF0248C是buff[1]的地址，我们存入了1（ebp的值是0xBFF02490）。

我们另起一段来看看最关键的一步，即对buff[3]的越界访问。我们存入了why_it_run函数的地址，也就是0x80483e4。从图中我们看到，此处存放的是调用完we_call函数后返回main函数里执行的指令的地址！换句话说，我们修改了程序的流程，让函数返回到了why_it_run函数里去执行了。原先的情况下we_call函数会继续执行leave指令，它等同于add esp 0x10,pop ebp两条语句，即就是函数刚开始执行的指令的反指令，以保证堆栈平衡。最后ret指令取出main存入的返回地址，再跳转回到main里执行。但是我们违规的修改了main函数原先的安排，转移了执行方向。

我们看到在why_it_run函数里有一个函数调用exit()，我们从这里结束了程序的执行。如果没有结束呢呢？会段错误的。可以想到，原本的栈被我们破坏了，如果此时不退出，程序从why_it_run函数返回后面对的将是一个混乱的错误的栈区。那么造成内存访问段错误是显而易见的。

综上，我们通过越界访问影响了程序原先应该进行的流程，让程序走了另外一条执行的线路。这只是一个很基本的原理说明，距离我们想要实现的依旧相距甚远。这是在程序代码里实现的，那么一个已经编译好的程序如何让它执行我们想要执行的代码呢？先卖个关子，我们在之后的文章里继续说明。不过我们总算迈出了万里长征第一步，接下来的<下>我们会继续深入，继续探索缓冲区溢出的简单实现。

于是，本篇完。
