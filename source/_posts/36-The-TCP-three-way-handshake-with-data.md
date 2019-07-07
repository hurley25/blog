title: TCP连接建立的三次握手过程可以携带数据吗？
date: 2015-04-15 16:38:00
tags:
- tcp
- linux
- 协议栈
- 网络
categories: 网络
toc: false
---

前几天实验室的群里扔出了这样一个问题：**TCP连接建立的三次握手过程可以携带数据吗？**突然发现自己还真不清楚这个问题，平日里用tcpdump或者Wireshark抓包时，从来没留意过第三次握手的ACK包有没有数据。于是赶紧用nc配合tcpdump抓了几次包想检验一下。但是经过了多次实验，确实都发现第三次握手的包没有其它数据（后文解释）。后来的探究中发现这个过程有问题，遂整理探究过程和结论汇成本文，以供后来者参考。

先来张三次握手的图（下面这张图来自网络，若侵犯了作者权利，请联系我删除）：

![](/images/36/1.png)

RFC793文档里带有SYN标志的过程包是不可以携带数据的，也就是说三次握手的前两次是不可以携带数据的（逻辑上看，连接还没建立，携带数据好像也有点说不过去）。重点就是第三次握手可不可以携带数据。

先说结论：TCP协议建立连接的三次握手过程中的**第三次握手允许携带数据**。

<!-- more -->

![](/images/36/2.png)

对照着上边的TCP状态变化图的连接建立部分，我们看下RFC793文档的说法。RFC793文档给出的说法如下（省略不重要的部分）：

![](/images/36/3.png)

重点是这句 “Data or controls which were queued for transmission may be included”，也就是说标准表示，第三次握手的ACK包是可以携带数据。那么Linux的内核协议栈是怎么做的呢？侯捷先生说过，“源码面前，了无秘密”。最近恰逢Kernel 4.0正式版发布，那就追查下这个版本的内核协议栈的源码吧。

