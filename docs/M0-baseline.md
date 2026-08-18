# M0 · Hồ sơ đo nền — trước khi đưa 3D vào

**Ngày đo:** 17/08/2026 · **Máy:** Xiaomi 220733SG qua `adb connect 192.168.1.55:5555`
**Bản app:** `com.example.beacon_client` 1.0.0, cài 17/08/2026 01:03

> Máy này **không phải** máy sẽ giao cho bảo tàng. Nó được dùng làm **đáy tuyệt đối**:
> con số nào đạt ở đây thì đạt ở mọi cấu hình cao hơn.

---

## 1. Phần cứng

| | |
|---|---|
| SoC | MediaTek MT6761 (Helio A22) — 4× Cortex-A53 |
| GPU | PowerVR Rogue GE8300, OpenGL ES 3.2 (`build 1.15@6070602`) |
| **Vulkan** | **không có** — `ro.hardware.vulkan` rỗng, `pm list features` không khai |
| ABI | `armeabi-v7a,armeabi` — **32-bit, không có arm64** |
| RAM | 1.79 GB (`MemTotal 1.875.668 kB`) |
| Swap | ZRAM 1.37 GB |
| Android | 12, API 31 · **`ro.config.low_ram = true`** (hạng Go) |
| Trần Java heap | 128 MB (`dalvik.vm.heapgrowthlimit`), app **không** khai `largeHeap` |
| Màn hình | 720×1600, density 320 (override 235) |
| WebView | `com.google.android.webview` 150.0.7871.181 · **`Multiprocess enabled: true`** |

---

## 2. Hai mốc nền

Lấy mẫu bằng `dumpsys meminfo` mỗi 5 giây.

| | **A. Màn Menu**<br>BLE quét, chưa vào tour | **B. Đang tham quan**<br>xong 1 khu, FGS bật, đã phát thuyết minh |
|---|---|---|
| Thời lượng mẫu | 60 s (12 mẫu) | 90 s (18 mẫu) |
| **PSS trung bình** | **107.7 MB** | **129.1 MB** |
| PSS min / max | 107.1 / 108.5 | 126.9 / 130.1 |
| RSS | 188 MB | **208 MB** |
| **Graphics (EGL+GL)** | 42.6 MB | **48.6 MB** |
| Java heap (PSS) | 3.6 MB | 4.0 MB |
| Native heap (PSS) | 6.9 MB | 19.9 MB |
| Code | 21.6 MB | 25.5 MB |
| RAM hệ thống còn trống | 875 MB | **882–920 MB** |

**Giá của một chuyến tham quan thật: +21.4 MB PSS, +6.0 MB Graphics** so với màn nghỉ.

### Ổn định
`Graphics` đứng nguyên **49.717 KB** ở cả 18 mẫu — bộ đệm ảnh có trần và tôn trọng trần đó.
PSS dao động trong 3.2 MB suốt 90 giây. **Không có rò rỉ.**

### Trạng thái tiến trình
```
Proc # 0: fg  T/A/TOP  8162:com.example.beacon_client
oom: curRaw=0 setRaw=0 cur=0 set=0        ← mức bảo vệ cao nhất
ServiceRecord .../AudioService  isForeground=true
  channel=com.museum.beacon_client.audio  category=transport
BLE scanner: app_if 7, appName com.example.beacon_client   ← đang quét
```

### Nhiệt và pin (chưa có 3D)
| | |
|---|---|
| CPU / GPU hiện tại | 37.3 °C |
| CPU / GPU **đỉnh đã ghi** | **45.6 °C** |
| Vỏ máy (SKIN) | 35–38 °C |
| Trạng thái throttle | `mStatus=0` — **chưa throttle** |
| Pin | 24 %, 33.4 °C, đang xả |
| CPU của app lúc nghỉ giữa hai bài | 0.0 % |

---

## 3. Chỗ trống còn lại cho 3D

| Nguồn lực | Đang dùng | Còn |
|---|---|---|
| RAM hệ thống | — | **~880 MB** |
| Java heap (trần 128 MB) | 4.0 MB | **124 MB — dùng chưa tới 3 %** |
| Graphics | 48.6 MB | không có trần cứng, giới hạn bởi RAM chung |

**Ba điều số liệu này nói ra:**

