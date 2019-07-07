title: sigslot 库源码分析
date: 2015-01-14 11:38:00
tags:
- 源码分析
- c++
categories: 源码分析
toc: false
---

最近一直在忙毕设的事情，博客都快被遗忘了。最近正好在研究sigslot库，索性晚上写点源码分析的水文充充数。

言归正传，sigslot是一个用标准C++语法实现的信号与槽机制的函数库，类型和线程安全。提到信号与槽机制，恐怕最容易想到的就是大名鼎鼎的Qt所支持的对象之间通信的模式吧。不过这里的信号与槽虽然在概念上等价与Qt所实现的信号与槽，但是采用的仅仅是标准C++语法，不像Qt采用了扩展C++语言的方式（Qt需要使用moc工具对代码预处理之后，才能由标准的C++编译器进行编译）。

众所周知，C++是一门特性众多的语言，其支持多种编程范式。虽然C++在一定程度上支持OOP编程，但是C++这种“静态消息机制”的语言一直没有实现对象级别的delegate机制，而C++之父Bjarne主张的“库扩展胜于语言扩展”的做法使得各种解决方案层出不穷。除了信号与槽机制，C++11正式加入的std:bind/std::function组合也提供了优秀的解决方案。这里所说的信号与槽机制也是一种对象间通信的机制，具体的讨论也可以看看sigslot相关介绍中的内容。

> sigslot主页: http://sigslot.sourceforge.net

> sigslot文档: http://sigslot.sourceforge.net/sigslot.pdf

sigslot库的用法文档中已然很明了了，所以在这里就不赘述了。接下来我们看看这个库的实现。源码分析的方法有很多种，具体到库代码的分析的方法，我喜欢的是先研究库的功能，直到能写出一个demo程序为止。研究一个库的前提是你得会用它，熟悉它的接口。读完文档，很容易就写出了下面的测试代码：

<!-- more -->

```c++
#include <iostream>
#include "sigslot.h"

using namespace sigslot;

class Switch
{
public:
    signal0<> clicked;
};

class Light : public has_slots<>
{
public:
    void turn_on()
    {
        std::cout << "Turn on ~" << std::endl;
    }
};

int main(int argc, char *argv[])
{
    Light lit1;
    Switch swh;

    swh.clicked.connect(&lit1, &Light::turn_on);
    swh.clicked.emit();

    return 0;
}
```

使用方法很简单。从这里我们就能看出来，这个库无非就是在信号那一端保存了这个信号所绑定的函数指针，在槽函数这一端保存了其绑定的信号而已。接下来的问题实际上就是采用合理的数据结构来处理问题了。

sigslot库简单到只有一个头文件sigslot.h，打开后洋洋洒洒几千行代码，其实仔细看看绝大多数代码都是为了适应参数数量不同的成员函数指针的定义，为其扩展的模版代码。从定义上看，这个库支持0~8个参数的成员函数绑定。在纸上画一下类的继承关系，很容易就得到了如下的函数继承图（IDE有相关的工具也可以拿来用~）:

![](/images/34/1.png)

从这个图上看，其实代码关系已经很清晰了。实现了槽函数的类需要继承`has_slots`类。而`has_slots`类拥有一个`std::set<_signal_base<mt_policy>*>`类型的容器（所有的`mt_policy`其实是库定义的三种锁策略而已[单线程无锁、多线程共享全局锁、多线程局部锁]）。所有的`_signal_base[0-8]`的类持有各自的`std::list<_connection_base[0-8]<mt_policy>>`的list容器，而`_connection_base[0-8]`则分别封装了0~8个参数的成员函数的指针。

这里的重复代码是很多的，作为分析的话完全可以每中类代码只留下一个，这样所有的代码就精简到只有6个类了（反正别的也只是为了适应参数个数写的模版罢了，代码除了参数个数外都是一样的）。

至于前面说到的锁，其实也只是因为C++ STL库中的容器本身不是线程安全的，需要在外部加锁。锁的实现很平常，另外用C++ RAII手法封装的lock_block类也是常见的用法。唯一需要注意的是，这个库在使用了信号与槽的用户类发生了拷贝构造时，其信号与槽的绑定关系也会被拷贝，所以代码中的类都自行编写了相关的拷贝构造函数。这里稍微解释下，如果A类的a对象的x信号和B类的b1对象的y函数绑定，然后用b1初始化构造b2（即 B b2(b1)）。这时候，A类的a对象的x信号也会绑定到b2对象的y函数。这个特性我感觉有点莫名其妙，而且使得代码复杂了不少（我觉得没必要这么设计，用户需要这个特性的话，自己再调用一次绑定函数就是了）。

