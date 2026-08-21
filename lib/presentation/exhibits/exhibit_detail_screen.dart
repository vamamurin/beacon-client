// Destination: lib/presentation/exhibits/exhibit_detail_screen.dart
//
// MÀN 04c · CHI TIẾT HIỆN VẬT — màn quan trọng nhất của cả app.
//
// ═══════════════════════════════════════════════════════════════════════════
// CHIA ĐÔI: SÂN KHẤU / BẢN LÝ LỊCH
// ═══════════════════════════════════════════════════════════════════════════
//
//   nửa trên   sân khấu 422 — một cuộn phim vuốt ngang, KHÔNG một cái nút nào
//   nửa dưới   bản lý lịch — dải ngôn ngữ · tên · trình phát · lời kể · tư liệu
//
// KHÔNG CÓ NÚT NÀO TRÊN SÂN KHẤU, và đó là một quyết định chứ không phải một
// việc chưa làm. Bản gốc của bố cục này (một trình xem 3D) treo bốn nút ở mép
// phải: tự xoay, phóng to, thu nhỏ, về góc gốc. Cả bốn đều là việc ngón tay làm
// THẲNG trên hình — chụm hai ngón để phóng, kéo để xoay, chạm để mở toàn màn.
// Vẽ nút cho chúng là dựng một bộ điều khiển gián tiếp nằm ĐÈ LÊN chính cái vật
// cần nhìn.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI ĐƯỜNG TỚI TƯ LIỆU, MỘT CHÍNH MỘT PHỤ
// ═══════════════════════════════════════════════════════════════════════════
//
//   chính  cuộn xuống đáy — lưới bày hết cùng lúc, chọn đúng cái muốn xem
//   phụ    vuốt ngang trên sân khấu — xem lướt mà không phải đi hết cả trang
//          mới biết là còn ảnh
//
// Vạch chỉ số ở góc dưới-trái là thứ DUY NHẤT nói rằng còn tư liệu bên cạnh, và
// nó nói bằng hình: mấy vạch là mấy tư liệu, vạch sáng là cái đang xem.
//
// ═══════════════════════════════════════════════════════════════════════════
// HAI THỨ CỦA BẢN VẼ CHƯA CÓ MẶT, VÀ CHÚNG ĐÃ CÓ CHỖ SẴN
// ═══════════════════════════════════════════════════════════════════════════
//
//   MÔ HÌNH 3D   khung đầu cuộn phim. Hoãn theo D3 (hoãn, KHÔNG bỏ — đây là
//                yêu cầu của khách). Tạm thời khung đầu là ảnh chính, nên mọi
//                số đo quanh nó đã đúng sẵn cho ngày thay bằng khối 3D thật.
//   VIDEO        hai khung cuối + hai ô có dấu phát trong lưới. Hoãn theo B4
//                (cần `media[]` trong manifest). Khi có, ô video khác ô ảnh
//                đúng MỘT thứ: một dấu phát trần ở giữa khung.
//
// ═══════════════════════════════════════════════════════════════════════════
// KHÁC BẢN VẼ MỘT CHỖ, CÓ CHỦ ĐÍCH
// ═══════════════════════════════════════════════════════════════════════════
//
// Bản vẽ bỏ hết tiêu đề mục và gộp lời kể thành những đoạn liền mạch. Ở đây GIỮ
// hai nhãn "Giới thiệu" / "Ý nghĩa" (quyết định 14/08/2026): ranh giới giữa
// *hiện vật này là gì* và *vì sao nó quan trọng* là một ranh giới có thật trong
// dữ liệu (`summary` và `meaning` là hai trường), và bỏ nhãn đi thì hai đoạn
// đọc thành một mạch văn duy nhất.
//
// Ngược lại, BẢNG THÔNG SỐ hai cột thì bỏ đúng theo bản vẽ: `specs` nay là một
// dòng meta dưới tên, nối các GIÁ TRỊ bằng dấu chấm giữa. Nhãn ("Chất liệu",
// "Nguồn gốc") không hiện nữa — chúng suy ra được từ chính giá trị, và vẫn nằm
// nguyên trong manifest cho ngày cần tới.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:beacon_client/domain/models/audio_queue_state.dart';
import 'package:beacon_client/domain/models/exhibit_info.dart';
import 'package:beacon_client/domain/models/zone_info.dart';
import 'package:beacon_client/presentation/app/app_router.dart';
import 'package:beacon_client/presentation/app/museum_top_bar.dart';
import 'package:beacon_client/presentation/audio_feedback.dart';
import 'package:beacon_client/presentation/providers/audio_provider.dart';
import 'package:beacon_client/presentation/providers/content_provider.dart';
import 'package:beacon_client/presentation/exhibits/model_route.dart';
import 'package:beacon_client/presentation/exhibits/turntable_view.dart';
import 'package:beacon_client/presentation/providers/model_provider.dart';
import 'package:beacon_client/presentation/providers/language_controller.dart';
import 'package:beacon_client/presentation/theme/app_space.dart';
import 'package:beacon_client/presentation/theme/app_text.dart';
import 'package:beacon_client/presentation/theme/hero_image.dart';
import 'package:beacon_client/presentation/theme/museum_tokens.dart';
import 'package:beacon_client/presentation/theme/player_marks.dart';
import 'package:beacon_client/presentation/ui_strings.dart';