1. **Chỗ trống rộng hơn dự đoán bi quan ban đầu.** 880 MB trống trên một máy 1.79 GB.
   Một tiến trình render WebView (~50–150 MB kèm texture) nằm lọt thoải mái.
2. **App ở `oom_adj = 0`.** Cộng TOP + foreground service, nó gần như là thứ *cuối cùng*
   Android nghĩ tới khi cần thu hồi bộ nhớ. Tiến trình render của WebView nằm ở mức
   `oom_adj` cao hơn hẳn ⇒ **nó chết trước, tour sống**. Đã xác nhận multiprocess đang bật.
3. **Java heap gần như chưa được đụng tới** — 4 MB trên trần 128 MB. Áp lực bộ nhớ của app
   này nằm ở `Graphics` và `Native`, không ở heap Dart/Java. Đúng chỗ 3D cũng sẽ đánh vào.

---

## 4. Rủi ro còn lại, xếp theo mức độ

| # | Rủi ro | Cơ sở | Cách kiểm |
|---|---|---|---|
| 1 | **Nhiệt khi chạy dài** | Đã ghi đỉnh **45.6 °C** khi *chưa có* 3D, trên máy tản nhiệt thụ động. Tải GPU kéo dài sẽ đẩy lên throttle, và throttle làm **cả app** chậm — cuộn, audio, không riêng 3D | Chạy 3D liên tục 30 phút, theo dõi `dumpsys thermalservice` tới khi `mStatus > 0` |
| 2 | **`flutter_scene` có khởi tạo nổi không** | Máy không có Vulkan; `flutter_scene` đi qua `flutter_gpu` (khác đường WebGL của Chromium), và 0.19.0 còn đòi kênh `master` | Câu hỏi tồn tại — trả lời trước, chưa cần đo hiệu năng |
| 3 | Hao pin | Pin còn 24 % lúc đo; chưa có số cho tải 3D | Đo %/30 phút, sạc trước khi thử |
| 4 | Tràn RAM | Đã hạ mức: 880 MB trống + `oom_adj=0` + WebView đa tiến trình | Vẫn theo dõi `lowmemorykiller` trong logcat |

---

## 5. Ghi chú về hai file `.glb` mẫu

Đo bằng `glb_report.py` (đọc thẳng chunk JSON của glTF).

| | `2CylinderEngine.glb` | `DamagedHelmet.glb` |
|---|---|---|
| Dung lượng đĩa | 1.75 MB | 3.60 MB |
| Tam giác vẽ | 121.496 *(lưới gốc 75.730 + instancing)* | 15.452 |
| Material | 34 | 1 |
| Node / mesh | 82 / 29 | 1 / 1 |
| Texture | không | 5 × 2048² JPEG |
| **VRAM texture (cận trên, RGBA8+mipmap)** | 0 MB | **106 MB** |
| Draco / KTX2 | không / không | không / không |

**Kết luận quan trọng nhất của cả hồ sơ:** dung lượng file **không** dự báo được chi phí
lúc chạy. `DamagedHelmet` chỉ 3.6 MB trên đĩa nhưng cận trên VRAM là 106 MB — khuếch đại
30 lần. Ngân sách nội dung phải ràng theo **tổng pixel texture**, không theo megabyte.

*(106 MB là cận trên lý thuyết. Trình duyệt trên chính máy này dựng được cùng model,
nên con số thực tế thấp hơn — driver nén texture và không phải lúc nào cũng giữ đủ mipmap.)*

---

## 6. Kết quả đo `model_viewer_plus` (18/08/2026)

Mẫu `DamagedHelmet.glb`, tự xoay bật (tải GPU liên tục), tour đang chạy với FGS +
BLE + audio. Lấy mẫu 20 giây/lần trong 4 phút.

### 6.1 Tải bị chia đôi giữa HAI tiến trình

Đây là điều bất ngờ nhất của cả phép đo, và nó lật một giả định đã dùng để chọn nghê:

| | Tiến trình app<br>`com.example.beacon_client` | Tiến trình render<br>`webview:sandboxed_process0` |
|---|---|---|
| PSS | **~415 MB** | ~176 MB |
| **Graphics (EGL/GL)** | **239 MB** | **0 MB** |
| Java heap | 9.4 MB | 0.9 MB |
| Native heap | 26.7 MB | 0.9 MB |
| Code | 42 MB | 21 MB |
| `oom_adj` | **0** | **0** |

