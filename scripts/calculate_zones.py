#!/usr/bin/env python3
"""配速与心率训练区间计算器

基于乳酸阈配速和心率，计算各训练区间、分段配速、等效成绩预测，
并生成周训练计划。支持彩色终端输出、JSON/CSV 导出、交互模式。

用法:
  python3 calculate_zones.py                  # 使用默认数据 (4:48, 171)
  python3 calculate_zones.py 4:30 175          # 自定义配速和心率
  python3 calculate_zones.py 4:48 171 58 192   # 完整参数
  python3 calculate_zones.py --json            # JSON 输出
  python3 calculate_zones.py --csv             # CSV 输出
  python3 calculate_zones.py --interactive     # 交互式问答
"""

import sys
import json
import csv
import os


# ── 颜色输出 ──

class Color:
    """ANSI 颜色码"""
    NONE = ""
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    WHITE = "\033[97m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"

    @staticmethod
    def supports_color():
        return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()

    @classmethod
    def c(cls, text, *colors):
        if not cls.supports_color():
            return str(text)
        return "".join(colors) + str(text) + cls.RESET


class TrainingZones:
    def __init__(self, threshold_pace, threshold_hr, rest_hr=58, max_hr=None, hm_pb="1:47:00"):
        """
        threshold_pace: 乳酸阈配速 (秒/公里)
        threshold_hr:   乳酸阈心率 (bpm)
        rest_hr:        静息心率 (bpm)
        max_hr:         最大心率 (bpm)，不传则自动推算
        hm_pb:          半马 PB 时间字符串，如 "1:47:00" 或 "1:47"
        """
        self.T = threshold_pace
        self.T_hr = threshold_hr
        self.rest_hr = rest_hr
        self.max_hr = max_hr or (threshold_hr + 21)
        self.hm_pb = hm_pb

    def pace_str(self, seconds):
        m, s = divmod(int(seconds), 60)
        return f"{m}:{s:02d}"

    def pace_range(self, lo, hi):
        return f"{self.pace_str(lo)} ~ {self.pace_str(hi)}"

    def hr_range(self, pct_lo, pct_hi):
        hrr = self.max_hr - self.rest_hr
        lo = int(self.rest_hr + hrr * pct_lo)
        hi = int(self.rest_hr + hrr * pct_hi)
        return lo, hi

    def calculate(self):
        T = self.T
        return [
            {
                "id": "R", "name": "恢复跑",
                "pace": (T * 1.32, T * 1.42),
                "hr": self.hr_range(0.55, 0.65),
                "purpose": "主动恢复，促进血液循环",
                "ratio": "10%",
                "color": Color.MAGENTA,
            },
            {
                "id": "E", "name": "轻松跑",
                "pace": (T * 1.19, T * 1.29),
                "hr": self.hr_range(0.65, 0.75),
                "purpose": "有氧基础，提升脂肪利用率",
                "ratio": "45%",
                "color": Color.GREEN,
            },
            {
                "id": "M", "name": "马拉松配速",
                "pace": (T * 1.06, T * 1.10),
                "hr": self.hr_range(0.75, 0.84),
                "purpose": "节奏耐力，比赛配速感",
                "ratio": "15%",
                "color": Color.CYAN,
            },
            {
                "id": "T", "name": "阈值跑",
                "pace": (T * 0.98, T * 1.02),
                "hr": (self.T_hr - 3, self.T_hr + 3),
                "purpose": "提升乳酸阈值，延迟疲劳",
                "ratio": "15%",
                "color": Color.YELLOW,
            },
            {
                "id": "I", "name": "VO2max 间歇",
                "pace": (T * 0.87, T * 0.93),
                "hr": (self.T_hr + 4, self.max_hr),
                "purpose": "最大摄氧量，提升速度上限",
                "ratio": "10%",
                "color": Color.RED,
            },
            {
                "id": "S", "name": "冲刺",
                "pace": (T * 0.78, T * 0.85),
                "hr": (0, 0),
                "purpose": "跑步经济性，神经系统",
                "ratio": "5%",
                "color": Color.RED,
            },
        ]

    def lap_splits(self):
        T = self.T
        return [
            {"name": "间歇 (I)", "pace": T * 0.90,
             "400m": self.pace_str(T * 0.90 * 0.4),
             "800m": self.pace_str(T * 0.90 * 0.8),
             "1000m": self.pace_str(T * 0.90)},
            {"name": "阈值 (T)", "pace": T * 1.00,
             "400m": self.pace_str(T * 0.4),
             "800m": self.pace_str(T * 0.8),
             "1000m": self.pace_str(T)},
            {"name": "冲刺 (R)", "pace": T * 0.82,
             "400m": self.pace_str(T * 0.82 * 0.4),
             "800m": self.pace_str(T * 0.82 * 0.8),
             "1000m": self.pace_str(T * 0.82)},
        ]

    def _time_to_sec(self, time_str):
        """将 'h:mm:ss' 或 'mm:ss' 转为秒数"""
        parts = time_str.strip().split(":")
        if len(parts) == 2:
            return int(parts[0]) * 60 + int(parts[1])
        elif len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
        return 0

    def _sec_to_hm(self, secs):
        h, r = divmod(secs, 3600)
        m = r // 60
        return f"{h}:{m:02d}"

    def _sec_to_ms(self, secs):
        m, s = divmod(secs, 60)
        return f"{m}:{s:02d}"

    def vdot_predictions(self):
        """基于半马 PB 推算 VDOT 和等效成绩"""
        # Jack Daniels VDOT 表: (vdot, 5k, 10k, hm_sec, fm_sec)
        table = [
            (30, 1860, 3840, 8520, 17700),
            (35, 1620, 3360, 7440, 15420),
            (38, 1512, 3135, 6960, 14520),
            (40, 1448, 3000, 6746, 14100),
            (41, 1410, 2925, 6576, 13740),
            (42, 1373, 2850, 6416, 13380),
            (43, 1338, 2775, 6258, 13020),
            (44, 1305, 2700, 6108, 12660),
            (45, 1273, 2625, 5958, 12300),
            (46, 1245, 2565, 5820, 12000),
            (47, 1218, 2510, 5682, 11700),
            (48, 1190, 2455, 5550, 11400),
            (49, 1162, 2400, 5424, 11130),
            (50, 1135, 2345, 5298, 10860),
            (55, 1020, 2110, 4740, 9720),
            (60, 930, 1920, 4260, 8760),
            (65, 855, 1760, 3870, 7980),
            (70, 790, 1630, 3540, 7320),
        ]

        # 从 HM PB 反推 VDOT
        hm_sec = self._time_to_sec(self.hm_pb)
        current_vdot = 30
        for v, *_ in table:
            idx = table.index((v, *_))
            tbl_hm_sec = table[idx][3]
            if hm_sec <= tbl_hm_sec:
                current_vdot = v
                # 不 break，继续找更高 VDOT

        # 阈值配速推算半马潜力
        # 经验系数: 半马配速 ≈ 阈值配速 × 1.03 (阈值跑 HR ~168, 半马 HR ~160)
        threshold_hm_pace = self.T * 1.03
        threshold_hm_sec = int(threshold_hm_pace * 21.0975)
        potential_vdot = 30
        for v, *_ in table:
            idx = table.index((v, *_))
            if threshold_hm_sec <= table[idx][3]:
                potential_vdot = v

        # 12 周务实目标: current_vdot + 2 (夏季保守)
        target_vdot = min(70, current_vdot + 2)

        predictions = []
        for dist_idx, dist_name in enumerate(["5K", "10K", "半马", "全马"]):
            col_idx = dist_idx + 1  # table 中从 index 1 开始是成绩列
            from_pb = table[[v for v, *_ in table].index(current_vdot)][col_idx]
            from_thr = table[[v for v, *_ in table].index(potential_vdot)][col_idx]
            from_target = table[[v for v, *_ in table].index(target_vdot)][col_idx]

            if dist_name in ("全马", "半马"):
                predictions.append({
                    "name": dist_name,
                    "from_pb": self._sec_to_hm(from_pb),
                    "from_thr": self._sec_to_hm(from_thr),
                    "target": self._sec_to_hm(from_target),
                })
            else:
                predictions.append({
                    "name": dist_name,
                    "from_pb": self._sec_to_ms(from_pb),
                    "from_thr": self._sec_to_ms(from_thr),
                    "target": self._sec_to_ms(from_target),
                })

        return predictions

    def generate_weekly_plan(self):
        zones = self.calculate()
        E = zones[1]["pace"]
        T = zones[3]["pace"]
        I = zones[4]["pace"]
        R = zones[0]["pace"]

        return [
            {"day": "周一", "type": "休息/交叉训练", "detail": "游泳45min 或 核心力量30min", "dist": "0"},
            {"day": "周二", "type": "阈值间歇",
             "detail": f"5×1200m @{self.pace_str(T[0])}~{self.pace_str(T[1])} (间歇90s)", "dist": "10"},
            {"day": "周三", "type": "轻松跑",
             "detail": f"10~12km @{self.pace_str(E[0])}~{self.pace_str(E[1])}", "dist": "11"},
            {"day": "周四", "type": "节奏跑",
             "detail": f"3km轻松 + 4km @{self.pace_str(T[0])}~{self.pace_str(T[1])} + 1km轻松", "dist": "8"},
            {"day": "周五", "type": "恢复跑",
             "detail": f"6~8km @{self.pace_str(R[0])}~{self.pace_str(R[1])}", "dist": "7"},
            {"day": "周六", "type": "VO2max间歇",
             "detail": f"6×800m @{self.pace_str(I[0])}~{self.pace_str(I[1])} (间歇2min)", "dist": "9"},
            {"day": "周日", "type": "长距离",
             "detail": f"16~22km @{self.pace_str(E[0])}~{self.pace_str(E[1])}", "dist": "18"},
        ]

    def print_report(self):
        """打印完整报告"""
        c = Color
        width = 76

        # 标题
        print()
        print(c.c("▄" * width, c.YELLOW))
        print(c.c("  训练配速与心率区间计算器", c.BOLD, c.WHITE))
        print(c.c(f"  阈值配速: {self.pace_str(self.T)}/km  |  阈值心率: {self.T_hr}bpm  |  静息心率: {self.rest_hr}bpm  |  最大心率: {self.max_hr}bpm", c.DIM))
        print(c.c("▄" * width, c.YELLOW))

        # 配速区间表
        print()
        print(c.c("  ● 训练配速与心率区间", c.BOLD, c.WHITE))
        print(c.c("  ────────────────────────────────────────────────────────────────────", c.DIM))
        header = f"  {'区间':<16} {'配速/km':<18} {'心率 bpm':<16} {'用途':<20} 占比"
        print(c.c(header, c.DIM))
        print(c.c("  ────────────────────────────────────────────────────────────────────", c.DIM))

        for z in self.calculate():
            pace = self.pace_range(z["pace"][0], z["pace"][1])
            if z["hr"][0] == 0:
                hr = "无参考"
            else:
                hr = f"{z['hr'][0]} ~ {z['hr'][1]}"
            label = f"{z['id']} {z['name']}"
            line = f"  {label:<16} {pace:<18} {hr:<16} {z['purpose']:<20} {z['ratio']}"
            print(c.c(line, z["color"]))

        print(c.c("  ────────────────────────────────────────────────────────────────────", c.DIM))

        # 分段配速
        print()
        print(c.c("  ● 分段配速参考 (间歇训练)", c.BOLD, c.WHITE))
        print(c.c("  ──────────────────────────────────────────────────", c.DIM))
        print(c.c(f"  {'区间':<14} {'400m':>10} {'800m':>10} {'1000m':>10}", c.DIM))
        print(c.c("  ──────────────────────────────────────────────────", c.DIM))

        for s in self.lap_splits():
            line = f"  {s['name']:<14} {s['400m']:>10} {s['800m']:>10} {s['1000m']:>10}"
            if "间歇" in s["name"]:
                print(c.c(line, c.RED))
            elif "阈值" in s["name"]:
                print(c.c(line, c.YELLOW))
            else:
                print(c.c(line, c.RED))

        print(c.c("  ──────────────────────────────────────────────────", c.DIM))

        # 成绩预测
        print()
        print(c.c("  ● VDOT 等效成绩预测", c.BOLD, c.WHITE))
        print(c.c(f"    基于半马 PB: {self.hm_pb}", c.DIM))
        print(c.c("  ────────────────────────────────────────────────", c.DIM))
        print(c.c(f"  {'距离':<8} {'基于 PB':>12} {'阈值潜力':>12} {'12周目标':>12}", c.DIM))
        print(c.c("  ────────────────────────────────────────────────", c.DIM))

        for p in self.vdot_predictions():
            line = f"  {p['name']:<8} {p['from_pb']:>12} {p['from_thr']:>12} {p['target']:>12}"
            print(c.c(line, c.CYAN))

        print(c.c("  ────────────────────────────────────────────────", c.DIM))
        print(c.c("  夏季高温高湿环境中训练，进步幅度比秋冬季低 30%~50%。", c.DIM))
        print(c.c("  目标按保守 +2 VDOT 点（约 4% 提升）估算。", c.DIM))

        # 周训练计划
        print()
        print(c.c("  ● 每周训练计划", c.BOLD, c.WHITE))
        print(c.c("  ────────────────────────────────────────────────────────────────────", c.DIM))

        total = 0
        for p in self.generate_weekly_plan():
            total += int(p["dist"])
            line = f"  {p['day']:<6} {p['type']:<12} {p['detail']}"
            print(line)

        print(c.c("  ────────────────────────────────────────────────────────────────────", c.DIM))
        print(c.c(f"  周跑量合计: ~{total}km", c.BOLD, c.GREEN))

        # 深圳提示
        print()
        print(c.c("  ⚠ 深圳夏季训练提示", c.BOLD, c.YELLOW))
        for tip in [
            "  训练时间: 清晨 5:30-7:00 或 晚上 19:00-21:00",
            "  60分钟以上跑步必须携带水，每20分钟补水150-200ml",
            "  高温下心率偏高 5-10bpm 正常，以体感为准",
            "  头晕/恶心/发冷 → 立即停止，找阴凉处",
            "  台风暴雨天 → 跑步机或力量训练替代",
        ]:
            print(c.c(tip, c.DIM))

        print()
        print(c.c("▄" * width, c.YELLOW))
        print()

    def to_json(self):
        """导出完整 JSON"""
        data = {
            "input": {
                "threshold_pace": self.pace_str(self.T),
                "threshold_pace_sec": self.T,
                "threshold_hr": self.T_hr,
                "rest_hr": self.rest_hr,
                "max_hr": self.max_hr,
                "hm_pb": self.hm_pb,
            },
            "zones": [],
            "splits": self.lap_splits(),
            "predictions": self.vdot_predictions(),
            "weekly_plan": self.generate_weekly_plan(),
        }

        for z in self.calculate():
            data["zones"].append({
                "id": z["id"],
                "name": z["name"],
                "pace_lo": self.pace_str(z["pace"][0]),
                "pace_hi": self.pace_str(z["pace"][1]),
                "pace_lo_sec": int(z["pace"][0]),
                "pace_hi_sec": int(z["pace"][1]),
                "hr_lo": z["hr"][0],
                "hr_hi": z["hr"][1],
                "purpose": z["purpose"],
                "ratio": z["ratio"],
            })

        return json.dumps(data, ensure_ascii=False, indent=2)

    def to_csv(self):
        """导出配速区间 CSV"""
        output = []
        output.append("区间,配速下限,配速上限,心率下限,心率上限,用途,占比")

        for z in self.calculate():
            output.append(
                f"{z['id']} {z['name']},"
                f"{self.pace_str(z['pace'][0])},"
                f"{self.pace_str(z['pace'][1])},"
                f"{z['hr'][0]},{z['hr'][1]},"
                f"{z['purpose']},{z['ratio']}"
            )

        output.append("")
        output.append("分段配速：区间,400m,800m,1000m")
        for s in self.lap_splits():
            output.append(f"{s['name']},{s['400m']},{s['800m']},{s['1000m']}")

        return "\n".join(output)


