"""依 Pain 原始觀測重現 GitHub README 的繁體中文 SVG／CSV 圖表。

只使用標準函式庫。相位篩選規則與既有分析器相同，
匯出筆數、極值與中位數皆交叉核對；不補值，也不跨越缺漏或重複資料連線。
"""
import argparse
import csv
from datetime import datetime, timezone, timedelta
from html import escape
import math
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))
from scripts.analysis.step6_post_settling_cko import (
    GUARDS, IDENTITY, LOCKS, analyze, board, fields,
)


def reviewed_rows(text):
    raw = [fields(line) for line in text.splitlines()
           if line.startswith('S6_INTERLEAVED_SAMPLE ') and board(line) == '1-11.2']
    retained = []
    identity = prior = None
    for row in raw:
        if (any(row.get(key) != '1' for key in GUARDS)
                or row.get('RESET_CHANGED') != '0'
                or row.get('PHASE_CONTEXT') not in ('1', '2')):
            continue
        try:
            signature = tuple(int(row[key], 16) for key in IDENTITY)
            ucnt = int(row['UCNT'], 16)
            if ucnt != int(row['PHASE_CONTEXT_UCNT'], 16):
                continue
            elapsed = int(row['elapsed_ms'])
            cko = int(row['CKO_PS'])
            state = int(row['SERVO_STATE'])
            setp = int(row['SETP_PS'])
            dms = int(row['DMS_PS'])
            if elapsed < 0 or not -2147483648 <= cko <= 2147483647:
                continue
        except (KeyError, ValueError):
            continue
        if identity is None:
            identity = signature
        if signature != identity:
            continue
        if prior is not None:
            delta = (ucnt - prior) & 0xffffffff
            if delta == 0 or delta > 0x7fffffff:
                continue
        prior = ucnt
        retained.append(dict(sample=int(row['sample']), elapsed_ms=elapsed,
                             ucnt=row['UCNT'], cko_ps=cko, setp_ps=setp,
                             dms_ps=dms, servo_state=state,
                             time_valid=int(row['STATUS_TIME_VALID']),
                             healthy=int(row.get('STEP1_GATE') == '1' and
                                         all(row.get(key) == '1' for key in LOCKS)),
                             cko_host_us=int(row['CKO_HOST_US'])))
    reference = analyze(text)
    if not retained or not reference['diagnostic_capture_complete']:
        raise ValueError('可信相位診斷尚未完整，不能產生看似通過的圖表。')
    assert len(retained) == reference['unique_update_rows']
    assert min(row['cko_ps'] for row in retained) == reference['cko_min_ps']
    assert max(row['cko_ps'] for row in retained) == reference['cko_max_ps']
    assert statistics.median(row['cko_ps'] for row in retained) == reference['cko_median_ps']
    return raw, retained, reference


