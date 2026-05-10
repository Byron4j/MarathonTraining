#!/usr/bin/env python3
"""训练日志统计分析脚本

读取 CSV 格式训练日志，输出多维度统计分析和趋势报告。

特性:
- 周/月汇总统计
- 训练类型分布
- 配速与心率趋势分析
- 配速-心率相关性
- 训练负荷变化趋势
- 详情列表展示

用法:
  python3 analyze_log.py <训练日志.csv>
  python3 analyze_log.py <训练日志.csv> --all       # 显示详细记录
  python3 analyze_log.py <训练日志.csv> --json      # JSON 输出
  python3 analyze_log.py <训练日志.csv> --trend     # 仅趋势分析
"""

import sys
import csv
import json
import os
from collections import defaultdict
from datetime import datetime, timedelta
from statistics import mean, stdev


# ── ANSI 颜色 ──

class C:
    NONE = ""; RED = "\033[91m"; GREEN = "\033[92m"; YELLOW = "\033[93m"
    BLUE = "\033[94m"; MAGENTA = "\033[95m"; CYAN = "\033[96m"; WHITE = "\033[97m"
    BOLD = "\033[1m"; DIM = "\033[2m"; RESET = "\033[0m"

    @staticmethod
    def ok():
        return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()

    @classmethod
    def c(cls, text, *colors):
        return ("".join(colors) + str(text) + cls.RESET) if cls.ok() else str(text)


# ── 数据加载 ──

def parse_duration(s):
    if not s or not str(s).strip(): return 0
    p = str(s).strip().split(":")
    if len(p) == 2: return int(p[0]) * 60 + int(p[1])
    if len(p) == 3: return int(p[0]) * 3600 + int(p[1]) * 60 + int(p[2])
    try: return float(s)
    except: return 0

def parse_pace(s):
    if not s or not str(s).strip(): return 0
    p = str(s).strip().split(":")
    if len(p) == 2: return int(p[0]) + int(p[1]) / 60.0
    return 0

def to_num(s):
    try: return float(s) if s and str(s).strip() else 0
    except: return 0

