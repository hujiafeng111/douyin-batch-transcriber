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
  拉取全部视频互动数据（点赞/评论/分享/收藏/播放）
    ↓
  按点赞数筛选 → 展示概览等你确认
    ↓
  只对达标视频下载 + 本地 AI 转写 (faster-whisper)
    ↓
  生成 汇总表.xlsx + 汇总表.csv（16 列完整数据）
```

## 适用范围

**支持：** 抖音创作者公开主页（`douyin.com/user/...` 或 `v.douyin.com/...` 短链）

**不支持：** 小红书 / B站 / 视频号、搜索、评论采集、私密/付费内容

**费用：** 全链路零 API 费用。douyin-downloader 免费开源，ASR 用本地 faster-whisper 模型。

## 新电脑只需 3 步

```powershell
# 1. 装 uv（Python 包管理）
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 2. 装 mrcarlsama-social-transcriber（单条下载+ASR 引擎）
git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $env:TEMP\mc
Copy-Item "$env:TEMP\mc\skills\mrcarlsama-social-transcriber" "$env:USERPROFILE\.claude\skills\" -Recurse -Force

# 3. 装 douyin-downloader（批量拉取引擎）
git clone --depth 1 https://github.com/jiji262/douyin-downloader.git "$env:USERPROFILE\.claude\tools\douyin-downloader"
```

`uv` 仅首次需要。之后每次只需提供 Cookie + 链接 + 阈值即可直接运行。

## 执行流程

不要只把命令丢给用户。只要条件允许就直接跑。

### 0. 环境自检

首次使用时逐一检查：

```powershell
uv --version
Test-Path "$env:USERPROFILE\.claude\skills\mrcarlsama-social-transcriber\scripts\run_one.py"
Test-Path "$env:USERPROFILE\.claude\tools\douyin-downloader\run.py"
```

缺失的按上方安装步骤补齐。

### 1. 收集参数

向用户确认三项：
- **主页链接** — `https://www.douyin.com/user/xxxxx`
- **最低点赞数** — 默认建议 100，用户不指定则不过滤
- **Cookie** — 浏览器 F12 → Console → `document.cookie` → 回车，复制整串

### 2. 创建工作目录

```powershell
$WORK_DIR = "$(Get-Location)\outputs"
New-Item -ItemType Directory -Path $WORK_DIR -Force | Out-Null
```

### 3. Phase ① — 拉取视频互动数据

将用户 Cookie 转为 Netscape 格式（douyin-downloader 需要）：

```powershell
$rawCookie = "<用户提供的 cookie>"
uv run --script "$env:USERPROFILE\.claude\skills\douyin-batch-transcriber\scripts\convert_cookie.py" $rawCookie "$env:WORK_DIR\cookies_netscape.txt"
```

生成 `$WORK_DIR\batch_config.yml`：

```yaml
link:
  - <用户提供的账号主页链接>
path: <WORK_DIR>/douyin_batch/
mode: [post]
number: { post: 0 }
thread: 4
retry_times: 3
database: false
music: false
cover: false
avatar: false
json: true
video_quality: lowest
folderstyle: true
author_dir: "nickname"
```

执行拉取：

```powershell
$env:DOUYIN_COOKIE = "<用户提供的 cookie>"
cd "$env:USERPROFILE\.claude\tools\douyin-downloader"
uv run python run.py -c "$env:WORK_DIR\batch_config.yml" -t 4
```

### 4. Phase ② — 筛选并确认

```powershell
$minLikes = <阈值>
$files = Get-ChildItem -Path "$env:WORK_DIR\douyin_batch" -Recurse -Filter "*_data.json"
$videos = $files | ForEach-Object {
    $raw = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $aweme = if ($raw.aweme_detail) { $raw.aweme_detail } else { $raw }
    [PSCustomObject]@{
        aweme_id        = $aweme.aweme_id
        desc            = $aweme.desc
        share_url       = if ($aweme.share_url) { $aweme.share_url } else { "https://www.douyin.com/video/$($aweme.aweme_id)" }
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
$qualifying = $videos | Where-Object digg_count -ge $minLikes | Sort-Object digg_count -Descending
```

展示概览并**等待用户确认**：

```
=== 账号概览 ===
创作者: <nickname>（@<unique_id>）
视频总数: N  平均点赞: X,XXX  范围: X ~ XXX,XXX
点赞 ≥ <阈值>: M 条
是否继续转写？
```

用户确认后立即清理低画质视频：

```powershell
Get-ChildItem "$env:WORK_DIR\douyin_batch" -Recurse -Include "*.mp4" | Remove-Item -Force
```

### 5. Phase ③ — 逐条 ASR 转写

只对达标视频逐条运行。清理旧空目录避免误判：

```powershell
Get-ChildItem "$env:WORK_DIR" -Directory | Where-Object { $_.Name -like "*[douyin]*" } | ForEach-Object {
    if ((Get-ChildItem $_.FullName -File -Recurse -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item $_.FullName -Recurse -Force
    }
}
Remove-Item "$env:WORK_DIR\_failed" -Recurse -Force -ErrorAction SilentlyContinue
```

逐条调用 mrcarlsama（使用前面转换好的 Netscape Cookie 文件）：