**Texture KHÔNG nằm ở tiến trình render.** Toàn bộ 239 MB `Graphics` bị tính cho
**tiến trình app**, vì WebView vẽ vào một surface do app sở hữu. Chỉ heap và code của
Chromium (~176 MB, tức 30 % tổng chi phí) là thật sự nằm ngoài.

**Và tiến trình render KHÔNG ở mức ưu tiên thấp hơn.** Nó được bind như một service của
app (`BTOP`) nên **thừa hưởng `oom_adj = 0` của app** — bằng đúng app. LMK không có lý do
gì để chọn nó trước.

> ⚠ Hai điều trên **bác bỏ** luận cứ "WebView tràn RAM thì chết tiến trình render, app
> sống" đã dùng ở §4 khi đánh giá rủi ro. Cơ chế cô lập có tồn tại, nhưng nó chỉ che
> được 30 % chi phí và không mang theo ưu tiên thấp hơn. Ghi lại ở đây để lần sau không
> ai dựa vào một lợi thế lớn hơn thực tế.

### 6.2 Đối chiếu với mốc nền

| | Nền (tour chạy) | **Có 3D** | Chênh |
|---|---|---|---|
| App PSS | 129.1 MB | **415 MB** | **+286 MB** |
| Graphics | 48.6 MB | **239 MB** | **+191 MB** |
| Swap PSS của app | 0.24 MB | **41.8 MB** | **+41.6 MB** |
| Tiến trình render | — | 176 MB | +176 MB |
| **TỔNG hai tiến trình** | 129.1 MB | **~591 MB** | **+462 MB** |
| RAM hệ thống trống | ~900 MB | **648 MB** | −252 MB |
| CPU / GPU | 37.3 °C | **46.3 °C** | **+9 °C** |
| Vỏ máy (SKIN) | 35 °C | **40.0 °C** | +5 °C |

### 6.3 Ổn định — đạt

Suốt 4 phút: PSS app dao động trong **4 MB** (413–417), `Graphics` đứng ở 239 MB,
RAM hệ thống trống giữ 641–658 MB. **Không một lần LMK/OOM kill nào.** Nhịp tim của
keep-alive vẫn `live=1` — **chuyến tham quan sống nguyên vẹn.** Chưa throttle (`mStatus=0`).

### 6.4 Thời gian tới khung hình đầu — **TRƯỢT**

```
[0ms]     bấm nạp — bắt đầu dựng widget
[717ms]   WebView đã tạo (Chromium khởi động)
[3810ms]  model-viewer: load — khung hình đầu
```

**3.81 giây**, ngưỡng đặt ra ≤ 1.5 s ⇒ **vượt 2.5 lần**.

Đây là kết quả rõ ràng nhất của cả buổi đo, và nó **xác nhận kiến trúc đã chốt**: 3.8 giây
là chính xác lý do không được đặt bộ dựng 3D vào lúc mở màn. Turntable hiện tức thì; 3D thật
nằm sau một cú chạm, nơi 3.8 giây kèm dấu hiệu đang tải là chấp nhận được.

### 6.5 Chất lượng hình — đạt, và cao

PBR đầy đủ, phản chiếu trên kính mũ, đổ bóng đúng. Ở mức này thì hình xứng với một hiện vật
bảo tàng. Đây là thứ mà GE8300 **không** dựng nổi bằng bất cứ đường nào khác.

### 6.6 Kết luận tạm

`model_viewer_plus` **chạy được trên máy tệ nhất trong tay**, ổn định, không giết tour.
Cái giá là **+462 MB (26 % RAM toàn hệ thống) cho một model 3.6 MB**, cộng ZRAM bắt đầu
nén, cộng 3.81 giây chờ.

### 6.7 Phép thử chạy dài — **ĐẠT**

Nạp lúc 01:08, đo lại lúc 01:47: **~38 phút tự xoay không nghỉ**, tour chạy suốt.

| | 4 phút | **38 phút** | Trôi |
|---|---|---|---|
| App PSS | 413–417 MB | 412.6–419.3 MB | **≈ 0** |
| Graphics | 239.2–239.9 MB | 240.7–241.5 MB | **+1.5 MB / 34 phút** |
| Tiến trình render | 167–180 MB | 179.5–180.2 MB | ổn định |
| **TỔNG** | ~591 MB | **~593 MB** | **+2 MB** |
| RAM hệ thống trống | 641–658 MB | 628–656 MB | ổn định |
| CPU / GPU | 45.6–46.7 °C | 46.2–47.4 °C | **+0.7 °C** |
| Vỏ máy (SKIN) | 40.0 °C | **41.0 °C** | **+1.0 °C** |
| **`Thermal Status`** | 0 | **0** | **KHÔNG throttle** |
| LMK / OOM kill | 0 | **0** | — |