def parse_pace(pace_str):
    """解析配速字符串，如 '4:48' → 288秒"""
    parts = pace_str.strip().split(":")
    if len(parts) == 2:
        return int(parts[0]) * 60 + int(parts[1])
    raise ValueError(f"无法解析配速: {pace_str}，格式应为 mm:ss")


def interactive_mode():
    """交互式问答模式"""
    print()
    print(Color.c("  ▸ 交互模式 - 输入你的生理数据", Color.BOLD, Color.WHITE))
    print()

    pace = input(Color.c("  乳酸阈配速 (如 4:48): ", Color.CYAN)).strip()
    if not pace:
        pace = "4:48"

    hr = input(Color.c("  乳酸阈心率 (如 171): ", Color.CYAN)).strip()
    if not hr:
        hr = "171"

    rest = input(Color.c("  静息心率 (如 58，回车跳过): ", Color.DIM)).strip()
    if not rest:
        rest = "58"

    mx = input(Color.c("  最大心率 (如 192，回车自动推算): ", Color.DIM)).strip()

    try:
        tz = TrainingZones(
            parse_pace(pace),
            int(hr),
            int(rest),
            int(mx) if mx else None,
            hm_pb="1:47:00",
        )
        tz.print_report()
    except ValueError as e:
        print(Color.c(f"  错误: {e}", Color.RED))
        sys.exit(1)