```powershell
$cookieFile = "$env:WORK_DIR\cookies_netscape.txt"
$qualifying | ForEach-Object {
    $url = if ($_.share_url) { $_.share_url } else { "https://www.douyin.com/video/$($_.aweme_id)" }
    uv run --script "$env:USERPROFILE\.claude\skills\mrcarlsama-social-transcriber\scripts\run_one.py" $url --cookie-file $cookieFile
}
```

每条视频约 30-90 秒。失败不阻塞后续。

### 6. Phase ④ — 汇总 Excel + CSV

```powershell
uv run --with openpyxl python "$env:USERPROFILE\.claude\skills\douyin-batch-transcriber\scripts\gen_summary.py" "$env:WORK_DIR" "$env:WORK_DIR"
```

### 7. 最终报告

```
=== 批量转写完成 ===
创作者: <nickname>
视频总数: N  符合条件: M
成功: S  跳过: K  失败: F
汇总表: <WORK_DIR>/汇总表.xlsx / 汇总表.csv
```

## 汇总表列定义

| # | 列名 | 来源 |
|---|------|------|
| 1 | 序号 | 自增 |
| 2 | 视频ID | `aweme_id` |
| 3 | 标题/文案 | `desc`（视频简介） |
| 4 | 链接 | `share_url` |
| 5 | 作者 | `author.nickname` |
| 6 | 点赞数 | `statistics.digg_count` |
| 7 | 评论数 | `statistics.comment_count` |
| 8 | 分享数 | `statistics.share_count` |
| 9 | 收藏数 | `statistics.collect_count` |
| 10 | 播放数 | `statistics.play_count` |
| 11 | 时长(秒) | `video.duration` / 1000 |
| 12 | 发布日期 | `create_time` → YYYY-MM-DD |
| 13 | 转写状态 | 成功 / 已存在 / 失败 |
| 14 | **原始文案全文** | `原始逐字稿.txt`（ASR 一字未改） |
| 15 | 本地文件路径 | mrcarlsama 输出目录 |

## 磁盘清理

每轮拉取和转写都会产生视频文件。默认可自动清理：

| 时机 | 命令 | 效果 |
|------|------|------|
| Phase ② 确认后 | `Remove-Item "$WORK_DIR\douyin_batch\*.mp4" -Recurse` | 删 douyin-downloader 低画质视频（已内置在流程中） |
| Phase ④ 完成后 | 删 `[douyin]` 目录中 `*.mp4` + `*.wav` | 只保留 txt/srt/metadata，每条 ~10KB |

## 本地目录结构

本 Skill 目录（`~/.claude/skills/douyin-batch-transcriber/`）：

```
SKILL.md                        ← 此文件
scripts/
├── gen_summary.py              ← 汇总脚本（读逐字稿 → Excel/CSV）
└── convert_cookie.py           ← Cookie 格式转换（document.cookie → Netscape）
```

项目输出目录（`outputs/`）：

```
outputs/
├── batch_config.yml            ← douyin-downloader 配置
├── cookies_netscape.txt        ← Netscape Cookie
├── douyin_batch/               ← douyin-downloader 产出（_data.json）
├── 汇总表.xlsx
├── 汇总表.csv
├── YYYY-M-D[douyin][标题A]/    ← mrcarlsama 逐条产出
│   ├── 标题A原始逐字稿.txt    ← 这就是你要的文案
│   ├── 标题A原始逐字稿.md
│   ├── 标题A字幕.srt
│   └── _meta/manifest.json
└── YYYY-M-D[douyin][标题B]/
    └── ...
```

## 已验证的坑

| 坑 | 现象 | 修复方式 |
|----|------|----------|
| Cookie 格式 | `document.cookie` 喂给 `--cookie-file` 报错 "Netscape format" | 用 `scripts/convert_cookie.py` 转换 |
| glob 兼容性 | Windows 上含 `？` `#` 的路径 `glob.glob()` 静默返回空 | `gen_summary.py` 已用 `os.listdir()` |
| 空目录残留 | Cookie 失败时的空输出目录被误判"已处理" | Phase ③ 开头清理 |
| 短链 | `v.douyin.com/` 需跟随重定向拿 `sec_uid` | 用 `requests.get(allow_redirects=True)` |

## 常见问题

**Q: Cookie 失效？** A: 重新 F12 → Console → `document.cookie`。

**Q: 换电脑怎么迁移？** A: 拷走 `~/.claude/skills/douyin-batch-transcriber` + `~/.claude/skills/mrcarlsama-social-transcriber`，在新电脑装 uv + douyin-downloader 即可。

**Q: 为什么 mrcarlsama 和 douyin-downloader 是分开的？** A: 职责不同。mrcarlsama 管单条高清下载+ASR（有 resume、模型降级、cookie 策略），douyin-downloader 管批量签名（处理 a-bogus）。合在一起会变 5000 行难以维护的代码。本 skill 做的是编排——像一个总指挥把它们串起来。

**Q: 能用其它 ASR 方案吗？** A: 改 Phase ③ 的调用即可。只要产出 `原始逐字稿.txt`，Phase ④ 的汇总不受影响。
