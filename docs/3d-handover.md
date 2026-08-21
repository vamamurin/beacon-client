# Mô hình 3D hiện vật — bàn giao

**Nhánh:** `epic/exhibit-3d-models` · **Ngày:** 21/08/2026
**Đọc kèm:** [`M0-baseline.md`](M0-baseline.md) — mọi con số trong tài liệu này lấy từ đó.

---

## 1. Ba lớp, và vì sao phải là ba

Khách mở màn chi tiết hiện vật (04c) và thấy hiện vật **tự xoay ngay** — đúng như
bản vẽ đòi. Nhưng thứ đang xoay lúc đó **không phải** bộ dựng 3D.

| Lớp | Khi nào | Cái gì chạy | Giá |
|---|---|---|---|
| 1. Poster | ngay khi màn dựng | ảnh tĩnh trong bundle | ≈ một tấm ảnh |
| 2. Turntable | vài giây sau | 24 khung WebP, tự xoay 30°/s, kéo ngang điều khiển | ~0.8 MB · ~10 MB RAM |
| 3. 3D thật | **chỉ khi chạm** | `<model-viewer>` toàn màn hình | **~200 MB** · 2.6–13.6 s |

Cả ba render từ **cùng một `.glb`**, nên chuyển lớp không có cú nhảy thị giác.

**Vì sao không đặt lớp 3 lên thẳng khung đầu như bản vẽ ngụ ý:** đo trên máy thực
địa cho thấy nó cần 3.81 s tới khung hình đầu (2.59 s những lần sau) và **+462 MB**
trên hai tiến trình. Phép đối chứng — mở đúng file đó bằng Chrome trên chính máy ấy —
cho **558 MB / 196.8 MB Graphics**, chênh app đúng 11 %. Kết luận:

> **~200 MB là giá CỐ ĐỊNH của Chromium.** Không đến từ model, không giảm được
> bằng ngân sách nội dung, và không trả lại hết khi đóng.

Nên cái giá ấy chỉ được phép tồn tại khi khách **chủ động yêu cầu**, trong một
route đóng được.

## 2. Vì sao `model_viewer_plus` chứ không `flutter_scene`

`flutter_scene` hứa hẹn hơn trên giấy — chạy qua Impeller, không mang Chromium.
Trên máy thực địa nó **khởi tạo được** (32 ms) và phân tích glTF **nhanh gấp đôi**
(1.96 s). Rồi ở khung hình đầu, backend OpenGL ES của Impeller gặp uniform sai kiểu
và engine `CHECK` fail → **`SIGABRT`**, giết cả tiến trình cùng foreground service,
BLE và audio.

Đó là khác biệt quyết định:

| | Khi gặp sự cố |
|---|---|
| `model_viewer_plus` | OS giết **tiến trình khác**; tour sống (đã chứng minh 38 phút) |
| `flutter_scene` | **giết cả tiến trình** — tour chết theo |

⚠ **Không phải kết luận vĩnh viễn.** Lỗi ở đường GLES, và máy thử **không có
Vulkan**. Máy có Vulkan thì `flutter_scene` mở lại được và bỏ được 200 MB kia.
Nếu cấu hình máy giao đổi, **đo lại trước khi coi lựa chọn này là đã xong**.

## 3. Dữ liệu đi từ máy chủ về máy

```
bundle (tar.gz, thay NGUYÊN KHỐI)        manifest + ảnh + audio + poster + thumb
  └─ exhibit.media[0] = {type:"model", id, poster, thumb}   ← chỉ một KHOÁ

model pack (TỪNG FILE, sha256)           models/<sha>.glb
                                         turntable/<id>/000..023.webp
```

Hai đường riêng vì bundle tải nguyên khối: nhét `.glb` vào thì sửa một dấu phẩy
trong manifest là bắt cả đội máy tải lại hàng trăm MB.

Model **tải lúc cần** (khách mở hiện vật), không tải lúc đồng bộ. Trên máy, dải ảnh
lưu theo **băm của model** — model cập nhật thì dải ảnh cũ tự hết hiệu lực.

## 4. Schema `media[]`

```jsonc
"media": [
  { "type": "model", "id": "tuong-phat",
    "poster": "images/…/model-poster.webp", "thumb": "images/…/model-thumb.webp" },
  { "type": "image", "file": "images/…/main.jpg", "thumb": "images/…/thumb.jpg" }
]
```

**Thứ tự là ngữ nghĩa, không phải sở thích:**

| | |
|---|---|
| `media[0]` | sân khấu màn 04c |
| `media[1..]` | lưới tư liệu ở đáy |

Mô hình **bắt buộc ở `media[0]`**. Vuốt ngang trên mô hình là *xoay* nó, nên cuộn
phim không lật trang được — một mô hình ở giữa dải là một trang không ai tới được.
`pack_models.py` từ chối bundle vi phạm.

`type: "video"` **đã có chỗ nhưng chưa dựng**. Parser bỏ nó kèm warning thay vì im
lặng, để CMS thấy ngay app chưa đọc được. Thêm video là thêm một nhánh của
`ExhibitMedia`, **không phải sửa schema lần nữa**.

## 5. Ngân sách nội dung — chốt chặn nằm ở máy chủ

**Bài học đắt nhất:** dung lượng file **không** dự báo được chi phí lúc chạy.
`DamagedHelmet.glb` nặng 3.6 MB trên đĩa và **106 MB VRAM** — khuếch đại 30 lần.

Nên trần đặt ở **VRAM ≤ 10 MB**, không ở megabyte. KTX2 là *khuyến nghị* (nó mua
thêm chất lượng ở cùng ngân sách), không phải điều kiện — hạ texture xuống 512²
đạt đích mà không cần cài `toktx`.

