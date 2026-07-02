import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/modal/share_event_modal.dart';
import 'package:intl/intl.dart';

const _bg        = Color(0xFFF7F8FA);
const _surface   = Color(0xFFFFFFFF);
const _cardBg    = Color(0xFFF4F6F8);
const _border    = Color(0xFFE4E9EE);
const _green     = Color(0xFF2E7D45);
const _greenLt   = Color(0xFFE6F4EB);
const _greenMid  = Color(0xFF4CAF67);
const _amber     = Color(0xFFD97706);
const _amberLt   = Color(0xFFFFF3CD);
const _red       = Color(0xFFD32F2F);
const _redLt     = Color(0xFFFFEBEE);
const _textDark  = Color(0xFF111827);
const _textMid   = Color(0xFF4B5563);
const _textLight = Color(0xFF9CA3AF);
const _pickleballBallAsset = 'assets/pickleball_ball_no_bg_1.png';

class _PickleballImageFallback extends StatelessWidget {
  const _PickleballImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1F14), Color(0xFF1A3D27)],
        ),
      ),
      child: Center(
        child: Image.asset(
          _pickleballBallAsset,
          width: 96,
          height: 96,
          fit: BoxFit.contain,
          opacity: const AlwaysStoppedAnimation(0.9),
        ),
      ),
    );
  }
}

class _S {
  final String lang;
  const _S(this.lang);
  bool get isJa => lang == kLangJa;

  String get loading         => isJa ? 'イベントを読み込み中...'  : 'Loading event...';
  String get notFound        => isJa ? 'イベントが見つかりませんでした' : 'Event not found';
  String get backLabel       => isJa ? 'イベント'              : 'Events';
  String get dateTime        => isJa ? '日時'                  : 'Date & Time';
  String get categories      => isJa ? 'カテゴリ＆スキルレベル'  : 'Categories & Skill Level';
  String get location        => isJa ? '場所'                  : 'Location';
  String get about           => isJa ? 'イベントについて'        : 'About this Event';
  String get organizedBy     => isJa ? '主催者'                : 'Organized by';
  String get entryFee        => isJa ? '参加費'                : 'Entry Fee';
  String get save            => isJa ? '保存'                  : 'Save';
  String get free            => isJa ? '無料'                  : 'Free';
  String get viewMap         => isJa ? 'Googleマップで見る'     : 'View on Google Maps';
  String get ends            => isJa ? '終了日'                : 'Ends';
  String get limit           => isJa ? '定員'                  : 'Participant limit';
  String get contact         => isJa ? '連絡先'                : 'Contact';
  String get loginToSave     => isJa ? '保存するにはログインしてください' : 'Log in to save events';
  String get saveAndMore     => isJa ? '保存＆詳細情報'         : 'Save & More Information';
  String get savedMyEvents   => isJa ? '自己申告で登録済み'      : 'Registered as Self-Reported';
  String get savedInterested => isJa ? 'お気に入りに保存済み'     : 'Saved as Favorite';
  String get updateStatus    => isJa ? 'イベントのステータスを更新' : 'Update Event Status';
  String get saveThisEvent   => isJa ? 'このイベントを保存'     : 'Save this Event';
  String get changeCategory  => isJa ? '保存カテゴリーを変更するか削除します。' : 'Change how this event is saved, or remove it.';
  String get chooseCategory  => isJa ? 'カテゴリーを選択してください。' : "Choose a category to save this event.";
  String get myEventsTitle   => isJa ? '自己申告で登録'          : 'Register as Self-Reported';
  String get myEventsSub     => isJa ? '参加予定のイベント'     : "Events you're planning to join";
  String get interestedTitle => isJa ? 'お気に入り'             : 'Favorite';
  String get interestedSub   => isJa ? '気になるイベント'       : "Events you'd like to keep an eye on";
  String get removeFromSaved => isJa ? '保存済みから削除'       : 'Remove from saved events';
  String get disclaimer      => isJa
      ? 'イベントの詳細は変更または不正確な場合があります。最新情報は公式イベントウェブサイトをご確認ください。'
      : 'Event details may change or be inaccurate. Please refer to the official event website for the most up-to-date information.';
  String get noLocation      => isJa ? '場所未設定'            : 'No location set';
  String get loadingLoc      => isJa ? '読み込み中...'         : 'Loading...';
  String get map             => isJa ? 'マップ'                : 'Map';

  String get tagPro           => isJa ? 'プロ'         : 'PRO';
  String get tagAmateur       => isJa ? 'アマチュア'    : 'AMATEUR';
  String get tagBeginner      => isJa ? '初級者'        : 'BEGINNER';
  String get tagMensSingles   => isJa ? '男子シングルス' : "MEN'S SINGLES";
  String get tagWomensSingles => isJa ? '女子シングルス' : "WOMEN'S SINGLES";
  String get tagMixedDoubles  => isJa ? '混合ダブルス'   : 'MIXED DOUBLES';
  String get tagMensDoubles   => isJa ? '男子ダブルス'   : "MEN'S DOUBLES";
  String get tagWomensDoubles => isJa ? '女子ダブルス'   : "WOMEN'S DOUBLES";
  String get tagJuniors       => isJa ? 'ジュニア'      : 'JUNIORS';
  String get tagCollegiate    => isJa ? '大学生'        : 'COLLEGIATE';
  String get tagSeniors       => isJa ? 'シニア'        : 'SENIORS';

