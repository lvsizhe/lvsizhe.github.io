---
layout: post
categories: paper
title: 短作业调度器Sparrow
tags: scheduler
---

这是一篇出现在SOSP'13的论文，全文为《Sparrow: Distributed, Low Latency Scheduling》，在后面几年的研究文献中经常被引用，因此有必要简单的介绍一下，了解一下这篇文章的主体思路。

与通用调度器不同，Sparrow面向的场景主要是各种短作业的调度，这类作业的执行时间一般为百毫秒级别，这就会给调度器提出一些额外的要求。比如，调度器必须要具备极高的吞吐，否则集群的资源利用率就会受到影响；另外，调度延时必须非常的低(毫秒级)，不能造成过大的overhead；系统需要有极高的可用性，短暂的停滞都可能导致作业的执行受到明显的冲击。这些要求对传统的中心式的调度器来说，都是十分困难的，有必要另辟蹊径，寻找一种分布式的解决方案。Sparrow就是一种。

其实从文章的标题就可以知道，Sparrow的两大卖点：分布式、低延时。为做到这两点，Sparrow第一个采用的手段是**基于采样而非全貌信息的调度**。什么意思呢？比如我有一个job，需要启动m个task，那么Sparrow先随机的挑选出$$d \cdot m$$台机器、查询这些机器的负载状况，而后从中选取负载最低的m台将任务调度上去。文章的评估结果表明，$$d=2$$的时候，也就是对于每个task选择2个备选机器，其调度效果传统的全局选择达到的效果差不多了。这种做法带来的好处是显而易见的，首先不需要记录大量的信息，所需的信息通过临时向各个Worker查询即可，这就为分布式化奠定了基础；其次是简单，整个调度不需要大量计算，基本就是简单的随机选机器加一些比较逻辑就够了，这使得调度的速度非常的迅速。

如果我们仅仅是简单的采用上述“二选一”的策略，那么还是存在一些问题。比如，调度器如果简单的按照Worker排队的task数来定义负载程度，由于作业的执行时间并无法简单预估，这就可能导致一些机器上存在的执行较长的作业，阻塞住后面新调度的任务，而其他机器资源却被空闲了。典型的例子是，有两个Worker，第一个Worker上只有一个需要执行300ms的任务，而第二个Worker上有两个只需要执行50ms的任务。那么按照之前描述的算法，新作业会被调度到第一个Worker上而不是第二个，从而增加了100ms的排队延时。Sparrow通过**延后绑定(Lazy binding)**来解决这个问题。其思路也很简单，Sparrow的调度器并不是直接将task确定的指派给某个Worker执行，而是在被选出来的Worker中登记一个排队信息。当Worker空闲准备启动下一个任务的时候，通过这个排队信息，向调度器请求真正的task数据，然后调度器会让第一个请求启动成功。通过这种简单的方式，可以显著的减少task在Worker处排队等待的时间。

另外，Sparrow还有一些篇幅在将如何解决诸如资源限制方面的问题，感兴趣的可以阅读完整的文章。笔者认为，Sparrow并非通用的调度器，但是这篇文章可以给我们一些好的启发。比如，我们现在大量的调度算法，其基本思路都是尽量逐个的做好每个task的调度。但事实上，**调度追求的不是每个task的最优化，而是全局统计层面的最优**。有时候一些简单的、考虑了概率分布情况的算法，就能够让全局的分布接近理想的水平（比如Sparrow的"二选一"策略)，并且由于其算法的简单，可以显著提升调度器的执行效率。这未尝不是一个好的解决问题的方向。
