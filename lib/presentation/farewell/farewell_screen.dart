// Destination: lib/presentation/farewell/farewell_screen.dart
//
// MÀN CẢM ƠN / XIN GỬI LẠI MÁY — sau khi phiên đã thật sự dọn.
//
// Đây là màn hình của [SessionPhase.farewell], và nó KHÔNG TỰ LÀM GÌ CẢ:
// không hẹn giờ, không tự điều hướng, không giữ cờ nào. Nó chỉ vẽ một trạng
// thái của phiên và phát biểu một ý định khi khách bấm.
//
// Toàn bộ phần "sống được bao lâu" nằm ở [SessionController]:
//   • hạn giữ (`farewellHold`, từ manifest `farewell.autoReturnSeconds`),
//   • khách bấm "Xong" ⇒ `dismissFarewell()`,
//   • máy lên dock ⇒ controller tự về `atDesk`.
// Cả ba đều dẫn tới cùng một chỗ, và root đưa stack về màn nghỉ vì PHASE đổi —
// không phải vì màn này gọi Navigator.
//
// Đó là lý do màn hình này lại là StatelessWidget: mọi thứ từng cần state
// (timer, cờ điều hướng) đã về đúng chỗ của nó là máy trạng thái phiên. Giữ
// vô hạn (`autoReturnSeconds: 0`) an toàn cũng nhờ vậy — cắm sạc là đường
// thoát vật lý được xử lý ngay trong controller.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/providers/session_provider.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class FarewellScreen extends StatelessWidget {
  const FarewellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.check_circle_outline, size: 48, color: t.accent),
              const SizedBox(height: AppSpace.x6),
              Text(content.ui(UiKeys.farewellTitle),
                  style: AppText.heroTitle.copyWith(color: t.ink)),
              const SizedBox(height: AppSpace.x3),
              Text(content.ui(UiKeys.farewellBody),
                  style: AppText.lede.copyWith(color: t.inkMuted)),
              const Spacer(),
              _DoneButton(
                label: content.ui(UiKeys.farewellCta),
                // Chỉ phát biểu ý định. Phiên về `atDesk`, và root đưa stack
                // về màn nghỉ vì phase đổi — màn này không đụng Navigator.
                onPressed: () =>
                    context.read<SessionProvider>().dismissFarewell(),
              ),
              const SizedBox(height: AppSpace.x8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DoneButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: t.ctaFill,
        borderRadius: t.sharpAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: t.sharpAll,
          child: Container(
            height: AppSpace.ctaHeight,
            alignment: Alignment.center,
            child: Text(label.toUpperCase(),
                style: AppText.button.copyWith(color: t.ctaLabel)),
          ),
        ),
      ),
    );
  }
}