def main():
    # 参数处理
    if len(sys.argv) > 1:
        arg = sys.argv[1]

        if arg in ("-h", "--help"):
            print(__doc__)
            return

        if arg == "--interactive":
            interactive_mode()
            return

        if arg == "--json":
            tz = TrainingZones(parse_pace("4:48"), 171, hm_pb="1:47:00")
            print(tz.to_json())
            return

        if arg == "--csv":
            tz = TrainingZones(parse_pace("4:48"), 171, hm_pb="1:47:00")
            print(tz.to_csv())
            return

        if arg == "--target":
            # 反推: 给定目标半马时间，算出所需阈值配速
            if len(sys.argv) < 3:
                print("用法: python3 calculate_zones.py --target 1:39:00")
                return
            target_hm = sys.argv[2]
            # 临时实例用于解析时间
            tmp = TrainingZones(288, 171)
            t = tmp._time_to_sec(target_hm)
            # 阈值配速 ≈ 半马配速 / 1.03
            target_hm_pace = t / 21.0975
            target_thr_pace = target_hm_pace / 1.03
            tz = TrainingZones(int(target_thr_pace), 171, hm_pb="1:47:00")
            print(Color.c(f"\n  ▸ 目标半马: {target_hm}", Color.BOLD, Color.WHITE))
            print(Color.c(f"  ▸ 所需阈值配速: {tz.pace_str(int(target_thr_pace))}/km", Color.BOLD, Color.GREEN))
            print(Color.c(f"  ▸ 所需半马配速: {tz.pace_str(int(target_hm_pace))}/km", Color.BOLD, Color.CYAN))
            print()
            tz.print_report()
            return

        # 位置参数: 配速 [心率] [静息心率] [最大心率]
        try:
            pace = parse_pace(arg)
            hr = int(sys.argv[2]) if len(sys.argv) > 2 else 171
            rest = int(sys.argv[3]) if len(sys.argv) > 3 else 58
            mx = int(sys.argv[4]) if len(sys.argv) > 4 else None
        except (ValueError, IndexError) as e:
            print(f"参数错误: {e}")
            print("用法: python3 calculate_zones.py [配速] [心率] [静息心率] [最大心率]")
            sys.exit(1)

        tz = TrainingZones(pace, hr, rest, mx, hm_pb="1:47:00")
        tz.print_report()
    else:
        # 默认：用户当前数据
        tz = TrainingZones(parse_pace("4:48"), 171, 58, 192, hm_pb="1:47:00")
        tz.print_report()


if __name__ == "__main__":
    main()