**Nhiệt đã tìm được điểm cân bằng, không phải đang leo.** +0.7 °C ở lõi và +1.0 °C ở vỏ
qua 34 phút là đường nằm ngang, không phải đường dốc. Nỗi lo ở §4 rủi ro #1 — *"throttle
làm cả app chậm"* — **không xảy ra trên máy này**, kể cả ở chế độ nặng nhất (tự xoay liên tục).

**Chuyến tham quan sống nguyên vẹn suốt 38 phút:**
```
[Heartbeat] 2026-08-18T01:47:33 live=1
BLE scanner: app_if 7, com.example.beacon_client        ← vẫn quét
FGS: tour_keep_alive     isForeground=true
FGS: ...audio            isForeground=true              ← cả hai còn sống
```

**Pin:** 83 % → 76 % trong 38 phút (≈ 11 %/giờ), máy KHÔNG cắm sạc. ⚠ Con số này
**chưa quy được cho 3D**: không có mốc hao pin nền để trừ ra. Muốn dùng nó thì phải đo
một phiên tour cùng thời lượng mà không bật 3D.

### 6.8 Kết luận M0 cho `model_viewer_plus`

| Tiêu chí | Ngưỡng | Đo được | |
|---|---|---|---|
| FGS + BLE sống sót | bắt buộc | 38 phút, cả hai FGS còn sống | **ĐẠT** |
| LMK / OOM kill | 0 | 0 | **ĐẠT** |
| Không rò rỉ | PSS phẳng | +2 MB / 34 phút | **ĐẠT** |
| Không throttle nhiệt | `mStatus = 0` | 0 sau 38 phút | **ĐẠT** |
| Chất lượng hình | xứng hiện vật | PBR đầy đủ, phản chiếu đúng | **ĐẠT** |
| ΔPSS | ≤ +120 MB | **+462 MB** | **TRƯỢT** |
| Thời gian tới khung hình đầu | ≤ 1.5 s | **3.81 s** | **TRƯỢT** |

**`model_viewer_plus` chạy được trên máy tệ nhất trong tay** — ổn định, không giết tour,
không nóng tới mức throttle, hình đẹp. Hai chỗ trượt đều là chỗ **kiến trúc đã chốt đã
xử lý sẵn**: 462 MB và 3.81 giây là chi phí của một *route mở theo cú chạm*, không phải
chi phí thường trực của màn 04c. Cả hai con số sẽ tốt hơn trên máy giao thật (máy này
không có Vulkan, 32-bit, 1.79 GB).

### 6.9 Lần nạp thứ hai rẻ hơn hẳn

Nhả rồi nạp lại, tiến trình render **vẫn là PID 27750** — nó sống sót qua lần nhả, nên
Chromium không phải khởi động lại:

| | Nạp lần 1 | **Nạp lần 2** |
|---|---|---|
| Dựng WebView | 717 ms | **85 ms** |
| Tới khung hình đầu | 3810 ms | **2585 ms** |

Con số đưa vào thiết kế là **2.6 s**, không phải 3.8 s: chỉ hiện vật đầu tiên trong buổi
phải trả giá khởi động.

### 6.10 Bộ nhớ KHÔNG được trả lại sau khi nhả — **TRƯỢT**

Nhả khối 3D khỏi cây widget, đo 5 mẫu trong 2.5 phút:

| | Nền (tour) | Đỉnh có 3D | **Sau khi NHẢ** | Trả lại được |
|---|---|---|---|---|
| App PSS | 129.1 MB | 415 MB | **347 MB** | 24 % |
| **Graphics** | 48.6 MB | 241–251 MB | **217.7 MB** | **17 %** |
| Swap PSS app | 0.24 MB | 52.8 MB | 46.8 MB | 12 % |
| Tiến trình render | — | 176 MB | **143 MB (CÒN SỐNG)** | 19 % |
| **TỔNG** | **129.1 MB** | 593 MB | **490 MB** | **22 %** |

