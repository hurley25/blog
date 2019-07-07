title: 线程眼中的线性地址空间
date: 2013-08-02 19:00:00
tags:
- Linux
- 基础知识
categories: 基础知识
toc: false
---

以前写过一篇[《进程眼中的线性地址空间》](http://www.0xffffff.org/2013/05/23/18-linux-process-address-space/)，这是她的姊妹篇线程篇。而且和以前一样我们只谈32位Linux下的实现。另外读者可能还需要之前的一篇文章[《Linux线程的前世今生》](http://www.0xffffff.org/2013/07/30/19-linux-thread-history/)作为前期的辅助资料。

如果读者已经看过这两篇文章，那么我们就可以继续往下说了。

我简单列出上述文章中的几个要点：

1. 32位操作系统下的每个进程拥有4GB的线性地址空间。

2. 从Linux内核的角度来说，它并没有线程这个概念。在内核中，线程看起来就像是一个普通的进程（只是线程和其他一些进程共享某些资源，比如地址空间）。

暂时有这两点就可以了。我们直接就能从第二点中看出来，一个进程创建的所有线程实际上是都是在它的线性地址空间里运行的。也就是说，一个进程所创建的所有线程没有创建新的地址空间，而是共享着进程所拥有的4G的线性空间罢了。除了地址空间还共享什么呢？大致还有文件系统资源、文件描述符、信号处理程序以及被阻断的信号等内容。不过即便是共享地址空间，但是每个线程还是有自己的私有数据的，比如线程的运行时栈。

<!-- more -->

线程真的是共享这4G的地址空间吗？口说无凭，咱们来给出实证。我们给出验证代码1：

```c
#include <unistd.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

void *thread_func(void *args)
{
    printf("tid: %u pid: %u thread id: %un", getpid(), syscall(224), pthread_self());

    while(1) {
        sleep(10);
    }
}

int main(int argc, char *argv[])
{
    pthread_t thread;
    int count = 0;

    while (pthread_create(&thread, NULL, thread_func, NULL) == 0) {
        sleep(1);
        count++;
    }

    perror("Create Error:");
    printf("Max Count:%dn", count);

    return EXIT_SUCCESS;
}
```

从代码中我们能看出主线程每休眠一秒就创建一个新的线程，子线程始终睡眠不会退出。

![](/images/20/1.png)

我们在其创建了10来个线程后在终端按下Ctrl+Z键将其放到后台休眠，然后进入/proc目录下用这个进程PID命令的目录，查看maps文件。

![](/images/20/2.png)

这里只是部分输出，我们看到，子线程创建的所有的私有栈(stack:后面的即是线程在内核中拥有的实际PID值)就在其所属进程所拥有的这4G的线性地址空间里。

也许你已经猜到，倘若我们注释掉代码中主函数的sleep()函数，这个程序终将输出32位Linux在默认情况下一个进程所能创建出的线程的总数。注意不要注释掉线程中的sleep()函数，因为我们需要子线程一直存在而且不要占用太多的CPU资源。我们修改代码然后编译执行，结果如下：

![](/images/20/3.png)

我们看到，最后因为内存资源不足无法再创建线程了，总数是381(不过在我的机器上偶尔也会是380)，再加上主线程就是382个。我们在《进程眼中的线性地址空间》中就知道一个线程默认的栈大小是8MB，8MB*382就是3056MB，因为其它诸如代码和全局数据也会占据一些空间，抛开内核占据的1GB，所以这些差不多就是用户空间所有的内存了。

P.S. 如果你要问，线程的私有栈在进程的地址空间里在何处分配？如何分配？我的答案是，请自行研究……maps里指明了地址范围的数值，结合进程的地址空间可以分析出来。另外在《Linux线程的前世今生》这篇文章的最后，我给出了NPTL库的两位作者写的文档，你可以参考阅读其中的章节。

上文中我们提到32位Linux默认线程创建的数量是382左右，那么我们想尝试创建更多的线程怎么办呢？修改默认栈大小就可以，我们既可以在代码中设置线程创建时的属性来设置，也可以在终端下使用ulimit命令来设置。

好了，我们继续。既然所有的线程在一个地址空间里，那….A线程在栈里创建的变量能否被B线程修改呢？答案是能，我们看代码：

```c
#include <unistd.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

int *p_num;

void *thread_1(void *args)
{
    int test_num = 1;

    printf("test_num: %dn", test_num);

    p_num = &test_num;

    sleep(2);

    printf("test_num: %dn", test_num);
}

void *thread_2(void *args)
{
    sleep(1);

    if (p_num != NULL) {
        *p_num = 2;
    }
}

int main(int argc, char *argv[])
{
    pthread_t thread1, thread2;

    pthread_create(&thread1, NULL, thread_1, NULL);
    pthread_create(&thread2, NULL, thread_2, NULL);

    pthread_join(thread1, NULL);
    pthread_join(thread2, NULL);

    return EXIT_SUCCESS;
}
```
简单起见我没有使用什么条件变量之类的同步手段而是简单的采用sleep()函数来演示，大家明白就好。

编译运行，结果如我们所料。

![](/images/20/4.png)

其实站在共享的角度看，这篇到这里就差不多了，因为在《进程眼中的线性地址空间》中，其他的东西已经有了。虽然我觉得还是没多少干货，但确实也不知道再说些什么了。姑且先发布，以后有补充的再说。
