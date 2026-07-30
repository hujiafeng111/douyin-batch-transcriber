# douyin-batch-transcriber 一键安装脚本
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"
Write-Host "🎬 抖音批量文案提取 — 一键安装" -ForegroundColor Cyan
Write-Host ""

$skillsDir = "$env:USERPROFILE\.claude\skills"
$toolsDir = "$env:USERPROFILE\.claude\tools"

# 1. uv
Write-Host "[1/4] 检查 uv..." -ForegroundColor Yellow
try {
    uv --version 2>$null | Out-Null
    Write-Host "  ✅ uv 已安装" -ForegroundColor Green
} catch {
    Write-Host "  安装 uv..." -ForegroundColor Yellow
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
    Write-Host "  ✅ uv 安装完成" -ForegroundColor Green
}

# 2. Mrcarlsama social transcriber
Write-Host "[2/4] 安装 mrcarlsama-social-transcriber..." -ForegroundColor Yellow
if (Test-Path "$skillsDir\mrcarlsama-social-transcriber\scripts\run_one.py") {
    Write-Host "  ✅ 已存在" -ForegroundColor Green
} else {
    $tmp = "$env:TEMP\mc-install"
    git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $tmp 2>$null
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
    Copy-Item "$tmp\skills\mrcarlsama-social-transcriber" $skillsDir -Recurse -Force
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✅ 安装完成" -ForegroundColor Green
}

# 3. douyin-downloader
Write-Host "[3/4] 安装 douyin-downloader..." -ForegroundColor Yellow
if (Test-Path "$toolsDir\douyin-downloader\run.py") {
    Write-Host "  ✅ 已存在" -ForegroundColor Green
} else {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    git clone --depth 1 https://github.com/jiji262/douyin-downloader.git $toolsDir\douyin-downloader
    Write-Host "  ✅ 安装完成" -ForegroundColor Green
}

# 4. douyin-batch-transcriber (本 skill)
Write-Host "[4/4] 安装 douyin-batch-transcriber..." -ForegroundColor Yellow
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
Copy-Item $src $skillsDir -Recurse -Force
Write-Host "  ✅ 安装完成" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 全部安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "使用方法：" -ForegroundColor Cyan
Write-Host "  在 Claude Code 中说：帮我提取抖音视频文案" -ForegroundColor White
Write-Host "  或：/douyin-batch-transcriber" -ForegroundColor White
Write-Host ""
Write-Host "需要提供：" -ForegroundColor Yellow
Write-Host "  1. 抖音创作者主页链接" -ForegroundColor White
Write-Host "  2. 最低点赞数（如 3000）" -ForegroundColor White
Write-Host "  3. Cookie (F12 → Console → document.cookie)" -ForegroundColor White
