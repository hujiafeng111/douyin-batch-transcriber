# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Pre-flight check — verify all dependencies are ready.
Run this after install.ps1 / install.sh to confirm everything works.
"""
import os, subprocess, sys
from pathlib import Path

HOME = Path(os.environ.get("USERPROFILE", os.environ.get("HOME", ".")))
SKILLS = HOME / ".claude" / "skills"
TOOLS = HOME / ".claude" / "tools"

checks = []

def check(name, ok, detail=""):
    mark = "[OK]" if ok else "[MISS]"
    msg = f"  {mark} {name}"
    if detail:
        msg += f" — {detail}"
    print(msg)
    checks.append(ok)
    return ok

print("=" * 50)
print("  douyin-batch-transcriber 环境检查")
print("=" * 50)

# 1. uv
print("\n[1/5] Python 环境")
try:
    r = subprocess.run(["uv", "--version"], capture_output=True, text=True, timeout=10)
    ok = r.returncode == 0
    check("uv", ok, r.stdout.strip() if ok else "")
except Exception:
    check("uv", False, "not found — 请安装: https://docs.astral.sh/uv/")

# 2. Python via uv
try:
    r = subprocess.run(["uv", "python", "--version"], capture_output=True, text=True, timeout=10)
    ok = r.returncode == 0 and "3." in (r.stdout or "")
    check("Python (via uv)", ok, (r.stdout or "").strip())
except Exception:
    check("Python (via uv)", False, "uv could not find Python")

# 3. mrcarlsama
print("\n[2/5] mrcarlsama-social-transcriber (ASR 引擎)")
run_one = SKILLS / "mrcarlsama-social-transcriber" / "scripts" / "run_one.py"
if check("SKILL.md + scripts", run_one.exists()):
    # Try bootstrapping
    bootstrap = run_one.parent / "bootstrap.py"
    if bootstrap.exists():
        try:
            r = subprocess.run(
                ["uv", "run", "--script", str(bootstrap), "--ensure"],
                capture_output=True, text=True, timeout=120
            )
            check("  依赖 (faster-whisper/yt-dlp)", r.returncode == 0,
                  "bootstrap ok" if r.returncode == 0 else "bootstrap failed, will retry at runtime")
        except subprocess.TimeoutExpired:
            check("  依赖", False, "bootstrap timed out")
        except Exception as e:
            check("  依赖", False, str(e)[:60])
else:
    print("  请安装:")
    print(f"    git clone --depth 1 https://github.com/MrCarlsama/mrcarlsama-social-transcriber-skill.git $env:TEMP\\mc")
    print(f"    Copy-Item $env:TEMP\\mc\\skills\\mrcarlsama-social-transcriber {SKILLS}\\ -Recurse -Force")

# 4. douyin-downloader
print("\n[3/5] douyin-downloader (视频拉取引擎)")
dy_run = TOOLS / "douyin-downloader" / "run.py"
check("run.py", dy_run.exists())

# 5. douyin-batch-transcriber (self)
print("\n[4/5] douyin-batch-transcriber (本 Skill)")
own_skill = SKILLS / "douyin-batch-transcriber" / "SKILL.md"
own_batch = SKILLS / "douyin-batch-transcriber" / "scripts" / "batch_run.py"
own_summary = SKILLS / "douyin-batch-transcriber" / "scripts" / "gen_summary.py"
own_cookie = SKILLS / "douyin-batch-transcriber" / "scripts" / "convert_cookie.py"
check("SKILL.md", own_skill.exists())
check("scripts/batch_run.py", own_batch.exists())
check("scripts/gen_summary.py", own_summary.exists())
check("scripts/convert_cookie.py", own_cookie.exists())

# 6. git
print("\n[5/5] 其他工具")
try:
    r = subprocess.run(["git", "--version"], capture_output=True, text=True, timeout=5)
    check("git", r.returncode == 0, r.stdout.strip() if r.returncode == 0 else "")
except Exception:
    check("git", False, "not found — 请安装 https://git-scm.com/")

# === Summary ===
print("\n" + "=" * 50)
passed = sum(checks)
total = len(checks)
if passed == total:
    print(f"  全部通过 ({passed}/{total})")
    print("  Skill 已就绪，可以直接使用！")
else:
    print(f"  通过 {passed}/{total}，{total - passed} 项需修复")
    print("  请根据上面的 [MISS] 提示安装缺失的依赖")
print("=" * 50)
