#!/usr/bin/env bash
# Lấy mẫu CẢ HAI tiến trình khi khối 3D đang sống, cộng nhiệt và LMK.
#
# Phải đo hai tiến trình vì tải bị chia đôi một cách không trực giác:
#   app        — giữ Graphics (EGL/GL), tức texture trên GPU
#   sandboxed  — giữ heap/code của Chromium
# Chỉ nhìn một bên là bỏ sót quá nửa chi phí.
export PATH=$PATH:/home/vamamurin/.local/share/android/sdk/platform-tools

PKG=com.example.beacon_client
DURATION=${1:-180}
INTERVAL=${2:-15}
OUT=${3:-./sample_3d.csv}

echo "t,app_pss,app_gfx,app_swap,wv_pss,combined_pss,sys_avail,cpu_temp,skin_temp,throttle" > "$OUT"

t=0
while [ "$t" -lt "$DURATION" ]; do
  apid=$(adb shell pidof $PKG | tr -d '\r')
  wpid=$(adb shell ps -A 2>/dev/null | grep "sandboxed_process0" | awk '{print $2}' | head -1 | tr -d '\r')

  if [ -z "$apid" ]; then echo "  ! APP DA CHET o t=${t}s"; break; fi

  araw=$(adb shell dumpsys meminfo "$apid" 2>/dev/null)
  app_pss=$(echo "$araw"  | grep -E "^\s+TOTAL PSS:" | awk '{print $3}')
  app_gfx=$(echo "$araw"  | grep -E "^\s+Graphics:" | awk '{print $2}')
  app_swap=$(echo "$araw" | grep -E "TOTAL SWAP PSS:" | awk '{print $NF}')

  if [ -n "$wpid" ]; then
    wv_pss=$(adb shell dumpsys meminfo "$wpid" 2>/dev/null | grep -E "^\s+TOTAL PSS:" | awk '{print $3}')
  else
    wv_pss=0
    echo "  ! TIEN TRINH RENDER DA CHET o t=${t}s  (app van song)"
  fi

  avail=$(adb shell cat /proc/meminfo | awk '/MemAvailable/{print $2}')
  th=$(adb shell dumpsys thermalservice 2>/dev/null | sed -n '/Current temperatures from HAL/,/Current cooling/p')
  cpu=$(echo "$th"  | grep 'mName=CPU'  | grep -o 'mValue=[0-9.]*' | cut -d= -f2 | head -1)
  skin=$(echo "$th" | grep 'mName=SKIN' | grep -o 'mValue=[0-9.]*' | cut -d= -f2 | head -1)
  thr=$(echo "$th"  | grep 'mName=CPU'  | grep -o 'mStatus=[0-9]*' | cut -d= -f2 | head -1)

  comb=$(( ${app_pss:-0} + ${wv_pss:-0} ))
  echo "${t},${app_pss:-0},${app_gfx:-0},${app_swap:-0},${wv_pss:-0},${comb},${avail:-0},${cpu:-0},${skin:-0},${thr:-0}" >> "$OUT"
  printf "  t=%4ds  app=%6.1fMB (gfx %5.1f, swap %5.1f)  webview=%6.1fMB  TONG=%6.1fMB  sysFree=%5.0fMB  CPU=%s°C skin=%s°C thr=%s\n" \
    "$t" "$((${app_pss:-0}))e-3" "$((${app_gfx:-0}))e-3" "$((${app_swap:-0}))e-3" \
    "$((${wv_pss:-0}))e-3" "$((comb))e-3" "$((${avail:-0}))e-3" "${cpu:-?}" "${skin:-?}" "${thr:-?}" 2>/dev/null \
    || printf "  t=%4ds  app=%s KB (gfx %s, swap %s)  webview=%s KB  TONG=%s KB  sysFree=%s KB  CPU=%s skin=%s thr=%s\n" \
       "$t" "${app_pss:-?}" "${app_gfx:-?}" "${app_swap:-?}" "${wv_pss:-?}" "$comb" "${avail:-?}" "${cpu:-?}" "${skin:-?}" "${thr:-?}"

  sleep "$INTERVAL"
  t=$((t + INTERVAL))
done

echo
echo "=== LMK / OOM KILL ==="
adb logcat -d -t 2000 2>/dev/null | grep -i -E "lowmemorykiller|lmkd|ActivityManager.*(Killing|died)" | tail -8
echo "(rong = khong co lan giet nao)"
