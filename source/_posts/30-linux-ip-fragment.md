title: Linux TCP/IP协议栈关于IP分片重组的实现
date: 2014-04-16 12:00:00
tags:
- Linux
- TCP/IP
categories: 网络
toc: false
---

最近学习网络层协议的时候，注意到了IP协议中数据包分片的问题。下图是IP协议头的数据字段的示意：

![](/images/30/1.png)

如图所示，IP协议理论上允许的最大IP数据报为65535字节（16位来表示包总长）。但是因为协议栈网络层下面的数据链路层一般允许的帧长远远小于这个值，例如以太网的MTU（即Maximum Transmission Unit，最大传输单元）通常在1500字节左右。所以较大的IP数据包会被分片传递给数据链路层发送，分片的IP数据报可能会以不同的路径传输到接收主机，接收主机通过一系列的重组，将其还原为一个完整的IP数据报，再提交给上层协议处理。上图中的红色字段便是被设计用来处理IP数据包分片和重组的。

那么，这三个字段如何实现对分片进行表示呢？

<!-- more -->

- 首先是标示符（16位），协议栈应该保证来自同一个数据报的若干分片必须有一样的值。

- 其次是标志位3位分别是R（保留位，未使用）位、DF（Do not Fragment，不允许分段）位和MF（More Fragment）位。MF位为1表示当前数据报还有更多的分片，为0表示当前分片是该数据报最后一个分片。

- 最后是偏移量（13位），表示当前数据报分片数据起始位置在完整数据报的偏移，注意这里一个单位代表8个字节。即这里的值如果是185，则代表该分片在完整数据报的偏移是185*8=1480字节。

