title: 如何精确测量一段代码的执行时间
date: 2015-12-06 17:59:00
tags:
- linux
- x86
categories: Linux
toc: false
---

最近在工作中遇到了需要精确测量一段C代码执行时间的需求，大家给出的方案有以下三种：

- `gettimeofday(2)`
- `rdtsc/rdtscp`
- `clock_gettime(2)`

下面我们就逐一介绍下这三种方案的用法和限制，主要的关注点是准确性、精度和调用成本，讨论环境是运行在Intel x86上的Linux x86_64系统，内核的版本号高于2.6.32。

<p></p>

#### gettimeofday(2)

首先是gettimeofday(2)，函数原型如下：

```c
#include <sys/time.h>

int gettimeofday(struct timeval *tv, struct timezone *tz);

struct timeval {
    time_t      tv_sec;     /* seconds */
    suseconds_t tv_usec;    /* microseconds */
};

struct timezone {
    int tz_minuteswest;     /* minutes west of Greenwich */
    int tz_dsttime;         /* type of DST correction */
};
```

<!-- more -->

从结构体定义山看，这个函数获取到的时间精度是微秒（us，10^-6s)。这个函数获得的系统时间是使用墙上时间xtime和jiffies处理得到的。墙上时间从UTC 1970-01-01 00:00:00开始，由主板电池供电的RTC（实时钟）芯片存储。jiffies是Linux内核启动后的节拍数，Linux内核从2.5版内核开始把频率从100调高到1000，即系统运行频率为1s/1000=1ms（毫秒）。由此可见，仅仅使用这两个来源是无法达到us的精度的。不过在Linux内核中，高精度定时器 hrtimer(High Resolution Timer)模块也会对xtime进行修正的，这个模块甚至支持ns（纳秒，10^-9）的时间精度。

在`Linux x86_64`系统中，gettimeofday的实现采用了“同时映射一块内存到用户态和内核态，数据由内核态维护，用户态拥有读权限”的方式使得该函数调用不需要陷入内核去获取数据，即`Linux x86_64`位系统中，这个函数的调用成本和普通的用户态函数基本一致。

总体上来说，微秒级别对于一般的时间获取已经足够，这个函数用在日志输出的时间戳上也很常用，不过对于精度要求很高的场合还是略有些欠缺。

<p></p>

#### rdtsc/rdtscp

接下来是rdtsc这个CPU指令。这个指令的含义是read tsc寄存器，即time stamp counter寄存器的值。从Pentium处理器开始，Intel的很多80x86微处理器都引入64bit的TSC寄存器，用于时间戳计数器。该寄存器在每个时钟信号到来时加1。那么这个数值的递增就和CPU的主频相关了，主频为1M Hz的处理器这个寄存器每秒就递增1,000,000次。而rdtsc指令把tsc寄存器的数值读出来，数值的低32位存放在eax寄存器中，高32位存放在edx寄存器中。那么很容易就能用gcc的内联汇编写出来读取这个数值的代码：

```c
typedef unsigned long long cycles_t;
inline cycles_t currentcycles() {
    cycles_t result;
    __asm__ __volatile__("rdtsc" : "=A" (result));
    return result;
}
```

但是这个计时方式在网上很容易找到一些反对的说法，常见的说法有以下几种：

1. 从Pentium Pro开始引入的CPU乱序执行使得指令重排序会影响。
2. CPU的频率可能会变化，比如节能模式。
3. 无法保证每个CPU核心的TSC寄存器是同步的。

重排序这个好说，使用cpuid指令保序就行，如果CPU比较新的话直接用rdtscp指令就好，这个已经是保序的指令了。至于频率变化问题，如果是较新的CPU，可以在`/proc/cpuinfo`文件里看看，如果tsc相关的特性有`constant_tsc`和`nonstop_tsc`存在，就不用担心这个了。前者`Constant TSC means that the TSC does not change with CPU frequency changes, however it does change on C state transitions`，后者`The Non-stop TSC has the properties of both Constant and Invariant TSC`。不过，多个CPU之间的不同步这里并没有解决。有意思的是，前面的gettimeofday(2)在返回时对xtime和jiffies进行修正时，也有使用TSC寄存器的值。

顺便说一下，我们的场景是单核心测试一段代码的执行时间。多次运行获得运行时间即可，不是持续长期运行的产品代码，所以用rdtscp指令是可以的。

<p></p>

#### clock_gettime(2)

最后是`clock_gettime(2)`，其原型如下：

```c
#include <time.h>

int clock_gettime(clockid_t clk_id, struct timespec *tp);

struct timespec {
    time_t   tv_sec;        /* seconds */
    long     tv_nsec;       /* nanoseconds */
};
```

从结构体定义上来看，这是一个ns（纳秒，10^-9）级别精度的时间获取函数。`clk_id`参数指定获取的时间类型，有以下取值：

- `CLOCK_REALTIME` 系统实时时间，从UTC 1970-01-01 00:00:00开始
- `CLOCK_MONOTONIC` 从系统启动起开始计时的运行时间，不计算休眠时间
- `CLOCK_MONOTONIC_RAW` （since Linux 2.6.28; Linux-specific）类似`CLOCK_MONOTONIC`，但是基于原始硬件数据，不受NTP时间变动影响
- `CLOCK_PROCESS_CPUTIME_ID` 本进程执行到当前代码时系统CPU花费的时间
- `CLOCK_THREAD_CPUTIME_ID` 本线程执行到当前代码时系统CPU花费的时间

从参数上看，平时获取时间使用第一个`CLOCK_REALTIM`E参数即可，用这个参数的话有点类似`gettimeofday(2)`，但是精度要高一些（10^-9 vs 10^-6）。事实上当时间类型是`CLOCK_PROCESS_CPUTIME_ID`或`CLOCK_THREAD_CPUTIME_ID`时，`clock_gettime(2)`也有利用rdtsc指令来获取时间。具体的调用成本我没有试验，参考资料里有人做了相关的实验并给出了相关的测试数据，可以参考下。

参考资料：
[1]  Linux man pages.
[2] 《Combined Volume Set of Intel® 64 and IA-32 Architectures Software Developer’s Manuals》2B
[3] 《How to Benchmark Code Execution Times on Intel® IA-32 and IA-64 Instruction Set Architectures》Gabriele Paoloni
[4]  http://stackoverflow.com/questions/6814792/why-is-clock-gettime-so-erratic