`Graphics` đứng ở **đúng 217.683 KB** ở cả 5 mẫu — không nhúc nhích một byte suốt 2.5 phút.
Đó không phải bộ nhớ đang trên đường trả về; đó là bộ nhớ **bị giữ**.

**Nhả widget chỉ thu hồi được 22 %. Còn lại 361 MB trên mốc nền, giữ vô thời hạn.**

Hai nguyên nhân có thể, và chúng dẫn tới hai kết luận rất khác nhau:
1. **Chromium cố ý giữ tiến trình render ấm** để lần mở sau nhanh (đúng như §6.9 cho thấy).
   Đây là thiết kế, không phải lỗi — nhưng về mặt tài nguyên thì vẫn là bộ nhớ không đòi lại được.
2. **Surface GPU của platform view không được giải phóng** khi widget bị huỷ.

⚠ **CHƯA đủ cơ sở gọi đây là rò rỉ.** Rò rỉ thì tăng vô hạn; cái này có thể chạm trần rồi
đứng. Phép thử phân biệt hai khả năng nằm ở §7.

### 6.11 Đổi mẫu — bộ nhớ **KHÔNG cộng dồn**

Sau khi app tự khởi động lại (PID mới, tour tắt ⇒ mốc so sánh là 107.7 MB / 42.6 MB):

| | Nền<br>(không tour) | Vòng 1 nhả<br>`DamagedHelmet` | **Vòng 2 nhả<br>`2CylinderEngine`** |
|---|---|---|---|
| App PSS | 107.7 MB | 381.9 MB | **278.7 MB** |
| **Graphics** | 42.6 MB | 214.8 MB | **108.4 MB** |
| Tiến trình render | — | 150.4 MB | **74.9 MB** |
| **TỔNG** | 107.7 MB | 532 MB | **353.6 MB** |
| RAM hệ thống trống | ~900 MB | 710 MB | **884.6 MB** |

**`Graphics` TỤT từ 214.8 xuống 108.4 MB.** Không cộng dồn — nó **đi theo model đang nạp**,
và nhả ra khi model sau nhẹ hơn. `2CylinderEngine` không có một texture nào, và con số phản
ánh đúng điều đó. RAM hệ thống trống hồi từ 710 lên 884.6 MB.

⇒ **Đây là "thu hồi chậm", KHÔNG phải rò rỉ.** Trần được đặt bởi model NẶNG NHẤT từng nạp,
không phải bởi số lần nạp. Một tour 9 hiện vật không cộng 9 lớp.

Phần dư ~66 MB `Graphics` trên mốc nền ngay cả với model 0 texture là chi phí cố định của
surface platform view + GPU của Chromium.

---

## 7. KẾT LUẬN M0

### 7.1 Phán quyết — ⚠ ĐÃ SỬA 18/08/2026, xem §7.1b

> **CẢNH BÁO: đoạn dưới đây SAI và được giữ lại có chủ ý** để không ai suy luận
> lại từ đầu rồi mắc đúng lỗi ấy. Bản sửa ở §7.1b.

~~Mọi rủi ro đo được đều truy về **một nguyên nhân duy nhất**: `DamagedHelmet.glb` mang
21.0 Mpx texture, gấp 3.5 lần trần. Model đúng ngân sách sẽ ở một hạng khác hẳn.
Ngân sách là thứ giữ cho máy sống.~~

Bằng chứng làm tôi kết luận như vậy vẫn đúng và vẫn đáng ghi:
```
04:45:32 lowmemorykiller: Kill 'com.android.vending' (31911), oom_score_adj 945
         to free 116288kB rss, 125836kB swap;
         reason: min watermark is breached even after kill
```
Hệ thống **giết Play Store** để nuôi app này, và giết xong **vẫn chưa đủ**. App sống sót nhờ
`oom_adj = 0` — tức nó sống bằng cách để hệ thống giết thứ khác.

### 7.1b Phán quyết đã sửa

Ba phép đo sau đó bác bỏ mệnh đề "ngân sách texture là nguyên nhân":

| Model | Texture | `Graphics` đo được |
|---|---|---|
| `2CylinderEngine` | **0 Mpx** | 108 MB *(sau khi nhả)* |
| `mercedes` | **5.1 Mpx** | **224.7 MB** |
| `tuong phat` | 16.8 Mpx | 234.7 MB |
| `DamagedHelmet` | **21.0 Mpx** | 239–251 MB |