class ExhibitDetailScreen extends StatelessWidget {
  final int major;
  final int minor;

  const ExhibitDetailScreen({
    super.key,
    required this.major,
    required this.minor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final zone = content.zoneByMajor(major);
    final exhibit = zone?.exhibitByMinor(minor);

    if (zone == null || exhibit == null) {
      return Scaffold(
        backgroundColor: t.surface,
        body: Center(
          child: Text(content.ui(UiKeys.exhibitNotFound),
              style: AppText.meta.copyWith(color: t.inkMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.surface,
      body: _FollowAudio(
        major: major,
        minor: minor,
        child: Stack(
        children: [
          Positioned.fill(child: _Page(zone: zone, exhibit: exhibit)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // TIÊU ĐỀ LÀ TÊN KHU, không phải tên hiện vật: tên hiện vật nằm
            // ngay dưới ở cỡ 28, và thanh trên ở đây trả lời câu "tôi đang ở
            // đâu" chứ không lặp lại câu "tôi đang xem gì".
            //
            // CHIP `VI` TẮT Ở RIÊNG MÀN NÀY. Dải ngôn ngữ bên dưới đã làm đúng
            // việc đó và làm rõ hơn (tên viết bằng chính ngôn ngữ đó); hai chỗ
            // đổi tiếng trong cùng một màn là nói một điều hai lần. Ô rỗng vẫn
            // giữ 48dp để tiêu đề nằm đúng giữa.
            child: MuseumTopBar(
              title: content.text(zone.name),
              leading: TopBarLeading.back,
              solid: false,
              showLanguage: false,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// MÀN HÌNH ĐI THEO TIẾNG, không đứng yên khi tiếng đã sang hiện vật khác.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// VÌ SAO CẦN
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Nghe hết clip của hiện vật A, engine tự phát sang B theo thứ tự tour. Trước
/// đây màn hình vẫn nằm ở A: khách nghe câu chuyện của một hiện vật trong khi
/// đang nhìn ảnh và lời kể của một hiện vật khác. Đó là hai nguồn sự thật nói
/// hai điều, và cái sai không phải ở tiếng — tiếng đang làm đúng.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// BỐN ĐIỀU KIỆN, VÀ MỖI CÁI CHẶN MỘT KIỂU HỎNG
/// ═══════════════════════════════════════════════════════════════════════════
///
///   không phải phần dẫn khu   phần dẫn không thuộc hiện vật nào để mà nhảy tới
///   CÙNG khu                  màn này ĐÓNG BĂNG theo `major`; tiếng sang khu
///                             khác là việc của arbiter và màn Khu vực, không
///                             phải chỗ này tự ý vượt biên
///   khác hiện vật đang mở     bằng nhau thì không có gì để làm
///   route đang ở TRÊN CÙNG    nếu không, một màn chi tiết nằm dưới đáy ngăn
///                             xếp sẽ tự đẩy route trong lúc khách đang xem
///                             màn khác — lỗi này không bao giờ lộ ra trong
///                             test, chỉ lộ khi có người mở màn xem ảnh lớn
///
/// Điều hướng chạy ở POST-FRAME: đẩy một route ngay trong `build` là lỗi. Cờ
/// [_navigating] chặn phát lại — engine có thể phát cùng một trạng thái nhiều
/// lần, và mỗi lần phát lại là một `pushReplacement` nữa.
class _FollowAudio extends StatefulWidget {
  final int major;
  final int minor;
  final Widget child;

  const _FollowAudio({
    required this.major,
    required this.minor,
    required this.child,
  });

  @override
  State<_FollowAudio> createState() => _FollowAudioState();
}

class _FollowAudioState extends State<_FollowAudio> {
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AudioProvider>().current;
    _maybeFollow(c);
    return widget.child;
  }

  void _maybeFollow(AudioTrackRef? c) {
    if (_navigating || c == null || c.isIntro) return;
    if (c.zoneMajor != widget.major) return;
    final target = c.exhibitMinor;
    if (target == null || target == widget.minor) return;

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // THAY THẾ, không chồng: tour tự chạy qua sáu hiện vật thì ngăn xếp
      // không được dày lên sáu tầng — lùi một bước phải về danh sách.
      Navigator.of(context).pushReplacementNamed(
        AppRouter.exhibitDetailRoute,
        arguments:
            ExhibitDetailArgs(major: widget.major, minor: target),
      );
    });
  }
}

class _Page extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;

  const _Page({required this.zone, required this.exhibit});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Stage(exhibit: exhibit)),
        SliverToBoxAdapter(child: _Dossier(zone: zone, exhibit: exhibit)),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

/// `.stage` — nửa trên. Nền là MỘT VỆT SÁNG, không phải một cái hộp.
///
/// Bản gốc dùng nền kem với một quầng cam ở giữa; ở đây lật sang bảng màu của
/// app: `surfaceRaised` ở tâm loang ra `surface` ở mép. Hiệu quả giống nhau —
/// vật được rọi đèn trong tủ kính — mà không cần thêm viền, bóng đổ hay khung.
class _Stage extends StatefulWidget {
  final ExhibitInfo exhibit;

  const _Stage({required this.exhibit});

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  final PageController _controller = PageController();
  int _index = 0;

  /// Nội dung cuộn phim — quy tắc sống ở [ExhibitInfo.stagePaths], không ở đây.
  ///
  /// Có mô hình ⇒ đúng MỘT khung. Vuốt ngang lúc đó là xoay mô hình, nên cuộn
  /// phim không lật trang được; ảnh của hiện vật chuyển hết xuống lưới tư liệu
  /// ở đáy màn, nơi ngón tay còn tới được.
  List<String> get _frames => widget.exhibit.stagePaths;

  /// Dải ảnh xoay, chỉ hỏi MỘT LẦN cho mỗi hiện vật.
  ///
  /// Giữ Future trong State chứ không gọi trong `build`: build chạy lại mỗi lần
  /// lật trang cuộn phim, và một `FutureBuilder` nhận Future mới mỗi lần sẽ
  /// khởi động lại vòng tải, nhấp nháy về poster rồi quay lại vòng xoay.
  Future<List<String>>? _turntable;

  @override
  void initState() {
    super.initState();
    final model = widget.exhibit.model;
    if (model != null) {
      _turntable = context.read<ModelProvider>().turntableFrames(model.id);
    }
  }

  @override
  void didUpdateWidget(_Stage old) {
    super.didUpdateWidget(old);
    // Khách bấm "Bài tiếp" thì CÙNG widget này nhận một hiện vật khác — phải
    // hỏi lại, nếu không sân khấu sẽ xoay mô hình của hiện vật trước đó.
    if (old.exhibit.minor != widget.exhibit.minor) {
      final model = widget.exhibit.model;
      _turntable = model == null
          ? null
          : context.read<ModelProvider>().turntableFrames(model.id);
      _index = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final frames = _frames;
    final media = MediaQuery.of(context);

    return SizedBox(
      height: DesignSize.exhibitStage * DesignSize.verticalScale(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.12), // = 50% 56% của bản vẽ
            radius: 0.64,
            colors: [t.surfaceRaised, t.surface],
          ),
        ),
        child: Stack(
          children: [
            // MỘT KHUNG ⇒ KHÔNG PageView. Không phải tối ưu vặt: một viewport
            // cuộn được mà chỉ có một trang vẫn nuốt cử chỉ vuốt ngang và vẫn
            // dựng cả bộ máy trang, để đổi lấy đúng không gì.
            if (frames.length == 1)
              _frame(context, frames, 0, media)
            else
              // CUỘN PHIM LÀ MỘT CONTAINER CÓ NHÃN, vị trí là GIÁ TRỊ của nó.
              //
              // Không dán "Ảnh 2 trên 3" vào nhãn từng khung: TalkBack sẽ đọc
              // lại cả cụm mỗi lần lật, trong khi thứ vừa đổi chỉ là con số. Một
              // container `label` + `value` cho phép screen reader báo đúng
              // phần đã đổi — và đó cũng là cách một carousel được khai báo
              // đúng chuẩn.
              Semantics(
                container: true,
                label: context.read<ContentProvider>()
                    .ui(UiKeys.exhibitGalleryLabel),
                value: context.read<ContentProvider>().uif(
                    UiKeys.exhibitGalleryPosition,
                    {'i': '${_index + 1}', 'n': '${frames.length}'}),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: frames.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) =>
                      _frame(context, frames, i, media),
                ),
              ),

            // `.sdots` — MỘT KHUNG THÌ KHÔNG CÓ VẠCH NÀO. Một vạch đơn độc
            // không nói "còn nữa", nó chỉ là một dấu gạch không ai giải thích.
            if (frames.length > 1)
              Positioned(
                left: AppSpace.gutter,
                bottom: AppSpace.x5,
                child: _Dashes(count: frames.length, index: _index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _frame(
      BuildContext context, List<String> frames, int i, MediaQueryData media) {
    // KHUNG ĐẦU LÀ SÂN KHẤU CỦA MÔ HÌNH. Khi hiện vật có dải ảnh xoay, nó phủ
    // lên tấm poster tĩnh — và poster vẫn là thứ hiện ra TRƯỚC, nên khung này
    // không bao giờ trống dù dải ảnh chưa tải xong hay không bao giờ tới.
    //
    // Chỉ khung 0, và chỉ khi đang ở khung 0: một vòng xoay chạy ticker ở trang
    // bên cạnh là đốt GPU cho thứ không ai nhìn. `PageView` dựng sẵn trang kề,
    // nên nếu không chặn ở đây thì nó thật sự chạy.
    final tt = _turntable;
    if (i == 0 && tt != null && _index == 0) {
      return Padding(
        padding: EdgeInsets.only(
          top: media.padding.top + MuseumTopBar.height,
          bottom: AppSpace.x10,
        ),
        child: TurntableOrPoster(
          frames: tt,
          decodeWidth: (media.size.width * media.devicePixelRatio).round(),
          placeholder: _frameImage(context, frames, i, media),
          onTap: () => _openFrame(context, i),
          semanticLabel:
              context.read<ContentProvider>().ui(UiKeys.exhibitImageOpen),
        ),
      );
    }
    return _frameImage(context, frames, i, media);
  }

  Widget _frameImage(
      BuildContext context, List<String> frames, int i, MediaQueryData media) {
    final content = context.read<ContentProvider>();
    return _Frame(
      path: frames[i],
      // ⚠ HERO CHỈ Ở TRANG ĐANG XEM. Hai cặp tag cùng khớp một lúc thì Flutter
      // không biết chọn cái nào và bay sai khung — nên các trang bên cạnh
      // KHÔNG được đeo tag, dù chúng đã dựng sẵn trong PageView.
      heroTag: i == _index ? heroTagFor(frames[i]) : null,
      // INSET LÀ TRẦN, KHÔNG PHẢI LỀ — và đây là chỗ bản vẽ tự ghi nhận nó đã
      // làm sai một lần. `contain` tự co vật lại cho lọt khung và tự sinh
      // khoảng trống quanh vật theo tỉ lệ từng ảnh; chừa thêm lề cứng nữa là
      // hai lớp lề chồng lên nhau và vật teo lại giữa một sân khấu rộng.
      //
      // Nên chỉ chừa đúng hai chỗ mà CÁI MÁY thật sự chiếm: thanh điều hướng
      // trong suốt ở trên (vật không được chui dưới nút ‹) và vạch chỉ số ở
      // dưới. Hai bên để 0.
      //
      // Bản vẽ ghi 100 cho mép trên; ở đây tính từ vùng an toàn cộng chiều cao
      // thanh, nên nó đúng trên mọi máy thay vì đúng trên đúng một máy.
      topInset: media.padding.top + MuseumTopBar.height,
      onTap: () => _openFrame(context, i),
      // Nhãn của KHUNG nói việc chạm vào nó làm gì; vị trí trong dải do
      // container phía trên báo. Hai vai khác nhau, hai chuỗi khác nhau.
      semanticLabel: content.ui(UiKeys.exhibitImageOpen),
    );
  }

  /// Chạm vào KHUNG ĐẦU của một hiện vật có mô hình ⇒ mở 3D thật.
  ///
  /// `open` trả về false khi không mở được — đã có một khối 3D đang sống, hoặc
  /// máy chưa có file model. Khi đó rơi xuống trình xem ảnh, nên cú chạm LUÔN
  /// dẫn tới một thứ gì đó. Một cú chạm không làm gì cả là lỗi tệ hơn hẳn so
  /// với việc mở nhầm lớp.
  Future<void> _openFrame(BuildContext context, int index) async {
    final model = widget.exhibit.model;
    if (index == 0 && model != null) {
      final opened = await ExhibitModelRoute.open(context, model.id);
      if (opened || !context.mounted) return;
    }
    if (context.mounted) await _openViewer(context, index);
  }

  /// Màn xem lớn trả về trang cuối cùng khách dừng ở đó, và cuộn phim NHẢY
  /// THEO. Không đồng bộ ngược thì khách lật ba tấm trong màn lớn, đóng lại, và
  /// thấy sân khấu vẫn đứng ở tấm đầu — hai chỗ cùng nói về một thứ mà nói lệch
  /// nhau.
  Future<void> _openViewer(BuildContext context, int index) async {
    final landed = await Navigator.of(context).push<int>(MaterialPageRoute<int>(
      fullscreenDialog: true,
      builder: (_) => _Viewer(paths: _frames, initialIndex: index),
    ));
    if (!mounted || landed == null || landed == _index) return;
    setState(() => _index = landed);
    if (_controller.hasClients) _controller.jumpToPage(landed);
  }
}

/// Một khung của cuộn phim. `contain`, không lấp đầy: khách đang nhìn CHÍNH
/// tấm ảnh, và cắt một cái bình gốm cho vừa khung là thứ bảo tàng không làm.
/// Tag của phép nở ảnh từ khung ra màn xem lớn.
///
/// Một hàm dùng chung chứ không phải hai chuỗi gõ ở hai nơi: hợp đồng thật của
/// Hero nằm ở chỗ HAI ĐẦU KHỚP NHAU, và lệch một ký tự thì không có lỗi nào
/// được ném ra — ảnh chỉ lặng lẽ thôi bay.
String heroTagFor(String path) => 'exhibit-image:$path';

/// Bọc Hero khi có tag, trả nguyên widget khi không. Tránh `tag ?? ''` — một
/// tag rỗng vẫn LÀ một tag, và hai trang cùng mang nó sẽ khớp nhầm nhau.
Widget _maybeHero(Object? tag, Widget child) =>
    tag == null ? child : Hero(tag: tag, child: child);

class _Frame extends StatelessWidget {
  final String path;
  final double topInset;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Null ⇒ không đeo Hero. Xem chú giải ở `_StageState._frame`.
  final Object? heroTag;

  const _Frame({
    required this.path,
    required this.topInset,
    required this.onTap,
    required this.semanticLabel,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentProvider>();
    final media = MediaQuery.of(context);

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.only(top: topInset, bottom: AppSpace.x10),
          child: _maybeHero(
            heroTag,
            HeroImage(
              filePath: content.imagePath(path),
              fit: BoxFit.contain,
              cacheWidth: (media.size.width * media.devicePixelRatio).round(),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.sdots` — những đoạn thẳng 18×2, KHÔNG phải chấm tròn.
///
/// Cả app không có hình tròn nào, và vạch thì cùng họ với thanh tiến độ của
/// trình phát ngay bên dưới.
class _Dashes extends StatelessWidget {
  final int count;
  final int index;

  const _Dashes({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
            child: Container(
              width: 18,
              height: 2,
              color: i == index ? t.ink : t.outline,
            ),
          ),
      ],
    );
  }
}

/// Xem một tư liệu ở cỡ lớn. Nền tối đặc — ở đây không còn trang nào, chỉ còn
/// bức ảnh.
class _Viewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _Viewer({required this.paths, required this.initialIndex});

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();

    // PopScope thay cho một nút đóng tự xử lý: khách còn lùi bằng cử chỉ hệ
    // thống và bằng nút back cứng, và cả hai đường đó cũng phải trả về trang
    // cuối cùng. Trả ở một chỗ thì ba lối ra không thể trôi khỏi nhau.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_index);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.paths.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _maybeHero(
                    // Cùng luật với cuộn phim: CHỈ trang đang xem đeo tag.
                    i == _index ? heroTagFor(widget.paths[i]) : null,
                    HeroImage(
                      filePath: content.imagePath(widget.paths[i]),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  // Semantics KHAI TƯỜNG MINH, không dựa vào `tooltip` của
                  // IconButton: tooltip sinh ra nhãn ở một tầng khác và một
                  // finder đọc `properties.label` sẽ không thấy nó. Quan trọng
                  // hơn tooltip là thứ chỉ hiện khi nhấn giữ — nó không phải
                  // hợp đồng với screen reader, chỉ là một tác dụng phụ tiện.
                  child: Semantics(
                    button: true,
                    label: content.ui(UiKeys.exhibitImageClose),
                    excludeSemantics: true,
                    onTap: () => Navigator.of(context).pop(_index),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(_index),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: AppSpace.tap,
                        height: AppSpace.tap,
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.dossier` — nửa dưới.
///
/// KHÔNG có vạch ngăn với sân khấu: sân khấu là một vùng sáng loang dần còn bản
/// lý lịch là mặt `surface` phẳng. Hai chất nền đã khác nhau; kẻ thêm một đường
/// là vẽ lại bằng mực cái ranh giới mắt đã thấy.
class _Dossier extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;

  const _Dossier({required this.zone, required this.exhibit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();

    // `specs` thành MỘT DÒNG, nối các giá trị. Xem khối doc đầu file.
    final meta = exhibit.specs
        .map((s) => content.text(s.value))
        .where((v) => v.isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LanguageStrip(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.text(exhibit.name),
                    style: AppText.heroTitle.copyWith(color: t.ink)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.x2),
                  Text(meta,
                      style: AppText.meta.copyWith(color: t.inkMuted)),
                ],
              ],
            ),
          ),
          _Player(zone: zone, exhibit: exhibit),
          _Script(exhibit: exhibit),
          _Documents(exhibit: exhibit),
        ],
      ),
    );
  }
}

/// `.langs` — dải ngôn ngữ, đặt đúng chỗ vạch ngăn vừa bỏ đi.
///
/// Đó là chỗ của nó VỀ NGHĨA: đổi ngôn ngữ ở đây không phải đổi cài đặt của
/// máy, mà là đổi GIỌNG KỂ của chính hiện vật này — tên, xuất xứ, tiếng thuyết
/// minh và lời kể đều thay theo.
///
/// Không nhãn "Ngôn ngữ" đứng trước: một hàng gồm Tiếng Việt · English · 中文
/// thì tự nó đã là câu hỏi lẫn câu trả lời. Không hộp, không viền, không nền —
/// chỉ chữ, và tiếng đang chọn lấy màu nhấn (accent chỉ báo TRẠNG THÁI, và
/// "tiếng đang chọn" nằm trong danh sách trạng thái được phép dùng nó).
///
/// Cuộn ngang được và không bao giờ xuống dòng: bảo tàng thêm tiếng thứ sáu,
/// thứ bảy thì hàng này DÀI RA chứ không vỡ thành hai tầng làm xô cả khối chữ
/// bên dưới.
class _LanguageStrip extends StatelessWidget {
  const _LanguageStrip();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final lang = context.watch<LanguageController>();
    final codes = lang.available;

    // Một ngôn ngữ thì không có gì để chọn, và một hàng chỉ có "Tiếng Việt"
    // đứng một mình đọc ra là một cái nhãn vô nghĩa.
    if (codes.length < 2) return const SizedBox(height: AppSpace.x5);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter, AppSpace.x3, AppSpace.gutter, AppSpace.x5),
      child: Row(
        children: [
          for (var i = 0; i < codes.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpace.x5),
              child: _LanguageChoice(
                code: codes[i],
                label: content.languageName(codes[i]),
                selected: codes[i] == lang.code,
                onTap: () => lang.setCode(codes[i]),
                accent: t.accent,
                faint: t.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color faint;

  const _LanguageChoice({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.faint,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          maxLines: 1,
          style: AppText.rowLabel.copyWith(
            fontSize: 13,
            color: selected ? accent : faint,
          ),
        ),
      ),
    );
  }
}

/// `.player` — không hộp, không bo góc, không nền nổi.
///
/// Một vạch tiến độ TRÀN HAI MÉP MÁY (nó là một đường kẻ của cái máy, không
/// phải một dòng nội dung), hai con số ở hai đầu, ba nút ở giữa. Thứ bậc do
/// KÍCH THƯỚC gánh: 34 cho nút chính, 22 cho hai nút bên.
class _Player extends StatelessWidget {
  final ZoneInfo zone;
  final ExhibitInfo exhibit;

  const _Player({required this.zone, required this.exhibit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final audio = context.watch<AudioProvider>();
    final state = audio.state;

    final c = state.current;
    final isThis = c != null &&
        !c.isIntro &&
        c.zoneMajor == zone.major &&
        c.exhibitMinor == exhibit.minor;
    final playing = isThis && state.isPlaying;
    final total = isThis ? state.duration : null;

    final idx = zone.tourIndexOf(exhibit.minor);
    final hasPrev = idx > 0;
    final hasNext = idx >= 0 && idx + 1 < zone.exhibits.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x6, bottom: AppSpace.x5),
      child: Column(
        children: [
          // ⚠ StreamBuilder RIÊNG, ở widget nhỏ nhất có thể: `position` nhích
          // vài lần mỗi giây và cố ý không đi qua `notifyListeners`.
          StreamBuilder<Duration>(
            stream: audio.position,
            builder: (context, snap) {
              final pos = isThis ? (snap.data ?? Duration.zero) : Duration.zero;
              final value = (total == null || total.inMilliseconds <= 0)
                  ? 0.0
                  : pos.inMilliseconds / total.inMilliseconds;
              return Column(
                children: [
                  ProgressTrack(
                    value: value,
                    // TUA ĐƯỢC chỉ khi clip NÀY đang nạp và đã biết độ dài —
                    // tua một clip chưa nạp thì không có gì để tua tới, và
                    // `onSeek == null` làm vạch trở lại thuần trưng bày.
                    onSeek: (total == null || !isThis)
                        ? null
                        : (f) => audio.seek(total * f),
                    semanticLabel: content.ui(UiKeys.exhibitProgressLabel),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.gutter, AppSpace.x3, AppSpace.gutter, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos),
                            style: AppText.timeCode
                                .copyWith(color: t.inkFaint, fontSize: 11.5)),
                        Text(_fmt(total ?? Duration.zero),
                            style: AppText.timeCode
                                .copyWith(color: t.inkFaint, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpace.x5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayMark(
                glyph: PlayGlyph.skipPrev,
                size: 22,
                // Hiện vật ĐẦU thì nút tắt, đối xứng với nút phải ở hiện vật
                // cuối. Trước đây nút này không bao giờ tắt vì nó chỉ tua lại
                // clip đang nghe — xem doc [UiKeys.exhibitPrev].
                color: hasPrev ? t.inkMuted : t.ctaDisabled,
                semanticLabel: content.ui(UiKeys.exhibitPrev),
                onTap: hasPrev ? () => _go(context, audio, idx - 1) : null,
              ),
              const SizedBox(width: AppSpace.x8),
              PlayMark(
                glyph: playing ? PlayGlyph.pause : PlayGlyph.play,
                size: PlayMark.main,
                // Nút chính lấy `accent` khi đang phát — accent chỉ báo "cái
                // này ĐANG XẢY RA", và đây đúng là một trạng thái đang xảy ra.
                color: playing ? t.accent : t.ink,
                semanticLabel: content
                    .ui(playing ? UiKeys.exhibitPause : UiKeys.exhibitPlay),
                onTap: () {
                  if (playing) {
                    // Không kèm showAudioFeedback: kết quả nghe thấy tức thì.
                    audio.pause();
                    return;
                  }
                  final r = isThis
                      ? audio.play()
                      : audio.tapExhibit(
                          major: zone.major, minor: exhibit.minor);
                  showAudioFeedback(context, r);
                },
              ),
              const SizedBox(width: AppSpace.x8),
              PlayMark(
                glyph: PlayGlyph.skipNext,
                size: 22,
                // Hiện vật cuối thì nút tắt — `ctaDisabled` có sàn tương phản
                // 3:1 với `inkMuted`, xem test hợp đồng của token.
                color: hasNext ? t.inkMuted : t.ctaDisabled,
                semanticLabel: content.ui(UiKeys.exhibitNext),
                onTap: hasNext ? () => _go(context, audio, idx + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Nhảy tới hiện vật ở vị trí [target] trong thứ tự tour, theo cả hai chiều.
  ///
  /// MỘT HÀM CHO CẢ HAI NÚT. Trước đây chỉ có `_goNext`, còn nút trái đi một
  /// đường hoàn toàn khác (tua lại clip) — và đó chính là lý do hai nút trông
  /// đối xứng mà cư xử lệch nhau.
  void _go(BuildContext context, AudioProvider audio, int target) {
    if (target < 0 || target >= zone.exhibits.length) return;
    final next = zone.exhibits[target];
    // Chạm là một yêu cầu tường minh ⇒ cắt ngang và phát clip được chọn.
    showAudioFeedback(
        context, audio.tapExhibit(major: zone.major, minor: next.minor));
    // THAY THẾ, không chồng: lùi từ bất kỳ hiện vật nào cũng về đúng danh sách,
    // dù khách đã đi qua bao nhiêu hiện vật bằng hai nút này.
    Navigator.of(context).pushReplacementNamed(
      AppRouter.exhibitDetailRoute,
      arguments: ExhibitDetailArgs(major: zone.major, minor: next.minor),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// `.script` — lời kể. 15/1.75, cùng cỡ với thân bài màn Hướng dẫn: khách vừa
/// nghe vừa liếc, mắt không ở yên trên màn nên chữ phải to hơn thân bài thường.
///
/// KHÔNG padding-top: đoạn đầu tiên đã tự mang khe x5 phía trên, cộng thêm nữa
/// thì khe giữa cụm nút và lời kể nở ra tới 56 và cụm nút trông như bị bỏ rơi.
class _Script extends StatelessWidget {
  final ExhibitInfo exhibit;

  const _Script({required this.exhibit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.watch<ContentProvider>();
    final summary = content.text(exhibit.summary);
    final meaning = content.textOrNull(exhibit.meaning);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, content.ui(UiKeys.exhibitSectionIntro)),
          ..._paragraphs(summary, t),
          if (meaning != null && meaning.isNotEmpty) ...[
            const SizedBox(height: AppSpace.x6),
            _label(context, content.ui(UiKeys.exhibitSectionMeaning)),
            ..._paragraphs(meaning, t),
          ],
        ],
      ),
    );
  }

  /// Tách đoạn ở dòng trống — cùng quy ước với mọi trường thân bài khác của
  /// manifest. Một khối chữ 700 ký tự không xuống đoạn thì đọc không nổi trên
  /// điện thoại, và bảo tàng đã viết sẵn chỗ ngắt.
  List<Widget> _paragraphs(String text, MuseumTokens t) => [
        for (final p in text.split(RegExp(r'\n\s*\n')))
          if (p.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.x5),
              child: Text(p.trim(),
                  style: AppText.readingBody.copyWith(color: t.inkMuted)),
            ),
      ];

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.x6),
        child: Text(text.toUpperCase(),
            style: AppText.kicker.copyWith(color: context.tokens.ink)),
      );
}

/// `.exgrid.thumbs` — TƯ LIỆU KHÁC của hiện vật.
///
/// Bản gốc tách làm hai khối có nhãn: "Thư viện hình ảnh" và "Thư viện video".
/// Ở đây là MỘT lưới, không nhãn nào — ô nào đeo dấu phát thì là video, ô nào
/// không đeo thì là ảnh. Hai cái nhãn ấy chỉ nói lại bằng chữ đúng điều mà dấu
/// phát đã nói bằng hình.
///
/// Không lẫn với lưới hiện vật ở màn 4b: BA cột ô 4:3 (thumbnail thì rộng hơn
/// cao) so với HAI cột ô vuông (vuông là tỉ lệ trung tính nhất cho một vật).
/// Khác hình dáng nên khác loại, không cần chữ để phân.
class _Documents extends StatelessWidget {
  final ExhibitInfo exhibit;

  const _Documents({required this.exhibit});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    // Quy tắc ở [ExhibitInfo.documentPaths]: khi hiện vật có mô hình, lưới này
    // bày CẢ ảnh chính — vì cuộn phim ở trên chỉ còn chỗ cho mô hình, và đây
    // thành đường duy nhất tới ảnh của hiện vật.
    final paths = exhibit.documentPaths;

    // Không có tư liệu nào ⇒ không có khối. Một tiêu đề treo trên khoảng trống
    // đọc ra là app hỏng; mà ở đây còn không có cả tiêu đề để treo.
    if (paths.isEmpty) return const SizedBox(height: AppSpace.x10);

    final media = MediaQuery.of(context);
    final cell = (media.size.width - AppSpace.gutter * 2 - AppSpace.x2 * 2) / 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.x10,
          AppSpace.gutter, AppSpace.x12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.x2,
          crossAxisSpacing: AppSpace.x2,
          childAspectRatio: 4 / 3,
        ),
        itemCount: paths.length,
        itemBuilder: (context, i) => _Document(
          path: paths[i],
          decodeWidth: (cell * media.devicePixelRatio).round(),
          label: content.uif(UiKeys.exhibitGalleryPosition,
              {'i': '${i + 1}', 'n': '${paths.length}'}),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _Viewer(paths: paths, initialIndex: i),
          )),
        ),
      ),
    );
  }
}

class _Document extends StatelessWidget {
  final String path;
  final int decodeWidth;
  final String label;
  final VoidCallback onTap;

  const _Document({
    required this.path,
    required this.decodeWidth,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = context.read<ContentProvider>();

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: t.surface,
        child: InkWell(
          onTap: onTap,
          child: HeroImage(
            filePath: content.imagePath(path),
            cacheWidth: decodeWidth,
          ),
        ),
      ),
    );
  }
}
