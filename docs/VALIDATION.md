# 0.4 本地实际验证

完整验证2026-11-13；版本0.4.0-dev.1，未推送、未发布、未执行新的远程CI。历史公开0.1/0.2验证见RELEASE.md；0.3证据保留于evidence/local-0.3-validation.json，不当作新版证据。

## 已执行命令

`python scripts/verify.py --browser` 的所有21步退出0。完整原始命令/输出在忽略的artifacts/validation.json，公开摘要及15个核心文件SHA256见[evidence/local-0.4-validation.json](evidence/local-0.4-validation.json)。

- 本地Windows；moon0.1.20261021 / moonc0.10.17+093cb8f9c。
- `moon check --target all --deny-warn`通过。wasm、wasm-gc、js分别实际test/build，每目标58项测试全通过（含8项公开API文档测试）。同一测试集在三个目标上重复验证，不当作174个不同用例。
- fmt严格检查、moon info接口、typed demo、JS桥接构建、25项CLI均通过。
- 原求根Fraction：2800算术、182系统、513份唯一性证据重放。
- 可行域Fraction：37系统、1215份内盒证据、4413有理数网格点；覆盖域内包含、正体积不重叠、叶数守恒和可行样本保留。
- 新独立mpmath1.3.0，100位：525表达式盒、4076函数值、5900解析导数；134模型在三种机制下共402次收缩核对、21114网格检查；19非线性根系统、3新增可行域场景、14562内盒端点/中心检查。
- 新正公式独立参考：54个有理数模型、284份内盒公式证据、920个可行有理数样本；162次配置收缩保留2760个可行样本；24组根搜索策略组合；3个新场景的3825个内盒高精度采样点。命令为`python tests/predicate_oracle.py`，原始结果在artifacts/predicate-oracle.json。
- Julia1.13.3 / IntervalRootFinding0.7.2实际运行所得20模型、Newton和Krawczyk40次参考保存在evidence/intervalrootfinding-reference.json。本轮将当前RootCover重新对照该参考；没有每次重跑Julia。16常规模型两方法根数吻合、3奇异/边界模型均未决、1极点差异如实披露；见BASELINE.md。
- 实际Chromium：六个新增可行域场景、机制/搜索切换、正公式报告下载、原场景、预算、重复JSON键、注入文本、乱序加载、取消和390px布局全部通过。桌面和390px截图另经人工视觉检查。
- 真实Moon包已打包并扫描：15个核心文件在包中，work/私人材料/缓存/联系方式不在包中。该检查不执行publish；最终包文件数/字节数以本地package-check.json为准。

## 验证边界

本机未配置MSVC/Windows SDK，native只有静态check，未实际build/run；不将0.2远程native成功挪作新版证据。未来CI配置已加入新检查，但本轮没有触发。

原Fraction参考不复用MoonBit实现；100位参考独立解析AST、使用解析AD，避免用有限差分在极大/极小尺度产生假零导数。正公式参考用Fraction计算区间/点值与组合真值；高精度场景参考沿用独立解析器。采样在高精度域构造，避免次正规区间的插值点下溢跑出输入范围。它们仍是有限回归，不是形式化证明或所有模型的可靠性保证。

所有示例合成，无真实设备/工业采用、统计置信度或安全认证结论。高维上限不等于能在给定预算内完成；病态、重根、域边界和精度限制可能未决。
