// Destination: test/manifest_parser_screens_test.dart
// Run with: flutter test test/manifest_parser_screens_test.dart
//
// Bốn khối manifest điều khiển các màn hình PHỤ TRỢ (menu / hướng dẫn / tổng
// kết / đánh giá). Chúng có một hợp đồng khác với phần nội dung trưng bày, và
// file này tồn tại để khoá đúng chỗ khác nhau đó:
//
//   • KHÔNG khối nào được phép làm hỏng bundle. Nội dung trưng bày sai thì thà
//     giữ bundle cũ; một mục menu gõ sai id thì không.
//   • Thiếu khối ⇒ mặc định im lặng (không warning), vì MỌI bundle đang chạy
//     ngoài hiện trường hôm nay đều thiếu cả bốn.
//   • Có một bất biến được ÉP chứ không chỉ cảnh báo: menu luôn còn đường vào
//     tour.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/repositories/manifest_parser.dart';
import 'package:beacon_client/data/repositories/mock_zone_repository.dart';
import 'package:beacon_client/domain/models/feedback_config.dart';
import 'package:beacon_client/domain/models/menu_config.dart';

Map<String, dynamic> baseManifest() =>
    jsonDecode(kMockManifestJson) as Map<String, dynamic>;

/// Khớp một warning theo mảnh chuỗi — thông điệp có thể được viết lại cho dễ
/// đọc hơn mà không làm test gãy, miễn là vẫn chỉ đúng chỗ hỏng.
Matcher hasWarning(String fragment) =>
    contains(predicate<String>((w) => w.contains(fragment), 'chứa "$fragment"'));

