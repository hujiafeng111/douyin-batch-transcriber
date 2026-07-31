# /// script
# requires-python = ">=3.10"
# dependencies = ["openpyxl"]
# ///
"""Batch transcriber with incremental Excel save every 10 videos.

Usage:
  uv run --with openpyxl python batch_run.py <outputs_dir> <qualifying_json> <cookie_file> <batch_name>
"""

import json, os, sys, subprocess, time
from pathlib import Path

OUTPUTS_DIR = Path(sys.argv[1])
QUALIFYING_JSON = Path(sys.argv[2])
COOKIE_FILE = Path(sys.argv[3])
BATCH_NAME = sys.argv[4]
RUN_ONE = Path(os.environ["USERPROFILE"]) / ".claude/skills/mrcarlsama-social-transcriber/scripts/run_one.py"
GEN_SUMMARY = Path(os.environ["USERPROFILE"]) / ".claude/skills/douyin-batch-transcriber/scripts/gen_summary.py"

SAVE_INTERVAL = 10  # Save Excel every N successful transcripts

def count_transcripts():
    return len(list(OUTPUTS_DIR.rglob("*原始逐字稿.txt")))

def run_summary():
    print(f"\n  📊 更新 Excel...")
    r = subprocess.run([
        "uv", "run", "--with", "openpyxl", "python", str(GEN_SUMMARY),
        str(OUTPUTS_DIR), str(OUTPUTS_DIR / BATCH_NAME)
    ], capture_output=True, text=True, timeout=60)
    print(f"  {r.stdout.strip()}")
    if r.stderr:
        print(f"  ERR: {r.stderr[:200]}")

def main():
    with open(QUALIFYING_JSON, "r", encoding="utf-8") as f:
        qualifying = json.load(f)

    total = len(qualifying)
    start_count = count_transcripts()

    # Build set of already-done video IDs by scanning manifest.json
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

    print(f"总目标: {total} 条")
    print(f"已存在逐字稿: {start_count} | 已确认完成: {len(done_ids)}")
    print(f"每 {SAVE_INTERVAL} 条保存一次 Excel")
    print(f"开始处理...\n")

    ok = 0
    fail = 0
    last_save = 0

    for i, v in enumerate(qualifying):
        vid = v.get("aweme_id") or v.get("awseme_id", "")
        desc = v.get("desc", "")[:28]
        likes = v.get("digg_count", 0)

        # Skip if already done
        if vid in done_ids:
            continue

        idx = len(done_ids) + ok + fail + 1

        url = f"https://www.douyin.com/video/{vid}"
        print(f"[{idx}/{total}] 👍{likes} {desc}...", end=" ", flush=True)

        try:
            r = subprocess.run([
                "uv", "run", "--script", str(RUN_ONE),
                url, "--cookie-file", str(COOKIE_FILE)
            ], capture_output=True, text=True, timeout=180)

            if '"ok": true' in r.stdout or '"ok":true' in r.stdout:
                ok += 1
                done_ids.add(vid)
                print("✅")

                # Incremental save
                if ok - last_save >= SAVE_INTERVAL:
                    run_summary()
                    last_save = ok

            elif '"ok": false' in r.stdout or '"ok":false' in r.stdout:
                fail += 1
                # Show brief error
                err = ""
                if '"reason"' in r.stdout:
                    import re
                    m = re.search(r'"reason"\s*:\s*"([^"]+)"', r.stdout)
                    if m:
                        err = m.group(1)
                print(f"❌ {err}")

            else:
                ok += 1
                done_ids.add(vid)
                print("✅")

        except subprocess.TimeoutExpired:
            fail += 1
            print("❌ 超时")
        except Exception as e:
            fail += 1
            print(f"❌ {str(e)[:60]}")

        # Small delay between videos
        time.sleep(0.5)

    # Final summary
    final_count = count_transcripts()
    print(f"\n{'='*50}")
    print(f"处理完成！新增: {ok} | 失败: {fail} | 逐字稿总数: {final_count}/{total}")
    run_summary()

if __name__ == "__main__":
    main()
