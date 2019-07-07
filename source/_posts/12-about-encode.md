title: 编码那点事
date: 2013-01-27 12:02:00
tags:
- 基础知识
categories: 基础知识
toc: false
---

最近一直忙着做一个C++项目，一直也抽不出时间来更新博客。项目代码托管在 GitHub。是一个跨平台的数据包捕获程序，基于Qt 4.X和WinPcap库（Windows下）和Libpcap库（Linux下）。目前还是进行中，只在Windows下测试。有兴趣的同学可以提提意见。

好了，言归正传。项目中频繁遇到了需要转换编码和字节序的地方，字节序没什么说的，无非就是大小端的问题。今天我们就谈一谈编码那点事吧。

现在还记得当时自己刚接触到字符串编码问题的纠结过程。什么ASCII、GBK、GB2312、ANSI、UTF-8、UNICODE……混乱不堪的，更别提什么UCS、DBCS等闻所未闻的名词了。

好了，我们先不谈转换和分析什么的，先来大致看一看编码发展的历史。先对“为什么有这么多编码？”给出一个大体上的解释。

**事先声明，历史部分参考了很多文章和书籍，甚至就是在其他文章的基础上改写的。另外我也没办法考证是否确切。所以，权当故事听吧。**

**术语和定义等内容基本来自百度百科和维基百科的相关词条，以下不再声明。**

最先介绍的应该是ASCII码吧，也就是所谓的美国信息交换标准代码。

<!-- more -->

标准ASCII码也叫基础ASCII码，使用7位二进制数来表示所有的大写和小写字母，数字0到9、标点符号，以及在美式英语中使用的特殊控制字符。其中0x20以下的字节状态称为”控制码”，定义了一些诸如换行之类的控制代码。

接着呢，计算机开始在世界上流行。很显然目前的编码并不能满各个文化的信息表示的需要。于是人们开始继续在ASCII码127号之后的位置开始编码，加入了新的字母、符号和线型形状。从128号到255号的字符被称为“扩展字符集”。此时，一个字节的容量消耗一空。

这时候摆在中国面前的是一个麻烦的问题了（当然不止中国），中国当时给出了这样一个解决方案：保留标准ASCII码，去掉127以后的扩展ASCII码，并且规定小于127的字符继续使用ASCII原意，如果两个大于127的字符在一起时，表示一个汉字。其中高字节0xA1~0xF7，低字节0xA1~0xFE，这样大概能表示7000多个汉字了，还有数学符号、罗马希腊的字母、日文的假名等等。另外对ASCII原先有的数字，标点，字母，符号也增加了2个字节 的版本，称为“全角”字符。原先的ASICC码就被称为“半角”字符了。我们在输入法设置那里看到的全角、半角就是这个意思。

这套汉字编码方案就是所谓的“GB2312”了，也就是对ASCII码的中文扩展。但是因为中国汉子还是比较多的，所以后来规定只要一个字符大于127，就和后面一个字符一起表示一个符号。而修改后的方案最后被就称为GBK标准。随着文化的传播，我国少数民族的文字也逐渐被加入，GBK最终扩展为GB18030。

这种编码方案被称为DBCS（Double Byte Charecter Set）即双字节字符集。正如我们看到的，这种混合了一个字节和两个字节的编码处理起来比较麻烦。首先需要判断一个字节的大小，如果大于127，认为这个字节和之后再一个字节一起表示一个字符，否则它本身就是一个字符。

这是中国给出的方案，其他国家和地区呢？当然各有各的编码而且相互不识别。就连台湾都有一个名叫BIG5的繁体中文编码方案。其实编码和字符之间就是一个映射的关系，不过的方案采取的映射关系不同，自然就没法相互识别了。对于未知的文档，如果采用了错误的编码表去识别，自然会是乱码，而且乱的一塌糊涂。

ANSI就是对不同国家和地区各自编码的称呼，比如在大陆ANSI指的就是GBK编码，在台湾是BIG5编码，在日本代表JIS编码。

后来ISO组织开始着手建立国际意义的统一编码，他们的做法很直接，不包含目前任何的地区性编码，重新建立一个包含全世界所有民族使用的符号的编码。这套编码称之为”Universal Multiple-Octet Coded Character Set”，简称 UCS, 俗称 “Unicode”编码。


大概来说，Unicode编码系统可分为编码方式和实现方式两个层次。目前实际应用的统一码版本对应于UCS-2，使用16位的编码空间。也就是每个字符占用2个字节。对于标准ASCII编码 ，保持原编码不变，只是扩展到16位（前面补0），而其它文字符号重新编码。使用Unicode编码的C语言程序此时有问题了，因为之前string.h里很多函数没法使用了。我们需要为strlen等函数实现新的宽字符函数，当然，早已经实现了。我们给出几个C语言字符函数的对应关系。