Lượng texture chênh nhau **4 lần**, `Graphics` chênh **11 %**. Và phép đối chứng bằng Chrome
trên chính máy đó (§9) đóng lại câu hỏi:

> **~200 MB là giá CỐ ĐỊNH của Chromium.** Không đến từ model, không đi khi model đi, và
> **ngân sách nội dung không chạm được vào nó.**

Ngân sách vẫn thật và vẫn bắt buộc — nhưng ở **trục khác**:

| Trục | Cái gì chi phối | Ngân sách giúp? |
|---|---|---|
| Bộ nhớ (~600 MB) | Chi phí cố định của Chromium | **Gần như không** |
| Thời gian nạp (3.8 → **13.6 s**) | Hình học, material, extension | **Rất nhiều** |
| Khung hình / nhiệt | Hình học, `KHR_materials_transmission` | **Rất nhiều** |

`mercedes` chứng minh vế phải: **nhẹ nhất về texture** nhưng **chậm nhất 3.5 lần**
(13.6 s tới khung hình đầu) và **nóng nhất** (49.6 °C) — 337k tam giác, 115 lần gọi vẽ,
31 material, cộng `transmission` để dựng kính xe.

### 7.2 Bảng chấm cuối

| Tiêu chí | Ngưỡng | Đo được | |
|---|---|---|---|
| FGS + BLE sống sót | bắt buộc | 38 phút, cả hai FGS còn sống | **ĐẠT** |
| Không throttle nhiệt | `mStatus = 0` | 0 sau 38 phút, nhiệt cân bằng | **ĐẠT** |
| Không rò rỉ tích luỹ | không cộng dồn | Graphics tụt 215 → 108 MB khi đổi mẫu | **ĐẠT** |
| Chất lượng hình | xứng hiện vật | PBR đầy đủ | **ĐẠT** |
| Khung hình đầu (lần 2+) | ≤ 1.5 s | 2.59 s | **TRƯỢT nhẹ** |
| Khung hình đầu (lần 1) | ≤ 1.5 s | 3.81 s | **TRƯỢT** |
| ΔPSS | ≤ +120 MB | +462 MB *(model vượt ngân sách 3.5×)* | **TRƯỢT** |
| Không ép hệ thống giết app khác | 0 | **LMK giết Play Store** | **TRƯỢT** |
| Thu hồi khi nhả | về gần nền | chỉ 22 % tức thời, phần còn lại thu hồi chậm | **CÓ ĐIỀU KIỆN** |

### 7.3 Ràng buộc kiến trúc rút ra từ số đo

1. **3D KHÔNG được nạp lúc mở màn.** 3.81 s lần đầu / 2.59 s lần sau. Lớp turntable giữ
   nguyên vai trò lớp mặt — quyết định này giờ có số liệu chống lưng, không còn là phòng xa.
2. **Chỉ MỘT khối 3D sống tại một thời điểm, toàn tiến trình.** Trần đặt bởi model nặng nhất;
   hai khối cùng lúc là hai trần cộng lại.
3. **Ngân sách nội dung phải chặn ở packer**, không phải nhắc trong tài liệu. Đây là kết luận
   đắt nhất của M0.
4. **Giữ tiến trình render ấm là có lợi** — 717 ms → 85 ms. Đừng cố giết nó.
5. **Phải nghe `didHaveMemoryPressure()`** và huỷ scene ngay, rơi về turntable. Log LMK cho
   thấy hệ thống có báo động thật, và ta đang không nghe.

### 7.4 Việc còn thiếu

- Đo lại **toàn bộ** với một model ĐÚNG ngân sách (≤ 6 Mpx, KTX2, Draco). Mọi con số ở §6
  là số của một model vượt trần 3.5 lần và phải được đọc như vậy.
- Trả lời câu hỏi tồn tại của `flutter_scene` trên máy không Vulkan.
- Đo hao pin có mốc nền để trừ.

---

## 8. `flutter_scene` — loại bằng thực nghiệm (18/08/2026)

Ứng viên thứ hai, và là ứng viên hứa hẹn nhất về lý thuyết: chạy qua `flutter_gpu`, **không
mang Chromium**, nên về nguyên tắc không phải trả khoản 200 MB ở §7.1b.

### 8.1 Đường tới lỗi — trước khi chết, nó chạy tốt