def make_svg(raw, rows, result):
    width, height = 1200, 760
    left, right = 85, 1150
    top, bottom = 165, 475
    status_top, status_bottom = 555, 610
    span_s = max(int(row['elapsed_ms']) for row in raw) / 1000
    bound = max(200, math.ceil(max(abs(result['cko_min_ps']),
                                  abs(result['cko_max_ps'])) / 100) * 100 + 100)
    x = lambda elapsed: left + elapsed / (span_s * 1000) * (right - left)
    y = lambda cko: bottom - (cko + bound) / (2 * bound) * (bottom - top)
    tz = timezone(timedelta(hours=8))
    first = datetime.fromtimestamp(rows[0]['cko_host_us'] / 1e6, tz)
    last = datetime.fromtimestamp(rows[-1]['cko_host_us'] / 1e6, tz)
    period = f'{first:%Y-%m-%d %H:%M:%S} - {last:%H:%M:%S}（臺北時間）'
    valid_rows = sum(row.get('STATUS_TIME_VALID') == '1' for row in raw)
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title description">',
           '<title id="title">Slave CKO 隨觀測時間變化與 TIME_VALID 狀態</title>',
           '<desc id="description">實際通過資料檢查的 Slave CKO 更新；不填補缺漏或重複資料。參考線為正負 60 與 120 皮秒。TIME_VALID 另以原始狀態讀取顯示。</desc>',
           '<rect width="1200" height="760" fill="#ffffff"/>',
           '<g font-family="Microsoft JhengHei, Noto Sans CJK TC, sans-serif" fill="#24303d">']

    def text(px, py, value, size=16, **attrs):
        extra = ' '.join(f'{key.replace("_", "-")}="{escape(str(value))}"' for key, value in attrs.items())
        svg.append(f'<text x="{px}" y="{py}" font-size="{size}" {extra}>{escape(str(value))}</text>')

    def line(x1, y1, x2, y2, color='#dbe1e7', stroke=1, dashed=False):
        dash = ' stroke-dasharray="5 5"' if dashed else ''
        svg.append(f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" stroke="{color}" stroke-width="{stroke}"{dash}/>')

    text(left, 40, 'Slave CKO 隨時間變化', 28, font_weight=600)
    text(left, 68, f'DE5 [1-11.2]  |  {period}  |  相位取得 /2、追蹤 /12', 16)
    text(left, 100, f'最小 {result["cko_min_ps"]:+d} ps    最大 {result["cko_max_ps"]:+d} ps    峰對峰 {result["cko_peak_to_peak_ps"]} ps    標準差 {result["cko_stddev_ps"]:.1f} ps', 17)
    svg.append(f'<circle cx="{left+3}" cy="130" r="3" fill="#245fa8"/>')
    text(left+15, 135, f'{len(rows)} 筆可信且不重複的 CKO 更新', 14)
    line(450, 130, 484, 130, '#ad770d', 1.3, True)
    text(492, 135, '±120 ps 參考線', 14)
    line(730, 130, 764, 130, '#71808e', 1.2, True)
    text(772, 135, '±60 ps 參考線', 14)

    svg.append(f'<rect x="{left}" y="{y(120):.2f}" width="{right-left}" height="{y(-120)-y(120):.2f}" fill="#faf3df"/>')
    for tick in range(-bound, bound+1, 200):
        line(left, y(tick), right, y(tick), '#e4e8ec')
        text(left-12, y(tick)+5, f'{tick:+d}' if tick else '0', 14, text_anchor='end')
    ticks = [0, 60, 120, 180, 240, 300]
    for tick in ticks:
        line(x(tick*1000), top, x(tick*1000), bottom, '#e7ebef')
        line(x(tick*1000), status_top, x(tick*1000), status_bottom, '#e7ebef')
        text(x(tick*1000), 645, str(tick), 15, text_anchor='middle')
    for limit in (-120, 120):
        line(left, y(limit), right, y(limit), '#ad770d', 1.2, True)
    for limit in (-60, 60):
        line(left, y(limit), right, y(limit), '#71808e', 1, True)
    line(left, y(0), right, y(0), '#66717b', 1.2)
    line(left, top, left, bottom, '#66717b')
    line(left, bottom, right, bottom, '#66717b')
    text(25, (top+bottom)/2, 'CKO（皮秒，ps）', 16, transform=f'rotate(-90 25 {(top+bottom)/2})', text_anchor='middle')

    previous = None
    for row in rows:
        if previous and row['sample'] == previous['sample']+1 and row['elapsed_ms']-previous['elapsed_ms'] <= 2000:
            line(x(previous['elapsed_ms']), y(previous['cko_ps']), x(row['elapsed_ms']), y(row['cko_ps']), '#6c98cb', 1)
        svg.append(f'<circle cx="{x(row["elapsed_ms"]):.2f}" cy="{y(row["cko_ps"]):.2f}" r="2.6" fill="#245fa8"/>')
        previous = row

    text(left, 528, f'STATUS_TIME_VALID（獨立狀態讀取）：{valid_rows}/{len(raw)} 筆為 1', 17)
    line(left, status_top, right, status_top, '#e4e8ec')
    line(left, status_bottom, right, status_bottom, '#e4e8ec')
    line(left, status_top-6, left, status_bottom, '#66717b')
    text(left-12, status_top+5, '1', 14, text_anchor='end')
    text(left-12, status_bottom+5, '0', 14, text_anchor='end')
    prior = None
    for row in raw:
        if row.get('STATUS_TIME_VALID') not in ('0', '1'):
            prior = None
            continue
        px = x(int(row['elapsed_ms']))
        py = status_top if row['STATUS_TIME_VALID'] == '1' else status_bottom
        if prior and 0 < int(row['elapsed_ms'])-prior[2] <= 1000:
            line(prior[0], prior[1], px, prior[1], '#245fa8', 1.5)
            line(px, prior[1], px, py, '#245fa8', 1.5)
        svg.append(f'<circle cx="{px:.2f}" cy="{py:.2f}" r="1.7" fill="#245fa8"/>')
        prior = (px, py, int(row['elapsed_ms']))
    text((left+right)/2, 680, '開始觀測後經過時間（秒）', 17, text_anchor='middle')
    text(left, 715, f'CKO：排除 {result["rejected"].get("untrusted_phase_frame", 0)} 筆不可信資料與 {result["duplicate_updates"]} 筆重複更新。', 14)
    text(left, 739, '只連接相鄰保留點；TIME_VALID 維持不代表 ±60/120 ps 精度，也不是實體抖動量測。', 13)
    svg.extend(['</g>', '</svg>'])
    return '\n'.join(svg)+'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path,
                        default=Path(__file__).resolve().parents[1]/'raw/observe/cko-303s.log')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    raw, rows, result = reviewed_rows(args.capture.read_text(encoding='utf-8'))
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output/'cko-timeseries.csv').open('w', encoding='utf-8', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    (args.output/'cko-timeseries.svg').write_text(make_svg(raw, rows, result), encoding='utf-8')
    print(f'CHART_REVIEWED_ROWS={len(rows)} CKO_MIN_PS={result["cko_min_ps"]} CKO_MAX_PS={result["cko_max_ps"]} TIME_VALID_ROWS={sum(r.get("STATUS_TIME_VALID")=="1" for r in raw)}/{len(raw)}')


if __name__ == '__main__':
    main()