| Chỉ tiêu | Trần |
|---|---|
| **VRAM** | **≤ 10 MB** ← cổng chính |
| Gọi vẽ | ≤ 50 |
| Material | ≤ 8 |
| Tam giác | ≤ 150.000 (tính cả instancing) |
| Dung lượng `.glb` | ≤ 8 MB (chỉ ràng buộc tải/đĩa) |

`pack_models.py` **từ chối xuất bản** model vượt trần. Không bộ dựng nào chữa được
một model quá nặng — chốt chặn phải ở nơi còn từ chối được, không phải trong một
trang tài liệu mà nhà thầu 3D có thể không đọc.

## 6. Quy trình máy chủ

```bash
./server.sh                 # đóng gói còn thiếu rồi phục vụ (dùng hằng ngày)
./server.sh --models        # + tối ưu .glb, dựng dải ảnh còn thiếu
./server.sh --stills        # trích ảnh tĩnh của mô hình vào bundle
./server.sh --repack        # đóng gói lại cùng version (hiếm khi cần)
```

**Cần:** `node`, `google-chrome-stable`, `magick`, `npx`, `ffmpeg`. **Không cần Blender** —
dải ảnh được render bằng chính `<model-viewer>`, nên lớp giữ chỗ và lớp 3D thật
khớp nhau *theo cấu tạo* chứ không theo công sức chỉnh màu.

⚠ **Đổi nội dung thì phải bump `bundleVersion`.** Client so version bằng **chuỗi**;
không bump thì mọi máy trả `upToDate` và không bao giờ thấy bản mới.

## 7. Cái đã đo, và cái chưa

**Đã đo trên máy thực địa** (Xiaomi Helio A22, 1.79 GB, không Vulkan, 32-bit, Android Go):
38 phút tự xoay liên tục — không LMK kill, không throttle, tour sống, PSS phẳng.

**CHƯA đo:**
- Toàn bộ số liệu §6 của `M0-baseline.md` lấy từ model **vượt trần 3.5 lần**. Chưa
  đo lại đầy đủ với model đúng ngân sách.
- Hao pin **chưa có mốc nền để trừ** — con số 11 %/giờ chưa quy được cho 3D.
- Chưa thử trên máy **có Vulkan**.

---

## 8. ⚠ VIỆC CHƯA LÀM — đội nhận phải biết

| # | Việc | Hậu quả nếu bỏ qua |
|---|---|---|
| 1 | **`museum_server` không phải git repo** | Không lịch sử, không lần được thay đổi, không rollback |
| 2 | **Thư mục bàn giao chưa dọn** — `src_backup/`, `src_backup2/`, `src_backup_3/`, `src.zip`, `src2.zip`, `manifest.json.bak`→`.bak7`, `pwned.tar.gz`, `serve_bundle.py.bak` | Đội nhận không biết đâu là bản thật |
| 3 | **`ModelStore.sweep()` viết rồi nhưng CHƯA AI GỌI** | Model tích lại vĩnh viễn. Tên file là băm nội dung ⇒ model cập nhật là file MỚI, không ghi đè. Sau vài đợt phát hành, máy đầy ổ mà không rõ vì sao. Chỗ gọi đúng: sau mỗi lần đồng bộ thành công, `keep` = tập băm mà manifest hiện tại còn trỏ tới |
| 4 | **`content-bundle-spec.md` chưa viết** | CMS chưa có tài liệu schema chính thức |
| 5 | **`applicationId` vẫn là `com.example.beacon_client`** | Google Play từ chối; đổi sau khi triển khai sẽ mất chữ ký, mất dữ liệu app, hỏng MDM |
| 6 | **`migrate_manifest_media.py` nên xoá** | Là công cụ di trú chạy một lần, không phải công cụ vận hành |
| 7 | **Con Mercedes chưa dùng được** | 269k tam giác / 30 material / 26 MB VRAM sau tối ưu. Gộp material cần người dựng 3D, không tự động được |
| 8 | **Spike còn trong mã** — `model_lab_screen.dart`, `main_spike.dart`, khối loopback trong `network_security_config.xml` | Xoá cùng nhau nếu không còn đo nữa. `AppRouter.extraRoutes` và `ModelStore` thì **giữ** — chúng là hạ tầng thật |

## 9. Công cụ để lại

| File | Việc |
|---|---|
| `docs/glb_report.py` | Bóc `.glb` ra tam giác/material/texture/VRAM. Không cần thư viện ngoài |
| `docs/sample_mem.sh` | Lấy mẫu PSS/RSS/Graphics một tiến trình |
| `docs/sample_3d.sh` | Lấy mẫu **cả hai** tiến trình + nhiệt + LMK — bắt buộc hai, vì tải chia đôi |
| `serve/model-test.html` | Đối chứng: mở cùng model bằng Chrome trên máy thật |

---

## 10. Một luật mà hai repo phải cùng tuân

`model.id` chịu regex `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`, khai ở **hai** nơi:

- `ManifestParser._modelIdRule` (ứng dụng)
- `MODEL_ID_RULE` trong `pack_models.py` (máy chủ)

Sửa một bên thì phải sửa bên kia. Đã gặp thật: máy chủ xuất bản id có dấu cách,
manifest trỏ đúng id ấy, đối chiếu báo khớp — và **ứng dụng lặng lẽ bỏ cả khối
model**. Khách đứng trước hiện vật, không có gì xảy ra, không ai biết vì sao.

Đây là chỗ **duy nhất** trong toàn bộ quy trình mà hai repo phải đồng ý với nhau.
