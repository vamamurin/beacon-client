# Luồng chuyến tham quan: từ màn nghỉ đến màn cảm ơn

Tài liệu này mô tả **thứ tự gọi giữa các file** cho luồng menu → tour → tổng kết
→ cảm ơn. Nó không lặp lại phần lý do — lý do nằm trong doc đầu mỗi file, và đó
mới là nguồn sự thật. Ở đây chỉ trả lời một câu: *thứ gì gọi thứ gì, theo thứ tự
nào.*

Đọc kèm: `session_controller.dart` (máy trạng thái), `app.dart`
(ánh xạ phase → route), `summary_screen.dart` (vì sao màn tổng kết nằm trong
phiên).

---

## Nguyên tắc chi phối cả luồng

**Màn hình không tự dựng lại ngăn xếp. Chúng phát biểu ý định; phiên đổi trạng
thái; root điều hướng.**

```
 màn hình ──intent──► SessionProvider ──► SessionController
                                               │
                                        SessionState mới
                                               │
        MuseumApp.build (watch) ──► _syncNavigation ──► tourNavigationTarget
                                               │
                                    pushNamedAndRemoveUntil
```

Ngoại lệ duy nhất là điều hướng TIẾN trong cùng một phiên (Menu → Gate, Zone →
danh sách hiện vật, mở màn tổng kết). Những cái đó là `pushNamed` bình thường vì
chúng không đụng tới vòng đời phiên.

Hệ quả để nhớ khi sửa: **`tourNavigationTarget` chỉ được nhận `prev` và `next`.**
Thêm được tham số thứ ba vào đó nghĩa là bộ định tuyến vừa mọc thành một máy
trạng thái thứ hai chạy song song với `SessionController`.

---

## 1. Khởi động

| Thứ tự | File | Việc |
|---|---|---|
| 1 | `main.dart` | `Injection.build()` → `AppGraph` |
| 2 | `main.dart` | dựng MultiProvider, bọc `MuseumApp` |
| 3 | `app_router.dart` | `initialRoute = restRoute = menuRoute` |

`AppRouter.restRoute` là tên của VAI TRÒ "màn nghỉ", không phải một alias cho
gọn. Khi màn poster ra đời và đứng trước Menu, đó là dòng duy nhất phải sửa.

Trách nhiệm đi theo vai trò đó: màn nghỉ phải mang các thẻ trạng thái dành cho
nhân viên (`deviceNotReadyCard()` trong `gate_screen.dart`, dùng chung với Gate),
vì nó là thứ nhân viên nhìn khi nhấc máy khỏi dock.

## 2. Bắt đầu tour

| Thứ tự | File | Việc |
|---|---|---|
| 1 | `menu_screen.dart` | `_onSelect(startTour)` → `pushNamed('/gate')` |
| 2 | `gate_screen.dart` | `_StartButton.onPressed` → `SessionProvider.startTour()` |
| 3 | `session_controller.dart` | `userStartedTour()` → dọn trí nhớ audio → phase `touring` |
| 4 | `app.dart` | `_syncNavigation(touring)` → `/zone`, xoá sạch stack |

Bước 3 là chỗ **dọn trí nhớ của tour trước** (`stopAll` + `resetSessionMemory`),
không phải ở cuối tour trước. Lý do đầy đủ ở comment "FIX P1" trong
`userStartedTour`.

## 3. Trong tour — thu thập tiến trình

`TourProgressService` là **listener thuần**: nghe 4 stream đã có, không gọi ngược
vào thứ nó quan sát.

```
session.state ──────────┐
presence.events ────────┤
engine.onStateChanged ──┼──► TourProgressService ──► TourProgress
engine.onCompleted ─────┘                                │
                                            TourProgressProvider
                                                         │
                            ZoneScreen._CompletionPrompt ─┘
```

Mẫu số (`totalZones` / `totalExhibits`) đọc qua **callback**, không phải giá trị
chụp lúc dựng graph — kho nội dung nạp bất đồng bộ.

## 4. Mở màn tổng kết

Hai đường, cùng đích `/summary`, đều là `pushNamed` thường:

- `zone_screen.dart` → `_TourChrome` → `MenuButton` → `menu_sheet.dart:showMenuSheet()`
  → `_EndTourRow` → `pop(_SheetResult.summary)` → `pushNamed('/summary')`
- `zone_screen.dart` → `_CompletionPrompt` → `pushNamed('/summary')`

Sheet đóng **trước** rồi mới push, để ngăn xếp không có route mới nằm dưới một
sheet đang tan biến.

## 5. Màn tổng kết — vẫn trong `touring`

Đây không phải màn hậu-kết-thúc. Nó là màn **xác nhận**, và ba thứ phụ thuộc vào
việc nó nằm trong phiên:

| Thứ | Vì sao cần phiên còn sống |
|---|---|
| Nút "Quay lại tham quan" | kết thúc là thao tác không hoàn tác được |
| `FeedbackPanel` → `AnalyticsRecorder.recordFeedback()` | recorder xoá `_sid` ngay khi rời `touring` |
| Số liệu tiến trình | `TourProgressService` chỉ dọn ở đầu tour SAU |

Vòng đời âm thanh của màn này:

- `initState` — nếu **đang phát** thì `AudioProvider.pause()`
- `dispose` — nếu lúc mở đang phát VÀ chưa bấm kết thúc thì `play()`

Chỉ phát lại khi lúc mở đang phát: khách đã tự tạm dừng trước đó thì không được
bật tiếng lên hộ họ.

## 6. Kết thúc

```
summary_screen.dart  _endTour()
   └─ SessionProvider.endTourWithFarewell()
        └─ SessionController.visitorEndedTour()
             └─ _endSession(manual, next: farewell)
                  ├─ publish SessionState(farewell, manual)
                  ├─ _audio.stopAll()
                  └─ _farewellTimer  (chỉ khi farewellHold > 0)
```

Các listener tự phản ứng theo cạnh **rời `touring`** — không ai phải gọi chúng:

| Listener | Phản ứng |
|---|---|
| `AnalyticsRecorder` | phát `TourEnded` kèm reason, rồi `flush()` |
| `museum_audio_handler.dart` | `super.stop()` → hạ foreground service |
| `injection.dart` (tourStartSub) | `keepAlive.stop()`, reset ngôn ngữ |
| `TourProgressService` | đóng sổ, **GIỮ** số liệu |
| `MuseumApp._syncNavigation` | `farewell` → `/farewell` |

Nút "Kết thúc tham quan" trên notification đi đường **khác**:
`staffEndSession()` → `_endSession(manual, next: atDesk)`. Không qua màn cảm ơn,
vì lúc đó không ai đứng trước máy.

## 7. Rời màn cảm ơn

Ba đường vào, một hàm ra:

```
"Xong"        → SessionProvider.dismissFarewell() ─┐
farewellHold  → _farewellTimer ────────────────────┼─► _settleFromFarewell()
cắm sạc       → _onChargingChanged(true) ──────────┘         │
                                                        phase atDesk
                                                             │
                                        _syncNavigation → restRoute
```

Đường thứ ba là lý do `farewellHold: 0` (giữ vô hạn) là một lựa chọn hợp lệ chứ
không phải một cách treo máy: máy bị bỏ quên trên ghế vẫn sạch khi lên dock.

`FarewellScreen` là `StatelessWidget` — không timer, không `Navigator`, không cờ.
Mọi thứ từng cần state đã về đúng chỗ của nó là máy trạng thái phiên.

---

## Bảng file → trách nhiệm

| File | Trách nhiệm | KHÔNG làm |
|---|---|---|
| `session_controller.dart` | Toàn bộ vòng đời phiên, kể cả cửa sổ giữ màn cảm ơn | biết gì về route |
| `app.dart` `tourNavigationTarget` | Ánh xạ thuần phase → route | giữ trạng thái riêng |
| `menu_screen.dart` | Màn nghỉ + thẻ trạng thái nhân viên | gọi `startTour()` |
| `gate_screen.dart` | Lời chào + `startTour()` + `deviceNotReadyCard()` | dựng lại stack |
| `tour_progress_service.dart` | Số liệu chuyến đi cho màn hình | gọi ngược vào nguồn |
| `summary_screen.dart` | Xác nhận kết thúc, đánh giá, QR | tự điều hướng sau khi kết thúc |
| `farewell_screen.dart` | Vẽ một trạng thái, phát biểu một ý định | timer, Navigator |
| `manifest_parser.dart` | Đọc 4 khối cấu hình màn phụ trợ | ném lỗi vì chúng |

## Cấu hình từ server

Bốn khối trong `manifest.json`, tất cả tùy chọn: `menu`, `guide`, `summary`,
`feedback`. Chi tiết hình dạng nằm ở doc đầu mỗi model trong `lib/domain/models/`.

Hai bất biến **được ép**, không chỉ cảnh báo:

1. Menu luôn còn một mục `start` đang bật — tắt nhầm là cả đội máy kẹt ở menu
   không có đường vào tour.
2. `showQr` tự tắt nếu `qrBaseUrl` không phải URL http/https hợp lệ.

`farewell.autoReturnSeconds` được đọc **một lần lúc dựng graph** (giống
`sessionSilence`), nên đổi trên server có hiệu lực sau lần khởi động lại kế tiếp.
