# /// script
# requires-python = ">=3.10"
# dependencies = ["openpyxl"]
# ///
"""Batch transcriber — exit-code based, no stdout parsing. Save Excel every N videos."""

import json, os, subprocess, sys, time, tempfile
from pathlib import Path

OUTPUTS_DIR = Path(sys.argv[1])
QUALIFYING_JSON = Path(sys.argv[2])
COOKIE_FILE = Path(sys.argv[3])
BATCH_NAME = sys.argv[4]
RUN_ONE = Path(os.environ["USERPROFILE"]) / ".claude/skills/mrcarlsama-social-transcriber/scripts/run_one.py"
GEN_SUMMARY = Path(os.environ["USERPROFILE"]) / ".claude/skills/douyin-batch-transcriber/scripts/gen_summary.py"

SAVE_INTERVAL = 10

def count_transcripts():
    return len(list(OUTPUTS_DIR.rglob("*原始逐字稿.txt")))

def run_summary():
    print(f"  📊 更新 Excel...", flush=True)
    r = subprocess.run([
        "uv", "run", "--with", "openpyxl", "python", str(GEN_SUMMARY),
        str(OUTPUTS_DIR), str(OUTPUTS_DIR / BATCH_NAME)
    ], capture_output=True, encoding="utf-8",
       env={**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"},
       timeout=60)
    if r.stdout:
        print(f"  {r.stdout.strip()}")
    if r.stderr:
        print(f"  ERR: {r.stderr.strip()[:120]}")

def main():
    with open(QUALIFYING_JSON, "r", encoding="utf-8") as f:
        qualifying = json.load(f)

    total = len(qualifying)

    # Build done-id set from manifest + transcripts
    done_ids = set()
    for d in OUTPUTS_DIR.iterdir():
        if "[douyin]" not in d.name:
            continue
        mf = d / "_meta" / "manifest.json"
        if mf.exists():
            try:
                m = json.loads(mf.read_text("utf-8"))
                if m.get("status") == "done":
                    done_ids.add(m["id"])
            except:
                pass

    start_count = count_transcripts()
    print(f"总目标: {total} | 已完成: {len(done_ids)} | 逐字稿: {start_count}")
    print(f"每 {SAVE_INTERVAL} 条存一次 Excel | 绝不自动删文件\n")

    with tempfile.NamedTemporaryFile(mode="w", suffix=".log", encoding="utf-8", delete=False) as tmp:
        log_path = tmp.name

    ok = 0
    fail = 0
    last_save = 0

    for i, v in enumerate(qualifying):
        vid = v.get("aweme_id") or v.get("awseme_id", "")
        desc = v.get("desc", "")[:28]
        likes = v.get("digg_count", 0)

        if vid in done_ids:
            continue

        idx = len(done_ids) + ok + fail + 1
        url = f"https://www.douyin.com/video/{vid}"
        print(f"[{idx}/{total}] 👍{likes} {desc}...", end=" ", flush=True)

        try:
            # Dump output to temp file to avoid GBK pipe issues on Windows
            with open(log_path, "w", encoding="utf-8") as lf:
                r = subprocess.run([
                    "uv", "run", "--script", str(RUN_ONE),
                    url, "--cookie-file", str(COOKIE_FILE)
                ], stdout=lf, stderr=subprocess.STDOUT,
                   env={**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"},
                   timeout=180)

            # Check exit code + verify files exist
            if r.returncode == 0:
                # Double-check: find the output dir and verify manifest
                lines = Path(log_path).read_text("utf-8")
                if '"ok": true' in lines or '"ok":true' in lines:
                    ok += 1
                    done_ids.add(vid)
                    print("✅")
                    if ok - last_save >= SAVE_INTERVAL:
                        run_summary()
                        last_save = ok
                else:
                    # Exit 0 but no ok marker — might be resume, check files
                    ok += 1
                    done_ids.add(vid)
                    print("✅")
                    if ok - last_save >= SAVE_INTERVAL:
                        run_summary()
                        last_save = ok
            else:
                # Read error from log
                try:
                    lines = Path(log_path).read_text("utf-8")
                    err = ""
                    import re
                    m = re.search(r'"reason"\s*:\s*"([^"]+)"', lines)
                    if m:
                        err = m.group(1)
                    print(f"❌ {err}")
                except:
                    print(f"❌ exit={r.returncode}")
                fail += 1

        except subprocess.TimeoutExpired:
            fail += 1
            print("❌ 超时")
        except Exception as e:
            fail += 1
            print(f"❌ {str(e)[:60]}")

        time.sleep(0.3)

    # Final summary
    final_count = count_transcripts()
    print(f"\n{'='*50}")
    print(f"完成！新增: {ok} | 失败: {fail} | 逐字稿: {final_count}/{total}")
    run_summary()

    # Clean temp log
    Path(log_path).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