  String get registerSection    => isJa ? '登録'                    : 'Registration';
  String get registerBtn        => isJa ? 'このイベントに登録'        : 'Register for this Event';
  String get registering        => isJa ? '登録中…'                  : 'Registering…';
  String get loginToRegister    => isJa ? '登録にはログインが必要です' : 'Log in to register for events';
  String get registrationClosed => isJa ? '登録終了'                 : 'Registration Closed';
  String get regClosedMsg       => isJa ? '主催者がこのイベントの登録を締め切りました。' : 'The organizer has closed registration for this event.';
  String get regDeadlinePassed  => isJa ? '申し込み締切日を過ぎました。' : 'Registration deadline has passed.';
  String get capacityReached    => isJa ? '定員に達しました'          : 'Maximum Capacity Reached';
  String get capacityMsg        => isJa ? 'このイベントは満席です。ウェイティングリストに登録できます。' : 'This event is full. You can join the waitlist.';
  String get joinWaitlist       => isJa ? 'ウェイティングリストに登録' : 'Join Waitlist';
  String get joiningWaitlist    => isJa ? '登録中…'                  : 'Joining waitlist…';
  String get cancelReg          => isJa ? '登録をキャンセル'          : 'Cancel Registration';
  String get alreadyRegistered  => isJa ? 'このイベントに登録済みです。' : 'You are registered for this event.';
  String get regApprovedMsg     => isJa ? '登録が承認されました！'     : 'Your registration has been approved!';
  String get regRejectedMsg     => isJa ? '登録は承認されませんでした。': 'Your registration was not approved.';
  String get regWaitlistMsg     => isJa ? 'ウェイティングリストに登録しました。' : "You're on the waitlist. We'll notify you if a spot opens.";
  String get regPending         => isJa ? '登録中（承認待ち）'         : 'Registration Pending';
  String get regApproved        => isJa ? '登録承認済み'              : 'Registration Approved';
  String get regRejected        => isJa ? '登録却下'                  : 'Registration Rejected';
  String get regWaitlist        => isJa ? 'ウェイティングリスト待機中'  : 'On Waitlist';
  String get cancelRegTitle     => isJa ? '登録をキャンセルしますか？' : 'Cancel your registration?';
  String get cancelRegBody      => isJa ? 'このイベントから登録が削除されます。' : 'This will remove your registration from this event.';
  String get isOrganizer        => isJa ? 'あなたが主催するイベント'   : 'You are the organizer';
  String get organizerNote      => isJa ? '自分のイベントへの登録は不要です。' : 'Registration is not required for your own event.';
  String get filled             => isJa ? '名参加中'                  : 'filled';
  String get full               => isJa ? '満席'                     : 'Full';
  String slotsLeft(int n)       => isJa ? '残り$n枠' : n == 1 ? '1 spot left' : '$n spots left';
  String get goToRegistrationPage => isJa ? '登録ページへ移動'         : 'Go to Registration Page';

  String get regFormTitle    => isJa ? 'イベント登録'   : 'Register for this Event';
  String get regFormSubtitle => isJa ? '以下のフォームにご記入の上、登録してください。' : 'Fill in your details to submit your registration.';
  String get stepDetails     => isJa ? '基本情報'       : 'Details';
  String get stepPayment     => isJa ? 'お支払い方法'    : 'Payment';
  String get stepConfirm     => isJa ? '確認'           : 'Confirm';
  String get nameLbl         => isJa ? 'お名前'         : 'Full Name';
  String get emailLbl        => isJa ? 'メールアドレス'  : 'Email Address';
  String get phoneLbl        => isJa ? '電話番号（任意）': 'Phone Number (optional)';
  String get notesLbl        => isJa ? 'メッセージ / 備考（任意）' : 'Message / Notes (optional)';
  String get namePh          => isJa ? '山田 太郎'      : 'Your full name';
  String get emailPh         => isJa ? 'example@email.com' : 'you@example.com';
  String get phonePh         => isJa ? '+81 90-0000-0000'  : '+81 90-0000-0000';
  String get notesPh         => isJa ? 'ご質問やご要望をどうぞ…' : 'Any questions or special requests…';
  String get cancel          => isJa ? 'キャンセル'     : 'Cancel';
  String get back            => isJa ? '戻る'          : 'Back';
  String get next            => isJa ? '次へ'          : 'Next';
  String get submit          => isJa ? '登録を送信'     : 'Submit Registration';
  String get submitting      => isJa ? '送信中…'        : 'Submitting…';
  String get confirmSubtitle => isJa ? '以下の内容で登録を送信します。' : 'Please review your details before submitting.';
  String get paymentMethod   => isJa ? 'お支払い方法'   : 'Payment Method';
  String get directPayment   => isJa ? '現地支払い / 直接支払い' : 'Direct / On-site Collection';
  String get notProvided     => isJa ? '未入力'         : 'Not provided';
  String get none            => isJa ? 'なし'           : 'None';
  String get importantNote   => isJa ? '注意事項'       : 'Important Note';
  String get paymentNote     => isJa ? '*現時点ではアプリ内での決済は行われません。参加費は参加者から直接回収してください。' : '*Payment is not collected through the app at this time. Please collect fees directly from participants.';
  String get directActive    => isJa ? '選択中'         : 'Active';
  String get creditCard      => isJa ? 'クレジットカード・デビットカード' : 'Credit / Debit Card';
  String get comingSoon      => isJa ? '近日対応'        : 'Soon';
  String get stripeNote      => isJa ? 'Stripeを利用した安全なアプリ内オンライン決済が間もなく登場します。' : 'Secure on-app online payment via Stripe is coming soon.';

  String regSuccessTitle(bool waitlist) => waitlist
      ? (isJa ? 'ウェイティングリストに登録されました！' : 'Added to Waitlist!')
      : (isJa ? '登録申請を送信しました！' : 'Registration Request Submitted!');
  String regSuccessBody(bool waitlist) => waitlist
      ? (isJa ? 'ウェイティングリストに登録されました。空きが出た場合に通知されます。' : 'You have been added to the waitlist. You will be notified if a spot opens up.')
      : (isJa ? '登録申請を受け付けました。主催者による承認をお待ちください。' : 'Your registration is now pending review by the organizer. You will be notified once your status is updated.');
  String get currentStatus => isJa ? '現在のステータス' : 'Current Status';
  String get pendingStatus => isJa ? '承認待ち' : 'PENDING APPROVAL';
  String get waitlistStatus=> isJa ? 'キャンセル待ち' : 'ON WAITLIST';
  String get close         => isJa ? '閉じる' : 'Close';

  String localizeType(String key) {
    if (!isJa) return key;
    const m = {
      'Professional Tournament':       'プロトーナメント',
      'Global Tournament':             'グローバルトーナメント',
      'Japan Tournament':              '日本トーナメント',
      'Open Play':                     'オープンプレイ',
      'Trial Session':                 '体験セッション',
      'Local Event':                   'ローカルイベント',
      'Lessons/Clinics':               'レッスン・クリニック',
      'Weekly Play / Recurring Play':  '定期プレイ',
      'Tournament':                    'トーナメント',
      'Camp/Lesson':                   'キャンプ/レッスン',
      'Social':                        'ソーシャル',
      'Other':                         'その他',
    };
    return m[key] ?? key;
  }
}

enum _SaveStatus { none, myEvents, interested }
enum _RegStatus  { none, pending, approved, rejected, waitlist }

class EventDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  GoogleMapController? _mapController;
  _SaveStatus _saveStatus  = _SaveStatus.none;
  bool        _saveLoading = true;

  _RegStatus _regStatus    = _RegStatus.none;
  String?    _regDocId;
  bool       _regLoading   = false;
  int?       _dbApprovedCount;

  _S get s => _S(ref.watch(appLangProvider));

  String get locId => (widget.event['event_loc_id'] ?? '').toString();

  // ── FIX: also check '_id' which is used when navigating from the
  //         OrganizerDashboard's Registered tab (the map key is '_id'
  //         because it's built from event_registrations + events docs).
  String get eventId {
    final docId = (widget.event['_doc_id'] ?? '').toString().trim();
    if (docId.isNotEmpty) return docId;
    final id = (widget.event['id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    // '_id' is the key used in _RegisteredTab when the event map is assembled
    // from event_registrations + events Firestore documents.
    final underscoreId = (widget.event['_id'] ?? '').toString().trim();
    if (underscoreId.isNotEmpty) return underscoreId;
    return (widget.event['event_id'] ?? '').toString().trim();
  }

  String get _registrationType =>
      (widget.event['registration_type'] ?? 'pikuru').toString().trim();

  bool get _isPikuruReg  => _registrationType != 'external';
  bool get _isExternalReg => _registrationType == 'external';

  String get _externalRegistrationLink {
    final raw = (widget.event['external_registration_link'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    return raw.startsWith('http') ? raw : 'https://$raw';
  }

  int? get _eventLimit => widget.event['event_limit'] != null
      ? int.tryParse(widget.event['event_limit'].toString())
      : null;

  int get _approvedCount =>
      _dbApprovedCount ?? (widget.event['event_approved_count'] ?? 0) as int;

  bool get _isFull =>
      _eventLimit != null && _approvedCount >= _eventLimit!;

  bool get _regOpen =>
      widget.event['event_registration_open'] != false &&
          !_isRegistrationDeadlinePassed;

  DateTime? get _registrationDeadline {
    final raw = widget.event['registration_deadline'];
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool get _isRegistrationDeadlinePassed {
    final d = _registrationDeadline;
    return d != null && DateTime.now().isAfter(d);
  }

  bool get _isEventOwner {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final submittedBy = (widget.event['submittedBy'] ?? '').toString().trim();
    return uid != null && uid.isNotEmpty && submittedBy.isNotEmpty && submittedBy == uid;
  }

  @override
  void initState() {
    super.initState();
    _loadSaveStatus();
    _loadRegStatus();
    _loadApprovedCount();
  }

  Future<void> _loadApprovedCount() async {
    if (eventId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: eventId)
          .where('status', isEqualTo: 'approved')
          .get();
      if (mounted) setState(() => _dbApprovedCount = snap.docs.length);
    } catch (_) {}
  }

  Future<void> _loadSaveStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) {
      setState(() => _saveLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_events').doc('${uid}_$eventId').get();
      if (doc.exists) {
        final status = (doc.data()?['status'] ?? '').toString();
        setState(() => _saveStatus = status == 'my_events'
            ? _SaveStatus.myEvents
            : status == 'interested' ? _SaveStatus.interested : _SaveStatus.none);
      }
    } catch (_) {}
    if (mounted) setState(() => _saveLoading = false);
  }

  Future<void> _loadRegStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) return;
    try {
      final q = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: eventId)
          .where('user_id', isEqualTo: uid)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return;
      final d = q.docs.first;
      if (mounted) {
        setState(() {
          _regDocId = d.id;
          final s = (d.data()['status'] ?? '').toString();
          _regStatus = s == 'approved' ? _RegStatus.approved
              : s == 'rejected'  ? _RegStatus.rejected
              : s == 'waitlist'  ? _RegStatus.waitlist
              : _RegStatus.pending;
        });
      }
    } catch (_) {}
  }

  Future<void> _setSaveStatus(_SaveStatus next) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _saveStatus = next);
    final docRef = FirebaseFirestore.instance
        .collection('user_events').doc('${uid}_$eventId');
    if (next == _SaveStatus.none) {
      await docRef.delete();
    } else {
      await docRef.set({
        'user_id':     uid,
        'event_id':    eventId,
        'status':      next == _SaveStatus.myEvents ? 'my_events' : 'interested',
        'event_title': widget.event['event_title'] ?? '',
        'event_pic':   widget.event['event_pic']   ?? '',
        'saved_at':    FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _submitRegistration({
    required String name,
    required String email,
    required String phone,
    required String notes,
    required bool asWaitlist,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || eventId.isEmpty) return;

    setState(() => _regLoading = true);
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('event_registrations')
          .add({
        'event_id':      eventId,
        'user_id':       user.uid,
        'user_name':     name.isNotEmpty ? name : (user.displayName ?? ''),
        'user_email':    email.isNotEmpty ? email : (user.email ?? ''),
        'user_phone':    phone,
        'user_notes':    notes,
        'user_avatar':   user.photoURL ?? '',
        'status':        asWaitlist ? 'waitlist' : 'pending',
        'registered_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _regDocId = docRef.id;
          _regStatus = asWaitlist ? _RegStatus.waitlist : _RegStatus.pending;
        });
        _showSuccessModal(asWaitlist);
      }
    } catch (e) {
      debugPrint('[EventDetail] _submitRegistration error: $e');
    } finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  Future<void> _cancelRegistration() async {
    if (_regDocId == null) return;
    setState(() => _regLoading = true);
    try {
      if (_regStatus == _RegStatus.approved && eventId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('events').doc(eventId)
            .update({'event_approved_count': FieldValue.increment(-1)})
            .catchError((_) {});
        if (_dbApprovedCount != null) {
          setState(() => _dbApprovedCount = (_dbApprovedCount! - 1).clamp(0, 9999));
        }
      }
      await FirebaseFirestore.instance
          .collection('event_registrations').doc(_regDocId!).delete();
      setState(() { _regStatus = _RegStatus.none; _regDocId = null; });
    } catch (_) {} finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  String _formatDate(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp)            dt = raw.toDate();
    else if (raw is String && raw.isNotEmpty) {
      try { dt = DateTime.parse(raw); } catch (_) {}
    }
    if (dt == null) return '';
    if (s.isJa) {
      const wd = ['月','火','水','木','金','土','日'];
      return '${dt.year}年${dt.month}月${dt.day}日(${wd[dt.weekday-1]})';
    }
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }

  String _formatTime(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp)            dt = raw.toDate();
    else if (raw is String && raw.isNotEmpty) return raw;
    if (dt == null) return '';
    if (s.isJa) return '${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
    return DateFormat('h:mm a').format(dt);
  }

  String _formatFee(dynamic fee) {
    if (fee == null) return s.free;
    final v = fee.toString();
    if (v.isEmpty || v == '0' || v == '0.0') return s.free;
    return '¥$v';
  }

  double? _parseCoord(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  void _showSaveSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SaveBottomSheet(
        s: s,
        currentStatus: _saveStatus,
        onSelect: (status) async {
          Navigator.pop(context);
          await _setSaveStatus(status);
        },
        onRemove: () async {
          Navigator.pop(context);
          await _setSaveStatus(_SaveStatus.none);
        },
      ),
    );
  }

  void _showRegistrationForm({required bool asWaitlist}) {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => _RegistrationFormSheet(
        s: s,
        defaultName:  user?.displayName ?? '',
        defaultEmail: user?.email ?? '',
        asWaitlist: asWaitlist,
        onSubmit: (name, email, phone, notes) async {
          Navigator.pop(context);
          await _submitRegistration(
              name: name, email: email,
              phone: phone, notes: notes,
              asWaitlist: asWaitlist);
        },
      ),
    );
  }

  void _showCancelConfirm() {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: s.cancelRegTitle,
        body: s.cancelRegBody,
        confirmLabel: s.cancelReg,
        confirmColor: _red,
        onConfirm: () { Navigator.pop(context); _cancelRegistration(); },
        onCancel:  () => Navigator.pop(context),
      ),
    );
  }

  void _showSuccessModal(bool waitlist) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SuccessDialog(s: s, isWaitlist: waitlist),
    );
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<Map<String, dynamic>?> _fetchLocation() async {
    if (locId.isEmpty) return null;
    try {
      final q = await FirebaseFirestore.instance
          .collection('locations').where('loc_id', isEqualTo: locId).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
      final d = await FirebaseFirestore.instance.collection('locations').doc(locId).get();
      if (d.exists) return d.data();
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOrganizer() async {
    final orgId = (widget.event['event_org_id'] ?? '').toString();
    if (orgId.isEmpty) return null;
    try {
      final q = await FirebaseFirestore.instance
          .collection('organizations').where('org_id', isEqualTo: orgId).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
      final d = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
      if (d.exists) return d.data();
    } catch (_) {}
    return null;
  }

  @override
  void dispose() { _mapController?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLangProvider);
    final e         = widget.event;
    final title     = s.isJa
        ? (e['event_title_jp'] ?? e['event_title'] ?? 'Untitled').toString()
        : (e['event_title'] ?? 'Untitled').toString();
    final desc      = s.isJa
        ? (e['event_description_jp'] ?? e['event_description_en'] ?? e['event_description'] ?? '').toString()
        : (e['event_description_en'] ?? e['event_description'] ?? '').toString();
    final imageUrl  = (e['event_pic'] ?? e['event_pic_thumbnail'] ?? '').toString();
    final rawType   = (e['event_type'] ?? '').toString();
    final dateStr   = _formatDate(e['event_date']);
    final timeStr   = _formatTime(e['event_time']);
    final endDateStr= _formatDate(e['event_date_end']);
    final feeStr    = _formatFee(e['event_fee']);
    final limitStr  = e['event_limit'] != null ? e['event_limit'].toString() : '';
    final contactStr= (e['event_contact'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _green,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => ShareEventModal.show(context, event: e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _PickleballImageFallback(),
                      )
                    : const _PickleballImageFallback(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                if (rawType.isNotEmpty)
                  Positioned(
                    bottom: 16, left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.localizeType(rawType).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                if (_isRegistrationDeadlinePassed)
                  Positioned(
                    top: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _amber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            s.registrationClosed.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                            color: _textDark, height: 1.25, letterSpacing: -0.3)),



                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _sectionLabel(s.dateTime),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icon(Icons.calendar_today_rounded, color: _green, size: 20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(dateStr, style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(timeStr, style: const TextStyle(
                                fontSize: 14, color: _textMid, fontWeight: FontWeight.w500)),
                          ],
                          if (endDateStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('${s.ends}: $endDateStr',
                                style: const TextStyle(fontSize: 13, color: _textLight)),
                          ],
                          if (_isPikuruReg && limitStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('${s.limit}: $limitStr',
                                style: const TextStyle(fontSize: 13, color: _textLight)),
                          ],
                          if (_isPikuruReg && _eventLimit != null) ...[
                            const SizedBox(height: 12),
                            _CapacityBar(
                              s: s,
                              approvedCount: _approvedCount,
                              eventLimit: _eventLimit!,
                            ),
                          ],
                          if (contactStr.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('${s.contact}: $contactStr',
                                style: const TextStyle(fontSize: 13, color: _textLight)),
                          ],
                        ]),
                      ),
                    ],

                    const SizedBox(height: 18),
                    _buildTags(),
                  ],
                )),

                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLocation(),
                  builder: (context, snap) {
                    final loc = snap.data;
                    final locName = s.isJa
                        ? (loc?['loc_name_jp'] ?? loc?['loc_name'] ?? '').toString()
                        : (loc?['loc_name'] ?? '').toString();
                    final locAddress = s.isJa
                        ? (loc?['loc_address_jp'] ?? loc?['loc_address'] ?? '').toString()
                        : (loc?['loc_address'] ?? '').toString();
                    final googleLink = (loc?['loc_googlelink'] ?? '').toString();
                    final lat = _parseCoord(loc?['loc_latitude']);
                    final lng = _parseCoord(loc?['loc_longitude']);
                    final isLoading = snap.connectionState == ConnectionState.waiting;

                    return _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(s.location),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icon(Icons.location_on_rounded, color: _green, size: 20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (locName.isNotEmpty)
                              Text(locName, style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700, color: _textDark)),
                            if (locAddress.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(locAddress, style: const TextStyle(
                                  fontSize: 13, color: _textMid)),
                            ],
                            if (locName.isEmpty && locAddress.isEmpty)
                              Text(isLoading ? s.loadingLoc : s.noLocation,
                                  style: const TextStyle(fontSize: 14, color: _textLight)),
                          ]),
                          trailing: (lat != null && lng != null)
                              ? GestureDetector(
                              onTap: () => _openGoogleMaps(lat, lng),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: _green, shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                              ))
                              : null,
                        ),
                        if (googleLink.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse(googleLink),
                                mode: LaunchMode.externalApplication),
                            child: Row(children: [
                              Icon(Icons.map_rounded, color: _green, size: 14),
                              const SizedBox(width: 6),
                              Text(s.viewMap, style: const TextStyle(
                                  fontSize: 13, color: _green,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline)),
                            ]),
                          ),
                        ],
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 16),
                          _sectionLabel(s.map),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _openGoogleMaps(lat, lng),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 180,
                                child: AbsorbPointer(
                                  child: GoogleMap(
                                    initialCameraPosition:
                                    CameraPosition(target: LatLng(lat, lng), zoom: 15),
                                    markers: {Marker(
                                        markerId: const MarkerId('loc'),
                                        position: LatLng(lat, lng))},
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    myLocationButtonEnabled: false,
                                    onMapCreated: (c) => _mapController = c,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ));
                  },
                ),

                if (desc.isNotEmpty)
                  _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(s.about),
                      const SizedBox(height: 10),
                      Text(desc, style: const TextStyle(
                          fontSize: 14, color: _textMid, height: 1.65)),
                    ],
                  )),

                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchOrganizer(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting ||
                        snap.data == null) return const SizedBox.shrink();
                    final org = snap.data!;
                    final orgName = s.isJa
                        ? (org['org_name_jp'] ?? org['org_name'] ?? '').toString()
                        : (org['org_name'] ?? '').toString();
                    final orgLogo = (org['org_image'] ?? org['org_logo'] ?? '').toString();
                    if (orgName.isEmpty) return const SizedBox.shrink();
                    return _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(s.organizedBy),
                        const SizedBox(height: 12),
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: orgLogo.isNotEmpty
                                ? Image.network(orgLogo, width: 48, height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _orgPlaceholder())
                                : _orgPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(orgName,
                              style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w700, color: _textDark))),
                        ]),
                      ],
                    ));
                  },
                ),

                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(s.entryFee),
                    const SizedBox(height: 6),
                    Text(feeStr,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: feeStr == s.free ? _greenMid : _textDark)),
                  ],
                )),

                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(s.save),
                    const SizedBox(height: 12),
                    _saveLoading
                        ? const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: CircularProgressIndicator(strokeWidth: 2)))
                        : _buildSaveWidget(),
                    if (FirebaseAuth.instance.currentUser == null) ...[
                      const SizedBox(height: 8),
                      Text(s.loginToSave,
                          style: const TextStyle(fontSize: 12, color: _textLight)),
                    ],
                  ],
                )),

                // ── Registration card ──────────────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(s.registerSection),
                    const SizedBox(height: 12),
                    _buildRegistrationWidget(),
                  ],
                )),

                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  color: _surface,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: _textLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.disclaimer,
                        style: const TextStyle(fontSize: 12, color: _textLight, height: 1.5))),
                  ]),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveWidget() {
    return Column(children: [
      _SaveTile(
        icon: Icons.bookmark_rounded,
        iconColor: _green,
        title: s.myEventsTitle,
        subtitle: s.myEventsSub,
        isSelected: _saveStatus == _SaveStatus.myEvents,
        onTap: () {
          HapticFeedback.lightImpact();
          if (_saveStatus == _SaveStatus.myEvents) {
            _showSaveSheet();
          } else {
            _setSaveStatus(_SaveStatus.myEvents);
          }
        },
      ),
      const SizedBox(height: 10),
      _SaveTile(
        icon: Icons.star_rounded,
        iconColor: _amber,
        title: s.interestedTitle,
        subtitle: s.interestedSub,
        isSelected: _saveStatus == _SaveStatus.interested,
        onTap: () {
          HapticFeedback.lightImpact();
          if (_saveStatus == _SaveStatus.interested) {
            _showSaveSheet();
          } else {
            _setSaveStatus(_SaveStatus.interested);
          }
        },
      ),
    ]);
  }

  // ── Registration widget ───────────────────────────────────────────────────
  // Priority order mirrors the web app exactly:
  //   1. Organizer viewing own event  → organizer banner
  //   2. Not logged in                → login prompt
  //   3. External registration_type   → "Go to Registration Page" button
  //   4. Registration closed          → closed banner
  //   5a. Approved                    → ✅ green approved banner ONLY (no cancel)
  //   5b. Pending / Rejected          → status banner + cancel button
  //   5c. Waitlist                    → status banner + cancel button
  //   6. Full + pikuru                → capacity banner + Join Waitlist
  //   7. Normal                       → Register button
  Widget _buildRegistrationWidget() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // ── 1. Organizer ─────────────────────────────────────────────────────────
    if (_isEventOwner) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _greenLt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: _green.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, color: _green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.isOrganizer,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
            const SizedBox(height: 2),
            Text(s.organizerNote,
                style: const TextStyle(fontSize: 12, color: _textMid)),
          ])),
        ]),
      );
    }

    // ── 2. Not logged in ──────────────────────────────────────────────────────
    if (uid == null) {
      return Text(s.loginToRegister,
          style: const TextStyle(fontSize: 13, color: _textLight));
    }

    // ── 3. External registration ──────────────────────────────────────────────
    if (_isExternalReg) {
      final extLink = _externalRegistrationLink;
      return GestureDetector(
        onTap: extLink.isNotEmpty ? () => _openUrl(extLink) : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _green.withOpacity(0.28),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(s.goToRegistrationPage,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      );
    }

    // ── From here: pikuru in-app registration ─────────────────────────────────

    // ── 4. Registration closed ────────────────────────────────────────────────
    // Mirrors web app: show the "Registration Closed" banner at the top, then
    // STILL show the user's registration status banner below (e.g. "Registration
    // Approved") if they already have one. Both stack together — closed banner
    // does NOT replace the status.
    if (!_regOpen) {
      final closedBanner = _StatusBanner(
        icon: Icons.lock_rounded,
        iconColor: _textMid,
        bgColor: _cardBg,
        borderColor: _border,
        title: s.registrationClosed,
        subtitle: _isRegistrationDeadlinePassed ? s.regDeadlinePassed : s.regClosedMsg,
      );

      if (_regStatus == _RegStatus.approved) {
        return Column(children: [
          closedBanner,
          const SizedBox(height: 10),
          _ApprovedBanner(s: s),
        ]);
      }
      if (_regStatus != _RegStatus.none) {
        return Column(children: [
          closedBanner,
          const SizedBox(height: 10),
          _regStatusBanner(),
        ]);
      }
      return closedBanner;
    }

    // ── 5a. APPROVED — show prominent green banner, no cancel button ──────────
    // Mirrors web app: approved status shows the checkmark banner with
    // "Registration Approved / Your registration has been approved!" and
    // NO cancel button (approved registrations cannot be self-cancelled).
    if (_regStatus == _RegStatus.approved) {
      return _ApprovedBanner(s: s);
    }

    // ── 5b/c. Pending / Rejected / Waitlist ───────────────────────────────────
    if (_regStatus != _RegStatus.none) {
      return Column(children: [
        _regStatusBanner(),
        if (_regStatus == _RegStatus.pending ||
            _regStatus == _RegStatus.rejected ||
            _regStatus == _RegStatus.waitlist) ...[
          const SizedBox(height: 10),
          _OutlineButton(
            label: s.cancelReg,
            color: _red,
            icon: Icons.cancel_outlined,
            loading: _regLoading,
            onTap: _showCancelConfirm,
          ),
        ],
      ]);
    }

    // ── 6. Full — show waitlist button ────────────────────────────────────────
    if (_isFull) {
      return Column(children: [
        _StatusBanner(
          icon: Icons.people_alt_rounded,
          iconColor: _red,
          bgColor: _redLt,
          borderColor: _red.withOpacity(0.25),
          title: s.capacityReached,
          subtitle: s.capacityMsg,
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: _regLoading ? s.joiningWaitlist : s.joinWaitlist,
          color: _amber,
          icon: Icons.schedule_rounded,
          loading: _regLoading,
          onTap: () => _showRegistrationForm(asWaitlist: true),
        ),
      ]);
    }

    // ── 7. Normal register button ─────────────────────────────────────────────
    return _PrimaryButton(
      label: _regLoading ? s.registering : s.registerBtn,
      color: _green,
      icon: Icons.how_to_reg_rounded,
      loading: _regLoading,
      onTap: () => _showRegistrationForm(asWaitlist: false),
    );
  }

  Widget _regStatusBanner() {
    Color color;
    Color bg;
    Color border;
    IconData icon;
    String title;
    String subtitle;

    switch (_regStatus) {
      case _RegStatus.approved:
        color = _green; bg = _greenLt; border = _green.withOpacity(0.3);
        icon = Icons.check_circle_rounded;
        title = s.regApproved; subtitle = s.regApprovedMsg;
      case _RegStatus.rejected:
        color = _red; bg = _redLt; border = _red.withOpacity(0.3);
        icon = Icons.cancel_rounded;
        title = s.regRejected; subtitle = s.regRejectedMsg;
      case _RegStatus.waitlist:
        color = _amber; bg = _amberLt; border = _amber.withOpacity(0.3);
        icon = Icons.schedule_rounded;
        title = s.regWaitlist; subtitle = s.regWaitlistMsg;
      default:
        color = _amber; bg = _amberLt; border = _amber.withOpacity(0.3);
        icon = Icons.pending_rounded;
        title = s.regPending; subtitle = s.alreadyRegistered;
    }

    return _StatusBanner(
      icon: icon, iconColor: color, bgColor: bg, borderColor: border,
      title: title, subtitle: subtitle,
    );
  }

  Widget _buildTags() {
    final e = widget.event;
    final tags = <String>[];
    if (e['event_skill_level_pro']       == true) tags.add(s.tagPro);
    if (e['event_skill_level_amateur']    == true) tags.add(s.tagAmateur);
    if (e['event_skill_level_beginner']   == true) tags.add(s.tagBeginner);
    if (e['event_category_menssingle']    == true) tags.add(s.tagMensSingles);
    if (e['event_category_womenssingle']  == true) tags.add(s.tagWomensSingles);
    if (e['event_category_mixeddoubles']  == true) tags.add(s.tagMixedDoubles);
    if (e['event_category_mensdoubles']   == true) tags.add(s.tagMensDoubles);
    if (e['event_category_womensdoubles'] == true) tags.add(s.tagWomensDoubles);
    if (e['event_category_juniors']       == true) tags.add(s.tagJuniors);
    if (e['event_category_collegiate']    == true) tags.add(s.tagCollegiate);
    if (e['event_category_seniors']       == true) tags.add(s.tagSeniors);
    if (tags.isEmpty) {
      final old = (e['event_skill_level'] ?? '').toString();
      if (old.isNotEmpty) tags.add(old.toUpperCase());
    }
    if (tags.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(s.categories),
      const SizedBox(height: 10),
      Wrap(spacing: 7, runSpacing: 7,
          children: tags.map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _greenLt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green.withOpacity(0.2)),
            ),
            child: Text(tag, style: const TextStyle(
                color: _green, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          )).toList()),
    ]);
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity, color: _surface,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    child: child,
  );

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: _green, letterSpacing: 0.8));

  Widget _orgPlaceholder() => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      color: _greenLt,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.groups_rounded, color: _green, size: 26),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Approved banner — mirrors web app "Registration Approved" green card exactly
