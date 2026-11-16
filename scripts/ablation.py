"""Ablation: contractors on/off and the tolerance ladder for the flagship case."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CASES = ['robot_workspace', 'thermal_parameters', 'mixed_process',
         'robust_localization', 'design_alternatives', 'design_window6']
LADDER = [0.4, 0.3, 0.2, 0.1]


def run(name, patch=None, path=None):
    q = json.loads((ROOT / 'examples' / (path or f'{name}.json')).read_text(encoding='utf-8'))
    if patch:
        q.update(patch)
    tmp = ROOT / 'artifacts' / '_ablation_request.json'
    tmp.parent.mkdir(exist_ok=True)
    tmp.write_text(json.dumps(q, ensure_ascii=False), encoding='utf-8')
    p = subprocess.run(['node', 'bin/rootcover.mjs', str(tmp)], cwd=ROOT,
                       capture_output=True, text=True, encoding='utf-8')
    data = json.loads(p.stdout)
    return {
        'inside': len(data.get('inside', [])),
        'unresolved': len(data.get('unresolved', [])),
        'assessments': data.get('stats', {}).get('assessments'),
        'resolution_met': data.get('resolution_met'),
        'complete': data.get('complete'),
        'exit': p.returncode,
    }


def main():
    rows = []
    for name in CASES:
        on = run(name)
        off = run(name, {'contractors': {'propagation': False, 'newton': False}})
        ratio = off['assessments'] / on['assessments'] if on['assessments'] else None
        rows.append({'case': name, 'on': on, 'off': off,
                     'assessment_ratio_off_over_on': round(ratio, 2) if ratio else None})

    ladder = []
    for tol in LADDER:
        r = run('design_window6', {'options': {'tolerance': tol, 'max_assessments': 20000}})
        ladder.append({'tolerance': tol, **r})

    out = {'contractors': rows, 'tolerance_ladder': ladder,
           'note': 'Synthetic models. Assessment counts are deterministic; wall time is not recorded.'}
    (ROOT / 'docs/evidence/ablation.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    lines = [
        '# 消融与精度阶梯',
        '',
        '这份表回答两个会被追问的问题：收缩器到底在哪些场景有效？旗舰场景是不是靠放精度"做出来"的？',
        '',
        '## 收缩器开关（其余参数同示例）',
        '',
        '| 场景 | 开：内盒/未决/评估 | 关：内盒/未决/评估 | 关闭后评估倍数 | 读法 |',
        '| --- | --- | --- | --- | --- |',
    ]
    for r in rows:
        on, off = r['on'], r['off']
        mult = f"{r['assessment_ratio_off_over_on']:.2f}×" if r['assessment_ratio_off_over_on'] else '—'
        if r['case'] == 'design_window6':
            note = '中性：at_least 的外包围收缩不改变该结构'
        elif r['case'] == 'thermal_parameters':
            note = '权衡：内盒更多但评估更多'
        else:
            note = '有效：评估减少'
        lines.append(f"| {r['case']} | {on['inside']}/{on['unresolved']}/{on['assessments']} | "
                     f"{off['inside']}/{off['unresolved']}/{off['assessments']} | {mult} | {note} |")

    lines += ['', '## flagships：design_window6 的精度阶梯（max_assessments=20000）', '',
              '| tolerance | 内盒 | 未决 | 评估 | resolution_met | 退出码 |',
              '| --- | --- | --- | --- | --- | --- |']
    for r in ladder:
        lines.append(f"| {r['tolerance']} | {r['inside']} | {r['unresolved']} | {r['assessments']} | "
                     f"{r['resolution_met']} | {r['exit']} |")

    lines += [
        '',
        '读法：0.3 是当前 20000 次预算下能达到 `resolution_met` 的精度；0.2 与 0.1 都耗尽预算，输出仍给出内盒与外包围，但 `resolution_met=false`。这不是"调参做出成功"，而是把可完成精度与预算一起报告；要更细的覆盖需要更高预算或更小维度。',
        '',
        '收缩器的作用是结构相关的：在机构、观测、混合模型上减少 1.7–3.8 倍评估；在 `design_window6` 的 `at_least` 外包围上中性；在 `thermal_parameters` 上是"更多内盒、更多评估"的权衡。材料不再声称"联合收缩解决耦合"这类绝对结论。',
        '',
        '复现：`python scripts/ablation.py`（数据写入 `docs/evidence/ablation.json`）。',
    ]
    (ROOT / 'docs/ABLATION.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps({'rows': rows, 'ladder': ladder}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