**RFC815文档(IP datagram reassembly algorithms）文档定义了IP分片重组的算法。**

操作系统内核协议栈（以下简称协议栈）只需要申请一块和原始数据报相同大小的内存空间，然后将这些数据报分片按照其偏移拷贝到指定的位置就能恢复出原先的数据报了。目前看起来一切都很清晰，不是么？但我的问题就出在这个判别数据报分片的方法上。因为标示字段只有16位，所以理论上只有65536个不同的表示。当一台拥有着超过65536个活跃连接用户的服务器时，理论上会出现重复的数据报分片。即使连接的客户没这么多，但是从概率上如果只用这个标示符的话，依旧会出现可能造成混乱的数据报分片。

协议栈究竟如何处理这个问题呢？本文不讨论IP分片可能会造成的Dos攻击和效率损失的问题，单就研讨一旦出现了IP数据报分片，协议栈如何处理的问题。妄加猜测是没有意义的，直接查阅Linux内核协议栈源码再清楚不过了。这里基于Linux-3.12.6内核源码来解释这个问题。（为什么是这个版本？因为我的机器上正好有这个版本…）

Linux内核协议栈关于IPV4协议的代码都在`net/ipv4`目录下。从文件名上分析，`ip_fragment.c`文件显然就是IP分片处理的源代码。（好吧，这种方法很不严谨…）

我们的目的是找到IP数据报组合的过程，至于分片什么的大家有兴趣的话可以自己去研究，理论上分片要比重组容易一些。

一番周折后我们找到了IP数据报重组的函数：

```c
int ip_defrag(struct sk_buff *skb, u32 user);
```

我怎么知道这个函数是碎片重组的？因为defrag这个单词就是碎片重组的意思……咳咳，看来良好的函数命名还是很重要的。开个玩笑，函数前面的注释说明了这个函数的任务是处理IP分片组合：Process an incoming IP datagram fragment.

这个函数参数是`struct sk_buff`结构的指针，而网络数据包在内核协议栈中就是以`struct sk_buff`结构进行传送的。这个函数的作用就是尝试组合数据报，成功组合的话返回一个`struct sk_buff`结构的指针。

函数代码如下（Linux-3.12.6）：

```c
/* Process an incoming IP datagram fragment. */
int ip_defrag(struct sk_buff *skb, u32 user)
{
        struct ipq *qp;
        struct net *net;

        net = skb->dev ? dev_net(skb->dev) : dev_net(skb_dst(skb)->dev);
        IP_INC_STATS_BH(net, IPSTATS_MIB_REASMREQDS);

        /* Start by cleaning up the memory. */
        ip_evictor(net);

        /* Lookup (or create) queue header */
        if ((qp = ip_find(net, ip_hdr(skb), user)) != NULL) {
                int ret;

                spin_lock(&qp->q.lock);

                ret = ip_frag_queue(qp, skb);

                spin_unlock(&qp->q.lock);
                ipq_put(qp);
                return ret;
        }

        IP_INC_STATS_BH(net, IPSTATS_MIB_REASMFAILS);
        kfree_skb(skb);
        return -ENOMEM;
}
```

ip_evictor对分片处理的内存占用进行统计，超出了使用范围的话会进行内存的释放，避免遭受恶意的网络攻击（比如恶意的制造IP分片，使得目标机器内存大量消耗等等）。这不是我们要分析的重点，跳过它就是ip_find函数了，函数头部的注释告诉我们这个函数的职责是”在不完整的IP数据报队列中寻找当前数据报分片的位置，没有找到的话就为当前分片重新建立一个队列”。

函数代码如下（Linux-3.12.6）：

```c
/* Find the correct entry in the "incomplete datagrams" queue for
 * this IP datagram, and create new one, if nothing is found.
 */
static inline struct ipq *ip_find(struct net *net, struct iphdr *iph, u32 user)
{
        struct inet_frag_queue *q;
        struct ip4_create_arg arg;
        unsigned int hash;

        arg.iph = iph;
        arg.user = user;

        read_lock(&ip4_frags.lock);
        hash = ipqhashfn(iph->id, iph->saddr, iph->daddr, iph->protocol);

        q = inet_frag_find(&net->ipv4.frags, &ip4_frags, &arg, hash);
        if (q == NULL)
                goto out_nomem;

        return container_of(q, struct ipq, q);

out_nomem:
        LIMIT_NETDEBUG(KERN_ERR "ip_frag_create: no memory left !\n");
        return NULL;
}
```

下面这行代码明确的指出了协议栈判断IP分片的依据：

```c
hash = ipqhashfn(iph->id, iph->saddr, iph->daddr, iph->protocol);
```

Ipqhashfn函数**依靠（标示符、源地址、目标地址、协议）这个四元组来唯一的表示一个IP数据报分片**，这就解决了单单依赖表示符无法确定一个数据报的问题。那么这个四元组怎么表示呢？查找的效率问题如何解决呢？答案就在ipqhashfn这个hash函数里，其代码如下（Linux-3.12.6）：

```c
static unsigned int ipqhashfn(__be16 id, __be32 saddr, __be32 daddr, u8 prot)
{
        return jhash_3words((__force u32)id << 16 | prot,
                            (__force u32)saddr, (__force u32)daddr,
                            ip4_frags.rnd) & (INETFRAGS_HASHSZ - 1);
}
```

jhash_3words函数参数累加求模，实现如下（Linux-3.12.6）：

```c
/* A special ultra-optimized versions that knows they are hashing exactly
 * 3, 2 or 1 word(s).
 *
 * NOTE: In partilar the "c += length; __jhash_mix(a,b,c);" normally
 *       done at the end is not done here.
 */
static inline u32 jhash_3words(u32 a, u32 b, u32 c, u32 initval)
{
        a += JHASH_GOLDEN_RATIO;
        b += JHASH_GOLDEN_RATIO;
        c += initval;

        __jhash_mix(a, b, c);

        return c;
}
```
OK，问题解决了。有兴趣的同学可以去研究一下IP数据报分片如何实现。最近很忙，就到这里吧～
