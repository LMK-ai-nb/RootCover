"""Render the per-model comparison table from the recorded evidence."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
comp = json.loads((ROOT / 'docs/evidence/intervalrootfinding-comparison.json').read_text(encoding='utf-8'))
ref = {c['name']: c for c in json.loads((ROOT / 'docs/evidence/intervalrootfinding-reference.json').read_text(encoding='utf-8'))['cases']}

lines = [
    '# 逐模型对照',
    '',
    '20 个模型，每个用 Newton 与 Krawczyk 两种方法各跑一次（共 40 次）。判据：常规模型要求根数相等，且每个 Julia 细胞与本库包围**一一匹配**（不允许多对一或漏配）。奇异/边界模型不参与匹配，匹配列记为 —。',
    '',
    '| 模型 | 变量 | 方程（截断） | 本库 唯一/未决 | Julia Newton | Julia Krawczyk | 匹配细胞 | 最大包围宽 | 宽度比中位数 |',
    '| --- | --- | --- | --- | --- | --- | --- | --- | --- |',
]
for row in comp['cases']:
    case = ref[row['name']]
    req = case['request']
    eq = (req.get('equations') or ['(feasibility)'])[0].replace('|', '\\|')[:38]
    jn = next(j for j in row['julia'] if j['method'] == 'Newton')
    jk = next(j for j in row['julia'] if j['method'] == 'Krawczyk')
    mc = row.get('matched_cells')
    mw = row.get('max_root_width')
    mr = row.get('median_width_ratio')
    lines.append(
        f"| {row['name']} | {len(req['variables'])} | `{eq}` | {row['rootcover_unique']}/{row['rootcover_unresolved']} | "
        f"{jn['unique']}/{jn['unknown']} | {jk['unique']}/{jk['unknown']} | {mc if mc is not None else '—'} | "
        f"{('%.2e' % mw) if mw else '—'} | {('%.1f' % mr) if mr else '—'} |"
    )
lines += [
    '',
    '读法：宽度比 = 本库包围宽 ÷ 匹配到的 Julia 细胞宽；远大于 1 表示本库给的是更粗的包围，不是错误。3 个奇异/边界模型本库与 Julia 同为未决；`pole_without_root` 是语义差异：本库在定义点上代数排除 1/x=0，Julia 保留极点处的未决盒。',
    '',
    '生成：`python scripts/compare_intervalrootfinding.py && python scripts/baseline_table.py`（数据在 `docs/evidence/intervalrootfinding-comparison.json`）。',
]
(ROOT / 'docs/BASELINE_TABLE.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('rows', len(comp['cases']))
