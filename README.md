<p align="center">
  <h1 align="center">🎬 抖音批量文案提取</h1>
  <p align="center">一条链接 → Excel 汇总表。零 API 费用，全本地运行。</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Cost-Free-brightgreen" alt="Cost">
  <img src="https://img.shields.io/badge/ASR-faster--whisper%20(local)-orange" alt="ASR">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

---

## 这是什么

输入一个抖音创作者主页链接 + 最低点赞数，自动完成：

```
主页链接
  → 拉取全部视频互动数据（点赞/评论/分享/收藏/播放）
  → 按点赞筛选热门视频
  → 逐条下载 + 本地 AI 转写为逐字稿
  → 生成 Excel + CSV 汇总表
```

**适合**：文案分析、竞品研究、内容策略、短视频运营。

**不适合**：批量搬运视频、破解私密内容、爬取评论数据。

---

## 快速开始

### 前置条件

| 工具 | 用途 | 安装 |
|------|------|------|
| **uv** | Python 包管理 | `powershell -c "irm https://astral.sh/uv/install.ps1 \| iex"` |
| **Mrcarlsama Social Transcriber** | 单条视频下载 + ASR | 见下方 |
| **jiji262/douyin-downloader** | 批量拉取视频列表 | 见下方 |
| **抖音 Cookie** | 鉴权 | 浏览器 F12 → Console → `document.cookie` |

### 一键安装

```powershell
# 1. 克隆本仓库
git clone https://github.com/<你的用户名>/douyin-batch-transcriber.git
Copy-Item douyin-batch-transcriber $env:USERPROFILE\.claude\skills\ -Recurse -Force

# 2. 安装 mrcarlsama-social-transcriber（单条 ASR 引擎）
git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $env:TEMP\mc
Copy-Item $env:TEMP\mc\skills\mrcarlsama-social-transcriber $env:USERPROFILE\.claude\skills\ -Recurse -Force

# 3. 安装 douyin-downloader（批量拉取引擎）
git clone --depth 1 https://github.com/jiji262/douyin-downloader.git $env:USERPROFILE\.claude\tools\douyin-downloader
```

### 使用

在 Claude Code 中直接说：

```
帮我提取抖音视频文案：
账号链接：https://www.douyin.com/user/MS4wLjABAAAA...
最低点赞数：3000
Cookie：<粘贴你从浏览器获取的 document.cookie>
```

或者用斜杠命令：

```
/douyin-batch-transcriber
```

---

## 输出示例

### 汇总表（Excel / CSV）

| 序号 | 标题/文案 | 点赞数 | 评论数 | 分享数 | 收藏数 | 播放数 | 时长 | 发布日期 | 原始文案全文 |
|------|-----------|--------|--------|--------|--------|--------|------|----------|-------------|
| 1 | 什么才是最好的婚姻？ | 291,525 | 12,341 | 45,678 | 23,456 | 5.2M | 343s | 2026-02-20 | 夫妻老了为什么大部分都是男生先走… |

### 单条视频产物

```
outputs/2026-2-20[douyin][什么才是最好的婚姻？]/
├── 什么才是最好的婚姻？原始逐字稿.txt    ← ASR 一字未改
├── 什么才是最好的婚姻？原始逐字稿.md     ← 带时间戳
├── 什么才是最好的婚姻？字幕.srt          ← 标准字幕
└── _meta/
    ├── manifest.json                    ← 完整元数据
    └── words.json                       ← 词级时间戳
```

---

## 流水线架构

```
Cookie + 账号链接 + 点赞阈值
    ↓
Phase ① douyin-downloader → 最低画质拉取全部视频 + _data.json
    ↓  处理 a-bogus 签名，支持翻页风控自动浏览器兜底
Phase ② 读取 _data.json → 按点赞筛选 → 展示概览等你确认
    ↓  确认后立即删除低画质视频（释放磁盘）
Phase ③ 仅对达标视频逐条调用 Mrcarlsama → 下载高清 + faster-whisper 本地 ASR
    ↓  自动跳过已存在的，失败不阻塞
Phase ④ 本仓库自带的 gen_summary.py → 汇总表.xlsx + 汇总表.csv
    ↓
结果：16 列完整数据，每条视频有原始文案全文
```

