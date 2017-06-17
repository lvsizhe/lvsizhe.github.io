---
layout: post
title: 关于第一个side project
categories: side-proj
---

两年前冲动报了一个英语培训，这两天就要到期结束了。如前面所说，计划启动一些小的side project，在周末闲暇之时，做着玩玩。一来解解自己coding的瘾，二来动手熟悉一下一些基本的思路方法。side project不求大，就是一些小的、能够说明基本原理的demo级别的程序即可。

写这篇博客的目的是梳理一下自己最近想动手的一个东西、整理一下基本的思路和大概计划。

第一个项目做的是一个基本的分布式任务管理，即很多分布式计算系统都有的那种AppMaster+Worker结构。每一个Job会拉起一个AppMaster，然后由AppMaster拉起Job下的众多Task并盯住众多Task直至执行完成。这个项目主要的目的是熟悉以下一些基本的思路：

- 通过动手写出一个简单的作业执行系统;
- 熟悉ZooKeeper和Go语言;
- 编写期间了解一下一些知名计算框架在这块的基本思路和共性问题，比如AppMaster的灾备处理，Master/Worker通讯问题等;
- 由于是第一个side project，可能需要搭建一个我自己的小Lab，跑跑CI/CD的pipeline啥的。中间会实际上手一些工具，比如实际用一下docker compose、配置jenkins集群什么的。

期间估计还会遇到许多问题，遇到就逐步解决，也会看很多的材料，我都会在这个side-proj这条线的blog里面记录的。
