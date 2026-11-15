"""Slave CKO 時間序列圖（與 2026-10-05 圖表相同版面），並與 10-05 比較。

輸入：read_step6_servo_interleaved_offset.tcl（mode 0）擷取紀錄。
CKO 只取 COHERENT=1 且 UCNT 不重複的 servo 更新；不補值、不連接超過 2 s 的缺口。
"""
import argparse
import csv
import re
import statistics
from datetime import datetime, timezone, timedelta
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

plt.rcParams["font.family"] = ["Microsoft JhengHei", "Noto Sans CJK TC", "sans-serif"]
plt.rcParams["axes.unicode_minus"] = False
INK, MUTED, BLUE, LINE, RAW = "#24303d", "#66717b", "#245fa8", "#6c98cb", "#b8c2cc"
GOLD, GREY, BAND = "#ad770d", "#71808e", "#faf3df"


def parse(path):
    raw_by_ucnt, rows, status, seen = {}, [], [], set()
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("S6_RAW_OFFSET"):
            m = re.search(r"UCNT=([0-9A-Fa-f]+) RAW_OFFSET_PS=(-?\d+)", line)
            if m:
                raw_by_ucnt.setdefault(m.group(1).upper(), int(m.group(2)))
            continue
        if not line.startswith("S6_INTERLEAVED_SAMPLE"):
            continue
        d = dict(re.findall(r"(\w+)=(\S+)", line))
        t = int(d["elapsed_ms"]) / 1000
        if d.get("STATUS_TIME_VALID") in ("0", "1"):
            status.append((t, int(d["STATUS_TIME_VALID"])))
        if d.get("COHERENT") != "1" or d["UCNT"] in seen:
            continue
        seen.add(d["UCNT"])
        rows.append(dict(t=t, sample=int(d["sample"]), ucnt=d["UCNT"].upper(),
                         cko=int(d["CKO_PS"]), state=int(d["SERVO_STATE"]),
                         host_us=int(d["CKO_HOST_US"])))
    for r in rows:
        r["raw"] = raw_by_ucnt.get(r["ucnt"])
    return rows, status


def stats(v):
    return dict(min=min(v), max=max(v), pp=max(v) - min(v), sd=statistics.stdev(v))


