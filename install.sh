#!/bin/bash
# douyin-batch-transcriber 一键安装脚本 (macOS/Linux)
set -e

echo "🎬 抖音批量文案提取 — 一键安装"
echo ""

SKILLS_DIR="$HOME/.claude/skills"
TOOLS_DIR="$HOME/.claude/tools"

# 1. uv
echo "[1/4] 检查 uv..."
if command -v uv &>/dev/null; then
    echo "  ✅ uv 已安装"
else
    echo "  安装 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo "  ✅ uv 安装完成"
fi

# 2. Mrcarlsama social transcriber
echo "[2/4] 安装 mrcarlsama-social-transcriber..."
if [ -f "$SKILLS_DIR/mrcarlsama-social-transcriber/scripts/run_one.py" ]; then
    echo "  ✅ 已存在"
else
    TMPDIR=$(mktemp -d)
    git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git "$TMPDIR"
    mkdir -p "$SKILLS_DIR"
    cp -R "$TMPDIR/skills/mrcarlsama-social-transcriber" "$SKILLS_DIR/"
    rm -rf "$TMPDIR"
    echo "  ✅ 安装完成"
fi

# 3. douyin-downloader
echo "[3/4] 安装 douyin-downloader..."
if [ -f "$TOOLS_DIR/douyin-downloader/run.py" ]; then
    echo "  ✅ 已存在"
else
    mkdir -p "$TOOLS_DIR"
    git clone --depth 1 https://github.com/jiji262/douyin-downloader.git "$TOOLS_DIR/douyin-downloader"
    echo "  ✅ 安装完成"
fi

# 4. douyin-batch-transcriber (本 skill)
echo "[4/4] 安装 douyin-batch-transcriber..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SKILLS_DIR"
cp -R "$SCRIPT_DIR" "$SKILLS_DIR/douyin-batch-transcriber"
echo "  ✅ 安装完成"

echo ""
echo "🎉 全部安装完成！"
echo ""
echo "使用方法：在 Claude Code 中直接说「帮我提取抖音视频文案」"
echo "需要提供：主页链接 + 最低点赞数 + Cookie (F12 → Console → document.cookie)"
