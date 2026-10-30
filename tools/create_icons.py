"""Original Colony Contract line icons. Authored for this project, no external shapes."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'game/assets/icons'
OUT.mkdir(parents=True, exist_ok=True)
ICONS = {
 'ore': '<path d="M10 40 18 20 38 13 53 31 45 51 22 53Z"/><path d="m18 20 12 18 23-7M30 38l-8 15M30 38l8-25"/>',
 'copper': '<path d="m11 24 21-11 21 11-21 12Z M11 24v20l21 10 21-10V24 M32 36v18"/><path d="m21 19 21 11M17 39l8 4m14-2 8-4"/>',
 'crystal': '<path d="m32 8 15 14-4 25-11 10-13-10-3-25Z"/><path d="m16 22 16 8 15-8M32 8v22l11 17M32 30 19 47m13-17v27"/>',
 'food': '<path d="M32 56V18 M32 29C19 29 13 22 15 14c10 0 17 6 17 15Z M32 41c13 0 19-7 17-15-10 0-17 6-17 15Z M32 18c-7-7-6-12 0-16 6 4 7 9 0 16Z"/><path d="M22 56h20"/>',
 'materials': '<path d="m9 22 26-10 20 11-26 10Z M9 22v10l20 11 26-10V23 M9 39l20 11 26-10v10L29 60 9 49Z"/><path d="M29 33v10m0 7v10"/>',
 'parts': '<path d="m26 9 12 0 2 9 8-4 8 12-7 6 7 6-8 12-8-4-2 9H26l-2-9-8 4-8-12 7-6-7-6 8-12 8 4Z"/><circle cx="32" cy="32" r="9"/>',
 'habitat': '<path d="M8 52V28L32 9l24 19v24Z M8 28h48 M26 52V36h12v16"/><path d="M16 35h4v7h-4zm28 0h4v7h-4zM16 20V10h8v5"/>',
 'power': '<path d="m35 5-22 29h16l-4 25 26-34H35Z"/><path d="M8 17v-5h8m32 40h8v-5"/>',
 'water': '<path d="M32 7C26 18 13 29 13 39a19 19 0 0 0 38 0C51 29 38 18 32 7Z"/><path d="M22 39a10 10 0 0 0 10 10M21 32c5 3 17 3 22 0"/>',
 'farm': '<path d="M7 53h50 M12 48V29l20-17 20 17v19 M12 29h40 M23 48V29m18 19V29 M8 59h48"/><path d="M32 47V35m0 6-5-3m5 0 5-3"/>',
 'processor': '<path d="M8 54V29l15 8V24l16 10V20h15v34Z M39 20V9h15v11"/><path d="M16 43h8v6h-8zm16 0h8v6h-8zm16 0h6"/>',
 'lab': '<path d="M23 8h18 M26 8v17L12 47c-4 6-1 10 6 10h28c7 0 10-4 6-10L38 25V8 M21 36h22"/><circle cx="27" cy="44" r="3"/><circle cx="38" cy="49" r="2"/><path d="m48 11 4-4m0 9h6"/>',
 'port': '<path d="M9 55h46 M14 55V37h36v18 M25 37V25h14v12 M32 25V6 M22 16l10-10 10 10"/><path d="M20 44h7v6h-7zm17 0h7v6h-7zM7 28h11m28 0h11"/>',
 'warning': '<path d="m32 9 26 45H6Z"/><path d="M32 25v13"/><circle cx="32" cy="46" r="1.5" fill="#E46F68"/>',
}
for name, shape in ICONS.items():
 color = '#E46F68' if name == 'warning' else '#E7EEF2'
 svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="{color}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">{shape}</g></svg>\n'
 (OUT / f'{name}.svg').write_text(svg, encoding='utf-8')
print(f'Created {len(ICONS)} original SVG icons in {OUT}')
