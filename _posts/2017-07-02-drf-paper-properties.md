---
layout: post
title: DRF调度算法(性质篇)
categories: paper
tags: scheduler
---

上周事情比较多，导致这篇博文延后了，这周加紧补上。好久没有弄过逻辑证明，因此这部分读得比较累，好在还是硬着头皮啃了下来。

废话少说，切入正题。

---

### DRF具备的属性

论文的中段主要证明了DRF具备的一些良好的性质，包括:

- **Sharing Incentive**: 如果用户可以在一个总资源只有$$\frac{1}{n}$$的资源下启动$$x$$个任务，那么在有$$n$$个user、可以使用全部资源的场景下，这个用户也可以启动不少于$$x$$的task。这个性质说明了应用该调度算法，合并更大的资源池，不会让整集群的吞吐变糟。
- **Strategy-proofness**: user无法通过虚假声明自己的资源使用量，来获得有利于自己的分配。即，在DRF下，即便用户虚假声明自己的任务资源使用量，也无法让其启动更多的task。
- **Envy-freeness**: 一个user不会"嫉妒"另一个user的分配结果，即如果User-A(为方便阐述，后面将用户A记为$$u_{A}$$)使用分配给$$u_{B}$$的资源、不使用分配给自己的，无法启动更多的task(获得实际的好处)。
- **Pareto efficiency**: 也称为帕累托最优(Pareto Optimality)。假定固有的一群人和可分配的资源，从一种分配状态到另一种状态的变化中，在没有使任何人境况变坏的前提下，使得至少一个人变得更好。帕累托最优状态就是不可能再有更多的帕累托改进的余地；换句话说，帕累托改进是达到帕累托最优的路径和方法。 帕累托最优是公平与效率的“理想王国”。
- **Single Resource Fairness**: 当把资源退化成一维的场景的时候，分配结果也要满足max-min fairness。
- **Bottleneck Fairness**: 如果有一个资源是瓶颈，那么算法在这维资源的分配上满足max-min fairness。
- **Population Monotonicity**: 如果一个user退场、并释放自己的资源，那么在剩余user中重新分配资源后，没有一个user的状况会变差。DRF大多数情况下满足这个性质。

---

### 证明准备：Progressive Filling

首先在证明中将任务看作是可以连续可无限细分的[^1]，即可以启动0.x个的task。那么DRF可以转换成如下被称为**Processive Filling**的过程: 
* 所有用户的Dominant Resource share(后面记为$$s$$)同速率的上涨、并且每个用户的non-dominant resource也同比例增加，直到资源池中有某个纬度的资源(记为$$R_{k}$$)被塞满;
* 将所有使用这个$$R_{k}$$的用户从列表中删除;
* 重复上述过程直至用户列表为空或者资源全部被塞满。

> **Theorem-1(max-min theorem)**: _DRF分配结果等价于每个用户都存在资源瓶颈项的分配解。_ 

**证**: 在Progressive Filling中，我们可以观察到分配结果中如果$$u_{j}$$的瓶颈在资源$$R_{k}$$上，那么其他对$$R_{k}$$有需求的用户$$u_{i}$$，必须满足$$ s_{j} \ge s_{i}$$。否则的话，$$u_{i}$$ 就应该分配更多资源、同时减少分配给$$u_{j}$$的资源（因为在$$R_{k}$$上$$u_{i}$$抢走了一些$$u_{j}$$的）。所以，当所有用户都有瓶颈资源项的时候，$$s$$最小的那个user无法再提高$$s$$了，因此是max-min faireness的($$\Leftarrow$$成立)。反过来，对于一个DRF解，每个用户必然有一个资源瓶颈项$$R_{k}$$。否则的话，假定$$u_{i}$$没有，那么$$s_{i}$$就可以增加，说明还不是最终解，这和前面已经是一个解的假设是矛盾的($$\Rightarrow$$成立)。$$\Box$$

> **Lemma-2**: _DRF分配结果中的每个user，都至少有一维资源被分配光了。_

