---
layout: post
categories: paper
title: 大数据领域经典系统之FlumeJava
tags: distributed-system google bigdata
---

发现接近有一年没有更新这个blog了，这一年里面变化了很多，最大的是成为了父亲、有了一个聪明可爱的女儿，另外也在年中的时候更换了工作。剧烈的身份变化，使得纯粹的技术学习有些停滞，因此准备重新捡起，继续找回之前的状态，希望自己能恢复到半月一更新的状态。

今天主要介绍的是Google在2010年PLDI上发表的经典文献《FlumeJava: Easy, Efficient Data Parallel Pipelines》文章[^1]。也许是因为FlumeJava是Google的内部系统并未开源，该文章比较少人知道，但我认为这片文章的重要性不亚于其他文章，主要体现在以下几个方面：
* 文章提出的对大数据处理的基本算子的抽象，对后续系统的API设计有很大的影响。比如ParallelDo, GroupByKey, CombineValue, Flatten等，相信很多人在后续系统中反复见到类似的接口；
* 文章提出的defer evaluation加optimization的模式，对后续系统设计影响不小。后续系统中的spark和tensorflow，都有类似设计，我怀疑后续系统设计借鉴了这篇文章的思想；
* 如果关注google的大数据处理系统的进展历史，就会发现这是一篇承上启下的文章。可以从这篇文章中看出，Google的大数据处理系统，是如何从简单的MR模型，转变为后面相对复杂的Dataflow/Beam Model的，是Google大数据系统演化中的“白垩纪“。

---

## 背景介绍

Google的MapReduce系统被广泛使用后，大家很快就会发现在实际业务场景中，单一MR作业是不足以表达业务需求的，而需要将多个MR任务组合成pipeline。这个pipeline会导致业务逻辑被碎片化的拆散到众多的MR作业中，复杂度就相当的高。开发者在维护的时候，一方面需要从众多的MR作业中反向工程出pipeline的原始意图，另一方面又需要艺术性的打碎逻辑到MR作业中以优化pipeline中的各阶段任务的内容，处于非常撕裂的状态。另外，开发者除了维护业务逻辑本身之外，还需要处理诸如局部MR任务执行失败、跨MR任务的数据传递、中间数据生命周期管理等工程问题。

为解决这个问题，有必要在简单的MR任务之上，增加一个管理层，去表达、调度这一系列的MR任务和其涉及的数据input/output。FlumeJava的定位就在于此，该系统首先定义了一种新的“大数据处理语言”，用户通过这个语言表达出对数据的处理逻辑，由系统将其“编译”成DAG图，并基于DAG图执行优化算法，最后将其分解成若干个子MR任务，交给下层MR系统调度执行。

因此，整篇论文的核心处理问题包括两个：
* 如何设计这门大数据语言，以表达出应用千变万化的业务场景？
* 如何对构建好的DAG进行优化，并最终分解成一系列的MR作业？

## 算子抽象

对于第一个问题，文献首先抽象定义了dataset的基础数据类型 _PCollection\<T\>_ 和 _PTable\<T\>_ ，而后，可以将各种对数据的处理，抽象成在 _PCollection\<T\>_ 或者 _PTable\<T\>_ 上执行定义的基本操作。这些基本操作包括：
* **ParallelDo()**: 将 _PCollection\<T\>_ 经计算转换成 _PCollection\<S\>_ ，_PCollection\<T\>_ 中的每一条数据，可以计算产出0或n条S类型的输出。这个计算类似于我们熟知的map;
* **GroupByKey()**: 基于multi-map的 _PTable\<K, V\>_, 生成 _PTable\<K, Collection\<T\>\>_，即将同key的数据放置在一起；
* **CombineValue()**: 将输入为 _PTable\<K, Collection\<T\>\>_, 计算得到 _PTable\<K, V\>_，类似于MR中的Reduce操作；
* **flatten()**: 合并多个 _PCollection\<T\>_ 的数据集，返回合并后的 _PCollection\<T\>_.

大多数的大数据处理计算需求，可以分解成上述基本抽象予以表达。出于使用方便考虑，框架使用上述operator实现了类似count()、join()等一些经常反复出现的操作。感兴趣的可以自己琢磨下这些功能如何实现，并不会太难。

## 图优化

当用户使用FlumeJava提供的上述抽象接口，写出自己对数据的处理流程后，FlumeJava框架并不会立即运行进行数据处理，而是将用户的调用顺序记录下来，生成一个DAG图。在这个图中，节点是上述的基本operator，而边则记录了这些节点执行的数据传递关系。这个过程称为defer evaluation，目标是通过抽象手段表达出计算的整个过程。

在实际开始处理数据之前，框架需要做两件事情：
* 对这个DAG图进行分析优化，以提高整个pipeline的处理效率；在这篇文章中，主要是通过ParallelDo Fussion、Sink Flatten、Lift CombineValue来做的；
* 生成MR作业，以便提交给下层的MapReduce系统执行。文章中主要是通过MSCR Fussion识别算法来完成。

### ParallelDo Fusion

所谓Fussion，就是在DAG图中，将若干个相关的节点合并成一个等价效果的复合节点，对DAG图进行简化。其中，ParallelDo Fussion是最容易、最直观的。