void main() {
  group('bundle không khai báo gì', () {
    test('rơi về mặc định, và im lặng — không warning', () {
      final parsed = ManifestParser.parse(baseManifest());

      expect(parsed.warnings, isEmpty);
      expect(parsed.config.menu, MenuConfig.defaults);
      expect(parsed.config.menu.entries.map((e) => e.action),
          [MenuAction.startTour, MenuAction.guide]);
      expect(parsed.config.guide.isEmpty, isTrue);
      expect(parsed.config.summary.showFeedback, isTrue);
      expect(parsed.config.summary.showQr, isFalse);
      expect(parsed.config.summary.farewellAutoReturn, Duration.zero);
      expect(parsed.config.feedback.scale, FeedbackScale.stars5);
      expect(parsed.config.feedback.tags, isEmpty);
    });
  });

  group('menu', () {
    test('giữ nguyên thứ tự mảng và cờ enabled', () {
      final m = baseManifest();
      m['menu'] = {
        'entries': [
          {'id': 'guide'},
          {'id': 'start'},
          {'id': 'map', 'enabled': false},
        ]
      };

      final cfg = ManifestParser.parse(m).config.menu;
      expect(cfg.entries.map((e) => e.action),
          [MenuAction.guide, MenuAction.startTour, MenuAction.map]);
      // `visible` lọc theo enabled nhưng không sắp xếp lại.
      expect(cfg.visible.map((e) => e.action),
          [MenuAction.guide, MenuAction.startTour]);
    });

    test('id không hỗ trợ bị bỏ kèm warning, các mục còn lại sống', () {
      final m = baseManifest();
      m['menu'] = {
        'entries': [
          {'id': 'start'},
          {'id': 'cafeteria'},
          {'id': 'guide'},
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, hasWarning('cafeteria'));
      expect(parsed.config.menu.entries.map((e) => e.action),
          [MenuAction.startTour, MenuAction.guide]);
    });

    test('id trùng: giữ lần khai báo đầu', () {
      final m = baseManifest();
      m['menu'] = {
        'entries': [
          {'id': 'start'},
          {'id': 'guide', 'enabled': true},
          {'id': 'guide', 'enabled': false},
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, hasWarning('trùng'));
      expect(parsed.config.menu.entries, hasLength(2));
      expect(parsed.config.menu.entries.last.enabled, isTrue);
    });

    // Bất biến: đây là khác biệt giữa "một mục hiển thị sai" và "cả đội máy
    // đứng ở màn Menu không có đường vào tour".
    test('tắt nhầm mục "start" được tự nắn lại thay vì khoá khách ở Menu', () {
      final m = baseManifest();
      m['menu'] = {
        'entries': [
          {'id': 'start', 'enabled': false},
          {'id': 'guide'},
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, hasWarning('start'));
      final entries = parsed.config.menu.entries;
      expect(entries.first.action, MenuAction.startTour);
      expect(entries.first.enabled, isTrue);
      expect(entries, hasLength(2)); // không nhân đôi mục start
    });

    test('mục "start" hoàn toàn vắng mặt cũng được thêm lại', () {
      final m = baseManifest();
      m['menu'] = {
        'entries': [
          {'id': 'guide'}
        ]
      };

      final cfg = ManifestParser.parse(m).config.menu;
      expect(cfg.entries.map((e) => e.action),
          [MenuAction.startTour, MenuAction.guide]);
    });

    test('khối sai kiểu / không mục nào hợp lệ ⇒ menu mặc định', () {
      for (final bad in <Object>[
        'menu',
        {'entries': 'start,guide'},
        {
          'entries': [
            {'id': 'cafeteria'}
          ]
        },
      ]) {
        final m = baseManifest()..['menu'] = bad;
        final parsed = ManifestParser.parse(m);
        expect(parsed.config.menu, MenuConfig.defaults, reason: 'với $bad');
        expect(parsed.warnings, isNotEmpty, reason: 'với $bad');
      }
    });
  });

  group('guide', () {
    test('đọc các bước theo thứ tự, icon và ảnh là tùy chọn', () {
      final m = baseManifest();
      m['guide'] = {
        'steps': [
          {
            'icon': 'headphones',
            'image': 'images/guide/step1.jpg',
            'title': {'vi': 'Đeo tai nghe'},
            'body': {'vi': 'Cắm tai nghe vào máy.'},
          },
          {
            'title': {'vi': 'Cứ đi tự nhiên'},
            'body': {'vi': 'Máy tự nhận khu.'},
          },
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, isEmpty);
      final steps = parsed.config.guide.steps;
      expect(steps, hasLength(2));
      expect(steps.first.iconId, 'headphones');
      expect(steps.first.imagePath, 'images/guide/step1.jpg');
      expect(steps.first.title.resolve('vi', 'vi'), 'Đeo tai nghe');
      expect(steps.last.iconId, isNull);
      expect(steps.last.imagePath, isNull);
    });

    test('bước thiếu bản dịch fallback bị bỏ, các bước khác sống', () {
      final m = baseManifest();
      m['guide'] = {
        'steps': [
          {
            'title': {'en': 'Wear headphones'}, // thiếu "vi" (fallback)
            'body': {'vi': '...'},
          },
          {
            'title': {'vi': 'Cứ đi tự nhiên'},
            'body': {'vi': 'Máy tự nhận khu.'},
          },
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, hasWarning('guide.steps[0]'));
      expect(parsed.config.guide.steps, hasLength(1));
    });

    // Khác với `title`/`body`: ảnh chỉ là trang trí nên không kéo cả bước theo.
    test('ảnh minh họa sai luật đường dẫn chỉ mất ảnh, bước vẫn còn', () {
      final m = baseManifest();
      m['guide'] = {
        'steps': [
          {
            'image': '../../etc/passwd',
            'title': {'vi': 'Đeo tai nghe'},
            'body': {'vi': 'Cắm tai nghe vào máy.'},
          }
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, hasWarning('ảnh minh họa'));
      expect(parsed.config.guide.steps, hasLength(1));
      expect(parsed.config.guide.steps.single.imagePath, isNull);
    });

    test('mọi bước đều hỏng ⇒ rỗng ⇒ UI dùng bộ bước mặc định', () {
      final m = baseManifest();
      m['guide'] = {
        'steps': [
          {'title': 'không phải object đa ngữ'}
        ]
      };
      expect(ManifestParser.parse(m).config.guide.isEmpty, isTrue);
    });
  });

  group('summary + farewell', () {
    test('đọc lời kết, cờ hiển thị và địa chỉ QR', () {
      final m = baseManifest();
      m['summary'] = {
        'closing': {'vi': 'Hẹn gặp lại quý khách.'},
        'showFeedback': false,
        'showQr': true,
        'qrBaseUrl': 'https://baotang.vn/t',
      };
      m['farewell'] = {'autoReturnSeconds': 30};

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, isEmpty);
      final s = parsed.config.summary;
      expect(s.closing!.resolve('vi', 'vi'), 'Hẹn gặp lại quý khách.');
      expect(s.showFeedback, isFalse);
      expect(s.showQr, isTrue);
      expect(s.qrBaseUrl, 'https://baotang.vn/t');
      expect(s.farewellAutoReturn, const Duration(seconds: 30));
    });

    // QR bật mà không có trang đích thì khách quét ra trang trắng — tệ hơn là
    // không có QR nào, nên bất biến này được ép chứ không chỉ cảnh báo.
    test('showQr bị tắt khi qrBaseUrl thiếu hoặc không phải http/https', () {
      for (final bad in <Object?>[
        null,
        'javascript:alert(1)',
        'baotang.vn/t', // thiếu scheme ⇒ không tuyệt đối
        'https://', // thiếu host
        42,
      ]) {
        final m = baseManifest();
        m['summary'] = {'showQr': true, if (bad != null) 'qrBaseUrl': bad};

        final parsed = ManifestParser.parse(m);
        expect(parsed.config.summary.showQr, isFalse, reason: 'với $bad');
        expect(parsed.config.summary.qrBaseUrl, isNull, reason: 'với $bad');
        expect(parsed.warnings, isNotEmpty, reason: 'với $bad');
      }
    });

    test('autoReturnSeconds bị kẹp vào [0, 300]', () {
      Duration parseWith(Object v) {
        final m = baseManifest()..['farewell'] = {'autoReturnSeconds': v};
        return ManifestParser.parse(m).config.summary.farewellAutoReturn;
      }

      expect(parseWith(-5), Duration.zero);
      expect(parseWith(9999), const Duration(seconds: 300));
      expect(parseWith('mãi mãi'), Duration.zero); // sai kiểu ⇒ giữ tới khi bấm
    });

    test('khai báo farewell mà không khai báo summary vẫn có hiệu lực', () {
      final m = baseManifest()..['farewell'] = {'autoReturnSeconds': 10};
      final s = ManifestParser.parse(m).config.summary;
      expect(s.farewellAutoReturn, const Duration(seconds: 10));
      expect(s.showFeedback, isTrue); // phần còn lại vẫn là mặc định
    });
  });

  group('feedback', () {
    test('đọc thang đo, câu hỏi và nhãn lý do', () {
      final m = baseManifest();
      m['feedback'] = {
        'scale': 'nps',
        'question': {'vi': 'Bạn thấy sao?'},
        'tags': [
          {
            'id': 'audio',
            'label': {'vi': 'Âm thanh'}
          },
          {
            'id': 'length',
            'label': {'vi': 'Thời lượng'}
          },
        ],
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, isEmpty);
      final f = parsed.config.feedback;
      expect(f.scale, FeedbackScale.nps);
      expect(f.question!.resolve('vi', 'vi'), 'Bạn thấy sao?');
      expect(f.tags.map((t) => t.id), ['audio', 'length']);
    });

    test('thang đo lạ rơi về stars5 kèm warning', () {
      final m = baseManifest()..['feedback'] = {'scale': 'thumbs'};
      final parsed = ManifestParser.parse(m);
      expect(parsed.warnings, hasWarning('thumbs'));
      expect(parsed.config.feedback.scale, FeedbackScale.stars5);
    });

    test('nhãn trùng id bị bỏ, nhãn thiếu id bị bỏ', () {
      final m = baseManifest();
      m['feedback'] = {
        'tags': [
          {
            'id': 'audio',
            'label': {'vi': 'Âm thanh'}
          },
          {
            'id': 'audio',
            'label': {'vi': 'Âm thanh (lần hai)'}
          },
          {
            'label': {'vi': 'Không có id'}
          },
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.config.feedback.tags, hasLength(1));
      expect(parsed.config.feedback.tags.single.label.resolve('vi', 'vi'),
          'Âm thanh');
    });

    test('quá 8 nhãn thì cắt phần thừa', () {
      final m = baseManifest();
      m['feedback'] = {
        'tags': [
          for (var i = 0; i < 12; i++)
            {
              'id': 'tag$i',
              'label': {'vi': 'Nhãn $i'}
            }
        ]
      };

      final parsed = ManifestParser.parse(m);
      expect(parsed.config.feedback.tags, hasLength(8));
      expect(parsed.warnings, hasWarning('cắt phần thừa'));
    });
  });
}
