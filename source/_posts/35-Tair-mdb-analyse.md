title: Tair mdb 存储引擎的实现
date: 2015-03-28 16:00:00
tags:
- tair
- 源码分析
categories: 源码分析
toc: false
---

[Tair](http://tair.taobao.org/)是一个高性能、分布式、可扩展、高可靠的NoSQL存储系统。本文基于Tair v3.1.2.43版本，探究其mdb存储引擎的实现。

Tair目前有mdb、ldb和rdb等存储引擎。其中mdb是Tair最早的一款内存型产品，也是在公司内部应用最广泛的集中式缓存。特别适用容量小（一般在M级别，50G之内），读写QPS高（万级别）的应用场景。由于是内存型产品，因此无法保证数据的安全性，对数据安全有要求的应用建议在后端加持久化数据源（例如MySQL）。本文接下来详细讨论Tair mdb存储引擎的实现。

Tair的存储引擎接口是`src\storage\storage_manager.hpp`里的虚基类`storage_manager`。所有的Tair存储引擎均继承实现了`storage_manager`这个虚基类。`src\dataserver\tair_manager.cpp`文件中的`tair_manager::initialize`函数根据配置文件中`storage_engine`的设置初始化相应的存储引擎。

![](/images/35/1.png)

![](/images/35/2.png)

<!-- more -->

mdb引擎默认使用POSIX共享内存的方式进行内存的分配和管理。mdb引擎会在初始化的时候创建或者使用已存在的共享内存。其配置使用内存的方式和共享内存命名的前缀均在其配置文件中进行设置。如图所示：

![](/images/35/3.png)

`src\storage\mdb`目录是mdb存储引擎的实现，这里的实现、测试和接口文件都放在同一个目录中。其中有关mdb存储实现的文件如下：

	◇ db_define.{hpp,cpp} —— mdb引擎相关的配置信息和定义。
	◇ mdb_factory.{hpp,cpp} —— mdb引擎初始化工厂类的实现。
	◇ mdb_manager.{hpp,cpp} —— mdb引擎管理结构的实现。
	◇ mdb_instance.{hpp,cpp} —— mdb实例相关的实现。
	◇ mem_cache.{hpp,cpp}  —— MemCache结构的实现。
	◇ mem_pool.{hpp,cpp} —— MemPool结构的实现。
	◇ cache_hashmap.{hpp,cpp} —— 全局缓存KV结构映射的Hash表的实现。
	◇ mdb_stat_manager.{hpp,cpp} —— mdb引擎状态管理相关实现。
	◇ mdb_stat.hpp —— mdb引擎读取写入统计的相关数据结构的定义和实现。
	◇ lock_guard.hpp —— pthread_mutex_t的简单RAII封装。

其中`mdb_define.{hpp,cpp}`里定义了mdb引擎的配置变量，打开共享内存的操作函数以及获取时间、判断当前时间的hour是否在给定区间等函数。

`mdb_factory.{hpp,cpp}`用于创建mdb引擎，`mdb_factory.hpp`中定义的接口如下：

![](/images/35/4.png)

create_mdb_manager读取配置文件中的配置信息，然后创建`mdb_manager`对象并返回。这个函数在`src\dataserver\tair_manager.cpp`文件中的`tair_manager::initialize`函数中被调用。

`mdb_manager.{hpp,cpp}`定义了mdb引擎管理类`mdb_manager`的实现，`mdb_manager`类继承自`storage_manager`虚基类，实现了相关的虚函数接口。其定义`std::vector<mdb_instance*>`结构保存所有的mdb实例。`mdb_instance`类在`mdb_instance.{hpp,cpp}`中定义和实现。`mdb_manager`类的`initialize`函数会调用`init_area_stat`函数创建/打开名为`mdb_param::mdb_path+".stat`这个存储mdb引擎状态信息的共享内存块，其大小为`TAIR_MAX_AREA_COUNT * sizeof(mdb_area_stat)`。然后会根据配置文件里的实例个数信息创建`mdb_instance`实例。配置如下：

![](/images/35/5.png)

`mdb_instance`创建时会创建名为`mdb_param::mdb_path+".000"`开始计数的共享内存块。创建的实例中bucket的个数由以下配置决定：

![](/images/35/6.png)

`mdb_instance` 、`mem_cache`、`mem_pool`、`cache_hashmap`这几个类构成了mdb存储引擎的核心。创建完成后，其包含指向关系如下：

![](/images/35/7.png)

对应的内存结构图大致如下：

![](/images/35/8.png)

其中MemPool以页的形式管理通过共享内存分配的内存，分配或者释放一个内存页。其定义了`uint8_t page_bitmap[BITMAP_SIZE]`，以位的形式来管理内存页；MemCache比页低一级，采用slab算法将内存分配给具体的item；HashTable以一个巨大的Hash表存储key的映射关系。下面阐述对共享内存具体的分配情况。内存布局如图所示：

![](/images/35/9.png)

cache meta的结构如下：

![](/images/35/10.png)

hash buckets的结构如下：

![](/images/35/11.png)

slab use这里，当前的代码实际上仅放置了一个mdb_cache_info：

![](/images/35/12.png)

下面是内存管理结构中的一些定义：

`mdb_id`的定义：

![](/images/35/13.png)

其中`item_id`的图示如下：

![](/images/35/14.png)

一些换算关系如下：

	page_addr = S0 + (page_id * page_size)
	item_addr = S0 + (page_id * page_size) + sizeof(page_info) + (slab_size * offset_in_page)

最后是slab分配器和K/V存储相关的细节。`mem_cache`类使用`slab_manager`类对从`mem_pool`中申请到的内存页进行管理。页信息的结构定义如下：

![](/images/35/15.png)

`mem_cache`里的pages被放置在三个链表中，分别是Free页链表、Full页链表和Partial页链表。Free页链表、Full页链表是简单的双向链表，用于链接空页和满页。Partial页链表如下图：

![](/images/35/16.png)

下图是不同的Area里放置item的图示：

![](/images/35/17.png)

最后剩下的`mdb_stat_manager.{hpp,cpp}`和`mdb_stat.hpp`定义和实现了访问统计相关的功能，其创建的共享内存块为相应的mdb实例的名称+"mdbstat"，此处不再赘述。
