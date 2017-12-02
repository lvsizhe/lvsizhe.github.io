---
layout: post
title: 延时敏感服务QoS根因分析
categories: paper
tags: isolate
---

这两三个月的周末，基本保持隔周外出的节奏，再加上需要处理搬家的事情，一直没有时间静下心来阅读论文。这个周末终于有时间了，赶紧阅读了积压了需求的这篇论文。

论文的标题叫《Reconciling High Server Utilization and Sub-millisecond Quality-of-Service》，发表于2014年的EuroSys会议上。和前面介绍的Paragon一样，文章也是试图解决混布场景下，延时敏感(lentency-sensitivy)服务的质量问题。Paragon主要通过集群调度的模式，避免将发生干扰的进程放在同一台服务器上。而这篇论文的思路和侧重点不同，主要通过memcached实验分析了发生服务延时的底层原因，然后通过制定单机策略加以解决。

<br>

文章认为，服务延时会受到影响，主要有以下三方面的原因：

### 排队延时(queueing delay)

典型的server一般遵循排队论(queueing theory)中M/M/n的模型。按照这个模型，请求到达server端后会进入队列等待work线程取走处理。根据排队论的结论，这个平均等待时间为$$\zeta_{avg} = \frac{1}{\mu-\lambda}$$，其中$$\mu$$表示请求消化的速率，而$$\lambda$$则表示请求的到达速率。对应的，系统的95分位请求的平均排队时间约为$$\zeta_{95} = \frac{ln \frac{100}{100 - 95}}{\mu - \lambda} \approx 3 \zeta_{avg}$$。从上面的数学模型中可以看出，当系统负载很高，即$$\lambda$$接近于$$\mu$$的时候，$$\zeta_{95}$$会显著非线性增加。在混布环境下，$$\mu$$的下降导致这个现象更容易发生。

从上面的式子可以看出，排队延时的影响主要发生在高负载的场景下，负载不高的时候，这个因素表现并不明显。因此论文提出的解决办法就是上层感知服务的干扰情况，并及时的执行扩容动作、降低单一副本的负载。

### 调度延时(scheduling delay)

调度延时包括在内核调度队列中等待调度的时间，以及进程被抢占时发生context switch的时间。论文的分析结果表明，context-switch的影响十分有限，主要问题出在等待时间(wait-time)上，这个等待时间主要是但前内核的CFS调度算法对wake-up进程的处理机制导致的。具体来说，就是CFS算法总是选择进程虚拟运行时间(virtual runtime)最小的那个进程来执行，但为了让被唤醒的进程能被尽快的执行，采用如下方式修正被wake-up进程$$T$$的vruntime值：

$$vruntime(T) = max \{vruntime(T), min(vruntime(*)) - L\}$$

其中$$min(vruntime(*))$$是所有进程中的最小的vruntime，而$$L$$是一个常量，默认是调度周期的一半。这个式子让wake-up的那个进程，能够排到队列的头部、尽快的被执行起来。这种机制导致只要B进程被wake-up，那么当前执行中的A进程很大概率会被抢占，从而影响了A的延时。需要注意的是，B进程未必比A进程"重要"，而仅仅是因为CFS的这个实现引发的。

所以，论文后面的解决方案中，提出除了通过各种手段修正vruntime计算的方式外，也可以考虑更换内核CFS调度算法，比如使用real-time的调度算法(SCHED_FIFO或SCHED_RR)，或者用CFS算法的修正版BVT解决。BVT通过让用户能够设置每个进程vruntime的一个warp值的方式，消除了CFS上述问题。在上面的那个场景中，如果A是延时敏感进程，就设置其$$warp(A) > L$$，那么：

$$vruntime(B) = min(vruntime(*)) - L) > (vruntime(A) - warp(A))$$

这样就保证了处于执行中的延时敏感的进程A不会被任意抢占。作者的实验表明，BVT在解决scheduling delay上，是个比较理想的解决方案。

### thread负载不均(thread load imbalance)

thread load imbalance指的是kernel调度进程到某个cpu core上执行。那么就可能将多个进程调度到一个cpu core上，导致一部分core很闲而一部分很忙。这种不均衡性使得服务的长尾请求数量增加。论文的解决办法非常直接，即通过绑定每个进程/线程所在的core，规避了这个现象。

<br>

总的来说，这篇论文的主要价值在于给出了QoS问题引发的一个底层解释，为后面单机策略的制定奠定了基础。文章中提到的CFS调度引发的问题，是比较新颖的，以往少有人想到，很有借鉴意义。文章的相关分析让我们认识到，服务QoS问题的引发，不是一个简单的"资源不足"引起的，不能简单的想当然。至于论文中提出的一些单机策略，个人以为考虑还是比较粗糙的，在真实生产环境还是需要仔细斟酌，不能盲目引入。