在探索源码前，我们假定读者对Linux的基本socket编程很熟悉，起码对连接的流程比较熟悉（可以参考这篇文章[《浅谈服务端编程》](http://www.0xffffff.org/2014/11/20/33-servie-program/)最前边的socket连接过程图）。至于socket接口和协议栈的挂接，可以参阅[《socket接口与内核协议栈的挂接》](http://rock3.info/blog/2013/10/28/socket%E6%8E%A5%E5%8F%A3%E4%B8%8E%E5%86%85%E6%A0%B8%E5%8D%8F%E8%AE%AE%E6%A0%88%E7%9A%84%E6%8C%82%E6%8E%A5) 。

首先， 第三次握手的包是由连接发起方（以下简称客户端）发给端口监听方（以下简称服务端）的，所以只需要找到内核协议栈在一个连接处于SYN-RECV（图中的SYN_RECEIVED）状态时收到包之后的处理过程即可。经过一番搜索后找到了，位于 net\ipv4目录下tcp_input.c文件中的tcp_rcv_state_process函数处理这个过程。如图：

![](/images/36/4.png)

这个函数实际上是个TCP状态机，用于处理TCP连接处于各个状态时收到数据包的处理工作。这里有几个并列的switch语句，因为函数很长，所以比较容易看错层次关系。下图是精简了无需关注的代码之后SYN-RECV状态的处理过程：

![](/images/36/5.png)

一定要注意这两个switch语句是并列的。所以当TCP_SYN_RECV状态收到合法规范的二次握手包之后，就会立即把socket状态设置为TCP_ESTABLISHED状态，执行到下面的TCP_ESTABLISHED状态的case时，会继续处理其包含的数据（如果有）。

上面表明了，当客户端发过来的第三次握手的ACK包含有数据时，服务端是可以正常处理的。那么客户端那边呢？那看看客户端处于SYN-SEND状态时，怎么发送第三次ACK包吧。如图：

![](/images/36/6.png)

tcp_rcv_synsent_state_process函数的实现比较长，这里直接贴出最后的关键点：

![](/images/36/7.png)

一目了然吧？if 条件不满足直接回复单独的ACK包，如果任意条件满足的话则使用inet_csk_reset_xmit_timer函数设置定时器等待短暂的时间。这段时间如果有数据，随着数据发送ACK，没有数据回复ACK。

之前的疑问算是解决了。

但是，那三个条件是什么？什么情况会导致第三次握手包可能携带数据呢？或者说，想抓到一个第三次握手带有数据的包，需要怎么做？别急，本博客向来喜欢刨根问底，且听下文一一道来。

**条件1：sk->sk_write_pending != 0**

这个值默认是0的，那什么情况会导致不为0呢？答案是协议栈发送数据的函数遇到socket状态不是ESTABLISHED的时候，会对这个变量做++操作，并等待一小会时间尝试发送数据。看图：

![](/images/36/8.png)

net/core/stream.c里的sk_stream_wait_connect函数做了如下操作：

![](/images/36/9.png)

sk->sk_write_pending递增，并且等待socket连接到达ESTABLISHED状态后发出数据。这就解释清楚了。

Linux socket的默认工作方式是阻塞的，也就是说，客户端的connect调用在默认情况下会阻塞，等待三次握手过程结束之后或者遇到错误才会返回。那么nc这种完全用阻塞套接字实现的且没有对默认socket参数进行修改的命令行小程序会乖乖等待connect返回成功或者失败才会发送数据的，这就是我们抓不到第三次握手的包带有数据的原因。

那么设置非阻塞套接字，connect后立即send数据，连接过程不是瞬间连接成功的话，也许有机会看到第三次握手包带数据。不过开源的网络库即便是非阻塞socket，也是监听该套接字的可写事件，再次确认连接成功才会写数据。为了节省这点几乎可以忽略不计的性能，真的不如安全可靠的代码更有价值。

**条件2：icsk->icsk_accept_queue.rskq_defer_accept != 0**

这个条件好奇怪，defer_accept是个socket选项，用于推迟accept，实际上是当接收到第一个数据之后，才会创建连接。tcp_defer_accept这个选项一般是在服务端用的，会影响socket的SYN和ACCEPT队列。默认不设置的话，三次握手完成，socket就进入accept队列，应用层就感知到并ACCEPT相关的连接。当tcp_defer_accept设置后，三次握手完成了，socket也不进入ACCEPT队列，而是直接留在SYN队列（有长度限制，超过内核就拒绝新连接），直到数据真的发过来再放到ACCEPT队列。设置了这个参数的服务端可以accept之后直接read，必然有数据，也节省一次系统调用。

SYN队列保存SYN_RECV状态的socket，长度由net.ipv4.tcp_max_syn_backlog参数控制，accept队列在listen调用时，backlog参数设置，内核硬限制由 net.core.somaxconn 限制，即实际的值由min(backlog,somaxconn) 来决定。

有意思的是如果客户端先bind到一个端口和IP，然后setsockopt(TCP_DEFER_ACCEPT），然后connect服务器，这个时候就会出现rskq_defer_accept=1的情况，这时候内核会设置定时器等待数据一起在回复ACK包。我个人从未这么做过，难道只是为了减少一次ACK的空包发送来提高性能？哪位同学知道烦请告知，谢谢。

**条件3：icsk->icsk_ack.pingpong != 0**

pingpong这个属性实际上也是一个套接字选项，用来表明当前链接是否为交互数据流，如其值为1，则表明为交互数据流，会使用延迟确认机制。

好了，本文到此就应该结束了，上面各个函数出现的比较没有条理。具体的调用链可以参考这篇文章[《TCP内核源码分析笔记》](http://www.cnblogs.com/mosp/p/3891783.html)，不过因为内核版本的不同，可能会有些许差异。毕竟我没研究过协议栈，就不敢再说什么了。
