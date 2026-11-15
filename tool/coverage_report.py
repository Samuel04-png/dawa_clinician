#!/usr/bin/env python3
"""Validate native Flutter LCOV and report its actual package-source coverage.

No records or lines are removed, rebased, synthesized or written to LCOV.
"""
import argparse
import hashlib
import json
from pathlib import Path


def parse_lcov(raw, root):
    records = {}
    pending = None
    for number, line in enumerate(raw.splitlines(), 1):
        if line.startswith('SF:'):
            if pending is not None:
                raise ValueError(f'Unterminated record at line {number}')
            source = line[3:]
            path = Path(source)
            if path.is_absolute():
                source = path.resolve().relative_to(root.resolve()).as_posix()
            if not source.startswith('lib/') or '..' in Path(source).parts or not source.endswith('.dart'):
                raise ValueError(f'Non-production source record: {source}')
            if source in records or not (root / source).is_file():
                raise ValueError(f'Duplicate or missing source: {source}')
            pending = {'path': source, 'lines': {}, 'declared_total': None, 'declared_hit': None, 'source_line_count': len((root / source).read_text().splitlines())}
        elif line.startswith('DA:'):
            if pending is None:
                raise ValueError(f'Line data outside a source record at {number}')
            fields = line[3:].split(',')
            if len(fields) not in (2, 3):
                raise ValueError(f'Invalid line data at {number}')
            position, count = map(int, fields[:2])
            if position < 1 or count < 0 or position in pending['lines']:
                raise ValueError(f'Invalid or duplicate line data at {number}')
            if position > pending['source_line_count']:
                raise ValueError(f'Line outside current source at {number}')
            pending['lines'][position] = count
        elif line.startswith(('LF:', 'LH:')):
            if pending is None:
                raise ValueError(f'Total outside source record at {number}')
            key = 'declared_total' if line.startswith('LF:') else 'declared_hit'
            if pending[key] is not None:
                raise ValueError(f'Duplicate total at {number}')
            pending[key] = int(line[3:])
        elif line == 'end_of_record':
            if pending is None or not pending['lines']:
                raise ValueError(f'Empty source record at {number}')
            total = len(pending['lines'])
            hit = sum(count > 0 for count in pending['lines'].values())
            if pending['declared_total'] != total or pending['declared_hit'] != hit:
                raise ValueError(f'LCOV totals disagree with line data: {pending["path"]}')
            records[pending['path']] = {'covered': hit, 'total': total,
                'uncovered_lines': [n for n, count in pending['lines'].items() if count == 0]}
            pending = None
    if pending is not None or not records:
        raise ValueError('Empty or incomplete coverage report')
    return records


def module_for(source):
    parts = Path(source).parts
    if parts[1] == 'application':
        return '/'.join(parts[1:3])
    if parts[1] == 'features':
        return '/'.join(parts[1:3])
    if parts[1] in ('services', 'backend', 'auth', 'components', 'flutter_flow'):
        return parts[1]
    return 'app/account/other'


def summarize(records):
    covered = sum(r['covered'] for r in records.values())
    total = sum(r['total'] for r in records.values())
    modules = {}
    for source, record in records.items():
        module = modules.setdefault(module_for(source), {'covered': 0, 'total': 0})
        module['covered'] += record['covered']
        module['total'] += record['total']
    for record in modules.values():
        record['percent'] = record['covered'] / record['total'] * 100
    return {'covered': covered, 'total': total, 'percent': covered / total * 100,
            'instrumented_files': len(records), 'modules': dict(sorted(modules.items())),
            'files': dict(sorted(records.items()))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('lcov', type=Path)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--json', type=Path)
    parser.add_argument('--minimum', type=float)
    parser.add_argument('--required-sources', type=Path)
    args = parser.parse_args()
    try:
        raw = args.lcov.read_text()
        records = parse_lcov(raw, args.root)
        if args.required_sources:
            required = set(args.required_sources.read_text().splitlines())
            missing = required - records.keys()
            if missing:
                raise ValueError('Previously instrumented sources missing: ' + ', '.join(sorted(missing)))
        result = summarize(records)
        result['lcov_sha256'] = hashlib.sha256(raw.encode()).hexdigest()
        result['scope'] = 'All records in native flutter test --coverage for package clinician; no source exclusions or line transformations'
        result['not_reported_by_flutter'] = sorted(str(p.relative_to(args.root)) for p in (args.root / 'lib').rglob('*.dart') if str(p.relative_to(args.root)) not in records)
        result['branch_coverage'] = None
        result['function_coverage'] = None
        print(f'Line coverage: {result["percent"]:.4f}% ({result["covered"]}/{result["total"]} lines; {len(records)} files)')
        if args.json:
            args.json.parent.mkdir(parents=True, exist_ok=True)
            args.json.write_text(json.dumps(result, indent=2) + '\n')
        if args.minimum is not None and result['covered'] * 100 < args.minimum * result['total']:
            raise ValueError(f'Measured coverage is below {args.minimum:g}%')
    except (OSError, ValueError) as error:
        parser.exit(1, f'Coverage validation failed: {error}\n')


if __name__ == '__main__':
    main()