def style(ax):
    ax.axhspan(-120, 120, color=BAND, zorder=0)
    for lim, col in ((120, GOLD), (-120, GOLD), (60, GREY), (-60, GREY)):
        ax.axhline(lim, color=col, lw=1.1, ls=(0, (5, 5)), zorder=1)
    ax.axhline(0, color=MUTED, lw=1.1, zorder=1)
    ax.set_ylim(-600, 600)
    ax.set_yticks(range(-600, 601, 200))
    ax.set_yticklabels([f"{v:+d}" if v else "0" for v in range(-600, 601, 200)])
    ax.set_xlim(0, 302)
    ax.set_xticks(range(0, 301, 60))
    ax.grid(color="#e4e8ec", lw=0.8)
    ax.set_axisbelow(True)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture")
    ap.add_argument("--old-csv", help="2026-10-05 cko-timeseries.csv for comparison")
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    rows, status = parse(a.capture)
    ck = [r["cko"] for r in rows]
    rw = [r["raw"] for r in rows if r["raw"] is not None]
    s, sr = stats(ck), stats(rw)
    tz = timezone(timedelta(hours=8))
    t0 = datetime.fromtimestamp(rows[0]["host_us"] / 1e6, tz)
    t1 = datetime.fromtimestamp(rows[-1]["host_us"] / 1e6, tz)
    with (out / "cko-timeseries.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    fig = plt.figure(figsize=(12, 7.6), dpi=150)
    fig.patch.set_facecolor("white")
    ax = fig.add_axes([0.07, 0.36, 0.89, 0.40])
    st = fig.add_axes([0.07, 0.15, 0.89, 0.08], sharex=ax)
    fig.text(0.07, 0.955, "Slave CKO 隨時間變化", fontsize=22, weight="bold", color=INK)
    fig.text(0.07, 0.915, f"DE5 [1-11.2]  |  {t0:%Y-%m-%d %H:%M:%S} - {t1:%H:%M:%S}（臺北時間）"
             "  |  4 Hz PTP、32 筆平均、追蹤 /8", fontsize=12, color=INK)
    fig.text(0.07, 0.877, f"最小 {s['min']:+d} ps    最大 {s['max']:+d} ps    峰對峰 {s['pp']} ps"
             f"    標準差 {s['sd']:.1f} ps", fontsize=13.5, color=INK)
    style(ax)
    ax.scatter([r["t"] for r in rows if r["raw"] is not None], rw, s=6, color=RAW, zorder=2,
               label=f"單次交換 raw offset（對照，σ {sr['sd']:.0f} ps）")
    prev = None
    for r in rows:
        if prev and r["t"] - prev["t"] <= 2.0:
            ax.plot([prev["t"], r["t"]], [prev["cko"], r["cko"]], color=LINE, lw=1, zorder=3)
        prev = r
    ax.scatter([r["t"] for r in rows], ck, s=9, color=BLUE, zorder=4,
               label=f"{len(rows)} 筆不重複的 CKO 更新（servo 使用值）")
    ax.plot([], [], color=GOLD, ls=(0, (5, 5)), label="±120 ps 參考線")
    ax.plot([], [], color=GREY, ls=(0, (5, 5)), label="±60 ps 參考線")
    ax.legend(loc="upper left", bbox_to_anchor=(0, 1.16), ncol=4, frameon=False, fontsize=10.5,
              handletextpad=0.4, columnspacing=1.6)
    ax.set_ylabel("CKO（皮秒，ps）", fontsize=12, color=INK)
    plt.setp(ax.get_xticklabels(), visible=False)
    nv = sum(v for _, v in status)
    fig.text(0.07, 0.255, f"STATUS_TIME_VALID（獨立狀態讀取）：{nv}/{len(status)} 筆為 1",
             fontsize=13, color=INK)
    st.step([t for t, _ in status], [v for _, v in status], where="post", color=BLUE, lw=1.4)
    st.scatter([t for t, _ in status], [v for _, v in status], s=3, color=BLUE)
    st.set_ylim(-0.15, 1.15)
    st.set_yticks([0, 1])
    st.grid(axis="x", color="#e4e8ec", lw=0.8)
    for sp in ("top", "right"):
        st.spines[sp].set_visible(False)
    st.set_xlabel("開始觀測後經過時間（秒）", fontsize=12, color=INK)
    in60 = sum(abs(c) <= 60 for c in ck)
    trk = sum(r["state"] == 4 for r in rows)
    fig.text(0.07, 0.055, f"|CKO|≤60 ps：{in60}/{len(rows)}；TRACK_PHASE：{trk}/{len(rows)}。"
             "CKO 為 servo 的 32 筆平均 PTP 偏移估測；灰點為單次交換值。", fontsize=10.5, color=INK)
    fig.text(0.07, 0.028, "只連接相鄰保留點；這不是實體 PPS 邊緣抖動量測。", fontsize=10, color=MUTED)
    fig.savefig(out / "cko-timeseries.png")
    plt.close(fig)

    if a.old_csv:
        old = list(csv.DictReader(open(a.old_csv, encoding="utf-8")))
        ot = [int(r["elapsed_ms"]) / 1000 for r in old]
        oc = [int(r["cko_ps"]) for r in old]
        so = stats(oc)
        fig, axes = plt.subplots(1, 2, figsize=(13, 5.4), dpi=150, sharey=True)
        fig.patch.set_facecolor("white")
        panels = ((axes[0], ot, oc, "2026-10-05（/2＋/12，單次交換）", so),
                  (axes[1], [r["t"] for r in rows], ck, "2026-11-15（T24P 7500、4 Hz、32 筆平均）", s))
        for axx, t, c, title, ss in panels:
            style(axx)
            axx.plot(t, c, color=LINE, lw=0.8, zorder=2)
            axx.scatter(t, c, s=7, color=BLUE, zorder=3)
            axx.set_title(title, fontsize=13, color=INK, loc="left")
            axx.text(0.0, -0.2, f"峰對峰 {ss['pp']} ps，標準差 {ss['sd']:.1f} ps，"
                     f"|CKO|≤120 ps：{sum(abs(v) <= 120 for v in c)}/{len(c)}",
                     transform=axx.transAxes, fontsize=11, color=INK)
            axx.set_xlabel("經過時間（秒）", fontsize=11)
        axes[0].set_ylabel("Slave CKO（ps）", fontsize=12)
        fig.suptitle("Slave CKO：改善前後比較（相同縱軸）", fontsize=17, weight="bold", color=INK,
                     x=0.06, ha="left")
        fig.subplots_adjust(left=0.07, right=0.98, top=0.85, bottom=0.22, wspace=0.06)
        fig.savefig(out / "cko-compare-20261005.png")
        plt.close(fig)
    print(f"ROWS={len(rows)} CKO={s} RAW={sr} TIME_VALID={nv}/{len(status)}")


if __name__ == "__main__":
    main()