```
[0ms]     nạp tuong phat qua flutter_scene
[32ms]    tài nguyên engine sẵn sàng — CÓ ngữ cảnh Flutter GPU
          MSAA is not currently supported on this backend
[83ms]    đọc 5.00 MB từ kho
          Unpacking glTF (nodes: 1, meshes: 1, materials: 1, skins: 0)
[1955ms]  phân tích glTF xong
[1956ms]  cảnh sẵn sàng
```

| | `model_viewer_plus` | `flutter_scene` |
|---|---|---|
| Khởi tạo | 717 ms | **32 ms** |
| Phân tích model | — | **1.96 s** |

**`flutter_gpu` KHỞI TẠO ĐƯỢC trên máy không Vulkan.** Câu hỏi tồn tại treo suốt spike đã có
đáp án, và đáp án là "được" — Impeller lùi về backend OpenGL ES đúng như tài liệu nói.

### 8.2 Nó chết ở khung hình đầu

```
ERROR impeller/renderer/backend/gles/buffer_bindings_gles.cc(409):
      Float uniform should have a float type
IMGSRV: ScheduleTA: Skipping render from different gc/thread!
FATAL impeller/renderer/backend/gles/render_pass_gles.cc(726):
      Check failed: result. Must be able to encode GL commands without error.
Fatal signal 6 (SIGABRT) in tid 18206 (1.raster), pid 10190
```

Backend **OpenGL ES** của Impeller gặp uniform sai kiểu trong shader của `flutter_scene`,
không mã hoá nổi lệnh GL, và engine `CHECK` fail. App biến mất hoàn toàn — không còn tiến
trình nào để đo, `MemAvailable` bật lên 1.018 MB vì mọi thứ đã chết.

### 8.3 Đây mới là khác biệt quyết định

| | Khi gặp sự cố |
|---|---|
| `model_viewer_plus` | Hệ điều hành giết **tiến trình khác** (Play Store, Play Services). Tour sống — đã chứng minh qua 38 phút và nhiều vòng nạp/nhả |
| `flutter_scene` | **SIGABRT, giết cả tiến trình.** Foreground service, BLE, audio, tour — mất sạch trong một tín hiệu |

`flutter_scene` chạy trong **chính tiến trình app**, nên hỏng là kéo tour theo. Nó còn không
cần tới OOM: một assertion của engine là đủ.

### 8.4 ⚠ KHÔNG phải kết luận vĩnh viễn

Lỗi nằm ở backend **GLES** — đường ít được `flutter_scene` kiểm thử nhất, và máy này buộc
phải đi đường đó vì **không có Vulkan**.

| Máy giao | 3D khả thi |
|---|---|
| **Không Vulkan** (máy đang có) | Chỉ `model_viewer_plus` — ~200 MB Chromium, không giảm được bằng ngân sách, không trả lại khi nhả |
| **Có Vulkan, ≥ 4 GB** | `flutter_scene` mở lại — đã cho thấy khởi tạo nhanh **22×**, phân tích nhanh **2×** |

Đây là con số dùng để đàm phán cấu hình máy với khách: *"máy có Vulkan hay không quyết định
app tốn 200 MB hay không"*.

### 8.5 Chi phí vận hành của `flutter_scene` (ghi lại phòng khi quay lại)

| Chi phí | |
|---|---|
| `flutter config --enable-native-assets` | mọi máy dev + mọi máy CI |
| Metadata `EnableFlutterGPU` trong manifest | cờ `flutter run --enable-flutter-gpu` KHÔNG tới được embedding Android; phải scope theo buildType nếu ship |
| Ràng buộc phiên bản không tin được | 0.18–0.20 khai `>=3.44.0` nhưng dùng ký hiệu `flutter_gpu` mà 3.44.4 không có |
| `flutter analyze` XANH khi biên dịch HỎNG | analyzer và CFE giải `flutter_gpu` khác nhau ⇒ **phải build thật mới biết** |
| `flutter_gpu` phá biên dịch widget test | `Type 'gpu.VertexFormat' not found` làm đỏ mọi widget test; đã cách ly bằng `lib/main_spike.dart` + `AppRouter.extraRoutes` |
| Chỉ 0.15.0 khớp SDK 3.44.4 | bản cũ 3 tháng, không có `SceneView` / `PerspectiveCamera.framing` |