// ═════════════════════════════════════════════════════════════════════════════
class _ApprovedBanner extends StatelessWidget {
  final _S s;
  const _ApprovedBanner({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: _greenLt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: _green,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.regApproved,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _green,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.regApprovedMsg,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textMid,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Capacity bar
// ═════════════════════════════════════════════════════════════════════════════
class _CapacityBar extends StatelessWidget {
  final _S s;
  final int approvedCount;
  final int eventLimit;
  const _CapacityBar({required this.s, required this.approvedCount, required this.eventLimit});

  @override
  Widget build(BuildContext context) {
    final pct = (approvedCount / eventLimit).clamp(0.0, 1.0);
    final slotsLeft = (eventLimit - approvedCount).clamp(0, 9999);
    final isFull = approvedCount >= eventLimit;
    final fillColor = pct >= 0.9 ? _red : pct >= 0.7 ? _amber : _greenMid;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$approvedCount / $eventLimit ${s.filled}',
            style: const TextStyle(fontSize: 11, color: _textLight, fontWeight: FontWeight.w500)),
        const Spacer(),
        if (isFull)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _redLt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(s.full,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _red)),
          )
        else
          Text(s.slotsLeft(slotsLeft),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fillColor)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 5,
          backgroundColor: _border,
          valueColor: AlwaysStoppedAnimation<Color>(fillColor),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Info row helper
// ═════════════════════════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final Widget icon;
  final Widget child;
  final Widget? trailing;
  const _InfoRow({required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: _greenLt, borderRadius: BorderRadius.circular(10)),
        child: Center(child: icon),
      ),
      const SizedBox(width: 12),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: child)),
      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Save tile
