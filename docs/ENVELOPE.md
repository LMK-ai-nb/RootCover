# 可行域覆盖与未决原因

盒数不能说明"交付的是区域还是碎片"。下表用初始盒体积归一化，给出内盒体积占比与内盒∪未决的体积上界，并按 `unresolved[].reason` 分桶。

| 场景 | 内盒 | 连通分支 | 最大分支盒数 | 最大分支体积占比 | 未决 | 评估次数 | 内盒体积占比 | 上界占比 | 未决原因 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| robot_workspace | 2 | 1 | 2 | 1.0000 | 21 | 59 | 0.0000 | 0.0005 | resolution reached without whole-box classification×21 |
| thermal_parameters | 537 | 1 | 537 | 1.0000 | 2974 | 10277 | 0.0012 | 0.0048 | resolution reached without whole-box classification×2974 |
| mixed_process | 5 | 1 | 5 | 1.0000 | 45 | 149 | 0.0001 | 0.0009 | resolution reached without whole-box classification×45 |
| robust_localization | 15 | 1 | 15 | 1.0000 | 38 | 127 | 0.0013 | 0.0027 | resolution reached without whole-formula classification×38 |
| design_alternatives | 184 | 2 | 95 | 0.5059 | 204 | 1001 | 0.0343 | 0.0534 | resolution reached without whole-formula classification×204 |
| design_window6 | 750 | 1 | 750 | 1.0000 | 1798 | 5191 | 0.6114 | 0.9869 | resolution reached without whole-formula classification×1798 |

读法：内盒体积占比是"已证明可行"的下界，上界占比是"可行点必定落在这里"的外包围；两者之差即未决部分。连通分支按"共享面或正长度重叠"判定（tol 1e-9），回答"交付的是几个区域"：`design_window6` 的 750 个内盒构成 **1 个连通区域**，`design_alternatives` 的 184 个内盒构成 **2 个分支**，对应两套互斥设计。
未决原因有四类文案：`resolution reached without whole-box classification`、`assessment budget exhausted`、`depth limit reached`、`no representable interior split point`。本次六个场景只触发第一类；预算耗尽与深度上限在代码中是分开的，不由文案合并。

复现：`python scripts/envelope.py`（数据写入 `docs/evidence/envelope.json`）。合成模型，不代表工业规模。