def load_logs(filepath):
    if not os.path.exists(filepath):
        print(C.c(f"文件不存在: {filepath}", C.RED))
        sys.exit(1)
    def _s(v):
        return (v or "").strip()

    records = []
    with open(filepath, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row.get("日期") or not _s(row["日期"]):
                continue
            records.append({
                "date": _s(row.get("日期", "")),
                "type": _s(row.get("训练类型", "")),
                "distance": to_num(row.get("距离(km)")),
                "duration": parse_duration(row.get("时长(min)")),
                "pace": parse_pace(row.get("平均配速(/km)")),
                "avg_hr": to_num(row.get("平均心率")),
                "max_hr": to_num(row.get("最大心率")),
                "feel": to_num(row.get("体感(1-10)")),
                "sleep": to_num(row.get("睡眠(h)")),
                "weight": to_num(row.get("体重(kg)")),
                "temp": to_num(row.get("气温(°C)")),
                "note": _s(row.get("备注", "")),
            })
    records.sort(key=lambda r: r["date"])
    return records


# ── 工具函数 ──

def week_key(date_str):
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d")
        iso = dt.isocalendar()
        return f"{iso[0]}-W{iso[1]:02d}"
    except: return date_str

def month_key(date_str):
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").strftime("%Y-%m")
    except: return date_str

def pace_fmt(m):
    if m <= 0: return "--:--"
    return f"{int(m)}:{int((m%1)*60):02d}"

def avg(lst): return sum(lst) / len(lst) if lst else 0


# ── 分析函数 ──

def analyze_weekly(records):
    weeks = defaultdict(lambda: {"dist": 0, "dur": 0, "runs": 0, "paces": [], "hrs": [], "feels": []})
    for r in records:
        wk = week_key(r["date"])
        weeks[wk]["dist"] += r["distance"]
        weeks[wk]["dur"] += r["duration"]
        weeks[wk]["runs"] += 1
        if r["pace"] > 0: weeks[wk]["paces"].append(r["pace"])
        if r["avg_hr"] > 0: weeks[wk]["hrs"].append(r["avg_hr"])
        if r["feel"] > 0: weeks[wk]["feels"].append(r["feel"])
    return weeks

def analyze_monthly(records):
    months = defaultdict(lambda: {"dist": 0, "dur": 0, "runs": 0, "paces": [], "hrs": []})
    for r in records:
        mo = month_key(r["date"])
        months[mo]["dist"] += r["distance"]
        months[mo]["dur"] += r["duration"]
        months[mo]["runs"] += 1
        if r["pace"] > 0: months[mo]["paces"].append(r["pace"])
        if r["avg_hr"] > 0: months[mo]["hrs"].append(r["avg_hr"])
    return months

def analyze_types(records):
    types = defaultdict(lambda: {"dist": 0, "count": 0})
    for r in records:
        t = r["type"] or "未分类"
        types[t]["dist"] += r["distance"]
        types[t]["count"] += 1
    return types

def trend_analysis(weeks):
    """计算周跑量、配速趋势"""
    sorted_weeks = sorted(weeks.items())
    if len(sorted_weeks) < 2:
        return None

    dists = [w[1]["dist"] for w in sorted_weeks]
    paces = [avg(w[1]["paces"]) if w[1]["paces"] else 0 for w in sorted_weeks]
    hrs = [avg(w[1]["hrs"]) if w[1]["hrs"] else 0 for w in sorted_weeks]

    # 简单线性趋势 (首周 vs 末周)
    return {
        "weeks": len(sorted_weeks),
        "first_week": sorted_weeks[0][0],
        "last_week": sorted_weeks[-1][0],
        "dist_first": dists[0],
        "dist_last": dists[-1],
        "dist_trend": "↑" if dists[-1] > dists[0] * 1.05 else ("↓" if dists[-1] < dists[0] * 0.95 else "→"),
        "pace_first": pace_fmt(paces[0]) if paces[0] else "--",
        "pace_last": pace_fmt(paces[-1]) if paces[-1] else "--",
        "pace_improvement": f"{(paces[0] - paces[-1]) * 60:.0f}s" if paces[0] and paces[-1] else "--",
        "hr_first": int(hrs[0]) if hrs[0] else 0,
        "hr_last": int(hrs[-1]) if hrs[-1] else 0,
    }

def pace_hr_correlation(records):
    """配速与心率相关性"""
    pairs = [(r["pace"], r["avg_hr"]) for r in records if r["pace"] > 0 and r["avg_hr"] > 0]
    if len(pairs) < 3:
        return None

    # 皮尔逊相关系数
    n = len(pairs)
    sum_x = sum(p[0] for p in pairs)
    sum_y = sum(p[1] for p in pairs)
    sum_xy = sum(p[0] * p[1] for p in pairs)
    sum_x2 = sum(p[0] ** 2 for p in pairs)
    sum_y2 = sum(p[1] ** 2 for p in pairs)

    num = n * sum_xy - sum_x * sum_y
    den = ((n * sum_x2 - sum_x ** 2) * (n * sum_y2 - sum_y ** 2)) ** 0.5
    r = num / den if den != 0 else 0

    # 解释
    if abs(r) > 0.7: strength = "强"
    elif abs(r) > 0.4: strength = "中等"
    else: strength = "弱"

    direction = "正相关 (配速越快心率越高)" if r > 0 else "负相关"

    return {"r": round(r, 3), "strength": strength, "direction": direction, "n": n}


# ── 打印报告 ──

def print_summary(records, weeks, months):
    total_dist = sum(r["distance"] for r in records)
    total_dur = sum(r["duration"] for r in records)
    total_runs = len(records)
    paces = [r["pace"] for r in records if r["pace"] > 0]
    hrs = [r["avg_hr"] for r in records if r["avg_hr"] > 0]
    feels = [r["feel"] for r in records if r["feel"] > 0]

    W = 68
    print()
    print(C.c("═" * W, C.YELLOW))
    print(C.c("  训练日志统计分析", C.BOLD, C.WHITE))
    print(C.c("═" * W, C.YELLOW))
    print(f"  {C.c('总训练次数:', C.DIM)} {total_runs:>6}")
    print(f"  {C.c('总跑量:', C.DIM)}     {total_dist:>7.1f} km")
    print(f"  {C.c('总时长:', C.DIM)}     {total_dur / 60:>7.1f} 小时")
    if paces:
        print(f"  {C.c('平均配速:', C.DIM)}   {pace_fmt(avg(paces)):>7}/km")
        print(f"  {C.c('最快配速:', C.DIM)}   {pace_fmt(min(paces)):>7}/km")
        print(f"  {C.c('最慢配速:', C.DIM)}   {pace_fmt(max(paces)):>7}/km")
    if hrs:
        print(f"  {C.c('平均心率:', C.DIM)}   {int(avg(hrs)):>7} bpm")
        print(f"  {C.c('最高心率:', C.DIM)}   {int(max(hrs)):>7} bpm")
    if feels:
        print(f"  {C.c('平均体感:', C.DIM)}   {avg(feels):>6.1f} / 10")
    if weeks:
        print(f"  {C.c('平均周跑量:', C.DIM)} {total_dist / len(weeks):>7.1f} km")
        print(f"  {C.c('记录周数:', C.DIM)}   {len(weeks):>7}")
    print(C.c("═" * W, C.YELLOW))

def print_weekly(weeks):
    W = 80
    print()
    print(C.c("  ▸ 每周训练汇总", C.BOLD, C.WHITE))
    print(C.c("  " + "─" * (W - 4), C.DIM))
    header = f"  {'周':>10} {'跑量(km)':>10} {'时长(h)':>9} {'次数':>5} {'均配速':>9} {'均心率':>7}"
    print(C.c(header, C.DIM))
    print(C.c("  " + "─" * (W - 4), C.DIM))

    for wk in sorted(weeks):
        w = weeks[wk]
        dur_h = w["dur"] / 60
        ap = pace_fmt(avg(w["paces"])) if w["paces"] else "--:--"
        ah = str(int(avg(w["hrs"]))) if w["hrs"] else "--"
        line = f"  {wk:>10} {w['dist']:>9.1f} {dur_h:>8.1f} {w['runs']:>5} {ap:>9} {ah:>7}"
        print(line)

    total_d = sum(w["dist"] for w in weeks.values())
    total_h = sum(w["dur"] for w in weeks.values()) / 60
    total_r = sum(w["runs"] for w in weeks.values())
    print(C.c("  " + "─" * (W - 4), C.DIM))
    print(f"  {'合计':>10} {total_d:>9.1f} {total_h:>8.1f} {total_r:>5}")
    print()

def print_monthly(months):
    W = 80
    print()
    print(C.c("  ▸ 每月训练汇总", C.BOLD, C.WHITE))
    print(C.c("  " + "─" * (W - 4), C.DIM))
    header = f"  {'月份':>9} {'跑量(km)':>10} {'时长(h)':>9} {'次数':>5} {'均配速':>9} {'均心率':>7}"
    print(C.c(header, C.DIM))
    print(C.c("  " + "─" * (W - 4), C.DIM))

    for mo in sorted(months):
        m = months[mo]
        dur_h = m["dur"] / 60
        ap = pace_fmt(avg(m["paces"])) if m["paces"] else "--:--"
        ah = str(int(avg(m["hrs"]))) if m["hrs"] else "--"
        line = f"  {mo:>9} {m['dist']:>9.1f} {dur_h:>8.1f} {m['runs']:>5} {ap:>9} {ah:>7}"
        print(line)
    print()

def print_types(types):
    total_dist = sum(v["dist"] for v in types.values())
    if total_dist == 0: return

    print()
    print(C.c("  ▸ 训练类型分布", C.BOLD, C.WHITE))
    print(C.c("  ────────────────────────────", C.DIM))
    print(C.c(f"  {'类型':<14} {'跑量(km)':>10} {'占比':>10} {'次数':>6}", C.DIM))
    print(C.c("  ────────────────────────────", C.DIM))

    for t in sorted(types, key=lambda x: types[x]["dist"], reverse=True):
        v = types[t]
        pct = v["dist"] / total_dist * 100
        print(f"  {t:<14} {v['dist']:>9.1f} {pct:>9.1f}% {v['count']:>6}")

    print(C.c("  ────────────────────────────", C.DIM))
    print(f"  {'合计':<14} {total_dist:>9.1f}")
    print()

def print_trend(records, weeks, types):
    trend = trend_analysis(weeks)
    corr = pace_hr_correlation(records)

    print()
    print(C.c("  ▸ 趋势与相关性分析", C.BOLD, C.WHITE))
    print(C.c("  ───────────────────────────────────────────────", C.DIM))

    if trend:
        print(f"  {C.c('训练周数:', C.DIM)} {trend['weeks']}")
        print(f"  {C.c('首周跑量:', C.DIM)} {trend['dist_first']:.1f} km  →  {C.c(f'末周: {trend["dist_last"]:.1f} km', C.GREEN)}")
        print(f"  {C.c('跑量趋势:', C.DIM)} {trend['dist_trend']}")
        if trend["pace_first"] != "--" and trend["pace_last"] != "--":
            better = "变快" if trend["pace_improvement"].startswith("-") else ""
            print(f"  {C.c('配速变化:', C.DIM)} {trend['pace_first']}  →  {C.c(trend['pace_last'], C.CYAN)}  ({trend['pace_improvement']} {better})")
        if trend["hr_first"] and trend["hr_last"]:
            print(f"  {C.c('心率变化:', C.DIM)} {trend['hr_first']} bpm  →  {trend['hr_last']} bpm")

    if corr:
        print(f"  {C.c('配速-心率相关:', C.DIM)} r={corr['r']} ({corr['strength']}{corr['direction']}, n={corr['n']})")

    # 训练类型建议
    total_easy = sum(types[t]["dist"] for t in types if "轻松" in t or "恢复" in t or "交叉" in t)
    total_hard = sum(types[t]["dist"] for t in types if "间歇" in t or "阈值" in t)
    total_total = total_easy + total_hard
    if total_total > 0:
        easy_pct = total_easy / total_total * 100 if total_total else 0
        print(f"  {C.c('强度分布:', C.DIM)} {C.c(f'轻松 {easy_pct:.0f}%', C.GREEN)} / {C.c(f'强度 {100-easy_pct:.0f}%', C.RED)}  (建议: 80/20)")

    print()

def print_all(records):
    W = 100
    print()
    print(C.c("  ▸ 详细训练记录", C.BOLD, C.WHITE))
    print(C.c("  " + "─" * (W - 4), C.DIM))
    header = f"  {'日期':>12} {'类型':<10} {'距离':>7} {'配速':>8} {'心率':>6} {'体感':>5} {'备注'}"
    print(C.c(header, C.DIM))
    print(C.c("  " + "─" * (W - 4), C.DIM))

    for r in records:
        p = pace_fmt(r["pace"]) if r["pace"] else "--:--"
        h = str(int(r["avg_hr"])) if r["avg_hr"] else "--"
        f = str(int(r["feel"])) if r["feel"] else "--"
        line = f"  {r['date']:>12} {r['type']:<10} {r['distance']:>6.1f} {p:>8} {h:>6} {f:>5} {r['note'][:30]}"
        print(line)
    print()


def export_json(records, weeks, months, types):
    data = {
        "total": {
            "runs": len(records),
            "distance_km": sum(r["distance"] for r in records),
            "duration_hr": round(sum(r["duration"] for r in records) / 60, 1),
        },
        "weekly": {},
        "monthly": {},
        "types": {},
        "trend": trend_analysis(weeks),
        "correlation": pace_hr_correlation(records),
    }

    for wk, w in weeks.items():
        data["weekly"][wk] = {
            "distance": round(w["dist"], 1),
            "duration_h": round(w["dur"] / 60, 1),
            "runs": w["runs"],
            "avg_pace": pace_fmt(avg(w["paces"])) if w["paces"] else None,
            "avg_hr": int(avg(w["hrs"])) if w["hrs"] else None,
        }

    for mo, m in months.items():
        data["monthly"][mo] = {
            "distance": round(m["dist"], 1),
            "duration_h": round(m["dur"] / 60, 1),
            "runs": m["runs"],
            "avg_pace": pace_fmt(avg(m["paces"])) if m["paces"] else None,
            "avg_hr": int(avg(m["hrs"])) if m["hrs"] else None,
        }

    for t, v in types.items():
        data["types"][t] = {"distance": round(v["dist"], 1), "count": v["count"]}

    if data["correlation"]:
        data["correlation"]["r"] = round(data["correlation"]["r"], 3)

    print(json.dumps(data, ensure_ascii=False, indent=2))


# ── 主函数 ──

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    filepath = sys.argv[1]
    records = load_logs(filepath)

    if not records:
        print(C.c("日志为空或没有有效记录", C.YELLOW))
        return

    weeks = analyze_weekly(records)
    months = analyze_monthly(records)
    types = analyze_types(records)

    if "--json" in sys.argv:
        export_json(records, weeks, months, types)
        return

    if "--trend" in sys.argv:
        print_trend(records, weeks, types)
        return

    print_summary(records, weeks, months)
    print_weekly(weeks)
    print_monthly(months)
    print_types(types)
    print_trend(records, weeks, types)

    if "--all" in sys.argv:
        print_all(records)


if __name__ == "__main__":
    main()
