---
layout: post
title: 三种并发编程模型介绍
categories: paper
tags: programming
---

很长时间没有更新这个blog了，主要是上半年大多数空闲时间都放在看Coursera上的UIUC的Cloud Computing系列课程上了[^1]。课程结束后，又因为在公司内上软件工程相关的课程，经历又转到了复习软件工程相关的东西上了。最近两周，因为项目的缘故复习了关于异步编程的三篇小文章，想起好久没有更新这个blog了，于是决定顺手在这里写一笔记录以下。三篇文章主要介绍了三个基本的并发编程模型：active-object、reactor和proactor，是由同一个人(Douglas C.Schmidt)写的三篇介绍文章，因此整体风格都非常的接近，文章也不长，适合一口气阅读。

----

一般在编码的时候，并发编程总是会引来不少的麻烦，因此有人将常见的并发模型，以pattern的形式整理，便于程序员的实现和沟通。Active-Object、Reactor、Proactor就是其中较为常见的三种模式，在大量的项目中被有意无意的运用了。

比如，在经典的WebServer的设计中，最朴素也是使用最广的并发模型是**"synchronous multi-threading"**，即当WebServer启动后，开若干个独立的Worker线程，每当有请求进来的时候，分配一个线程进行处理，在线程内依次进行连接、解析请求、处理请求、返回等操作。在处理这个请求的时候，整个线程会被该请求占用。这种模型的最大好处是简单，编码上基本上就是一条线走到底，但缺陷也是非常明显的。由于每个请求的处理会占据一个worker线程，为提高系统的吞吐，就需要增加执行的线程数，而线程数的增加会导致内核调度overhead的增加(在单一物理核上排队等待执行的task数增加、context switch的开销等); 另外，如果请求中存在IO操作（如读取磁盘上的数据文件)，也会影响该请求的响应时间。

那么如何减少需要开的线程数、降低cpu切换引发的各种开销呢？Proactor就是一个经典的解决方案。该Pattern主要是**将请求的处理异步化**。比如我将请求的处理分成A, B, C, D几个顺序发生的阶段，每个阶段的工作完成后，会触发"Completion Event”，发送给Completion Dispatcher。Completion Dispatcher一般运行在某个独立的线程内，其核心工作是将某个阶段的工作”调度"到空闲线程内执行。比如请求1的B工作完成后，会被通知Dispatcher，进入pending队列等待调度；当Dispatcher发现某个工作线程空闲的时候，可以将请求1的阶段C的代码在空闲线程内启动执行，如此反复直至请求的所有阶段工作完成。这样一来，就可以开少量的工作线程，来并行的执行众多的请求。一般而言，我们会将需要发生IO、或者相互独立的工作，拆分成单独的"阶段", 以最大限度的发挥并发执行的效果。Proactor的执行效果，非常类似于”协程"，请求主动挂起自己、释放出当前的worker线程，由Dispatcher调度新的任务过来将Worker线程使用上。在提高性能、降低overhead的同时，Proactor往往也带来许多麻烦。比如，应用proactor后，处理流程会被拆碎成很多的片段，导致代码维护困难；另外，如何合理的拆分一个处理流程、如何管理好内存，都是运用这个pattern时需要事先考虑清楚的事情。

可能是因为名字比较接近，Reactor是一个很容易和Proactor搞混的Pattern。但其实Reactor和Proactor试图解决的问题是完全不同的。**Reactor主要面对的是如何快速的分发并发事件的问题(Demultiplexing)**。最典型的场景是一个WebServer，bind到某个端口上Listen，那么显然，当大量并发请求到达的时候，我们就需要一种机制快速"接客"。负责接客的线程需要用最快的速度，接单后将请求转给其他线程/进程处理。在典型的Reactor实现中，是使用操作系统的select或者epool机制实现，当感知到请求到达的时候，立即调用匹配的event handler处理。Reactor的核心并不是高并发的处理请求，更多的是如何"高并发的转发请求"。在使用Reactor接收请求以后，经常会使用Proactor或者Active-Object的模式，来执行请求的处理。Proactor中的Completion Dispatcher，也可以使用Reactor的模式来实现，以提高Proactor的”调度器"的处理吞吐。在简单的事件处理场景下(比如kv存储系统)，简单的使用reactor模式，由于event handler的执行时间极短，用很少的线程就能够将系统的吞吐提高到相当高的水平。

Active-Object与Proactor的基本思路类似，都是为了**将某个请求的处理进行异步化**。典型的场景是在请求处理的过程中涉及IO操作，那么就很希望将处理IO的工作放到某个"后台"，使得当前的线程可以继续执行一些其他的计算工作、**降低请求的响应时间**。Active-Objec中的Object可以理解成是"跑腿的"，处理请求的线程将一些工作委托给了该Object处理（一般在另一个线程或者进程执行)，而后等到需要结果的时候，再拿回执行结果。在实现上，一般是请求处理线程内call一个proxy，proxy通过既定协议将消息发送给另一个线程/进程的pending queue，然后由一个被称为active dispatcher的组件监听到并寻找匹配的stub执行命令(这里可能使用了一个Reactor)。stub和proxy实现了同一个interface，只不过stub是真的干活的人、proxy负责消息的生成和发送。请求线程在调用proxy后，一般不会block等待处理结果，而是取得一个"Future"对象，记录下来后请求线程可以继续执行其他不依赖该请求结果的其他计算，等到需要的时候，调用Future::Get()方法，试图获取结果。如果此时stub已经计算完毕并返回，那么Future::Get直接返回执行结果；如果没有，该方法阻塞直至stub调用结束。这个工作过程是不是很熟悉？是的，RPC就是一种经典的Active-Object。

至此，三种Pattern都介绍完毕。虽然Reactor、Proactor、Active-Object都是提高并发的有效手段，但其实三种Pattern并不是完全一样的。Reactor是解决请求快速接入的问题，而Proactor和Active-Object是都将请求的处理异步化了。对于Proactor来说，主要通过降低系统overhead来提高系统的整体吞吐，而Active-Object一般用于将同步的IO操作同步异步执行、以降低请求处理的延时。在现实世界中，这三个Pattern经常是组合在一起使用的，并不是简单的谁比谁好的替代关系。

----
[^1]: 这门课的给人的感觉挺不错，尤其是前面的两门，非常适合于系统性的了解分布式的核心原理。
