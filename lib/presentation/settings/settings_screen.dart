// Destination: lib/presentation/settings/settings_screen.dart (NEW)
//
// Màn Cài đặt. Hôm nay chỉ có chọn giao diện; sau này thêm ngôn ngữ, đồng bộ.
//
// AI DÙNG MÀN NÀY: nhân viên bảo tàng, một lần, lúc bàn giao thiết bị. Khách
// tham quan mượn máy rồi đi 90 phút — họ không vào đây. Vì vậy lối vào là
// long-press lên wordmark ở Gate, không phải một nút hiện rõ.
//
// Lựa chọn được LƯU BỀN VỮNG (ISettingsStore) và KHÔNG tự reset khi hết phiên:
// đây là quyết định sản phẩm đã chốt. Hệ quả cần biết: thiết bị cho mượn sẽ giữ
// nguyên giao diện mà khách trước để lại, cho tới khi nhân viên đổi.
//
// Màn này chỉ biết ThemeController. Không import ContentProvider, ZoneProvider,
// hay HeroImage — nếu bạn thấy mình cần chúng, có lẽ thứ bạn đang thêm không
// thuộc về Cài đặt.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/widgets/language_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ctrl = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: t.ink),
        title:
            Text('Cài đặt', style: AppText.sheetTitle.copyWith(color: t.ink)),
      ),
      body: ListView(
        // AppSpace.gutter (20), KHÔNG phải t.gutter (18 — đã xoá khỏi
        // MuseumTokens). Màn này là call site DUY NHẤT còn đọc token đó, nên
        // nó là màn duy nhất trong app đang lệch 2dp so với màn 1 và màn 3.
        // Một token chỉ có một người đọc thì không ai kiểm nó.
        //
        // `8` và `24` vẫn là số thô: màn Cài đặt chưa qua đợt tái cấu trúc thị
        // giác (mới làm màn 1 và 3). Để nguyên có chủ đích — sửa nửa vời một
        // màn chưa redesign chỉ tạo ra một lưới thứ ba.
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 24),
        children: [
          Text('NGÔN NGỮ', style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          const LanguagePicker(),
          const SizedBox(height: 32),
          
          Text('GIAO DIỆN', style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          for (final id in MuseumThemeId.values)
            _ThemeOption(
              id: id,
              selected: id == ctrl.id,
              // Đổi ngay, không cần nút Lưu: thay đổi là khả nghịch, thấy được
              // tức thì, và lerp của MuseumTokens làm nó mượt.
              onTap: () => ctrl.select(id),
            ),
          const SizedBox(height: 24),
          Text(
            'Giao diện được lưu trên thiết bị và giữ nguyên cho khách tiếp theo.',
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
          const SizedBox(height: 32),
          Text('CHẨN ĐOÁN', style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          _DistanceToggle(),
          const SizedBox(height: 12),
          Text(
            'Chỉ dùng khi tinh chỉnh khoảng cách tại hiện trường. Hiện số mét ước '
            'lượng trên màn khu vực. Tắt trước khi giao máy cho khách.',
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
          const SizedBox(height: 32),
          Text('MÁY CHỦ NỘI DUNG',
              style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          const _ServerSection(),
        ],
      ),
    );
  }
}

/// Content-server URL override + manual "sync now". Staff-only (this screen is
/// reached by long-pressing the Gate wordmark).
class _ServerSection extends StatefulWidget {
  const _ServerSection();

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
        text: context.read<SettingsProvider>().baseUrlOverride);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String _syncLabel(ManualSyncState s) => switch (s) {
        ManualSyncState.running => 'Đang đồng bộ…',
        ManualSyncState.updated => 'Đã cập nhật nội dung mới',
        ManualSyncState.upToDate => 'Đã là bản mới nhất',
        ManualSyncState.noServer => 'Không gọi được máy chủ',
        ManualSyncState.failed => 'Đồng bộ thất bại',
        ManualSyncState.mock => 'Chế độ thử — không có máy chủ',
        ManualSyncState.idle => '',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    final last = settings.lastSuccessfulSyncAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.sheetSub.copyWith(color: t.ink),
          decoration: InputDecoration(
            labelText: 'Địa chỉ máy chủ',
            hintText: 'http://192.168.1.8:8000',
            labelStyle: AppText.stopMeta.copyWith(color: t.inkFaint),
            hintStyle: AppText.stopMeta.copyWith(color: t.inkFaint),
            enabledBorder: UnderlineInputBorder(
                // Viền ô nhập là ranh giới CONTROL ⇒ t.outline (3.55:1).
                // t.line là hairline trang trí: 1.17:1 — ô nhập không có viền.
                borderSide: BorderSide(color: t.outline)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.ctaFill)),
          ),
          onSubmitted: settings.setBaseUrlOverride,
          onEditingComplete: () =>
              settings.setBaseUrlOverride(_urlCtrl.text),
        ),
        const SizedBox(height: 6),
        Text(
          'Để trống để dùng địa chỉ mặc định của bản cài. Đổi tại đây có hiệu '
          'lực ngay lần đồng bộ kế tiếp, không cần cài lại app.',
          style: AppText.stopMeta.copyWith(color: t.inkFaint),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.ctaFill,
                  foregroundColor: t.ctaLabel,
                ),
                onPressed: settings.isSyncing
                    ? null
                    : () {
                        // Commit any typed URL before syncing.
                        settings.setBaseUrlOverride(_urlCtrl.text);
                        settings.syncNow();
                      },
                child: Text(
                  settings.isSyncing ? 'ĐANG ĐỒNG BỘ…' : 'ĐỒNG BỘ NGAY',
                  style: AppText.button,
                ),
              ),
            ),
          ],
        ),
        if (settings.syncState != ManualSyncState.idle) ...[
          const SizedBox(height: 10),
          Text(_syncLabel(settings.syncState),
              style: AppText.sheetSub.copyWith(color: t.ink)),
        ],
        if (last != null) ...[
          const SizedBox(height: 6),
          Text(
            'Lần đồng bộ gần nhất: ${_fmt(last)}',
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
        ],
      ],
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