PrallelDo Fussion包括两种，一种是produce-consumer形态，假如其中给一个ParallelDo执行了函数$$f$$，其输出被另一个ParallelDo函数$$g$$处理了，那么，我们可以合并这两个节点，让其执行$$g \circ f$$。另一种Fusion是sibling fusion，当一个输入数据，被多个并列的算子处理，那么我们可以将这些sibling operator合并成一个算子，让这个合并后的算子产出多路输出，这样也能显著减少DAG的复杂度。

![paralleldo-fussion]({{site.url}}/images/paralleldo-fussion.png){:width="40%"}

比如上图，经过这两种Fusion后，可以将A、B、C、D四个算子合并成一个A+B+C+D的复合算子。

### Sink Flatten

flatten的主要工作是合并数据集，有些情况下可以将flatten推迟到ParallelDo操作之后以获得性能收益。简单的说，对于函数$$h(f(a) + g(b))$$（这里$$+$$是Flatten）我们可以尝试变换成$$h(f(a)) + h(g(b))$$，这样一来，就可以运用ParallelDo Fussion进一步处理成$$(h \circ f)(a) + (h \circ g)(b)$$；或者在某些情况下，经过函数$$h$$计算的产出数据集规模更小，可以减小需要传输的数据的规模。

### Lift CombineValue

如果一个CombineValue函数，满足交换律和结合律[^2]，那么可以考虑将CombineValue拆分成两段，即先进行局部Combine、再在局部Combine结果的基础上进一步Combine出最终结果。典型的如WordCount，用户可以在每个Map端先做一个局部的计数，计算得到在这个Map task中的计数结果，而后再将这个中间统计结果发送到Reduce端进行汇总得到最终结果。

### MSCR Fussion

MSCR是MapShuffleCombineReduce的缩写，也就是一个MSCR其实就是一个MapReduce任务。MSCR Fussion将首先找出Related GroupByKey算子(shuffle)，然后向前推进融合前趋的ParallelDo(map)算子、向后推进融合后继的CombineValue和ParallelDo(reduce)，然后将这些圈入的算子合并成一个大的MSCR节点、并计算相关的Input/output Channel与剩余部分对街上。每一个这样的fussion节点，后续就会作为一个MR作业提交给下层的MapReduce系统执行。

在这里，所谓的Related GroupByKey，指的是这些GBK算子，在输入的数据集合上存在交集、且从Input到GBK节点中，仅经过Flatten或者ParallelDo算子[^3]。大家可以把数据想像成某种染色的液体，沿着DAG图往下流动，只有Fltten和ParallelDo两个节点是通的，如果GBK被染上了相同的颜色，则这几个GBK就是related的；对于多个数据源的场景，我们可以将相交GBK集合合并成更大的集合，以进一步减少MSCR Fussion节点的数量。

## 小结

大多数系统用户只是拿着相关的系统，做着CRUD的事情，比较少去关注系统的设计思路。如果多看一些系统设计，就会有一种感觉，这些系统的内部设计逻辑有很多互通的地方。比如这篇文章Defer Evaluation的思路，在Spark和TensorFlow中都出现了。而Defer Evaluation的思路，其实又来自于Compilier的设计。就像地球上的生态系统一样，计算机系统也在交换着各自的”基因片段“（核心设计思路）、繁衍出不同的后代，并在不同的场景下竞争、适者生存。我们读系统设计，很多时候是要找到、学习这些”片段“，把它”杂交“到自己当下正在面对的场景中去。

另外，相信许多人在读完这篇文章后，会对其中的optimization算法感兴趣。我相信在许多计算引擎中，都有类似的构建，比如TensorFlow中基于AutoGraph、矩阵运算规则进行优化等。我现在猜想这类算法的基本处理过程是在graph上运行某种模式匹配算法，找到复合规则集中的子图结构，然后估算打分后择优变换。但总感觉会有些问题，比如打分时依赖的统计数据可能需要执行期才能获得、执行过程中变换如何保证正确性？找pattern的这个过程有没有什么高效算法、rule集合如何表达易于扩展等。后面有机会的话，我想找下时间做一下专题调研，系统性的看一下这些问题。


---
[^1]: 前阵子阅读了《Streaming System》这本书，书的最后一个章节对整个大数据处理领域出现过的一些重要系统，进行了一个概要性的介绍。该章节中的一些引用资料，如果顺着阅读下来，能够了解大数据处理领域10多年来的关键进展。因此打算follow这个章节读一下这些材料，并对有感觉的文献做一些阅读笔记。
[^2]: 满足交换律，意味着输入的顺序不重要；而满足结合律，则意味着可以按照需要自由组合进行计算。在分布式系统中，具备这两个性质的算子显得非常友好。比如系统要对计算$$a+b+c+d$$，假设a和c、b和d分别在两台机器上，那么可以理解为先运用交换律调换计算顺序为$$a+c+b+d$$后，再运用结合律得到$$((a+c)+(b+d))$$。
[^3]: 因为经过Sink Flattern和ParallelDo Fussion后，路径中的节点可以变换成唯一的一个function，也就是map。


