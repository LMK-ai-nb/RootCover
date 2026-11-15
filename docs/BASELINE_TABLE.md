# 逐模型对照

20 个模型，每个用 Newton 与 Krawczyk 两种方法各跑一次（共 40 次）。判据：常规模型要求根数相等，且每个 Julia 细胞与本库包围**一一匹配**（不允许多对一或漏配）。

| 模型 | 变量 | 方程（截断） | 本库 唯一/未决 | Julia Newton | Julia Krawczyk | 匹配细胞 | 最大包围宽 | 宽度比中位数 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| documented_four_roots | 1 | `sin(x)-0.1*x^2+1` | 4/0 | 4/0 | 4/0 | 4 | 4.22e-09 | 822.9 |
| fixed_point | 1 | `cos(x)-x` | 1/0 | 1/0 | 1/0 | 1 | 3.80e-09 | 314130.4 |
| exponential_decay | 1 | `exp(-x)-x` | 1/0 | 1/0 | 1/0 | 1 | 1.06e-10 | 45.7 |
| log_domain | 1 | `log(x)` | 1/0 | 1/0 | 1/0 | 1 | 1.55e-11 | 4.7 |
| sqrt_domain | 1 | `sqrt(x)-2` | 1/0 | 1/0 | 1/0 | 1 | 1.60e-14 | 0.0 |
| nested_transcendentals | 1 | `sin(exp(x))` | 2/0 | 2/0 | 2/0 | 2 | 8.41e-13 | 1.6 |
| atan | 1 | `atan(x)-0.5` | 1/0 | 1/0 | 1/0 | 1 | 9.14e-09 | 36458.4 |
| asin | 1 | `asin(x)-0.25` | 1/0 | 1/0 | 1/0 | 1 | 4.19e-09 | 1.6 |
| acos | 1 | `acos(x)-1` | 1/0 | 1/0 | 1/0 | 1 | 9.66e-15 | 0.0 |
| sinh | 1 | `sinh(x)-1` | 1/0 | 1/0 | 1/0 | 1 | 1.31e-12 | 0.2 |
| cosh | 1 | `cosh(x)-2` | 2/0 | 2/0 | 2/0 | 2 | 2.70e-08 | 5033.1 |
| tanh | 1 | `tanh(x)-0.5` | 1/0 | 1/0 | 1/0 | 1 | 1.36e-11 | 2401.0 |
| pole_without_root | 1 | `1/x` | 0/0 | 0/1 | 0/1 | 1 | 1.36e-11 | 2401.0 |
| absolute_corner | 1 | `abs(x)` | 0/1 | 0/1 | 0/1 | 1 | 1.36e-11 | 2401.0 |
| sqrt_boundary | 1 | `sqrt(x)` | 0/1 | 0/1 | 0/1 | 1 | 1.36e-11 | 2401.0 |
| multiple_log_root | 1 | `log(x)^2` | 0/1 | 0/1 | 0/1 | 1 | 1.36e-11 | 2401.0 |
| trigonometric_2d | 2 | `sin(x)` | 2/0 | 2/0 | 2/0 | 2 | 7.51e-12 | 11277.0 |
| robot_2r | 2 | `cos(q1)+cos(q1+q2)-1` | 2/0 | 2/0 | 2/0 | 2 | 6.37e-11 | 7418.7 |
| coupled_12d | 12 | `2*x0-2` | 1/0 | 1/0 | 1/0 | 1 | 1.84e-14 | — |
| coupled_32d | 32 | `2*x0-2` | 1/0 | 1/0 | 1/0 | 1 | 4.06e-14 | — |

读法：宽度比 = 本库包围宽 ÷ 匹配到的 Julia 细胞宽；远大于 1 表示本库给的是更粗的包围，不是错误。三个奇异/边界模型本库与 Julia 同为未决；`pole_without_root` 是语义差异：本库在定义点上代数排除 1/x=0，Julia 保留极点处的未决盒。

生成：`python scripts/compare_intervalrootfinding.py`（数据在 `docs/evidence/intervalrootfinding-comparison.json`）。
