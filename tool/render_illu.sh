#!/bin/bash
# Рендер превью иллюстрации: один кадр (тема) на процесс.
#
# Харнесс .claude/skills/illustration-widget/tools/render_preview_test.dart
# после записи PNG зависает (второй toImage в том же процессе не возвращается),
# поэтому здесь мы ждём появления файла и убиваем процесс — кадр стоит ~10 с
# вместо четырёх минут.
#
#   tool/render_illu.sh <slug> [theme] [frame_ms]
set -u

SLUG="$1"
THEME="${2:-light}"
FRAME="${3:-0}"
OUT="build/illustration_preview"
TARGET="$OUT/$SLUG-$THEME.png"

mkdir -p "$OUT"
rm -f "$TARGET"

SLUG="$SLUG" THEMES="$THEME" FRAMES="$FRAME" \
  flutter test .claude/skills/illustration-widget/tools/render_preview_test.dart \
  >/tmp/render_illu.log 2>&1 &
PID=$!

for _ in $(seq 1 120); do
  if [ -s "$TARGET" ]; then
    sleep 1
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    if [ "$FRAME" != "0" ]; then
      mv "$TARGET" "$OUT/$SLUG-$THEME-${FRAME}ms.png"
      echo "OK $OUT/$SLUG-$THEME-${FRAME}ms.png"
    else
      echo "OK $TARGET"
    fi
    exit 0
  fi
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "FAIL: процесс завершился без PNG, см. /tmp/render_illu.log"
    tail -30 /tmp/render_illu.log
    exit 1
  fi
  sleep 2
done

kill "$PID" 2>/dev/null
echo "TIMEOUT, см. /tmp/render_illu.log"
tail -30 /tmp/render_illu.log
exit 1