Không khoản nào trong sáu khoản này xuất hiện với `model_viewer_plus`.

---

## 9. Đối chứng: cùng model, cùng thư viện, mở bằng Chrome

Câu hỏi: ~200 MB kia là giá của **Chromium**, hay của cách **Flutter nhúng WebView**?

Trang `serve/model-test.html` phục vụ đúng file `.glb` (cùng sha256 từ `models.json`) với
đúng `model-viewer.min.js` mà `model_viewer_plus 1.10.0` nhúng. Chỉ khác vật chủ.

Chrome tách **5 tiến trình**, cộng hết:

| Tiến trình | PSS | Graphics |
|---|---|---|
| `com.android.chrome` (browser) | 151.7 MB | 34.2 MB |
| `chrome_zygote` | 5.8 MB | — |
| `sandboxed_process0` (render 1) | 45.8 MB | — |
| **`privileged_process0` (GPU)** | **223.4 MB** | **163.4 MB** |
| `sandboxed_process0` (render 2) | 135.2 MB | — |
| **TỔNG** | **558.4 MB** | **196.8 MB** |

| | Chrome (không tour) | App (WebView, **có tour**) |
|---|---|---|
| Tổng PSS | 558.4 MB | 584.0 MB |
| **Graphics** | **196.8 MB** | **219.4 MB** |

**Chênh 11 %**, và app còn cõng thêm cả một chuyến tham quan. ⇒ **Giá của Chromium.**

Chi tiết giải luôn chỗ §6.1 đọc nhầm: trong Chrome, `Graphics` nằm ở **tiến trình GPU riêng**
(163 MB). App không có tiến trình GPU riêng nên cùng khoản đó rơi vào tiến trình app. Cùng
một cái giá, **chỉ khác chỗ ghi sổ** — không phải một đặc tính xấu của Flutter.

### 9.1 Ghi chú về nhiễu trong số liệu nhiệt

Người đo có **chủ động xoay bằng tay** ở nhiều lần đo. Ảnh hưởng:

| Loại số đo | Bị ảnh hưởng? |
|---|---|
| PSS / Graphics / swap | **Không** — texture và hình học cấp phát lúc NẠP; xoay chỉ vẽ lại |
| Thời gian tới khung hình đầu | **Không** — đo xong trước mọi thao tác |
| Nhiệt / CPU / pin | **Có** |

Vế thứ ba lệch về phía **an toàn**: phép thử 38 phút đã bật tự xoay và thao tác tay chồng
lên trên, tức tải thực tế **cao hơn** cái ghi được, mà vẫn `Thermal Status: 0`. Chỉ đừng
đọc quá kỹ chênh lệch nhiệt **giữa các model** (46.3 vs 49.6 °C) — trong đó có nhiễu.

---

## 10. Bước kế

| # | Việc | Vì sao bây giờ |
|---|---|---|
| 1 | **Dựng một `.glb` ĐÚNG ngân sách** (≤ 6 Mpx, KTX2, Draco) rồi đo lại toàn bộ §6 | Mọi con số hiện có là số của một model vượt trần 3.5×. Không có phép đo này thì không kết luận được gì về cấu hình sẽ giao |
| 2 | Trả lời câu hỏi tồn tại của `flutter_scene` trên máy không Vulkan | Rẻ, và nếu nó chạy thì bỏ được toàn bộ khối Chromium |
| 3 | Đo hao pin **có mốc nền để trừ** | Con số 11 %/giờ hiện chưa quy được cho 3D |
| 4 | M1 — schema `exhibit.model` + nới `_pathRule` + kiểm ổ trống | Không phụ thuộc kết quả trên |
| 5 | M2 — `validate_models.py` ở server | Kết luận đắt nhất của M0: ngân sách phải được ÉP, không phải nhắc |

**Công cụ đã dựng** (đang ở scratchpad, soạn lại vào repo server ở M2):

| Script | Việc |
|---|---|
| `glb_report.py` | Bóc `.glb` ra tam giác / material / texture / VRAM ước tính + đối chiếu ngân sách. Không cần thư viện ngoài — đội CMS chạy được ngay |
| `sample_mem.sh` | Lấy mẫu PSS/RSS/Graphics của một tiến trình |
| `sample_3d.sh` | Lấy mẫu **cả hai** tiến trình + nhiệt + LMK. Bắt buộc phải hai, vì tải chia đôi (xem §6.1) |
