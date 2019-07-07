title: C++ 并发编程那些事
date: 2016-02-11 21:56:10
tags:
- x86
- c++
categories: c++
toc: true
---

### 背景介绍

这篇文章主要针对C++11标准发布之后的现代C++的并发编程进行阐述。C++11首次在语言层面承认了多线程的存在，这使得“仅仅使用C++标准库就能编写跨平台的多线程程序”的愿望成为现实。

设计多线程的程序目的主要有两个：**充分利用多核CPU的性能**（利用多核心的计算能力以及让计算和IO重叠来降低RT并提升吞吐量）和**简化程序逻辑**（即把单线程状态机的逻辑拆分成多个线程彼此同步，这么做虽然不见得能提升代码性能，但是可以简化代码逻辑）。然而有些场合是不合适使用多线程的，最常见的两种场景是：**限制CPU使用率**和**线程代码中调用了`fork(2)`**。前者不用解释，后者道理也很简单，因为`fork(2)`这个系统调用只会复制当前调用了该系统调用的线程，而其它线程并不会原样复制。如果此线程执行路径上的某个互斥锁已被没有原样复制的线程持有，那么该线程将永远死锁。只复制当前线程的行为也很合理。因为其它线程可能等在IO上，可能持有某些互斥锁，这些都使得forkall这样的行为难以实现。除非立即在调用`fork(2)`后调用`exec(2)`，否则在线程代码里调用`fork(2)`可不是什么好主意。

其他的非必要场景也可以举一个例子，比如少量的CPU负载就能把IO跑满（静态web或者文件下载服务器）。这样的场景没有必要使用多线程，因为增加线程数也没有办法提高吞吐量。

<!-- more -->

下面的篇幅将从C++的线程类的基础、同步原语等角度来介绍C++11的并发线程相关的内容。

### 线程

C++的线程类是`std::thread`，包含`thread`头文件即可使用。下面是一个简单的例子：

```c++
#include <iostream>
#include <thread>

void thread_func()
{
    std::cout << "Thread running...\n";
}

int main(void)
{
    std::thread thd(thread_func);

    thd.join();

    return 0;
}
```

这里传入`std::thread`的是一个函数，这里的传入参数只要是Callable的对象就行，比如重载了函数调用符()的类或者lamada表达式均可，下面是一个使用lamada表达式作为线程函数的例子：

```c++
#include <iostream>
#include <thread>

int main(void)
{
    std::thread thd([]{ std::cout << "Thread running...\n"; });

    thd.join();

    return 0;
}
```

上面的例子中创建了线程对象后，其持有的线程在后台就已经自动运行了。代码中调用的是`join()`成员函数来等待线程结束，这样可以避免主线程结束后子线程被操作系统强制结束掉。另一个可选的方案是调用`detach()`来放弃对这个线程等待，使其成为一个后台线程/守护线程。这两个方案必选其一，以避免线程结束时资源未释放造成泄漏（尤其是局部创建的线程对象在其尚未执行到`join()`的时候因为异常或者其他错误直接跳出函数体导致的错误，这点可以用RAII惯用法封装对线程对象的资源释放操作）。

在向线程对象传递参数时，参数会以默认的方式被复制（copied）到内部存储空间。如果是普通变量或者指针不会有问题，但如果是引用参数，可能会出现与直觉不符的结果。解决方法是使用`std::ref`包装引用参数，熟悉`std::bind`的读者对这个并不陌生。好在现在编译器一般都会给出错误提示，使用引用参数的例子如下：

```
#include <iostream>
#include <thread>

void thread_func(int &sum)
{
    for (int i = 1; i <= 100; ++i) {
        sum += i;
    }
}

int main(void)
{
    int sum = 0;

    std::thread thd(thread_func, std::ref(sum));
    thd.join();

    std::cout << "sum is " << sum << std::endl;

    return 0;
}
```

`std::thread`的构造函数和`std::bind`依据相同的机制定义，也就是说`std::thread`也支持传入类的成员函数指针作为线程函数，当然也得先传入合适的类对象指针作为第一个参数。另外，`std::thread`是**可移动（movable）**而**非可复制（copyable）**的，可移动的支持同样考虑了`std::thread`对象的容器，只要STL容器是移动感知的即可。

