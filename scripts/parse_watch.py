#!/usr/bin/env python3
"""手表数据解析脚本

解析 GPX 和 FIT 文件，提取训练摘要。
支持格式: .gpx (XML, 大多数手表通用)

FIT 文件需要 fitparse 库:
  pip3 install fitparse

用法:
  python3 parse_watch.py file.gpx
  python3 parse_watch.py file.fit
  python3 parse_watch.py --dir data/   # 批量解析目录
"""

import sys
import os
import xml.etree.ElementTree as ET
import math
from datetime import datetime
from collections import defaultdict


def haversine(lat1, lon1, lat2, lon2):
    """计算两点间距离 (米)"""
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))


def parse_gpx(filepath):
    """解析 GPX 文件"""
    ns = {"gpx": "http://www.topografix.com/GPX/1/1"}
    tree = ET.parse(filepath)
    root = tree.getroot()

    # 命名空间处理
    ns_uri = "http://www.topografix.com/GPX/1/1"
    ns_tag = f"{{{ns_uri}}}"

    # 查找 trackpoints
    trkpts = root.findall(f".//{ns_tag}trkpt")
    if not trkpts:
        # 尝试不带命名空间
        trkpts = root.findall(".//trkpt")
    if not trkpts:
        # 尝试 GPX 1.0
        trkpts = root.findall(".//{http://www.topografix.com/GPX/1/0}trkpt")

    if not trkpts:
        print("  ⚠ 未找到轨迹点")
        return None

    total_distance = 0.0
    total_time = 0.0
    hr_values = []
    elevations = []
    prev_lat = prev_lon = None
    prev_time = None

    for pt in trkpts:
        lat = float(pt.get("lat"))
        lon = float(pt.get("lon"))

        # 海拔
        ele_el = pt.find(f"{ns_tag}ele")
        if ele_el is not None and ele_el.text:
            elevations.append(float(ele_el.text))

        # 时间
        time_el = pt.find(f"{ns_tag}time")
        cur_time = None
        if time_el is not None and time_el.text:
            cur_time = datetime.fromisoformat(time_el.text.replace("Z", "+00:00"))

        # 心率 (常见扩展)
        for ext in pt.findall(f"{ns_tag}extensions"):
            hr_el = ext.find(".//{http://www.garmin.com/xmlschemas/TrackPointExtension/v1}hr")
            if hr_el is None:
                hr_el = ext.find(".//hr")
            if hr_el is not None and hr_el.text:
                hr_values.append(int(hr_el.text))

        # 距离累计
        if prev_lat is not None:
            total_distance += haversine(prev_lat, prev_lon, lat, lon)

        # 时间累计
        if prev_time is not None and cur_time is not None:
            delta = (cur_time - prev_time).total_seconds()
            if delta > 0 and delta < 300:  # 忽略大于5分钟的暂停
                total_time += delta

        prev_lat, prev_lon = lat, lon
        prev_time = cur_time

    total_km = total_distance / 1000

    if total_time == 0:
        avg_pace = 0
    else:
        avg_pace = total_time / 60 / total_km  # 分钟/公里

    avg_hr = int(sum(hr_values) / len(hr_values)) if hr_values else 0
    max_hr = max(hr_values) if hr_values else 0
    elev_gain = 0
    if len(elevations) > 1:
        for i in range(1, len(elevations)):
            diff = elevations[i] - elevations[i-1]
            if diff > 0:
                elev_gain += diff

    return {
        "file": os.path.basename(filepath),
        "distance_km": round(total_km, 2),
        "duration_min": round(total_time / 60, 1),
        "avg_pace": avg_pace,
        "avg_hr": avg_hr,
        "max_hr": max_hr,
        "elevation_gain": round(elev_gain, 0),
        "trackpoints": len(trkpts),
    }


