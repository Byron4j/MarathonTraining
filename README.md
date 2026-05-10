# 马拉松训练系统

## 个人数据
- 年龄: 36岁 | 性别: 男 | 身高: 170cm | 体重: 67.2kg (BMI 23.3)
- 跑步能力: 78.9 (高驰手表) | VO2max: 52
- 乳酸阈配速: 4:48/km | 乳酸阈心率: 171 bpm
- 静息心率: 58 bpm | 最大心率: 192 bpm
- 半马 PB: 1:47 (2025.11 郴州)
- 目标赛事: 2026.10 底长沙半马 或 2026.11 初郴州半马
- 目标: 半马 sub-1:40 (target 1:39:59)
- 训练开始: 2026-05-10 (24周周期)
- 所在地: 广东深圳

## 项目结构

```
├── README.md                  # 项目说明
├── 训练计划.md                 # 8周训练计划文档
├── data/
│   └── 训练日志模板.csv        # 训练日志 CSV 模板
├── logs/                      # 存放每次训练的实际记录
├── scripts/
│   ├── calculate_zones.py    # 配速/心率区间计算器
│   ├── parse_watch.py        # 手表数据解析 (GPX/FIT)
│   └── analyze_log.py        # 训练日志统计分析
└── tools/
    └── index.html            # 网页版训练规划工具
```

## 快速开始

### 1. 网页工具（推荐主力使用）
```bash
open tools/index.html
```
功能：数据看板、配速区间计算、每周训练计划、8周训练周期、训练日志管理（增删改查 + CSV 导出）、SVG 趋势图表、多预设管理。
键盘快捷键：`1` 看板 | `2` 配速 | `3` 计划 | `4` 日志 | `5` 设置

### 2. 命令行计算配速区间
```bash
python3 scripts/calculate_zones.py              # 使用默认数据
python3 scripts/calculate_zones.py 4:30 175     # 自定义配速和心率
python3 scripts/calculate_zones.py --json       # JSON 输出
python3 scripts/calculate_zones.py --interactive # 交互式问答
```

### 3. 查看训练计划文档
打开 `训练计划.md`

### 4. 训练数据分析
```bash
python3 scripts/analyze_log.py logs/训练日志.csv          # 完整分析
python3 scripts/analyze_log.py logs/训练日志.csv --all    # 含详细记录
python3 scripts/analyze_log.py logs/训练日志.csv --json   # JSON 输出
python3 scripts/analyze_log.py logs/训练日志.csv --trend  # 仅趋势分析
```

### 5. 手表数据解析
```bash
python3 scripts/parse_watch.py data/file.gpx              # 单个 GPX
python3 scripts/parse_watch.py --dir data/                # 批量解析目录
python3 scripts/parse_watch.py --dir data/ --csv out.csv  # 导出 CSV
```
FIT 文件需要安装 fitparse：`pip3 install fitparse`

### 6. 训练日志格式
复制 `data/训练日志模板.csv` 到 `logs/` 目录，每次训练后填写一行。网页工具中也有内置日志管理。
