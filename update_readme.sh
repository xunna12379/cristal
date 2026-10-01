#!/usr/bin/env bash
# =========================================================
# 每周笔记维护脚本（由 GitHub Actions 每周调用）
#   1. 自动补建缺失的周笔记 weekN.md（模板）
#   2. 把最新笔记列表写回 README.md（START/END 标记之间）
# =========================================================
set -euo pipefail

# ---- 配置 ----
START_DATE="2026-10-01"   # 第 1 周（week1.md）的起始日期
MARKER_START="<!-- WEEKLY-NOTES:START -->"
MARKER_END="<!-- WEEKLY-NOTES:END -->"

# ---- 计算当前是第几周 ----
now_epoch=$(date +%s)
start_epoch=$(date -d "$START_DATE" +%s)
week_now=$(( (now_epoch - start_epoch) / 86400 / 7 + 1 ))
[ "$week_now" -lt 1 ] && week_now=1

# ---- 1) 补齐缺失的周笔记模板 ----
for ((n = 1; n <= week_now; n++)); do
  f="week${n}.md"
  if [ ! -f "$f" ]; then
    d=$(date -d "$START_DATE +$(( (n - 1) * 7 )) days")
    printf '#%s  %s\n\n##本周完成\n-\n-\n\n##新问题\n-\n-\n\n##下周计划\n-\n-\n' \
      "$(date -d "$d" +%Y)" "$(date -d "$d" +%-m.%-e)" > "$f"
    echo "已创建模板：$f"
  fi
done

# ---- 2) 生成最新笔记列表（新周在前） ----
max_n=0
for f in week*.md; do
  [ -e "$f" ] || continue
  n=${f//[^0-9]/}
  [ "$n" -gt "$max_n" ] && max_n=$n
done

notes_list=""
for ((n = max_n; n >= 1; n--)); do
  f="week${n}.md"
  [ -f "$f" ] || continue
  d=$(date -d "$START_DATE +$(( (n - 1) * 7 )) days" +%Y-%m-%d)
  title=$(head -n 1 "$f" | sed 's/^#*//; s/^[[:space:]]*//')
  notes_list+="- 第 ${n} 周｜${d} 起｜${title} — [查看笔记](${f})"$'\n'
done

# ---- 3) 写回 README.md（只替换标记之间的内容） ----
if ! grep -q "$MARKER_START" README.md || ! grep -q "$MARKER_END" README.md; then
  echo "错误：README.md 中缺少 $MARKER_START / $MARKER_END 标记" >&2
  exit 1
fi

awk -v block="$notes_list" -v ms="$MARKER_START" -v me="$MARKER_END" '
  index($0, ms) { print; print block; skip = 1; next }
  index($0, me) { skip = 0; print; next }
  !skip { print }
' README.md > README.md.new && mv README.md.new README.md

echo "README.md 更新完成"