最后，`std::thread::hardware_currency()`返回可以真正并行的线程数量，在一个多核的CPU上，这通常是CPU核心的数量。`std::this_thread`代表了当前执行的线程，比如想获取主线程的ID就可以调用`std::this_thread::get_id()`函数。

### 互斥锁

互斥锁作为同步原语的一种，用于对一段存在竞态条件（race condition）的代码进行保护，使得在同一时间只有一个执行逻辑可以执行该互斥锁保护的代码区域。C++11标准库提供了`std::mutex`实例来创建互斥锁。创建一个`std::mutex`的对象就创建了一个互斥锁，调用成员函数`lock()`可以加锁，调用成员函数`unlock()`可以解锁。但是在代码中直接调用这两个成员方法也会遇到上文中因为异常返回而导致没有调用`join()`函数的问题。C++标准库提供了`std::lock_guard`类模板实现了RAII惯用法。下面的代码简单演示了如何通过`std::mutex`和`std::lock_guard`来保护互斥的函数（代码来自cppreference）：

```c++
#include <thread>
#include <mutex>
#include <iostream>
 
int g_i = 0;
std::mutex g_i_mutex;
 
void safe_increment()
{
    std::lock_guard<std::mutex> lock(g_i_mutex);
    ++g_i;
 
    std::cout << std::this_thread::get_id() << ": " << g_i << '\n';
}
 
int main()
{
    std::cout << __func__ << ": " << g_i << '\n';
 
    std::thread t1(safe_increment);
    std::thread t2(safe_increment);
 
    t1.join();
    t2.join();
 
    std::cout << __func__ << ": " << g_i << '\n';
}
```

除了`std::lock_guard`，C++11标准库还定义了`std::unique_lock`来提供更多的灵活性。这将在后续阐述条件变量时详细介绍。另外`std::mutex`不是递归锁，已经持有某个锁的线程再次对该锁尝试加锁，就会导致未定义行为（undefined behavior）。如果设计中确实需要允许递归加锁的需求，C++标准库提供了`std::recursive_mutex`类型来支持递归锁。

熟悉C++实现单例模式的读者应该对二次检查锁定（Double-Checked Locking）并不陌生，这一用法很常见，所以C++11标准库提供了`std::once_flag`和`std::call_once`来处理这种情况。不过局部的static类对象初始化在新标准中已经是线程安全的操作，所以单例模式有更简单优雅的实现方式了：

```c++
static Singleton &instance()
{
    static Singleton singleton;
    return singleton;
}
```

初学者容易误解的是互斥锁真的是“锁”住了要保护的变量使其不被意外修改。事实上互斥锁本身和某变量或者某代码之前并无真正的关联，而是在代码逻辑上要保证互斥锁对临界区域的保护。也就是说，**不可以将受保护的变量的指针或者引用传递到锁的作用范围之外**。另外，互斥锁的数量和作用的临界区范围也很重要，锁定的粒度过大会抵消掉并发带来的性能优势。

