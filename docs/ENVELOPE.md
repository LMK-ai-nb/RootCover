# 可行域覆盖与未决原因

盒数不能说明"交付的是区域还是碎片"。下表用初始盒体积归一化，给出内盒体积占比与内盒∪未决的体积上界，并按 `unresolved[].reason` 分桶。

| 场景 | 内盒 | 未决 | 评估次数 | 内盒体积占比 | 上界占比 | 未决原因 |
| --- | --- | --- | --- | --- | --- | --- |
| robot_workspace | 2 | 21 | 59 | 0.0000 | 0.0005 | resolution reached without whole-box classification×21 |
| thermal_parameters | 537 | 2974 | 10277 | 0.0012 | 0.0048 | resolution reached without whole-box classification×2974 |
| mixed_process | 5 | 45 | 149 | 0.0001 | 0.0009 | resolution reached without whole-box classification×45 |
| robust_localization | 15 | 38 | 127 | 0.0013 | 0.0027 | resolution reached without whole-formula classification×38 |
| design_alternatives | 184 | 204 | 1001 | 0.0343 | 0.0534 | resolution reached without whole-formula classification×204 |
| design_window6 | 750 | 1798 | 5191 | 0.6114 | 0.9869 | resolution reached without whole-formula classification×1798 |

读法：内盒体积占比是"已证明可行"的下界，上界占比是"可行点必定落在这里"的外包围；两者之差即未决部分。
未决原因目前只有一类文案（分辨率到达但整盒未分类），预算耗尽与深度上限都会落到同一文案，因此不区分"算不动"与"已到 ε"。

复现：`python scripts/envelope.py`（数据写入 `docs/evidence/envelope.json`）。合成模型，不代表工业规模。