```c
strcat()  ->  wcscat()

strncpy() ->  wcscpy()

strlen()  ->  wcslen()
```

意思一下就可以了，更详细的列表请求助搜索引擎。

ISO制定Unicode的时候，没有考虑与任何编码保持兼容（标准ASCII除外）。使得如果要转换现有编码的话没有一个简单的数学计算的解决方案。对于两种不同的字符映射关系，人们不得不通过查表来进行。

目前2字节表示的Unicode能表示65535个字符，满足了现阶段的表示要求。不过ISO还有一个备用的UCS-4方案，采用4字节表示一个字符……

不过网络传输中采用的不是直接传递Unicode编码（真蛋疼），而是所谓的UTF（UCS Transfer Format）标准，UTF8就是一次传输 8位，UTF16就是一次传输16位。Unicode到UTF8或UTF16有一定的算法和规则去转换。

UTF-8是一种变长编码，实际表示ASCII字符的UNICODE字符，将会编码成1个字节，并且UTF-8表示与ASCII字符表示是一样的。所有其他的UNICODE字符转化成UTF-8将需要至少2个字节。每个字节由一个换码序列开始。第一个字节由唯一的换码序列，由n位连续的1加一位0组成, 首字节连续的1的个数表示字符编码所需的字节数。由于汉字编码的位置因素，所以一个汉字由Unicode转换为UTF-8后通常是3个字节。

UTF-8编码可以通过屏蔽位和移位操作快速读写。字符串比较时strcmp()和wcscmp()的返回结果相同，因此使排序变得更加容易。字节FF和FE在UTF-8编码中永远不会出现，因此他们可以用来表明UTF-16或UTF-32文本UTF-8 是字节顺序无关的。它的字节顺序在所有系统中都是一样的，因此它实际上并不需要BOM（Byte Order Mark，即字节顺序标记）。

[维基百科关于BOM](http://zh.wikipedia.org/wiki/%E4%BD%8D%E5%85%83%E7%B5%84%E9%A0%86%E5%BA%8F%E8%A8%98%E8%99%9F)的解释。

关于编码的故事基本上就到这里了，详细的问题就不继续研究了。

接下来我们看看在编码转换的一些方法。

首先是文本编辑器，几乎所有的文本编辑器在保存的时候都有编码的选项，就连Windows的记事本都有编码的选择，虽然可选的方案很少。Notepad++、Ultra Edit、Sublime Text之类的文本编辑器可选的编码就很多了。

Linux系统下也有编码转换的命令以及同名函数函数iconv，具体使用请自行man查询。

关于编程中的编码转换，一般的高级语言本身会有相关的库函数。关于第三方编码转换的库比如Libiconv提供了几乎世界上所有编码转换的方案。

Windows API也有关于宽窄字符的转换函数MultiByteToWideChar和WideCharToMultiByte。

我们用一个使用Win API将UTF8编码转换到GBK编码的例子结束文章吧：

```c
// UTF8编码转换到GBK编码
INT UTF8ToGBK(CHAR *lpUTF8Str, CHAR *lpGBKStr, INT nGBKStrLen)
{
    WCHAR      *lpUnicodeStr = NULL;
    INT        nRetLen = 0;
 
    // 获取转换到Unicode编码后所需要的字符空间长度
    nRetLen = MultiByteToWideChar(CP_UTF8, 0,
                                        (char *)lpUTF8Str, -1, NULL, NULL);
 
    // 为Unicode字符串申请空间
    lpUnicodeStr = new WCHAR[nRetLen + 1];
 
    // 转换到Unicode编码
    nRetLen = MultiByteToWideChar(CP_UTF8, 0, (char *)lpUTF8Str, -1,
                                                  lpUnicodeStr, nRetLen);  
 
    // 获取转换到GBK编码后所需要的字符空间长度
    nRetLen = WideCharToMultiByte(CP_ACP, 0, lpUnicodeStr,
                                               -1, NULL, NULL, NULL, NULL);
 
    // 输出缓冲区为空则返回转换后需要的空间大小
    if (!lpGBKStr) {
        if (lpUnicodeStr)
            delete []lpUnicodeStr;   
        return nRetLen;
    }
 
    // 如果输出缓冲区长度不够则退出
    if (nGBKStrLen < nRetLen) {
        if (lpUnicodeStr)
            delete []lpUnicodeStr;
        return 0;
    }
 
    // 转换到GBK编码
    nRetLen = WideCharToMultiByte(CP_ACP, 0, lpUnicodeStr, -1,
                                 (char *)lpGBKStr, nRetLen, NULL, NULL);
 
    if (lpUnicodeStr)
        delete []lpUnicodeStr;
 
    return nRetLen;
}
```