最后，死锁问题也是使用互斥锁经常会遇到的，典型的场景简单说就是有不止一把互斥锁，两个执行线程当前各自持有一把锁，却又在等待对方已经持有的锁释放，这样永远都跳不出等待。如果避免不了要同时持有多个锁的话，那就按照固定的顺序去加锁，实际代码中可以比较锁对象的内存地址，先对内存地址小的锁加锁（但这无疑会增加维护的成本）。`std::lock`这个辅助函数用于对多个互斥锁进行加锁，从而避免因为加锁顺序造成的死锁问题。`mutex`头文件的其他类可以点击[这里](http://en.cppreference.com/w/cpp/header/mutex)。

### 条件变量

上面讲述线程的部分提到了`std::join()`函数来等待一个线程结束任务，但是很多时候需要的是确认执行线程是否完成某件事情或者满足了某个条件，这在多个线程相互协作完成一件事情时候尤其重要。典型的如生产者消费者队列：生产者线程添加任务或者数据，消费者线程执行任务或者消费数据。互斥锁可以实现对任务队列或者数据队列的并发访问保护，但是队列是否有数据就需要不断的查询。轮询永远是最低效的方案，这时候就需要新的机制来支持线程间互相通知和同步事件。C++标准库提供了条件变量（condition variables）和期值（future）这两个工具来处理此类问题。标准库有`std::condition_variable`和`std::condition_variable_any`两个实现，两者都需要和互斥锁配合一起工作。区别是前者仅支持`std::mutex`，后者可以与符合类似互斥锁最低标准的任何对象一起工作。扩展性总会由额外的执行代价或者资源代价来买单，所以如无特殊需求，使用前者即可。

下面是一个简单的任务队列，使用`std::condition_variable`来进行同步。

```c++
#include <deque>
#include <mutex>
#include <condition_variable>

template <typename T>
class BlockingQueue
{
public:
    BlockingQueue() { }
    ~BlockingQueue() { }

    // 添加任务
    void put(T task)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        queue_.push_back(task);
        notEmptyCond_.notify_one();
    }

    /// 取得任务
    T take()
    {
        std::unique_lock<std::mutex> lock(mutex_);
        // 避免虚假唤醒
        while (queue_.empty()) {
            notEmptyCond_.wait(lock);
        }
        T task(queue_.front());
        queue_.pop_front();

        return task;
    }

    // 获得队列长度
    size_t size() const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        return queue_.size();
    }

    // 判断队列是否为空
    bool empty() const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        return queue_.empty();
    }

private:
    mutable std::mutex mutex_;
    std::condition_variable notEmptyCond_;
    std::deque<T> queue_;
};
```

`std::lock_guard`和`std::mutex`的用法之前已经介绍过了。不过这里`take()`函数的实现中使用了`std::unique_lock`的这个新的RAII辅助类，这个类比`std::lock_guard`类提供了更大的灵活性，比如`lock()`、`try_lock()`和`unlock()`三个成员函数可以和其他类配合使用，而`std::lock_guard`只是一个纯粹的RAII类，没有额外的成员函数提供灵活性。

`std::condition_variable`在调用`wait()`时需要传入`std::unique_lock`的实例。这里的互斥锁用来保护要检查的条件（这里是检查队列是否为空），在条件不满足时需要等待，直到条件改变后被触发。注意执行到这里时是持有互斥锁的，所以`wait()`函数必须释放互斥锁，否则其他代码永远都无法使用共享数据了。待条件变量被触发后又要再次加锁访问共享数据，所以这里的实现就是这样的，还不理解的话可以研究下Linux pthread库的设计，相关的讨论可以看[这里](http://faq.0xffffff.org/question/2014/07/28/the-question-on-mutex-and-cond/)。

上面的代码例子中还需要注意这个代码片段：

```c++
// 避免虚假唤醒
while (queue_.empty()) {
    notEmptyCond_.wait(lock);
}
```

这里使用`while`而不是`if`的原因是可能存在虚假唤醒（spurious wake）的问题，这种虚假唤醒的频率和次数都是无法预知的，所以用`while`条件进行检查是最好的做法。或者代码可以直接更优雅的写成这样：

```c++
notEmptyCond_.wait(lock, [&]{return !queue_.empty()});
```

如果等待线程只打算等待一次，那么条件变量也许不是最佳的选择，如果等待的条件是诸如一个特定数据是否可用时，使用期值（future）可能会更合适。C++标准库使用期值来为这类一次性等待的场景建模，在`future`头文件里有两类期值：**唯一期值**（unique futures，`std::future<>`）和**共享期值**（shared futures，`std::shared_future<>`）。这两个类模板是参照`std::unique_ptr`和`std::shared_ptr`建立的。`std::future<>`实例是仅有的一个指向关联事件的实例，而多个`std::shared_future<>`可以指向同一事件。一旦事件发生，`future`就变为就绪，且无法复位。`future`对象本身不是线程安全的，如果多个线程需要访问同一个`future`对象则需要额外的互斥锁做同步，但是多个线程可以访问各自的`std::shared_future<>`副本而无需同步操作。

创建异步任务并返回`future`的方式有多种，最基本的就是`std::async`调用。在不需要立即得到执行结果的时候，可以使用`std::async`来创建异步的任务，其返回一个`std::future`对象，在需要结果时可以在`future`对象上调用`get()`，线程就会阻塞直到`future`就绪并返回该值。下面是一个简单的使用例子：

```c++
#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>
#include <future>
 
template <typename Iter>
int parallel_sum(Iter beg, Iter end)
{
    size_t len = end - beg;
    if (len < 1000)
        return std::accumulate(beg, end, 0);
 
    Iter mid = beg + len / 2;
    std::future<int> handle = std::async(std::launch::async, parallel_sum<Iter>, mid, end);
    int sum = parallel_sum(beg, mid);

    return sum + handle.get();
}
 
int main()
{
    std::vector<int> v(10000, 1);
    std::cout << "The sum is " << parallel_sum(v.begin(), v.end()) << '\n';
}
```

如果函数需要额外的执行参数，用法和`std::thread`一致，不再赘述。默认情况下，`std::async`是否启动新的线程和等待`std::future`时任务是否同步取决于实现，不过可以使用额外的参数来明确行为，`std::launch::deferred`表示函数调用将延迟，`std::launch::async`表示该函数运行在自己的线程上。

除了`std::async`，也可以将任务封装在`std::packaged_task<>`类模板的实例中，`std::packaged_task<>`将一个`future`绑定到一个函数或可调用对象上。当`std::packaged_task<>`对象被调用时，它就调用相关联的函数或可调用对象，将返回值作为关联数据存储，并且让`future`就绪。这个类从包装可调用对象的意义上看类似`std::function`，可以作为线程池的构件（将`std::packaged_task<>`对象传递到其他地方调用时可以先获取`future`，在需要知道调用结果时等待`future`就绪即可），也可以再次将`std::packaged_task<>`对象封装为一个`std::function`传递给`std::thread`作为线程函数。具体使用的例子和成员函数可以参阅[这里](http://en.cppreference.com/w/cpp/thread/packaged_task)。

有时候一些任务无法用一个简单的函数调用来实现，甚至执行结果需要来自多个任务合并后才可以。`std::promise`可以用来解决这个问题。当取得执行的结果时，可以调用`std::promise`的`set_value()`来设置最终的结果，同时`future`会变为就绪状态。其实说白了就是允许用户在合适的时候调用`set_value()`来自行让`future`变为就绪，而不是之前自动将函数返回值作为`future`的结果。具体的例子这里看[这里](http://en.cppreference.com/w/cpp/thread/promise)。

条件变量相关的内容介绍到这里就差不多了，之前涉及到的状态等待函数都是阻塞等待直到获取到执行结果为止。有时候需要限制等待的时间，比如代码执行时间有硬性限制，或者可以让线程去做其他任务来避免处理器资源浪费。C++标准库对以上的涉及到等待的函数都提供了基于时间的等待函数，一般有两类：**基于时间段的等待**（比如等待10ms）和**绝对的超时时间**（比如到2016年2月14日 21:46:12:012343454就超时返回）。前者的`wait`函数一般有`_for`后缀，后者一般是`_until`后缀。C++标准库的时间相关实现在`std::chrono`，具体信息可以看[这里](http://en.cppreference.com/mwiki/index.php?title=Special%3ASearch&search=chrono&button=)。

### 原子变量

提到原子变量，不得不提到C++11标准的内存模型。但是普通程序员一般不用关注这些细节，所以这里就不提这个了（其实是我自己都没完全搞清楚...就不现眼了），想了解的话看[这里](http://en.cppreference.com/w/cpp/atomic/memory_order)，还有[这里](https://www.zhihu.com/question/24301047)。

下面主要关注C++11标准库提供的原子变量相关的工具类。最简单的是`std::atomic_flag`类，这个类只提供了`test_and_set()` 和`clear()`两个API，具体使用可以参考[这里](http://en.cppreference.com/w/cpp/atomic/atomic_flag)。

功能更强大的原子模板类是`std::atomic`，这个类重载了常用的一些运算符，也使用typedef定义了很多常见类型的别名便于使用。使用方法很简单，不再赘述，成员函数可以参阅[这里](http://en.cppreference.com/w/cpp/atomic/atomic)。

参考资料：

- C++ Concurrency in Action，Anthony Williams 
- C++多线程网络编程，陈硕
- C++ reference，http://en.cppreference.com/w/