// ═════════════════════════════════════════════════════════════════════════════
class _SaveTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _SaveTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isSelected ? iconColor.withOpacity(0.07) : _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? iconColor.withOpacity(0.4) : _border,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(isSelected ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: isSelected ? iconColor : _textDark)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _textLight)),
        ])),
        isSelected
            ? Icon(Icons.check_circle_rounded, color: iconColor, size: 20)
            : Icon(Icons.chevron_right_rounded, color: _textLight, size: 20),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Status banner
// ═════════════════════════════════════════════════════════════════════════════
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor, borderColor;
  final String title, subtitle;
  const _StatusBanner({required this.icon, required this.iconColor,
    required this.bgColor, required this.borderColor,
    required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: iconColor)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: _textMid)),
      ])),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Primary button
// ═════════════════════════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.color,
    required this.icon, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (loading)
          const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        else
          Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Outline button
// ═════════════════════════════════════════════════════════════════════════════
class _OutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.color,
    required this.icon, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Confirm dialog
// ═════════════════════════════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final String title, body, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm, onCancel;
  const _ConfirmDialog({required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor,
    required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title, style: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
    content: Text(body, style: const TextStyle(fontSize: 14, color: _textMid)),
    actions: [
      TextButton(onPressed: onCancel, child: Text('Cancel',
          style: TextStyle(color: _textMid, fontWeight: FontWeight.w600))),
      TextButton(onPressed: onConfirm, child: Text(confirmLabel,
          style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700))),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Success dialog
// ═════════════════════════════════════════════════════════════════════════════
class _SuccessDialog extends StatelessWidget {
  final _S s;
  final bool isWaitlist;
  const _SuccessDialog({required this.s, required this.isWaitlist});

  @override
  Widget build(BuildContext context) {
    final accent = isWaitlist ? _amber : _green;
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(isWaitlist ? Icons.schedule_rounded : Icons.check_rounded,
                color: accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(s.regSuccessTitle(isWaitlist),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 8),
          Text(s.regSuccessBody(isWaitlist),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textMid, height: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.2), style: BorderStyle.solid),
            ),
            child: Column(children: [
              Text(s.currentStatus,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _textLight, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(isWaitlist ? s.waitlistStatus : s.pendingStatus,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                        color: accent, letterSpacing: 0.5)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(s.close, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Registration form — 3-step bottom sheet
// ═════════════════════════════════════════════════════════════════════════════
class _RegistrationFormSheet extends StatefulWidget {
  final _S s;
  final String defaultName, defaultEmail;
  final bool asWaitlist;
  final void Function(String name, String email, String phone, String notes) onSubmit;
  const _RegistrationFormSheet({
    required this.s, required this.defaultName, required this.defaultEmail,
    required this.asWaitlist, required this.onSubmit,
  });

  @override
  State<_RegistrationFormSheet> createState() => _RegistrationFormSheetState();
}

class _RegistrationFormSheetState extends State<_RegistrationFormSheet> {
  int _step = 1;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.defaultName);
    _emailCtrl = TextEditingController(text: widget.defaultEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _greenLt, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.how_to_reg_rounded, color: _green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.regFormTitle, style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
                Text(s.regFormSubtitle, style: const TextStyle(
                    fontSize: 11, color: _textLight)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _cardBg, shape: BoxShape.circle,
                      border: Border.all(color: _border)),
                  child: const Icon(Icons.close_rounded, size: 16, color: _textMid),
                ),
              ),
            ]),
          ),
          _StepBar(step: _step, s: s),
          const Divider(height: 1, color: _border),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Form(
                key: _formKey,
                child: _step == 1 ? _buildStep1(s)
                    : _step == 2 ? _buildStep2(s)
                    : _buildStep3(s),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStep1(_S s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FormField(label: s.nameLbl, controller: _nameCtrl,
          placeholder: s.namePh, required: true),
      const SizedBox(height: 16),
      _FormField(label: s.emailLbl, controller: _emailCtrl,
          placeholder: s.emailPh, required: true,
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _FormField(label: s.phoneLbl, controller: _phoneCtrl,
          placeholder: s.phonePh, required: false,
          keyboardType: TextInputType.phone),
      const SizedBox(height: 16),
      _FormField(label: s.notesLbl, controller: _notesCtrl,
          placeholder: s.notesPh, required: false, maxLines: 3),
      const SizedBox(height: 28),
      _FormActions(
        cancelLabel: s.cancel,
        nextLabel: s.next,
        nextIcon: Icons.arrow_forward_rounded,
        onCancel: () => Navigator.pop(context),
        onNext: () {
          if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
          setState(() => _step = 2);
        },
      ),
    ],
  );

  Widget _buildStep2(_S s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(s.isJa
          ? 'このイベントの参加費支払いに使用する決済手段を選択してください。'
          : 'Select your preferred payment method for the registration fee.',
          style: const TextStyle(fontSize: 13, color: _textMid)),
      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _greenLt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withOpacity(0.35), width: 1.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 13),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('💵 ', style: TextStyle(fontSize: 14)),
              Expanded(child: Text(s.directPayment, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _textDark))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _greenLt, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withOpacity(0.3))),
                child: Text(s.directActive, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: _green)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(s.isJa
                ? '主催者へ直接お支払いください。大会当日に現金または主催者指定の方法となります。'
                : 'Pay directly to the organizer. Fees collected at the venue.',
                style: const TextStyle(fontSize: 12, color: _textMid)),
          ])),
        ]),
      ),

      const SizedBox(height: 10),

      Opacity(
        opacity: 0.45,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _border, width: 2)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('💳 ', style: TextStyle(fontSize: 14)),
                Expanded(child: Text(s.creditCard, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _textDark))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _cardBg, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border)),
                  child: Text('⏳ ${s.comingSoon}', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: _textMid)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(s.stripeNote, style: const TextStyle(fontSize: 12, color: _textLight)),
            ])),
          ]),
        ),
      ),

      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _amberLt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _amber.withOpacity(0.3), style: BorderStyle.solid),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: _amber, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.importantNote, style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: _amber, letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(s.paymentNote,
                style: const TextStyle(fontSize: 12, color: _textMid, fontStyle: FontStyle.italic)),
          ])),
        ]),
      ),

      const SizedBox(height: 28),
      _FormActions(
        cancelLabel: s.back,
        nextLabel: s.next,
        nextIcon: Icons.arrow_forward_rounded,
        onCancel: () => setState(() => _step = 1),
        onNext: () => setState(() => _step = 3),
      ),
    ],
  );

  Widget _buildStep3(_S s) {
    final rows = <({String label, String value})>[
      (label: s.nameLbl,      value: _nameCtrl.text.trim().isEmpty  ? s.notProvided : _nameCtrl.text.trim()),
      (label: s.emailLbl,     value: _emailCtrl.text.trim().isEmpty ? s.notProvided : _emailCtrl.text.trim()),
      (label: s.isJa ? '電話番号' : 'Phone Number',
      value: _phoneCtrl.text.trim().isEmpty ? s.notProvided : _phoneCtrl.text.trim()),
      (label: s.isJa ? 'メッセージ / 備考' : 'Message / Notes',
      value: _notesCtrl.text.trim().isEmpty ? s.none : _notesCtrl.text.trim()),
      (label: s.paymentMethod, value: '💵 ${s.directPayment}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.confirmSubtitle, style: const TextStyle(fontSize: 13, color: _textMid)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: _border)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: Text(rows[i].label.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: _textLight, letterSpacing: 0.6))),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: Text(rows[i].value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: rows[i].label == s.paymentMethod ? _green : _textDark))),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 28),
        _FormActions(
          cancelLabel: s.back,
          nextLabel: s.submit,
          nextIcon: Icons.send_rounded,
          onCancel: () => setState(() => _step = 2),
          onNext: () => widget.onSubmit(
            _nameCtrl.text.trim(),
            _emailCtrl.text.trim(),
            _phoneCtrl.text.trim(),
            _notesCtrl.text.trim(),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step progress bar
// ═════════════════════════════════════════════════════════════════════════════
class _StepBar extends StatelessWidget {
  final int step;
  final _S s;
  const _StepBar({required this.step, required this.s});

  @override
  Widget build(BuildContext context) {
    final steps = [s.stepDetails, s.stepPayment, s.stepConfirm];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(child: Container(height: 2,
                color: step > i ? _green : _border)),
          _StepDot(index: i + 1, label: steps[i], currentStep: step),
        ],
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index, currentStep;
  final String label;
  const _StepDot({required this.index, required this.currentStep, required this.label});

  @override
  Widget build(BuildContext context) {
    final done   = currentStep > index;
    final active = currentStep == index;
    final color  = (done || active) ? _green : _textLight;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: (done || active) ? _green : _cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text('$index', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: active ? Colors.white : _textLight)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: (done || active) ? _green : _textLight)),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Form field helper
// ═════════════════════════════════════════════════════════════════════════════
class _FormField extends StatelessWidget {
  final String label, placeholder;
  final TextEditingController controller;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  const _FormField({required this.label, required this.placeholder,
    required this.controller, required this.required,
    this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label.toUpperCase(), style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: required ? _green : _textLight, letterSpacing: 0.6)),
        if (!required)
          Text(' (opt)', style: const TextStyle(fontSize: 10, color: _textLight)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: _textLight, fontSize: 14),
          filled: true,
          fillColor: _cardBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _green, width: 1.5)),
        ),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Form action buttons
// ═════════════════════════════════════════════════════════════════════════════
class _FormActions extends StatelessWidget {
  final String cancelLabel, nextLabel;
  final IconData nextIcon;
  final VoidCallback onCancel, onNext;
  const _FormActions({required this.cancelLabel, required this.nextLabel,
    required this.nextIcon, required this.onCancel, required this.onNext});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: GestureDetector(
        onTap: onCancel,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1.5),
          ),
          child: Center(child: Text(cancelLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: _textMid))),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      flex: 2,
      child: GestureDetector(
        onTap: onNext,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _green.withOpacity(0.3),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(nextLabel, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 6),
            Icon(nextIcon, color: Colors.white, size: 16),
          ]),
        ),
      ),
    ),
  ]);
}

