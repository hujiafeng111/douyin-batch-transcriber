---
name: douyin-batch-transcriber
description: 抖音批量文案提取。输入创作者主页链接和最低点赞阈值，自动拉取全部视频互动数据，筛选热门视频后逐条下载并本地 ASR 转写为逐字稿，最终汇总为 Excel/CSV 表格。全链路零 API 费用。以任何形式提及提取抖音视频文案、下载抖音文案、批量转写抖音视频时使用。
---

# 抖音批量文案提取

一站式 Skill：从抖音创作者主页链接到 Excel 汇总表，全自动。

## 做了什么

```
抖音主页链接 + Cookie + 点赞阈值
    ↓
Phase ① 拉取全部视频互动数据
    ↓
Phase ② 按点赞筛选 → 展示概览等你确认
    ↓
Phase ③ 逐条下载 + ASR 转写 → 每 10 条自动存 Excel（中断不丢数据）
    ↓
Phase ④ 最终汇总 → 等你确认 Excel 没问题
    ↓
Phase ⑤ 确认无误 → 手动清理视频，仅保留文案
```

**关键原则：绝对不在 Excel 确认完成前删除任何文件。** 视频删除只在 Phase ⑤ 手动执行。

## 适用范围

**支持：** 抖音创作者公开主页（`douyin.com/user/...` 或 `v.douyin.com/...` 短链）

**不支持：** 小红书 / B站 / 视频号、搜索、评论采集、私密/付费内容

**费用：** 全链路零 API 费用。

## 新电脑只需 3 步

```powershell
# 1. 装 uv
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 2. 装 mrcarlsama-social-transcriber（单条下载+ASR 引擎）
git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $env:TEMP\mc
Copy-Item "$env:TEMP\mc\skills\mrcarlsama-social-transcriber" "$env:USERPROFILE\.claude\skills\" -Recurse -Force

# 3. 装 douyin-downloader（批量拉取引擎）
git clone --depth 1 https://github.com/jiji262/douyin-downloader.git "$env:USERPROFILE\.claude\tools\douyin-downloader"
```

`uv` 仅首次需要。

## 执行流程

### 0. 环境自检

```powershell
uv --version
Test-Path "$env:USERPROFILE\.claude\skills\mrcarlsama-social-transcriber\scripts\run_one.py"
Test-Path "$env:USERPROFILE\.claude\tools\douyin-downloader\run.py"
```

### 1. 收集参数

向用户确认三项：
- **主页链接** — `https://www.douyin.com/user/xxxxx`
- **最低点赞数** — 默认建议 100
- **Cookie** — 浏览器 F12 → Console → `document.cookie` → 回车，复制整串

### 2. 创建工作目录

```powershell
$WORK_DIR = "$(Get-Location)\outputs"
New-Item -ItemType Directory -Path $WORK_DIR -Force | Out-Null
```

### 3. Phase ① — 拉取视频互动数据

Cookie 转 Netscape 格式：

```powershell
uv run --script "$env:USERPROFILE\.claude\skills\douyin-batch-transcriber\scripts\convert_cookie.py" "<raw_cookie>" "$env:WORK_DIR\cookies_netscape.txt"
```

生成 `$WORK_DIR\batch_config.yml` 并运行 douyin-downloader：

```yaml
link:
  - <账号主页链接>
path: <WORK_DIR>/douyin_batch/
mode: [post]
number: { post: 0 }
thread: 4
json: true
video_quality: lowest
music: false
cover: false
avatar: false
database: false
folderstyle: true
author_dir: "nickname"
```

```powershell
$env:DOUYIN_COOKIE = "<cookie>"
cd "$env:USERPROFILE\.claude\tools\douyin-downloader"
uv run python run.py -c "$env:WORK_DIR\batch_config.yml" -t 4
```

### 4. Phase ② — 筛选并确认

```powershell
$files = Get-ChildItem -Path "$env:WORK_DIR\douyin_batch" -Recurse -Filter "*_data.json"
$videos = $files | ForEach-Object {
    $raw = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $aweme = if ($raw.aweme_detail) { $raw.aweme_detail } else { $raw }
    [PSCustomObject]@{
        aweme_id        = $aweme.aweme_id
        desc            = $aweme.desc
        create_time     = $aweme.create_time
        digg_count      = [int]$aweme.statistics.digg_count
        comment_count   = [int]$aweme.statistics.comment_count
        share_count     = [int]$aweme.statistics.share_count
        collect_count   = [int]$aweme.statistics.collect_count
        play_count      = [int]$aweme.statistics.play_count
        duration_ms     = [int]$aweme.video.duration
        author_nickname = $aweme.author.nickname
        author_unique_id = $aweme.author.unique_id
    }
}
$qualifying = $videos | Where-Object digg_count -ge <阈值> | Sort-Object digg_count -Descending
```

展示概览，**必须等用户确认**：

```
=== 账号概览 ===
创作者: <nickname>
视频总数: N  平均点赞: X  范围: X ~ XXX
点赞 ≥ <阈值>: M 条
是否继续转写？
```

> **⚠️ 此时不删除 douyin-downloader 的低画质视频。** 保留一切文件直到 Phase ⑤。

### 5. Phase ③ — 逐条转写 + 增量保存 Excel

使用 `batch_run.py`（每次跑 ~15 条，每 10 条自动更新 Excel）：

```powershell
$env:Path = "C:\Users\$env:USERNAME\.local\bin;$env:Path"
uv run --with openpyxl python "$env:USERPROFILE\.claude\skills\douyin-batch-transcriber\scripts\batch_run.py" "$env:WORK_DIR" "$env:WORK_DIR\batch_<name>\qualifying_videos.json" "$env:WORK_DIR\cookies_netscape.txt" "batch_<name>"
```

