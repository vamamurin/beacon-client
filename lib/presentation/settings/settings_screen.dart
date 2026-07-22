// Destination: lib/presentation/settings/settings_screen.dart
//
// Màn Cài đặt (nhân viên). Lối vào: long-press wordmark ở Gate — khách mượn máy
// không vào đây.
//
// Theme LƯU BỀN VỮNG (ISettingsStore), KHÔNG reset theo phiên (quyết định sản
// phẩm). Ngược lại, NGÔN NGỮ là per-session (reset khi hết tour) — picker ở đây
// chỉ là lối phụ; lối chính là Gate.
//
// Feature B: mọi chữ giao diện đọc qua ContentProvider.ui (chuỗi chrome đi cùng
// bundle). Đây là lý do màn này GIỜ import ContentProvider — trước kia cố ý
// không, nhưng l10n toàn app khiến nó thành nguồn chữ duy nhất, kể cả ở đây.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/settings_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/app_theme.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';
import 'package:beacon_client/presentation/widgets/language_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ctrl = context.watch<ThemeController>();
    final content = context.watch<ContentProvider>();

    return Scaffold(
      backgroundColor: t.surface,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: t.ink),
        title: Text(content.ui(UiKeys.settingsTitle),
            style: AppText.sheetTitle.copyWith(color: t.ink)),
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.gutter, 8, AppSpace.gutter, 24),
        children: [
          // ── NGÔN NGỮ (per-session; lối phụ, lối chính ở Gate) ──
          Text(content.ui(UiKeys.settingsLanguage).toUpperCase(),
              style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          const LanguagePicker(),
          const SizedBox(height: 32),

          // ── GIAO DIỆN ──
          Text(content.ui(UiKeys.settingsThemeHeader).toUpperCase(),
              style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          for (final id in MuseumThemeId.values)
            _ThemeOption(
              id: id,
              selected: id == ctrl.id,
              onTap: () => ctrl.select(id),
            ),
          const SizedBox(height: 24),
          Text(
            content.ui(UiKeys.settingsThemeDesc),
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
          const SizedBox(height: 32),

          // ── CHẨN ĐOÁN ──
          Text(content.ui(UiKeys.settingsDiagnosticsHeader).toUpperCase(),
              style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          _DistanceToggle(),
          const SizedBox(height: 12),
          Text(
            content.ui(UiKeys.settingsDistanceDesc),
            style: AppText.stopMeta.copyWith(color: t.inkFaint),
          ),
          const SizedBox(height: 32),

          // ── MÁY CHỦ NỘI DUNG ──
          Text(content.ui(UiKeys.settingsServerHeader).toUpperCase(),
              style: AppText.kicker.copyWith(color: t.inkFaint)),
          const SizedBox(height: 12),
          const _ServerSection(),
        ],
      ),
    );
  }
}

/// Content-server URL override + manual "sync now". Staff-only.
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

  String _syncLabel(ContentProvider content, ManualSyncState s) => switch (s) {
        ManualSyncState.running => content.ui(UiKeys.settingsSyncRunning),
        ManualSyncState.updated => content.ui(UiKeys.settingsSyncUpdated),
        ManualSyncState.upToDate => content.ui(UiKeys.settingsSyncUpToDate),
        ManualSyncState.noServer => content.ui(UiKeys.settingsSyncNoServer),
        ManualSyncState.failed => content.ui(UiKeys.settingsSyncFailed),
        ManualSyncState.mock => content.ui(UiKeys.settingsSyncMock),
        ManualSyncState.idle => '',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
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
            labelText: content.ui(UiKeys.settingsServerUrlLabel),
            hintText: 'http://192.168.1.8:8000',
            labelStyle: AppText.stopMeta.copyWith(color: t.inkFaint),
            hintStyle: AppText.stopMeta.copyWith(color: t.inkFaint),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.outline)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: t.ctaFill)),
          ),
          onSubmitted: settings.setBaseUrlOverride,
          onEditingComplete: () => settings.setBaseUrlOverride(_urlCtrl.text),
        ),
        const SizedBox(height: 6),
        Text(
          content.ui(UiKeys.settingsServerUrlDesc),
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
                        settings.setBaseUrlOverride(_urlCtrl.text);
                        settings.syncNow();
                      },
                child: Text(
                  settings.isSyncing
                      ? content.ui(UiKeys.settingsSyncRunning).toUpperCase()
                      : content.ui(UiKeys.settingsSyncNowBtn).toUpperCase(),
                  style: AppText.button,
                ),
              ),
            ),
          ],
        ),
        if (settings.syncState != ManualSyncState.idle) ...[
          const SizedBox(height: 10),
          Text(_syncLabel(content, settings.syncState),
              style: AppText.sheetSub.copyWith(color: t.ink)),
        ],
        if (last != null) ...[
          const SizedBox(height: 6),
          Text(
            content.uif(UiKeys.settingsLastSync, {'time': _fmt(last)}),
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

/// Staff toggle: show estimated distance (metres) on the zone screen.
class _DistanceToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final settings = context.watch<SettingsProvider>();
    return Material(
      color: Colors.transparent,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: settings.showDistanceDebug,
        onChanged: settings.setShowDistanceDebug,
        activeThumbColor: t.ctaFill,
        title: Text(content.ui(UiKeys.settingsDistanceToggle),
            style: AppText.sheetSub.copyWith(color: t.ink)),
      ),
    );
  }
}

/// Một dòng chọn theme. Tự vẽ thay vì RadioListTile (giữ token của ta).
class _ThemeOption extends StatelessWidget {
  final MuseumThemeId id;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  /// Tên theme theo ngôn ngữ hiện tại. Fallback về id.label (nhúng trong enum)
  /// đã được lo bởi kUiDefaults, nên luôn có chữ.
  String _label(ContentProvider content) => switch (id) {
        MuseumThemeId.dark => content.ui(UiKeys.settingsThemeDark),
        MuseumThemeId.light => content.ui(UiKeys.settingsThemeLight),
        MuseumThemeId.highContrast =>
          content.ui(UiKeys.settingsThemeHighContrast),
      };

  /// Cảnh báo vận hành. Thông tin, không phải rào cản.
  String? _caveat(ContentProvider content) => switch (id) {
        MuseumThemeId.light => content.ui(UiKeys.settingsCaveatLight),
        MuseumThemeId.highContrast =>
          content.ui(UiKeys.settingsCaveatHighContrast),
        MuseumThemeId.dark => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final label = _label(content);
    final caveat = _caveat(content);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
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
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: t.ink),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppText.body.copyWith(color: t.ink)),
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