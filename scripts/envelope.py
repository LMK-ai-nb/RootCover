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
    return {
        'case': name,
        'exit': p.returncode,
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
    (ROOT / 'docs/evidence/envelope.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    lines = [
        '# 可行域覆盖与未决原因',
        '',
        '盒数不能说明"交付的是区域还是碎片"。下表用初始盒体积归一化，给出内盒体积占比与内盒∪未决的体积上界，并按 `unresolved[].reason` 分桶。',
        '',
        '| 场景 | 内盒 | 未决 | 评估次数 | 内盒体积占比 | 上界占比 | 未决原因 |',
        '| --- | --- | --- | --- | --- | --- | --- |',
    ]
    for r in rows:
        reasons = '；'.join(f'{k}×{v}' for k, v in r['reasons'].items()) or '—'
        lines.append(f"| {r['case']} | {r['inside_boxes']} | {r['unresolved_boxes']} | {r['assessments']} | "
                     f"{r['inside_volume_ratio']:.4f} | {r['envelope_volume_ratio']:.4f} | {reasons} |")
    lines += [
        '',
        '读法：内盒体积占比是"已证明可行"的下界，上界占比是"可行点必定落在这里"的外包围；两者之差即未决部分。',
        '未决原因目前只有一类文案（分辨率到达但整盒未分类），预算耗尽与深度上限都会落到同一文案，因此不区分"算不动"与"已到 ε"。',
        '',
        '复现：`python scripts/envelope.py`（数据写入 `docs/evidence/envelope.json`）。合成模型，不代表工业规模。',
    ]
    (ROOT / 'docs/ENVELOPE.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(rows, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
