#!/usr/bin/env python3
"""Check machine-readable design contracts. Does not certify full accessibility."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def luminance(color):
    channels = [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * w for c, w in zip(linear, (0.2126, 0.7152, 0.0722)))
def contrast(a, b):
    lo, hi = sorted((luminance(a), luminance(b)))
    return (hi + 0.05) / (lo + 0.05)
def main():
    tokens = json.loads((ROOT / 'architecture/design-tokens.json').read_text())
    checks = []
    for name, theme in tokens['themes'].items():
        for surface in ('background', 'surface'):
            for foreground in ('text', 'secondaryText', 'train', 'fuel', 'stack', 'body', 'success', 'warning', 'danger'):
                ratio = contrast(theme[foreground], theme[surface])
                assert ratio >= 4.5, (name, foreground, surface, ratio)
                checks.append(ratio)
            assert contrast(theme['border'], theme[surface]) >= 3, (name, surface, 'border')
    assert tokens['minInteractiveSizePt'] >= 48
    assert tokens['motion']['chartDrawMs'] <= 400
    assert len(tokens['chart']['categoricalTokens']) <= 8
    assert len(set(tokens['chart']['symbols'])) >= len(tokens['chart']['categoricalTokens'])
    print(f'PASS: {len(checks)} text/essential-mark contrast pairs; minimum {min(checks):.2f}:1, border ≥3:1, 48pt targets, motion and redundant symbols.')
if __name__ == '__main__':
    main()
