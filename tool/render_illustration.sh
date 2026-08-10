#!/bin/bash
# Рендер превью иллюстрации: один слаг, одна тема, один процесс.
#
# Харнесс .claude/skills/illustration-widget/tools/render_preview_test.dart
# записывает PNG за ~30 секунд, после чего процесс виснет до 10-минутного
# таймаута. Поэтому ждём появления файла и убиваем процесс сами.
#
#   tool/render_illustration.sh <slug> [light|dark]
set -u
slug="$1"
theme="${2:-light}"
out="build/illustration_preview"
png="$out/$slug-$theme.png"

rm -f "$png"
SLUG="$slug" THEMES="$theme" OUT="$out" \
  flutter test .claude/skills/illustration-widget/tools/render_preview_test.dart \
  >"/tmp/render-$slug-$theme.log" 2>&1 &
pid=$!

for _ in $(seq 1 90); do
  if [ -f "$png" ]; then
    sleep 1 # даём дописать файл
    kill "$pid" 2>/dev/null
    pkill -f flutter_tester 2>/dev/null
    echo "OK $png"
    exit 0
  fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 4
done

kill "$pid" 2>/dev/null
pkill -f flutter_tester 2>/dev/null
echo "FAILED $slug/$theme — см. /tmp/render-$slug-$theme.log"
tail -20 "/tmp/render-$slug-$theme.log"
exit 1
