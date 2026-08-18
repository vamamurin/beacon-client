// Test cho phần THUẦN TUÝ của ModelStore: đọc models.json và biên an toàn của
// sha256. Phần tải mạng không test ở đây (cùng lý do với HttpSyncTransport —
// nó là I/O thật); thứ đáng test là các quyết định LOẠI BỎ, vì chúng là chỗ một
// máy chủ bị chỉnh sửa có thể đẩy được thứ gì đó vào hệ thống file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_client/data/repositories/model_store.dart';

/// 64 ký tự hex. Viết thẳng ra vì `'a' * 64` không phải biểu thức const, và
/// `_entry` cần nội suy nó vào một giá trị mặc định.
const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _entry({
  Object? id = 'tuong-phat',
  Object? file = 'models/$_sha.glb',
  Object? sha256 = _sha,
  Object? bytes = 5240632,
}) =>
    {'id': id, 'file': file, 'sha256': sha256, 'bytes': bytes};

void main() {
  group('ModelStore.isValidSha256', () {
    test('nhận đúng 64 ký tự hex thường', () {
      expect(ModelStore.isValidSha256(_sha), isTrue);
      expect(ModelStore.isValidSha256('A' * 64), isTrue, reason: 'hoa cũng được');
    });

    test('từ chối mọi thứ không phải băm', () {
      for (final bad in [
        null,
        '',
        'a' * 63,
        'a' * 65,
        'g' * 64, // không phải hex
        '../../etc/passwd',
        '${'a' * 60}/../',
      ]) {
        expect(ModelStore.isValidSha256(bad), isFalse, reason: 'với "$bad"');
      }
    });

    test('fileFor ném khi băm không hợp lệ — không bao giờ ghép vào đường dẫn',
        () {
      // Không chạm đĩa: fileFor xác thực TRƯỚC khi có I/O nào xảy ra, nên một
      // thư mục không tồn tại là đủ để kiểm đúng thứ cần kiểm.
      final store = ModelStore(Directory('/nonexistent/models'));
      expect(() => store.fileFor('../escape'), throwsArgumentError);
      expect(() => store.fileFor(''), throwsArgumentError);
      expect(store.fileFor(_sha).path, endsWith('$_sha.glb'));
    });
  });

  group('ModelRef.tryParse', () {
    test('đọc được một bản ghi hợp lệ', () {
      final w = <String>[];
      final ref = ModelRef.tryParse(_entry(), w);
      expect(ref, isNotNull);
      expect(ref!.id, 'tuong-phat');
      expect(ref.sha256, _sha);
      expect(ref.bytes, 5240632);
      expect(w, isEmpty);
    });

    test('hạ băm về chữ thường — tên file trên đĩa phải một dạng duy nhất', () {
      final ref = ModelRef.tryParse(_entry(sha256: 'A' * 64), <String>[]);
      expect(ref!.sha256, 'a' * 64);
    });

    // Đây là biên an toàn thật: "file" đi thẳng vào một URL, nên nó phải được
    // chứng minh vô hại chứ không được tin tưởng.
    test('từ chối đường dẫn thoát ra ngoài models/', () {
      for (final bad in [
        'models/../../secret.glb',
        '/etc/passwd.glb',
        'http://evil/x.glb',
        'audio/x.mp3',
        'models/x.exe',
        'models/x.glb.exe',
      ]) {
        final w = <String>[];
        expect(ModelRef.tryParse(_entry(file: bad), w), isNull,
            reason: 'với "$bad"');
        expect(w, isNotEmpty, reason: 'phải kèm warning cho "$bad"');
      }
    });

    test('từ chối bản ghi thiếu hoặc sai kiểu, KÈM warning', () {
      final cases = <String, Map<String, dynamic>>{
        'id rỗng': _entry(id: ''),
        'id không phải chuỗi': _entry(id: 7),
        'sha256 ngắn': _entry(sha256: 'abc'),
        'sha256 không phải chuỗi': _entry(sha256: 123),
        'bytes âm': _entry(bytes: -1),
        'bytes bằng 0': _entry(bytes: 0),
        'bytes không phải int': _entry(bytes: '5 MB'),
      };
      cases.forEach((name, map) {
        final w = <String>[];
        expect(ModelRef.tryParse(map, w), isNull, reason: name);
        expect(w, hasLength(1), reason: '$name phải sinh đúng 1 warning');
      });
    });

    test('phần tử không phải object thì bỏ chứ không ném', () {
      final w = <String>[];
      expect(ModelRef.tryParse('không phải map', w), isNull);
      expect(ModelRef.tryParse(null, w), isNull);
      expect(w, hasLength(2));
    });

    test('hai bản ghi cùng băm và id thì bằng nhau', () {
      final a = ModelRef.tryParse(_entry(), <String>[])!;
      final b = ModelRef.tryParse(_entry(), <String>[])!;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
