title: 《Linux 多线程服务端编程》总结备忘
date: 2014-01-09 15:09:00
tags:
- Linux
- 多线程
categories: 读书笔迹
toc: false
---

**§ 1 线程安全的对象生命期管理**

- 对象的生与死不能由对象自身拥有的mutex（互斥器）来保护。如何避免对象析构时可能存在的race condition（竞态条件）是C++多线程编程面临的基本问题。

-  当一个对象被多个线程同时看到，那么对象的销毁时机就会模糊不清，可能出现多种的race condition（竞态条件）：
    - 即将析构一个对象时，从何而知此刻是否有别的对象正在执行该对象的成员函数？
    - 如何保证在执行成员函数期间，对象不会被另一个线程所析构？
    - 在调用某个对象的成员函数之前，如何得之这个对象还活着？它的析构函数是否会碰巧执行到一半？

-  一个线程安全的class应当满足下面三个条件：
    - 多个线程同时访问时，其表现出正确的行为。
    - 无论操作系统如何调度这些线程，无论这些线程的执行顺序如何交织（interleaving）。
    - 调用端代码无需额外的同步或其它协调动作。

-  按照以上定义，C++标准库中的大多数类都不是线程安全的，包括std:string、std::vector、std::map等，这些class通常需要在外部加锁才能供多个线程同步访问。

<!-- more -->

-  对象构造要做到线程安全，唯一的要求是在构造期间不要泄漏this指针，即：
    - 不要在构造函数中注册任何回调。
    - 不要在构造函数中把this指针传给跨线程的对象。
    - 即使是构造函数最后一行也不行（如果该类是一个基类，基类会先于派生类构造，执行完父类构造函数的最后一句后会接着执行子类的构造函数，这时most-derived class的对象还处于构造中，仍然不安全）。

-  一个函数如果要锁住相同类型的多个对象，为了始终按照相同的顺序加锁，我们可以比较mutex对象的地址，始终先加锁地址较小的对象。

-  一个对象在析构的时候，调用它的任何非静态函数都是不安全的。

-  scoped_ptr/shared_ptr/weak_ptr都是值语义，要么是栈上对象，或者是其它对象的直接数据成员，其“计数”操作在主流平台上的实现都是原子操作。

-  注意shared_ptr本身不是线程安全的，它的引用计数本身是安全无锁的，但对象的读写却不是。如果多个线程要读写同一个shared_ptr，那么需要加锁。

-  如果对象的析构比较耗时，我们可以用一个单独的线程专门做析构，通过一个BlockingQueue<shared_ptr<void>>把对象的析构都挪到专门的析构线程。

-  分析可能出现的rece condition不仅是多线程编程的基本功，也是分布式系统设计的基本功，需要反复历练，形成一定的思考范式，并积累一些经验教训，才能少犯错误。

-  用流水线、生产者消费者、任务队列等这些有规律的机制，最低限度的共享数据。这是我已知的最好的多线程编程的建议了。

**§ 2 线程同步精要**

-  并发编程有两种基本模型，一种是message passing（消息传递），另一种是shared memory（共享内存）。在分布式系统中，运行在多台机器的多个进程的并行编程只有一种实用的模型：message passing。

-  线程同步的四项重要原则：
    - 首要原则是最低限度的共享对象，减少需要同步的场合。
    - 其次是尽量使用高级的并发编程构建，如TaskQueue、Producer-Consumer Queue等等。
    - 最后不得已必须使用底层同步原语（primitives）时，只用非递归（不可重入）的互斥器和条件变量，慎用读写锁，不要用信号量。
    - 除了使用atomic整数之外，不要再自己编写lock-free代码，也不要使用内核级的同步原语，不凭空猜测哪种效率可能会更好。

-  互斥器（mutex）注意点：
    - 用RAII手法封装mutex的创建、销毁、加锁、解锁操作。
    - 只使用不可重入的mutex（非递归）。
    - 不手工调用lock()和unlock()函数，一切交给栈上的Guard对象的构造和析构函数负责。Guard对象的生命期正好等于临界区。
    - 在每次构造Guard对象的时候，思考栈上已经持有的锁，放置因为加锁顺序所导致的死锁（deadlock）。
    - 不使用跨进程的mutex，进程间通信只使用TCP Sockets。
    - 加锁/解锁在同一个线程里进行，线程a不能去unlock线程b已经锁住的mutex（RAII自动保证）。

-  Linux下mutex的一个封装实例：

