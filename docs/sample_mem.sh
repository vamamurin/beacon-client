#!/usr/bin/env bash
# Lấy mẫu bộ nhớ của app trên máy thật, mỗi INTERVAL giây, trong DURATION giây.
#
# Đo PSS/RSS/Graphics tách riêng vì ba con số này nói ba chuyện khác nhau:
#   PSS      — phần app thật sự "chịu trách nhiệm", thứ LMK nhìn vào
#   RSS      — trang vật lý đang giữ, kể cả dùng chung
#   Graphics — EGL + GL, tức texture/framebuffer trên GPU; đây là chỗ 3D sẽ nổ
export PATH=$PATH:/home/vamamurin/.local/share/android/sdk/platform-tools

PKG=com.example.beacon_client
DURATION=${1:-60}
INTERVAL=${2:-3}
OUT=${3:-/tmp/mem_samples.csv}

echo "t,pss_kb,rss_kb,graphics_kb,java_kb,native_kb,code_kb,avail_sys_kb" > "$OUT"

t=0
while [ "$t" -lt "$DURATION" ]; do
  raw=$(adb shell dumpsys meminfo $PKG 2>/dev/null)
  if [ -z "$raw" ]; then
    echo "  ! app khong chay o t=${t}s"
    break
  fi

  pss=$(echo "$raw"  | grep -E "^\s+TOTAL PSS:" | awk '{print $3}')
  rss=$(echo "$raw"  | grep -E "TOTAL RSS:"     | awk '{print $6}')
  gfx=$(echo "$raw"  | grep -E "^\s+Graphics:"  | awk '{print $2}')
  java=$(echo "$raw" | grep -E "^\s+Java Heap:" | awk '{print $3}')
  nat=$(echo "$raw"  | grep -E "^\s+Native Heap:" | awk '{print $3}')
  code=$(echo "$raw" | grep -E "^\s+Code:"      | awk '{print $2}')
  avail=$(adb shell cat /proc/meminfo | awk '/MemAvailable/{print $2}')

  echo "${t},${pss:-0},${rss:-0},${gfx:-0},${java:-0},${nat:-0},${code:-0},${avail:-0}" >> "$OUT"
  printf "  t=%3ds  PSS=%6s KB  RSS=%7s KB  GFX=%6s KB  sysAvail=%8s KB\n" \
    "$t" "${pss:-?}" "${rss:-?}" "${gfx:-?}" "${avail:-?}"

  sleep "$INTERVAL"
  t=$((t + INTERVAL))
done

echo
echo "=== TONG KET (${OUT}) ==="
awk -F, 'NR>1 {
  n++
  if (max_pss=="" || $2>max_pss) max_pss=$2
  if (min_pss=="" || $2<min_pss) min_pss=$2
  sum_pss+=$2
  if (max_gfx=="" || $4>max_gfx) max_gfx=$4
  sum_gfx+=$4
  if (min_avail=="" || $8<min_avail) min_avail=$8
} END {
  if (n==0) { print "  (khong co mau)"; exit }
  printf "  mau      : %d\n", n
  printf "  PSS      : min %.1f MB / tb %.1f MB / max %.1f MB\n", min_pss/1024, sum_pss/n/1024, max_pss/1024
  printf "  Graphics : tb %.1f MB / max %.1f MB\n", sum_gfx/n/1024, max_gfx/1024
  printf "  RAM he thong con thap nhat: %.0f MB\n", min_avail/1024
}' "$OUT"