/// Staff toggle: show estimated distance (metres) on the zone screen. Persisted
/// via SettingsProvider -> ISettingsStore. Off by default.
class _DistanceToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    return Material(
      color: Colors.transparent,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: settings.showDistanceDebug,
        onChanged: settings.setShowDistanceDebug,
        activeThumbColor: t.ctaFill,
        title: Text('Hiện khoảng cách ước lượng',
            style: AppText.sheetSub.copyWith(color: t.ink)),
      ),
    );
  }
}

/// Một dòng chọn theme. Tự vẽ thay vì dùng RadioListTile: RadioListTile kéo
/// theo màu Material mặc định (không phải token của ta), và trên Flutter mới
/// groupValue/onChanged của nó đã deprecate.
class _ThemeOption extends StatelessWidget {
  final MuseumThemeId id;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  /// Cảnh báo vận hành cho light mode. Sếp yêu cầu tính năng này; người bấm nút
  /// vẫn xứng đáng biết đánh đổi. Đây là thông tin, không phải rào cản.
  String? get _caveat => switch (id) {
        MuseumThemeId.light =>
          'Màn hình sáng gây chói trong phòng trưng bày tối và có thể làm phiền '
              'khách đứng cạnh.',
        MuseumThemeId.highContrast =>
          'Tăng độ tương phản cho khách lớn tuổi hoặc thị lực kém.',
        MuseumThemeId.dark => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final caveat = _caveat;

    return Semantics(
      button: true,
      selected: selected,
      label: id.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vòng tròn chọn — cùng ngôn ngữ thị giác với badge số hiện vật.
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? t.ink : t.inkFaint),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: t.ink),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(id.label,
                          style: AppText.body.copyWith(color: t.ink)),
                      if (caveat != null) ...[
                        const SizedBox(height: 4),
                        Text(caveat,
                            style:
                                AppText.stopMeta.copyWith(color: t.inkFaint)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}