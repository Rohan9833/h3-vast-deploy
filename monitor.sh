#!/usr/bin/env bash
set -Eeuo pipefail

INTERVAL="${1:-2}"
if ! [[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: bash monitor.sh [interval_seconds]" >&2
  exit 2
fi

echo "Monitoring host memory and MiniMax H3/SGLang process usage every ${INTERVAL}s."
echo "Press Ctrl+C to stop."
while true; do
  printf '\n===== %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S')"

  echo "--- System RAM and swap ---"
  free -h

  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "--- GPU memory and utilization ---"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,utilization.memory --format=csv,noheader || true
  else
    echo "--- nvidia-smi unavailable ---"
  fi

  echo "--- SGLang-related process RSS (MiB) ---"
  ps -eo pid=,rss=,args= | awk '
    /[s]glang/ {
      printf "PID=%s RSS=%.1f MiB CMD=", $1, $2/1024
      for (i=3; i<=NF; i++) printf "%s%s", $i, (i==NF ? "\n" : " ")
      found=1
    }
    END { if (!found) print "No SGLang process found yet." }
  '

  sleep "$INTERVAL"
done