def parse_fit(filepath):
    """解析 FIT 文件 (需要 fitparse 库)"""
    try:
        from fitparse import FitFile
    except ImportError:
        print("  ❌ 需要 fitparse 库，请运行: pip3 install fitparse")
        return None

    fitfile = FitFile(filepath)

    records = []
    hr_values = []
    lat_lon = []
    total_distance = 0.0

    for record in fitfile.get_messages("record"):
        data = {}
        for field in record:
            data[field.name] = field.value
        records.append(data)

        if "heart_rate" in data:
            hr_values.append(data["heart_rate"])

        if "position_lat" in data and "position_long" in data:
            lat = data["position_lat"] * (180.0 / 2**31)
            lon = data["position_long"] * (180.0 / 2**31)
            lat_lon.append((lat, lon))

        if "distance" in data:
            total_distance = max(total_distance, data["distance"])

    # 时间
    if records:
        first_ts = records[0].get("timestamp")
        last_ts = records[-1].get("timestamp")
        if first_ts and last_ts:
            total_time = (last_ts - first_ts).total_seconds()
        else:
            total_time = 0
    else:
        total_time = 0

    total_km = total_distance / 1000 if total_distance > 0 else 0

    if total_time == 0 or total_km == 0:
        avg_pace = 0
    else:
        avg_pace = total_time / 60 / total_km

    avg_hr = int(sum(hr_values) / len(hr_values)) if hr_values else 0
    max_hr = max(hr_values) if hr_values else 0

    # 海拔
    elevations = [r.get("enhanced_altitude") or r.get("altitude", 0) for r in records if r.get("altitude")]
    elev_gain = 0
    if len(elevations) > 1:
        for i in range(1, len(elevations)):
            diff = (elevations[i] or 0) - (elevations[i-1] or 0)
            if diff > 0:
                elev_gain += diff

    return {
        "file": os.path.basename(filepath),
        "distance_km": round(total_km, 2),
        "duration_min": round(total_time / 60, 1),
        "avg_pace": avg_pace,
        "avg_hr": avg_hr,
        "max_hr": max_hr,
        "elevation_gain": round(elev_gain, 0),
        "trackpoints": len(records),
    }


def pace_to_str(pace_min):
    """配速分钟数 → mm:ss"""
    m = int(pace_min)
    s = int((pace_min - m) * 60)
    return f"{m}:{s:02d}"


def export_csv(summaries, output_path):
    """导出为 CSV"""
    import csv
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "file", "distance_km", "duration_min", "avg_pace",
            "avg_hr", "max_hr", "elevation_gain", "trackpoints"
        ])
        writer.writeheader()
        for s in summaries:
            writer.writerow(s)
    print(f"已导出: {output_path}")


def print_summary(data):
    """打印单条摘要"""
    print(f"  📁 {data['file']}")
    print(f"     距离:     {data['distance_km']} km")
    print(f"     时长:     {data['duration_min']} 分钟")
    print(f"     平均配速: {pace_to_str(data['avg_pace'])}/km")
    if data["avg_hr"]:
        print(f"     平均心率: {data['avg_hr']} bpm")
        print(f"     最大心率: {data['max_hr']} bpm")
    if data["elevation_gain"]:
        print(f"     累计爬升: {data['elevation_gain']} m")
    print(f"     数据点数: {data['trackpoints']}")


def main():
    if len(sys.argv) < 2:
        print("用法: python3 parse_watch.py <file.gpx|file.fit>")
        print("      python3 parse_watch.py --dir <目录>")
        print("      python3 parse_watch.py --dir <目录> --csv output.csv")
        sys.exit(1)

    if sys.argv[1] == "--dir":
        if len(sys.argv) < 3:
            print("请指定目录: python3 parse_watch.py --dir data/")
            sys.exit(1)
        directory = sys.argv[2]
        csv_output = None
        if "--csv" in sys.argv:
            idx = sys.argv.index("--csv")
            if idx + 1 < len(sys.argv):
                csv_output = sys.argv[idx + 1]

        files = sorted(os.listdir(directory))
        summaries = []

        for fname in files:
            fpath = os.path.join(directory, fname)
            if fname.lower().endswith(".gpx"):
                print(f"\n解析 GPX: {fname}")
                data = parse_gpx(fpath)
                if data:
                    print_summary(data)
                    summaries.append(data)
            elif fname.lower().endswith(".fit"):
                print(f"\n解析 FIT: {fname}")
                data = parse_fit(fpath)
                if data:
                    print_summary(data)
                    summaries.append(data)

        if csv_output and summaries:
            export_csv(summaries, csv_output)

        print(f"\n共解析 {len(summaries)} 个文件")

    else:
        fpath = sys.argv[1]
        if not os.path.exists(fpath):
            print(f"文件不存在: {fpath}")
            sys.exit(1)

        if fpath.lower().endswith(".gpx"):
            data = parse_gpx(fpath)
        elif fpath.lower().endswith(".fit"):
            data = parse_fit(fpath)
        else:
            print(f"不支持的文件格式: {fpath} (支持 .gpx 和 .fit)")
            sys.exit(1)

        if data:
            print_summary(data)


if __name__ == "__main__":
    main()