```c++
// Mutex.h
 
#ifndef MUTEX_H_
#define MUTEX_H_
 
#include <pthread.h>
 
#include "noncopyable.h"
    
/**
 * 原始互斥锁的封装
 */
class MutexLock : private noncopyable
{
public:
    MutexLock();
    ~MutexLock();
 
    /// 加锁函数（仅允许 MutexLockGuard 类调用）
    void lock();
 
    /// 解锁函数（仅允许 MutexLockGuard 类调用）
    void unlock();
 
    /// 返回原始互斥锁类型的指针（仅允许 Condition 类调用）
    pthread_mutex_t *getPthreadMutex();
 
private:
    pthread_mutex_t mutex_;
};
 
/**
 * MutexLock 互斥锁的加/解锁类
 */
class MutexLockGuard : private noncopyable
{
public:
    /// 构造函数自动加锁
    explicit MutexLockGuard(MutexLock &mutex) : mutex_(mutex)
    {
        mutex_.lock();
    }
 
    /// 脱离作用域的时候自动解锁
    ~MutexLockGuard()
    {
        mutex_.unlock();
    }
 
private:
    MutexLock &mutex_;
};
 
/**
 * 下面的宏防止出现诸如 MutexLockGuard(mutex) 的定义
 * 正规做法是 MutexLockGuard lock(mutex)
 */
#define MutexLockGuard(x) static_assert(false, "missing mutex guarg var name!")
 
#endif // MUTEX_H_
```
```c++
// MutexLock.cpp
#include "MutexLock.h"
 
MutexLock::MutexLock()
{
    pthread_mutexattr_t attr;
    
    pthread_mutexattr_init(&attr);
    /// 初始化互斥锁类型为 PTHREAD_MUTEX_NORMAL
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
    pthread_mutex_init(&mutex_, &attr);
    pthread_mutexattr_destroy(&attr);
}
 
MutexLock::~MutexLock()
{
    pthread_mutex_destroy(&mutex_);
}
 
void MutexLock::lock()
{
    pthread_mutex_lock(&mutex_);
}
 
void MutexLock::unlock()
{
    pthread_mutex_unlock(&mutex_);
}
 
pthread_mutex_t *MutexLock::getPthreadMutex()
{
    return &mutex_;
}
```

-  条件变量（condition variable）用于一个或者多个线程等待某个布尔表达式为真，即等待别的线程“唤醒”它，条件变量的学名叫管程（monitor）。对于wait端：
    - 条件变量必须与mutex一起使用，该布尔表达式的读写需受此mutex保护。
    - 在mutex已经上锁的时候才能调用wait()。
    - 把判断布尔条件和wait()放到while循环里（避免虚假唤醒（suprious wakeup））。
    - 对于signal/broadcast端
    - 不一定要再mutex已经上锁的情况下调用signal（理论上）。
    - 在signal之前一定要修改布尔表达式。修改布尔表达式的时候需用mutex保护。
    - 注意区分signal和broadcast。

- Linux下condition封装的一个实例：

```c++
// Condition.h
 
#ifndef CONDITION_H_
#define CONDITION_H_
 
#include <pthread.h>
 
#include "noncopyable.h"
#include "MutexLock.h"
 
/**
 * 条件变量的封装类
 */
class Condition : private noncopyable
{
public:
    /// 构造函数
    explicit Condition(MutexLock &mutex) : mutex_(mutex)
    {
        pthread_cond_init(&pcond_, NULL);
    }
 
    /// 析构函数
    ~Condition()
    {
        pthread_cond_destroy(&pcond_);
    }
 
    /// 等待该条件变量
    void wait()
    {
        pthread_cond_wait(&pcond_, mutex_.getPthreadMutex);
    }
 
    /// 通知一个等待该条件变量的线程
    void notify()
    {
        pthread_cond_signal(&pcond_);
    }
 
    /// 通知所有等待该条件变量的线程
    void notifyAll()
    {
        pthread_cond_broadcast(&pcond_);
    }
 
private:
    MutexLock &mutex_;
    pthread_cond_t pcond_;
};
 
#endif // CONDITION_H_
```

-  真正影响性能的不是锁，而是锁争用（lock contention）。

-  必须用单线程的场合：
    - 程序有可能会fork(2)；
    - 限制程序的CPU使用率。

-  多线程的适用场景是：提高响应速度，让IO和“计算”相互重叠，降低latency。虽然多线程不能提高绝对性能，但能提高平均响应性能。
