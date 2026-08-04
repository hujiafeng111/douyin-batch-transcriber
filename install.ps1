# ============================================================
# douyin-batch-transcriber 一键安装脚本 (Windows)
# Run: powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "抖音批量文案提取 - 安装中..."
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  抖音批量文案提取 Skill - 一键安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$skillsDir = "$env:USERPROFILE\.claude\skills"
$toolsDir = "$env:USERPROFILE\.claude\tools"
$uvBinDir = "$env:USERPROFILE\.local\bin"
$failed = @()

# === Step 1: Check/Install Git ===
Write-Host "[1/5] 检查 Git..." -ForegroundColor Yellow
try {
    git --version 2>$null | Out-Null
    Write-Host "  [OK] Git 已安装" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Git 未安装！请手动安装: https://git-scm.com/download/win" -ForegroundColor Red
    Write-Host "  (安装后重新运行本脚本)" -ForegroundColor Red
    $failed += "Git not installed"
}

# === Step 2: Install uv (Python package manager) ===
Write-Host "[2/5] 安装 uv..." -ForegroundColor Yellow
$uvPath = Join-Path $uvBinDir "uv.exe"
if (Test-Path $uvPath) {
    & $uvPath --version 2>$null
    Write-Host "  [OK] uv 已安装: $(& $uvPath --version 2>&1)" -ForegroundColor Green
} else {
    Write-Host "  正在下载安装 uv..." -ForegroundColor Gray
    try {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" 2>$null
        if (Test-Path $uvPath) {
            Write-Host "  [OK] uv 安装完成" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] uv 安装失败，请手动执行:" -ForegroundColor Red
            Write-Host "    powershell -c `"irm https://astral.sh/uv/install.ps1 | iex`"" -ForegroundColor Red
            $failed += "uv install failed"
        }
    } catch {
        Write-Host "  [FAIL] uv 安装失败" -ForegroundColor Red
        $failed += "uv install failed"
    }
}

# Add uv to PATH for this session
$env:Path = "$uvBinDir;$env:Path"

# === Step 3: Install mrcarlsama-social-transcriber ===
Write-Host "[3/5] 安装 mrcarlsama-social-transcriber (ASR 引擎)..." -ForegroundColor Yellow
$mrcPath = Join-Path $skillsDir "mrcarlsama-social-transcriber\scripts\run_one.py"
if (Test-Path $mrcPath) {
    Write-Host "  [OK] 已存在" -ForegroundColor Green
} else {
    $tmpDir = "$env:TEMP\mc_skill_install_$(Get-Random)"
    Write-Host "  从 GitHub 下载..." -ForegroundColor Gray
    try {
        git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $tmpDir 2>&1 | Out-Null
        if (Test-Path "$tmpDir\skills\mrcarlsama-social-transcriber") {
            New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
            Copy-Item "$tmpDir\skills\mrcarlsama-social-transcriber" $skillsDir -Recurse -Force
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] 安装完成" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] 仓库结构异常" -ForegroundColor Red
            $failed += "mrcarlsama clone failed"
        }
    } catch {
        Write-Host "  [FAIL] Git clone 失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  [FIX] 手动执行:" -ForegroundColor Yellow
        Write-Host "    git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git `$env:TEMP\mc" -ForegroundColor White
        Write-Host "    Copy-Item `$env:TEMP\mc\skills\mrcarlsama-social-transcriber `$env:USERPROFILE\.claude\skills\ -Recurse -Force" -ForegroundColor White
        $failed += "mrcarlsama install failed"
    }
}

# === Step 4: Install douyin-downloader ===
Write-Host "[4/5] 安装 douyin-downloader (视频拉取引擎)..." -ForegroundColor Yellow
$dyPath = Join-Path $toolsDir "douyin-downloader\run.py"
if (Test-Path $dyPath) {
    Write-Host "  [OK] 已存在" -ForegroundColor Green
} else {
    Write-Host "  从 GitHub 下载 (约 2MB)..." -ForegroundColor Gray
    try {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        git clone --depth 1 https://github.com/jiji262/douyin-downloader.git "$toolsDir\douyin-downloader" 2>&1 | Out-Null
        if (Test-Path $dyPath) {
            Write-Host "  [OK] 安装完成" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] 克隆失败" -ForegroundColor Red
            $failed += "douyin-downloader clone failed"
        }
    } catch {
        Write-Host "  [FAIL] Git clone 失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  [FIX] 手动执行:" -ForegroundColor Yellow
        Write-Host "    git clone --depth 1 https://github.com/jiji262/douyin-downloader.git `$env:USERPROFILE\.claude\tools\douyin-downloader" -ForegroundColor White
        $failed += "douyin-downloader install failed"
    }
}

# === Step 5: Install douyin-batch-transcriber (this skill) ===
Write-Host "[5/5] 安装 douyin-batch-transcriber (本 Skill)..." -ForegroundColor Yellow
$srcDir = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
Copy-Item $srcDir (Join-Path $skillsDir "douyin-batch-transcriber") -Recurse -Force
Write-Host "  [OK] 安装完成" -ForegroundColor Green

# === Pre-bootstrap mrcarlsama dependencies ===
Write-Host ""
Write-Host "正在预装 Python 依赖（首次需要下载 ASR 模型，约 1-2GB）..." -ForegroundColor Yellow
if (Test-Path $mrcPath) {
    try {
        $mrcScriptsDir = Split-Path $mrcPath -Parent
        $bootstrapPy = Join-Path $mrcScriptsDir "bootstrap.py"
        if (Test-Path $bootstrapPy) {
            Write-Host "  运行 mrcarlsama 环境初始化..." -ForegroundColor Gray
            & uv run --script $bootstrapPy --ensure 2>&1 | Select-Object -Last 5
            Write-Host "  [OK] Python 依赖就绪 (faster-whisper, yt-dlp, playwright, ffmpeg)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] 预装失败，首次运行时将自动安装" -ForegroundColor Yellow
        Write-Host "  这不是致命错误，Skill 仍可使用" -ForegroundColor Yellow
    }
}

# === Final report ===
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($failed.Count -eq 0) {
    Write-Host "  安装完成！" -ForegroundColor Green
} else {
    Write-Host "  安装完成，但有以下问题需手动处理:" -ForegroundColor Yellow
    foreach ($f in $failed) {
        Write-Host "    - $f" -ForegroundColor Red
    }
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "使用方法：" -ForegroundColor Cyan
Write-Host "  1. 重启 Claude Code（或新开终端）" -ForegroundColor White
Write-Host "  2. 对话中说：帮我提取抖音视频文案" -ForegroundColor White
Write-Host "  3. 提供：主页链接 + 最低点赞数 + Cookie" -ForegroundColor White
Write-Host ""
Write-Host "所需 Cookie 获取方式：" -ForegroundColor Yellow
Write-Host "  浏览器打开 douyin.com → F12 → Console" -ForegroundColor White
Write-Host "  输入 document.cookie → 回车 → 复制整串" -ForegroundColor White
Write-Host ""