知晓了基本的原理之后，看代码就很容易了。比如在拥有信号和拥有槽函数的对象析构时，会自动的取消掉之前的绑定，代码很清晰易读的。下面是我自己根据sigslot的原理，简化出来的代码，大家可以先看看然后去读sigslot的源码会简单很多。

代码如下（去掉了复制拷贝和锁相关的代码，线程不安全，仅供参考）：

```c++
#ifndef _SIGNAL_SLOT_H__
#define _SIGNAL_SLOT_H__

#include <set>
#include <list>

namespace signalslot {

// 前置声明 has_slots 类
class has_slots;

// 连接管理信息虚基类
class _connection_base
{
public:
    virtual has_slots *getdest() const = 0;
    virtual void emit() = 0;
};

// 信号的虚基类
class _signal_base
{
public:
    virtual void slot_disconnect(has_slots *pslot) = 0;
};

// has_slots 类
// 所有实现了槽函数的用户代码必须继承自该类
class has_slots
{
    typedef std::set<_signal_base *> sender_set;
    typedef sender_set::const_iterator const_iterator;

private:
    sender_set senders_;

public:
    has_slots()
    { }

    virtual ~has_slots()
    {
        // 含有信号与槽的对象析构时，断开所有连接的信号与槽
        disconnect_all();
    }

    // 当含有槽函数的对象被拷贝时只对槽数据进行初始化
    // 不拷贝信号和槽的绑定关系
    has_slots(const has_slots &)
    { }

    // 断开所有连接的信号与槽
    void disconnect_all()
    {
        const_iterator it = senders_.begin();
        const_iterator end = senders_.end();
        while (it != end) {
            (*it)->slot_disconnect(this);
            ++it;
        }
        senders_.clear();
    }

    // 仅供信号相关的类回调，不允许用户调用
    void signal_connect(_signal_base *sender)
    {
        senders_.insert(sender);
    }

    // 仅供信号相关的类回调，不允许用户调用
    void signal_disconnect(_signal_base *sender)
    {
        senders_.erase(sender);
    }

};

// 封装了一个类和其成员函数的指针
template <typename dest_type>
class _connection : public _connection_base
{
private:
    // 泛型类指针
    dest_type *pobject_;

    // 泛型成员函数指针
    void (dest_type::*pmemfun_)();

public:
    _connection(dest_type *pobject, void (dest_type::*pmemfun)())
    {
        pobject_ = pobject;
        pmemfun_ = pmemfun;
    }

    virtual has_slots *getdest() const
    {
        return pobject_;
    }

    virtual void emit()
    {
        (pobject_->*pmemfun_)();
    }
};

class signal : public _signal_base
{
    typedef std::list<_connection_base *> connections_list;
    typedef connections_list::const_iterator const_iterator;

protected:
    connections_list connected_slots_;

public:
    signal()
    { }

    // 信号对象销毁时自动断开所有槽函数的连接
    ~signal()
    {
        disconnect_all();
    }

    // 当含有信号的对象被拷贝时只对信号进行初始化
    // 不拷贝信号和槽的绑定关系
    signal(const signal &)
    { }

    void disconnect_all()
    {
        const_iterator it = connected_slots_.begin();
        const_iterator end = connected_slots_.end();
        while (it != end) {
            (*it)->getdest()->signal_disconnect(this);
            delete *it;
            ++it;
        }
        connected_slots_.clear();
    }

    template <typename desttype>
    void connect(desttype *pclass, void (desttype::*pmemfun)())
    {
        _connection_base *conn = new _connection<desttype>(pclass, pmemfun);
        connected_slots_.push_back(conn);

        pclass->signal_connect(this);
    }

    void disconnect(has_slots *pclass)
    {
        const_iterator it = connected_slots_.begin();
        const_iterator end = connected_slots_.end();
        while (it != end) {
            if ((*it)->getdest() == pclass) {
                delete *it;
                connected_slots_.erase(it);
                pclass->signal_disconnect(this);
                return;
            }
            ++it;
        }
    }

    void emit()
    {
        const_iterator it = connected_slots_.begin();
        const_iterator end = connected_slots_.end();
        while (it != end) {
            (*it)->emit();
            ++it;
        }
    }

    void operator()()
    {
        emit();
    }

    void slot_disconnect(has_slots *pslot)
    {
        const_iterator it = connected_slots_.begin();
        const_iterator end = connected_slots_.end();
        while (it != end) {
            if ((*it)->getdest() == pslot) {
                connected_slots_.erase(it);
            }
            ++it;
        }
    }

};

} // namespace signalslot

#endif // _SIGNAL_SLOT_H__
```