**证**: 很简单，假如不是如此，存在一个$$u_{i}$$还有资源可用，那么说明Progressive Filling算法还没结束，即$$s_{i}$$还可以继续上涨，和前面这已经是一个解的前提假设是矛盾的。$$\Box$$

### 各性质证明


> **Theorem-3(Pareto efficient)**: _DRF的分配结果是Pareto efficient的。_

**证**: 假如$$u_{i}$$还有帕累托改进的余地。根据Lemma-2，$$u_{i}$$必然有某个维度的资源$$R_{k}$$已经被分配完了。如果$$R_{k}$$只被$$u_{i}$$一个人使用，那么自然无法再提高$$s_{i}$$；但如果$$R_{k}$$被分配给了多人，那么提高$$u_{i}$$的分配量，必然降低也使用$$R_{k}$$的其他用户的$$s$$，这就不是帕累托改进了，因而发生了矛盾。$$\Box$$

> **Theorem-4(sharing incentive, bottleneck fairness)**: _DRF满足sharing incentive和bottleneck fairness_。

**证**: 考虑有$$n$$个用户，$$R_{k}$$是第一个被分配光的资源，设$$u_{i}$$为这个$$R_{k}$$中share最大的那个，记$$u_{i}$$使用$$R_{k}$$的占比为$$t_{i,k}$$，显然$$t_{i,k} \ge \frac{1}{n}$$(否则资源不会被分配光)，再由Dominant Resource Share的定义可知，$$s_{i} \ge t_{i,k} \ge \frac{1}{n}$$，由于Progress Filling中$$s$$是同速率增长的，因此所有用户的$$s \ge \frac{1}{n}$$。因此满足了sharing incentive。如果所有用户的瓶颈资源都出现在$$R_{k}$$上，就能推出每个用户都拿到了刚好$$\frac{1}{n}$$的$$R_{k}$$资源，满足bottleneck fairness。$$\Box$$

> **Theorem-5(envy freeness)**：_DRF是envy-free的。_

**证**: 假设$$u_{i}$$想拿到$$u_{j}$$分配的资源，那么必然 _**'$$u_{j}$$在所有资源维度上拿到的比例都要大于$$u_{i}$$'**_ (\*)，否则$$u_{i}$$拿到后也没法跑更多的任务。根据Theorem-1，在DRF分配结果中，任意一个用户$$u_{i}$$必然有个瓶颈资源$$R_{k}$$，在$$R_{k}$$下其他用户(包括$$u_{j}$$)的$$s$$必然不高于$$u_{i}$$($$s_{j} \le s_{i}$$)，(*)的条件就不满足了。因此，$$u_{i}$$拿到$$u_{j}$$的资源也无法跑更多的任务，所以是envy-free的。$$\Box$$

> **Theorem-6(strategy-proofness)**: _在DRF中，用户无法虚报自己的资源需求，以获得更加有利的资源分配结果。_

**证**: 假定$$u_{i}$$的真实资源需求为$$d_{i}$$，通过虚报为$$\hat{d}_{i}$$，使得对$$R_{k}$$获得的分配从$$a_{i,k}$$变成了$$\hat{a}_{i,k}$$。由题设可知，需要满足$$d_{i} \ne \hat{d}_{i}$$且$$\hat{a}_{i,k} > a_{i,k}(\forall k, d_{i,k} > 0)$$，即$$\hat{a}_{i} > a_{i}$$，$$u_{i}$$才有动机这么做。记$$R_{r}$$为$$u_{i}$$采用$$d_{i}$$的时候第一个被分配完毕的资源。假设只有$$u_{i}$$需要$$R_{r}$$，那么显然$$u_{i}$$已经能得到它能拿到的最大的了，虚报资源需求也没用；否则假定还有$$u_{j}$$分配得到了$$R_{r}$$，记分配到了$$a_{j,r} > 0$$且$$j \ne i$$。在这种情况下，设Progressive Filling在$$t$$时刻将$$R_{r}$$在$$u_{i}$$使用$$d_{i}$$申请的时候分配完，而在$$t'$$时刻、按照$$\hat{d}_{i}$$的需求将$$R_{r}$$分配完。由于$$\hat{a}_{i} > a_{i}$$，所以$$t'>t$$。这说明在时刻$$t'$$之前，在声明自己需要$$\hat{d}_{i}$$的情况下，$$u_{i}$$并未把$$R_{r}$$资源吃完。在$$t$$到$$t'$$之间的过程中，$$u_{j}$$就可以拿走一部分$$R_{r}$$资源，使得$$\hat{a}_{i,r} < a_{i,r}$$，出现矛盾。$$\Box$$

