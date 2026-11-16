"""Envelope: how much of the initial box each feasibility run actually classifies."""
from pathlib import Path
import json
import subprocess
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
CASES = [
    'robot_workspace', 'thermal_parameters', 'mixed_process',
    'robust_localization', 'design_alternatives', 'design_window6',
]


def volume(box):
    v = 1.0
    for lo, hi in box:
        v *= (hi - lo)
    return v


def components(boxes, tol=1e-9):
    n = len(boxes)
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i, j):
        a, b = find(i), find(j)
        if a != b:
            parent[b] = a

    for i in range(n):
        for j in range(i + 1, n):
            if all(max(boxes[i]['box'][d][0], boxes[j]['box'][d][0]) - tol <=
                   min(boxes[i]['box'][d][1], boxes[j]['box'][d][1])
                   for d in range(len(boxes[i]['box']))):
                union(i, j)
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    parts = []
    for idx in groups.values():
        vol = sum(volume(boxes[i]['box']) for i in idx)
        dim = len(boxes[idx[0]]['box'])
        hull = [[min(boxes[i]['box'][d][0] for i in idx), max(boxes[i]['box'][d][1] for i in idx)] for d in range(dim)]
        parts.append({'boxes': len(idx), 'volume': vol, 'hull': hull})
    parts.sort(key=lambda x: x['volume'], reverse=True)
    total = sum(p['volume'] for p in parts) or 1.0
    return parts, total


def run(name):
    p = subprocess.run(['node', 'bin/rootcover.mjs', f'examples/{name}.json'],
                       cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
    data = json.loads(p.stdout)
    request = json.loads((ROOT / 'examples' / f'{name}.json').read_text(encoding='utf-8'))
    initial = volume(request['box'])
    inside = sum(volume(b['box']) for b in data.get('inside', []))
    unresolved = data.get('unresolved', [])
    unknown = sum(volume(b['box']) for b in unresolved)
    reasons = Counter(b['reason'] for b in unresolved)
    parts, total = components(data.get('inside', []))
    return {
        'case': name,
        'exit': p.returncode,
        'components': len(parts),
        'largest_component_boxes': parts[0]['boxes'] if parts else 0,
        'largest_component_volume_share': round(parts[0]['volume'] / total, 4) if parts else 0.0,
        'largest_component_hull': parts[0]['hull'] if parts else None,
        'component_detail': parts,
        'inside_boxes': len(data.get('inside', [])),
        'unresolved_boxes': len(unresolved),
        'assessments': data.get('stats', {}).get('assessments'),
        'inside_volume_ratio': round(inside / initial, 6),
        'envelope_volume_ratio': round((inside + unknown) / initial, 6),
        'reasons': dict(reasons),
    }


def main():
    rows = [run(name) for name in CASES]
    out = {'cases': rows, 'note': 'Volume ratios use axis-aligned box volumes; inside and unresolved boxes are disjoint by construction. Ratios are evidence of coverage, not a performance claim.'}
    (ROOT / 'docs/evidence/envelope.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')

    lines = [
        '# 可行域覆盖与未决原因',
        '',
        '盒数不能说明"交付的是区域还是碎片"。下表用初始盒体积归一化，给出内盒体积占比与内盒∪未决的体积上界，并按 `unresolved[].reason` 分桶。',
        '',
        '| 场景 | 内盒 | 连通分支 | 最大分支盒数 | 最大分支体积占比 | 未决 | 评估次数 | 内盒体积占比 | 上界占比 | 未决原因 |',
        '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |',
    ]
    for r in rows:
        reasons = '；'.join(f'{k}×{v}' for k, v in r['reasons'].items()) or '—'
        lines.append(f"| {r['case']} | {r['inside_boxes']} | {r['components']} | {r['largest_component_boxes']} | "
                     f"{r['largest_component_volume_share']:.4f} | {r['unresolved_boxes']} | {r['assessments']} | "
                     f"{r['inside_volume_ratio']:.4f} | {r['envelope_volume_ratio']:.4f} | {reasons} |")
    lines += ['', '## 分支明细（hull 为外包盒，两个不相交分支的 hull 仍可能重叠）', '',
              '| 场景 | 分支 | 盒数 | 占内盒体积 | hull |', '| --- | --- | --- | --- | --- |']
    for r in rows:
        if r['components'] > 1 or r['case'] in ('design_window6',):
            for n, part in enumerate(r['component_detail'], 1):
                share = part['volume'] / max(sum(x['volume'] for x in r['component_detail']), 1e-300)
                hull = ' × '.join(f'[{a:.4g},{b:.4g}]' for a, b in part['hull'])
                if r['case'] == 'design_window6' and len(r['component_detail']) == 1:
                    hull += '（hull 等于初始盒，不构成额外证据）'
                lines.append(f"| {r['case']} | {n} | {part['boxes']} | {share:.4f} | {hull} |")
    lines += [
        '',
        '读法：内盒体积占比是"已证明可行"的下界，上界占比是"可行点必定落在这里"的外包围；两者之差即未决部分。',
        '未决原因有四类文案：`resolution reached without whole-box classification`、`assessment budget exhausted`、`depth limit reached`、`no representable interior split point`。本次六个场景只触发第一类；预算耗尽与深度上限在代码中是分开的，不由文案合并。',
        '',
        '复现：`python scripts/envelope.py`（数据写入 `docs/evidence/envelope.json`）。合成模型，不代表工业规模。',
    ]
    (ROOT / 'docs/ENVELOPE.md').write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(rows, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