**特点：**
- 自动跳过已有逐字稿的视频（resume）
- 每 10 条成功自动更新 Excel
- 进程中断后重新运行即可续传
- 失败不阻塞后续
- **不会删除任何文件**

重复执行直到全部完成。

### 6. Phase ④ — 最终汇总与验证

```powershell
$env:Path = "C:\Users\$env:USERNAME\.local\bin;$env:Path"
uv run --with openpyxl python "$env:USERPROFILE\.claude\skills\douyin-batch-transcriber\scripts\gen_summary.py" "$env:WORK_DIR" "$env:WORK_DIR\batch_<name>"
```

验证：
- `汇总表.xlsx` 存在且非空
- 抽查 3-5 条"原始文案全文"列内容完整

```
=== 批量转写完成 ===
创作者: <nickname>
视频总数: N  符合条件: M
成功: S  跳过: K  失败: F
汇总表: <WORK_DIR>/batch_<name>/汇总表.xlsx / 汇总表.csv
```

### 7. Phase ⑤ — 清理视频（用户确认后）

**仅在用户确认 Excel 没问题后再执行清理。**

```powershell
# 1. 删 douyin-downloader 低画质视频（仅保留 _data.json）
Get-ChildItem "$env:WORK_DIR\douyin_batch" -Recurse -Include "*.mp4" | Remove-Item -Force

# 2. 删 mrcarlsama 输出的视频和音频（仅保留逐字稿/字幕/元数据）
Get-ChildItem "$env:WORK_DIR" -Directory | Where-Object { $_.Name -like "*[douyin]*" -and $_.Name -ne "douyin_batch" } | ForEach-Object {
    Get-ChildItem $_.FullName -Include "*.mp4", "*.wav" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
}

# 3. 清理空目录
Get-ChildItem "$env:WORK_DIR" -Directory | Where-Object { $_.Name -like "*[douyin]*" -and $_.Name -ne "douyin_batch" } | ForEach-Object {
    if ((Get-ChildItem $_.FullName -File -Recurse -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $_.FullName -Recurse -Force
    }
}
Remove-Item "$env:WORK_DIR\_failed" -Recurse -Force -ErrorAction SilentlyContinue
```

| 清理项 | 删除内容 | 保留内容 |
|--------|---------|---------|
| douyin_batch | *.mp4 | _data.json |
| [douyin] 逐条目录 | *.mp4, *.wav | 原始逐字稿.txt, 字幕.srt, _meta/ |

清理后每条视频仅占 ~10-50KB。

## 汇总表列定义

| # | 列名 | 来源 |
|---|------|------|
| 1 | 序号 | 自增 |
| 2 | 视频ID | `aweme_id` |
| 3 | 标题/文案 | `desc` |
| 4 | 链接 | `share_url` |
| 5 | 作者 | `author.nickname` |
| 6 | 点赞数 | `statistics.digg_count` |
| 7 | 评论数 | `comment_count` |
| 8 | 分享数 | `share_count` |
| 9 | 收藏数 | `collect_count` |
| 10 | 播放数 | `play_count` |
| 11 | 时长(秒) | `video.duration` / 1000 |
| 12 | 发布日期 | `create_time` → YYYY-MM-DD |
| 13 | 转写状态 | 成功 / 已存在 / 失败 |
| 14 | **原始文案全文** | `原始逐字稿.txt` |
| 15 | 本地文件路径 | mrcarlsama 输出目录 |

## 本地目录结构

本 Skill 目录：

```
~/.claude/skills/douyin-batch-transcriber/
├── SKILL.md
└── scripts/
    ├── batch_run.py          ← 批量转写 + 增量保存 Excel
    ├── gen_summary.py        ← 逐字稿 → Excel/CSV
    └── convert_cookie.py     ← Cookie 格式转换
```

项目输出目录（Phase ⑤ 清理前）：

```
outputs/
├── cookies_netscape.txt
├── batch_config.yml
├── douyin_batch/             ← douyin-downloader 产物
├── batch_<name>/
│   ├── qualifying_videos.json
│   ├── 汇总表.xlsx           ← 增量更新，不会丢
│   └── 汇总表.csv
├── YYYY-M-D[douyin][标题A]/
│   ├── 标题A原始逐字稿.txt
│   ├── 标题A原始逐字稿.md
│   ├── 标题A字幕.srt
│   ├── 标题A原视频.mp4
│   ├── 标题A原音频.wav
│   └── _meta/manifest.json
└── ...
```

## 已验证的坑

| 坑 | 现象 | 修复方式 |
|----|------|----------|
| 过早清理 | Excel 未确认就删视频，数据全丢 | Phase ⑤ 确认后才清理 |
| Cookie 格式 | `document.cookie` → `--cookie-file` 报 Netscape 错误 | `convert_cookie.py` |
| glob 兼容性 | Windows 含 `？` `#` 路径 glob 返回空 | `os.listdir()` |
| share_url 格式 | `iesdouyin.com/share/video/...` 不被 run_one 支持 | 改用 `douyin.com/video/{id}` |
| 进程中断 | 转 298 条时中断，已转数据全丢 | `batch_run.py` 每 10 条存 Excel |

## 常见问题

**Q: Cookie 失效？** A: F12 → Console → `document.cookie`。

**Q: 换电脑？** A: 拷贝 `~/.claude/skills/douyin-batch-transcriber` + `~/.claude/skills/mrcarlsama-social-transcriber`，在新电脑装 uv + douyin-downloader。

**Q: 为什么 cleanup 放在最后？** A: 之前踩过坑——清理脚本误删已完成数据。现在必须等用户确认 Excel 无误后再清理。