至此，还剩Single resource fairness和Population Monotonicity两条属性未证明，对于Single Resource Fairness，是不证自明的，在这里不做赘述。对于Population Monotonicity，DRF在满足strictly positive demand的情况下，是可以满足的。所谓strictly positive demand的条件，就是所有user的资源需求都是大于0的，即$$d_{i,k} > 0$$对任意$$u_{i}$$和$$R_{k}$$成立。

> **Theorem-7**: 在strictly positive demands的前提下，DRF分配结果中所有用户的$$s$$相等，即$$\forall i,j$$，$$s_{i} = s_{j}$$。

**证**: Progressive Filling的过程中，所有user的$$s$$都是同步增长的，当第一个资源$$R_{k}$$被分配完毕后，所有的user的$$s$$都不能再增长了(因为$$d_{i,k} > 0$$)，此时的结果就是DRF分配结果，因此大家的$$s$$都相等。$$\Box$$

> **Theorem-8,9(population monotonicity)**: _DRF在strictly positive demands情况下，满足population monotonicity，否则不一定满足。_

**证**: 在strictly positive demands下，意味着一个DRF分配结果中，所有用户都因为同一个资源的紧缺而无法继续提高$$s$$、而停留在$$s=\alpha$$上(Theorem-7)。假设一个用户退场并释放出他占据的资源，而DRF不满足Population monotonicy，那么就存在一个用户$$u_{i}$$，其最终分配结果$$s_{i} < \alpha$$，而其他用户能够提高自己的$$s_{j} > \alpha$$。这个和前面已经证明的Theorem-3是矛盾的，因为DRF下用户无法通过损害他人来获取自己的利益(帕累托改进的定义)。但不满足strictly positive demands的条件的时候，由于Theorem-7不一定成立，所以存在打破Population monotonicity的反例：假定总资源为<24, 24>，然后$$u_{1}$$的资源需求为<2, 0>，$$u_{2}$$为<1, 2>，$$u_{3}$$为<0, 2>。此时DRF的分配结果为<9, 6, 6>；$$u_{3}$$退出分配，则DRF得到分配结果为<8, 8>，$$u_{1}$$能拿到的资源反倒变少了。$$\Box$$

Theorem-8中的反例，原因在于$$u_{3}$$还在的时候，$$R_{2}$$资源会首先被分配完，导致此时每个用户都只能分配到6，但$$R_{1}$$还有剩余，而此时只有$$u_{1}$$可以分配，Progressive Filling得以继续，将剩余的$$R_{1}$$全部给了$$u_{1}$$。但$$u_{3}$$挪走后，$$R_{2}$$不再首先发生紧缺，$$u_{1}$$也就没办法占到便宜了。

<br/>

至此，DRF的各项属性证明完毕，可以看出DRF具备的这些属性还是非常优良的，在"公平"和"效率"之间，寻求了一个比较好的平衡。个人以为尤其是Sharing Incentive，Pareto efficient和Strategy proofness三条，在现实中非常的重要。DRF能够从数理上证明自己的有效性，这也是为什么DRF会成为许多知名调度系统的核心算法。

下一篇博文将继续解读DRF算法，将其与另外的Asset Fairness和CEEI进行比对，加深对这些调度算法的理解。

<br/>

---

[^1]: 现实中是离散的，这里没太明白这个变换会不会有问题

