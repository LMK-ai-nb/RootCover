# 容差可行域：定义与验证

## 输入与结果

1…6个变量组成有限闭初始盒X，1…32个约束为 p_i(x)∈[a_i,b_i]。约束数可多于、等于或少于变量数；允许带宽为0，但这种边界一般难以整盒分类。观测带和初始边界均须有限且有序。表达式、次数、节点与binary64定义沿用SEMANTICS.md；观测输出带不代表系数不确定族、统计置信区间或真实测量精度。

`ConstraintModel`由变量名与Constraint(polynomial,allowed)组成。`classify_constraints`对一个完整盒进行Inside/Outside/Indeterminate判定；`pave`返回inside证据、unresolved覆盖与统计。JSON采用version=1、mode=feasibility、variables、constraints(expression,range)、box、options。不混用equations字段。

## 整盒判定

在盒B上，用向外舍入自然区间扩展计算R_i=p_i(B)：

- 任意R_i与观测带无交集，整盒不可行，可排除。
- 所有R_i都包含在观测带内，整盒可行；输出B与各R_i作为内包围证据。
- 否则保留未决或继续划分。仅中点可行、仅若干样本可行、残差很小均不足以认证整盒。

采用既有SIVIA思路，以同一确定性非对称划分产生闭子盒，子盒联合覆盖父盒且仅接口重合。本版未实现IBEX的完整收缩器体系、通用超越表达式或全局优化。

## 覆盖与停止

I为所有inside盒的联合，U为所有未决盒的联合，S为初始域中满足全部约束的点集，则 I⊆S⊆I∪U。由于只删除已排除盒，预算/深度限制会把所有待处理盒输出为未决，仍保留此外包围性质。未决盒可能全可行、部分可行或全不可行。

complete当且仅当U为空；resolution_met仅检查所有未决盒的最大坐标宽度不大于用户容差，不能代替complete。预算耗尽仍可能留下大盒，此时resolution_met为false。definitely_empty仅在complete=true且inside为空时为true。可行盒数量不是根数或连通分支数；本模式不返回root_count。

停止精度、深度和预算均不把未决自动标成可行。最大20000次评估、深度80；绝对分辨率的尺度由用户选择。CLI只要存在未决就退出1，即使resolution_met=true；这不是输入错误。

## 独立核对

固定37个观测带模型，使用独立Fraction/AST区间值计算，重算1310个内包围证据；检查每个报告区间像包围精确参考像且落在观测带中。对输出盒检查域内包含、正体积不相交和叶数守恒，另以4413个有理数网格点检查可行点未丢失。有限网格检查不是所有连续点的形式化证明，覆盖性质还依赖上述区间与分割不变量。

示例noisy_localization输入三个基站(0,0)、(4,0)、(0,4)的距离平方带[1.75,2.25]、[9.75,10.25]、[9.75,10.25]，区域[0,2]²；输出19个内盒和40个未决盒，分辨率1/64。输入界必须由调用者按其测量模型提供，不能把结果外推为现实安全或概率承诺。

算法/概念来源：[IBEX set inversion](https://ibex-team.github.io/ibex-lib/lab.html)、[Solving and Visualizing Nonlinear Set Inversion Problems](https://reliable-computing.org/reliable-computing-22-pp-104-115.pdf)。独立实现，无上游源码移植；不主张SIVIA首创。