---

## 一键安装

### Windows
```powershell
git clone https://github.com/hujiafeng111/douyin-batch-transcriber.git
cd douyin-batch-transcriber
powershell -ExecutionPolicy Bypass -File install.ps1
```

### macOS / Linux
```bash
git clone https://github.com/hujiafeng111/douyin-batch-transcriber.git
cd douyin-batch-transcriber
bash install.sh
```

### 验证安装
```powershell
uv run --script ~/.claude/skills/douyin-batch-transcriber/scripts/preflight.py
```

## 目录结构

```
~/.claude/
├── skills/
│   ├── douyin-batch-transcriber/      ← 本 Skill（编排者）
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── batch_run.py           ← 批量转写 + 增量存 Excel
│   │       ├── gen_summary.py         ← 逐字稿 → Excel/CSV
│   │       ├── convert_cookie.py      ← Cookie 格式转换
│   │       └── preflight.py           ← 环境检查
│   └── mrcarlsama-social-transcriber/ ← ASR 引擎
│       └── scripts/run_one.py
└── tools/
    └── douyin-downloader/             ← 视频拉取引擎
        └── run.py
```

## 首次运行故障排查

### 问题 1：`uv` 找不到
```powershell
# 重新装 uv
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
# 或加入 PATH
$env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
```

### 问题 2：`mrcarlsama` 没装好
```powershell
git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $env:TEMP\mc
Copy-Item "$env:TEMP\mc\skills\mrcarlsama-social-transcriber" "$env:USERPROFILE\.claude\skills\" -Recurse -Force
# 预装依赖（首次需要下载 faster-whisper 模型，约 1-2GB）
uv run --script $env:USERPROFILE\.claude\skills\mrcarlsama-social-transcriber\scripts\bootstrap.py --ensure
```

### 问题 3：`douyin-downloader` 没装好
```powershell
git clone --depth 1 https://github.com/jiji262/douyin-downloader.git "$env:USERPROFILE\.claude\tools\douyin-downloader"
```

### 问题 4：Git 没安装
去 https://git-scm.com/download/win 下载安装。

### 问题 5：转写时 Cookie 报错
Cookie 必须是 **Netscape 格式**（制表符分隔），不能是 `document.cookie` 原始格式。
使用本 Skill 自带的转换工具：
```powershell
uv run --script ~/.claude/skills/douyin-batch-transcriber/scripts/convert_cookie.py "你的cookie字符串"
```

---

## 已验证的坑

| 坑 | 现象 | 解法 |
|----|------|------|
| Cookie 格式 | 原始 cookie 喂给 yt-dlp 报错 | `convert_cookie.py` 转为 Netscape 制表符格式 |
| glob 兼容性 | Windows 含 `？` `#` 路径 `glob.glob()` 静默返回空 | 改用 `os.listdir()` |
| 空目录残留 | Cookie 失败时的空目录被误判"已处理" | 转写前清理 0 文件目录 |
| 直接调抖音 API | 部分账号返回空响应 | 换用 douyin-downloader（处理 a-bogus 签名） |

---

## 费用

**零 API 费用。**

- douyin-downloader：免费开源
- faster-whisper：纯本地运行，不调用任何云端 API
- openpyxl：免费 Python 库

唯一消耗：本机 CPU/GPU 算力 + 磁盘空间（可随时清理视频只留文案）。

---

## License

MIT

---

## 致谢

本 Skill 编排了两个开源工具：

- [jiji262/douyin-downloader](https://github.com/jiji262/douyin-downloader) — 批量拉取引擎，9k+ stars
- [MrCarlsama/mrcarlsama-social-transcriber-skill](https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill) — 单条 ASR 引擎

## Star History

如果你觉得有用，请给个 ⭐