// ═════════════════════════════════════════════════════════════════════════════
// Save bottom sheet
// ═════════════════════════════════════════════════════════════════════════════
class _SaveBottomSheet extends StatelessWidget {
  final _S s;
  final _SaveStatus currentStatus;
  final void Function(_SaveStatus) onSelect;
  final VoidCallback onRemove;
  const _SaveBottomSheet({required this.s, required this.currentStatus,
    required this.onSelect, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isAlreadySaved = currentStatus != _SaveStatus.none;
    return Container(
      decoration: const BoxDecoration(color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _border,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(isAlreadySaved ? s.updateStatus : s.saveThisEvent,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: _textDark, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text(isAlreadySaved ? s.changeCategory : s.chooseCategory,
              style: const TextStyle(fontSize: 13, color: _textMid)),
          const SizedBox(height: 20),
          _OptionTile(
            icon: Icons.bookmark_rounded, iconColor: _green,
            title: s.myEventsTitle, subtitle: s.myEventsSub,
            isSelected: currentStatus == _SaveStatus.myEvents,
            onTap: () => onSelect(_SaveStatus.myEvents),
          ),
          const SizedBox(height: 10),
          _OptionTile(
            icon: Icons.star_rounded, iconColor: _amber,
            title: s.interestedTitle, subtitle: s.interestedSub,
            isSelected: currentStatus == _SaveStatus.interested,
            onTap: () => onSelect(_SaveStatus.interested),
          ),
          if (isAlreadySaved) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: _border),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onRemove,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _redLt,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: _red, size: 22),
                ),
                const SizedBox(width: 14),
                Text(s.removeFromSaved, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _red)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Option tile (save sheet)
// ═════════════════════════════════════════════════════════════════════════════
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? iconColor.withOpacity(0.07) : _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? iconColor.withOpacity(0.45) : _border,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(isSelected ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: _textDark)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(
              fontSize: 12.5, color: _textLight)),
        ])),
        isSelected
            ? Icon(Icons.check_circle_rounded, color: iconColor, size: 22)
            : Icon(Icons.chevron_right_rounded, color: _textLight, size: 22),
      ]),
    ),
  );
}
