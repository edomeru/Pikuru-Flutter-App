import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final String lang;
  const _S(this.lang);
  bool get isJa => lang == kLangJa;

  String get page         => isJa ? 'カレンダー'              : 'Calendar Events';
  String get noEvents     => isJa ? 'この日のイベントはありません' : 'No events on this day';
  String get free         => isJa ? '無料'                    : 'Free';
  String get filters      => isJa ? 'フィルター'               : 'Filters';
  String get filterActive => isJa ? 'Active'                 : 'Active';
  String get allCountries => isJa ? 'すべての国'               : 'All Countries';
  String get clearAll     => isJa ? 'クリア'                  : 'Clear All';
  String get applyFilters => isJa ? 'フィルターを適用'         : 'APPLY FILTERS';
  String get viewOnMaps   => isJa ? 'Googleマップで見る'       : 'View on Google Maps';

  String get secSave           => isJa ? '保存'           : 'SAVE';
  String get saveMyEvents      => isJa ? 'マイイベント'     : 'My Events';
  String get saveMyEventsSub   => isJa ? '参加予定のイベント' : "Events you're planning to join";
  String get saveInterested    => isJa ? '興味あり'        : 'Interested';
  String get saveInterestedSub => isJa ? '注目しているイベント' : "Events you'd like to keep an eye on";

  String get saveMarkMyEvents      => isJa ? 'My Eventsに追加？'   : 'Add to My Events?';
  String get saveMarkMyEventsBody  => isJa ? 'このイベントをMy Eventsリストに保存します。' : 'This event will be saved to your My Events list.';
  String get saveMarkInterested    => isJa ? '「気になる」に登録？'   : 'Mark as Interested?';
  String get saveMarkInterestedBody=> isJa ? 'このイベントを「気になる」リストに保存します。' : 'This event will be saved to your Interested list.';
  String get saveYes               => isJa ? 'はい'  : 'Yes';
  String get saveMark              => isJa ? '保存'  : 'Save';
  String get modalCancel           => isJa ? 'キャンセル' : 'Cancel';

  String get visitSiteTitle => isJa ? 'イベントサイトへ？'   : 'Visit Event Website?';
  String get visitSiteBody  => isJa ? '詳細や登録は公式イベントページでご確認いただけます。サイトを開きますか？'
      : 'Would you like to go to the official event page for more details and registration?';
  String get visitSiteYes   => isJa ? 'サイトを見る'  : 'Visit Website';
  String get visitSiteNo    => isJa ? 'いいえ'        : 'No thanks';

  // ── Registration ─────────────────────────────────────────────────────────
  String get secRegistration        => isJa ? '登録'              : 'REGISTRATION';
  String get registerBtn            => isJa ? 'このイベントに登録する' : 'Register for this Event';
  String get registerConfirmTitle   => isJa ? 'このイベントに登録しますか？'    : 'Register for this event?';
  String get registerConfirmBody    => isJa ? '登録情報は主催者に送信され、承認を待ちます。' : 'Your registration will be sent to the organizer for review.';
  String get registering            => isJa ? '登録中…'           : 'Registering…';
  String get loginToRegister        => isJa ? '登録にはログインが必要です' : 'Log in to register for events';
  String get registrationPending    => isJa ? '登録中（承認待ち）' : 'Registration Pending';
  String get registrationApproved   => isJa ? '登録承認済み'       : 'Registration Approved';
  String get registrationRejected   => isJa ? '登録却下'          : 'Registration Rejected';
  String get registrationWaitlist   => isJa ? 'ウェイティングリスト待機中' : 'On Waitlist';
  String get alreadyRegistered      => isJa ? 'このイベントに登録済みです。' : 'You are registered for this event.';
  String get regApprovedMsg         => isJa ? '登録が承認されました！' : 'Your registration has been approved!';
  String get regRejectedMsg         => isJa ? '登録は承認されませんでした。' : 'Your registration was not approved.';
  String get regWaitlistMsg         => isJa ? 'ウェイティングリストに登録しました。' : "You're on the waitlist. We'll notify you if a spot opens.";
  String get cancelReg              => isJa ? '登録をキャンセル'  : 'Cancel Registration';
  String get cancelRegTitle         => isJa ? '登録をキャンセルしますか？' : 'Cancel your registration?';
  String get cancelRegBody          => isJa ? 'このイベントから登録が削除されます。' : 'This will remove your registration from this event.';
  String get capacityReached        => isJa ? '定員に達しました'  : 'Maximum Capacity Reached';
  String get capacityMsg            => isJa ? 'このイベントは満席です。ウェイティングリストに登録できます。' : 'This event is full. You can join the waitlist.';
  String get joinWaitlist           => isJa ? 'ウェイティングリストに登録' : 'Join Waitlist';
  String get joiningWaitlist        => isJa ? '登録中…'                  : 'Joining waitlist…';
  String get registrationClosed     => isJa ? '登録終了'                 : 'Registration Closed';
  String get regClosedMsg           => isJa ? '主催者がこのイベントの登録を締め切りました。' : 'The organizer has closed registration for this event.';
  String slotsLeft(int n)           => isJa ? '残り$n枠' : n == 1 ? '1 spot left' : '$n spots left';

  // ── Registration form labels ──────────────────────────────────────────────
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

  // ── Success modal ─────────────────────────────────────────────────────────
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

  String get secDateTime  => isJa ? '日時'   : 'DATE & TIME';
  String get secCatSkill  => isJa ? 'カテゴリー・スキルレベル' : 'CATEGORIES & SKILL LEVEL';
  String get secLoc       => isJa ? '場所'   : 'LOCATION';

  String get ends      => isJa ? '終了日：'      : 'Ends:';
  String get partLimit => isJa ? '参加人数上限：' : 'Participant limit:';
  String get contact   => isJa ? '連絡先：'      : 'Contact:';

  String get fCountry     => isJa ? '国'           : 'Country';
  String get fPrefecture  => isJa ? '都道府県'      : 'Prefecture';
  String get fCity        => isJa ? '市区町村'      : 'City';
  String get fType        => isJa ? 'イベントの種類' : 'Event Type';
  String get fAll         => isJa ? 'すべて'        : 'All';
  String get fAllTypes    => isJa ? 'すべての種類'   : 'All types';
  String get secLocation  => isJa ? '場所'          : 'LOCATION';
  String get secSkill     => isJa ? 'スキルレベル'   : 'SKILL LEVELS';
  String get secCat       => isJa ? 'カテゴリー'     : 'CATEGORIES';
  String get secOther     => isJa ? 'その他'         : 'OTHER';
  String get skillPro     => isJa ? '上級'      : 'Pro';
  String get skillAmateur => isJa ? '中級'      : 'Amateur';
  String get skillBeginner=> isJa ? '初級'      : 'Beginner';
  String get catMx => isJa ? 'ミックスダブルス' : 'Mixed Doubles';
  String get catMd => isJa ? '男子ダブルス'    : "Men's Doubles";
  String get catWd => isJa ? '女子ダブルス'    : "Women's Doubles";
  String get catMs => isJa ? '男子シングルス'   : "Men's Singles";
  String get catWs => isJa ? '女子シングルス'   : "Women's Singles";
  String get catSe => isJa ? 'シニア'          : 'Seniors';
  String get catJu => isJa ? 'ジュニア'        : 'Juniors';
  String get catCo => isJa ? '学生'            : 'Collegiate';
  String get tourist => isJa ? '観光客歓迎' : 'Tourist Friendly';

  List<String> get months => isJa
      ? ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月']
      : ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  List<String> get weekdays => isJa
      ? ['日','月','火','水','木','金','土']
      : ['SU','MO','TU','WE','TH','FR','SA'];

  String eventCount(int n) => isJa ? '$n件のイベント' : '$n event${n == 1 ? '' : 's'}';

  String localizeType(String key) {
    if (!isJa) return key;
    const m = {
      'Professional Tournament':      'プロトーナメント',
      'Global Tournament':            'グローバルトーナメント',
      'Japan Tournament':             '日本トーナメント',
      'Open Play':                    'オープンプレイ',
      'Trial Session':                '体験セッション',
      'Local Event':                  'ローカルイベント',
      'Lessons/Clinics':              'レッスン・クリニック',
      'Weekly Play / Recurring Play': '定期プレイ',
    };
    return m[key] ?? key;
  }

  String formatDate(DateTime d) {
    if (isJa) return '${d.year}年${months[d.month - 1]}${d.day}日';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String formatMonth(DateTime d) {
    if (isJa) return '${d.year}年 ${months[d.month - 1]}';
    return '${months[d.month - 1]} ${d.year}';
  }

  String formatDateLong(DateTime d) {
    if (isJa) {
      const days = ['日曜日','月曜日','火曜日','水曜日','木曜日','金曜日','土曜日'];
      return '${days[d.weekday % 7]}、${d.year}年${months[d.month - 1]}${d.day}日';
    }
    return DateFormat('EEEE, MMMM d, yyyy').format(d);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter state
// ─────────────────────────────────────────────────────────────────────────────
class _CalFilter {
  String country;
  String prefecture;
  String city;
  String type;
  bool skillPro, skillAmateur, skillBeginner;
  bool catMx, catMd, catMs, catWs, catWd, catSe, catJu, catCo;
  bool tourist;

  _CalFilter({
    this.country = '',
    this.prefecture = '',
    this.city = '',
    this.type = '',
    this.skillPro = false,
    this.skillAmateur = false,
    this.skillBeginner = false,
    this.catMx = false, this.catMd = false, this.catMs = false, this.catWs = false,
    this.catWd = false, this.catSe = false, this.catJu = false, this.catCo = false,
    this.tourist = false,
  });

  _CalFilter copyWith({
    String? country, String? prefecture, String? city, String? type,
    bool? skillPro, bool? skillAmateur, bool? skillBeginner,
    bool? catMx, bool? catMd, bool? catMs, bool? catWs,
    bool? catWd, bool? catSe, bool? catJu, bool? catCo, bool? tourist,
  }) => _CalFilter(
    country: country ?? this.country,
    prefecture: prefecture ?? this.prefecture,
    city: city ?? this.city,
    type: type ?? this.type,
    skillPro: skillPro ?? this.skillPro,
    skillAmateur: skillAmateur ?? this.skillAmateur,
    skillBeginner: skillBeginner ?? this.skillBeginner,
    catMx: catMx ?? this.catMx, catMd: catMd ?? this.catMd,
    catMs: catMs ?? this.catMs, catWs: catWs ?? this.catWs,
    catWd: catWd ?? this.catWd, catSe: catSe ?? this.catSe,
    catJu: catJu ?? this.catJu, catCo: catCo ?? this.catCo,
    tourist: tourist ?? this.tourist,
  );

  bool get hasNonLocationFilters =>
      type.isNotEmpty || skillPro || skillAmateur || skillBeginner ||
          catMx || catMd || catMs || catWs || catWd || catSe || catJu || catCo || tourist;

  bool get isActive =>
      hasNonLocationFilters || country.isNotEmpty || prefecture.isNotEmpty || city.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Save / Reg status types
// ─────────────────────────────────────────────────────────────────────────────
enum _SaveStatus { none, myEvents, interested }
enum _RegStatus  { none, pending, approved, rejected, waitlist }

// ─────────────────────────────────────────────────────────────────────────────
// Dedicated calendar provider
// ─────────────────────────────────────────────────────────────────────────────
final _calendarFetchProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final in30  = today.add(const Duration(days: 30));

  return FirebaseFirestore.instance
      .collection('events')
      .where('event_active',         isEqualTo: true)
      .where('event_checked',        isEqualTo: true)
      .where('event_pending_review', isEqualTo: false)
      .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
      .where('event_date', isLessThanOrEqualTo:    Timestamp.fromDate(in30))
      .orderBy('event_date')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) {
    final data = Map<String, dynamic>.from(d.data());
    data['_doc_id'] = d.id;
    return data;
  }).toList());
});

// ─────────────────────────────────────────────────────────────────────────────
// 3-Step Registration Form Bottom Sheet
// Mirrors the web app's RegistrationFormModal exactly
// ─────────────────────────────────────────────────────────────────────────────
class _RegistrationFormSheet extends StatefulWidget {
  final _S s;
  final String defaultName;
  final String defaultEmail;
  final bool asWaitlist;
  final void Function(String name, String email, String phone, String notes) onSubmit;

  const _RegistrationFormSheet({
    required this.s,
    required this.defaultName,
    required this.defaultEmail,
    required this.asWaitlist,
    required this.onSubmit,
  });

  @override
  State<_RegistrationFormSheet> createState() => _RegistrationFormSheetState();
}

class _RegistrationFormSheetState extends State<_RegistrationFormSheet> {
  int _step = 1; // 1=Details, 2=Payment, 3=Confirm
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const Color _surface   = Colors.white;
  static const Color _border    = Color(0xFFE4E9EE);
  static const Color _cardBg    = Color(0xFFF4F6F8);
  static const Color _green     = Color(0xFF2E7D45);
  static const Color _greenLt   = Color(0xFFE6F4EB);
  static const Color _amber     = Color(0xFFD97706);
  static const Color _amberLt   = Color(0xFFFFF3CD);
  static const Color _textDark  = Color(0xFF111827);
  static const Color _textMid   = Color(0xFF4B5563);
  static const Color _textLight = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.defaultName);
    _emailCtrl = TextEditingController(text: widget.defaultEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
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
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
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
          // Step Progress Bar
          _buildStepBar(s),
          const Divider(height: 1, color: _border),
          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: _step == 1 ? _buildStep1(s, context)
                  : _step == 2 ? _buildStep2(s)
                  : _buildStep3(s, context),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStepBar(_S s) {
    final steps = [s.stepDetails, s.stepPayment, s.stepConfirm];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(child: Container(
              height: 2,
              color: _step > i ? const Color(0xFF2E7D45) : const Color(0xFFE4E9EE),
            )),
          _buildStepDot(i + 1, steps[i]),
        ],
      ]),
    );
  }

  Widget _buildStepDot(int index, String label) {
    final done   = _step > index;
    final active = _step == index;
    const green = Color(0xFF2E7D45);
    final color = (done || active) ? green : const Color(0xFF9CA3AF);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: (done || active) ? green : const Color(0xFFF4F6F8),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text('$index', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF9CA3AF))),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: (done || active) ? green : const Color(0xFF9CA3AF))),
    ]);
  }

  // ── Step 1: Details ───────────────────────────────────────────────────────
  Widget _buildStep1(_S s, BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFormField(s.nameLbl, _nameCtrl, s.namePh, required: true),
      const SizedBox(height: 16),
      _buildFormField(s.emailLbl, _emailCtrl, s.emailPh,
          required: true, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _buildFormField(s.phoneLbl, _phoneCtrl, s.phonePh,
          required: false, keyboardType: TextInputType.phone),
      const SizedBox(height: 16),
      _buildFormField(s.notesLbl, _notesCtrl, s.notesPh,
          required: false, maxLines: 3),
      const SizedBox(height: 28),
      _buildFormActions(
        cancelLabel: s.cancel,
        nextLabel: s.next,
        nextIcon: Icons.arrow_forward_rounded,
        onCancel: () => Navigator.pop(context),
        onNext: () {
          if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
          setState(() => _step = 2);
        },
      ),
    ]);
  }

  // ── Step 2: Payment ───────────────────────────────────────────────────────
  Widget _buildStep2(_S s) {
    const green  = Color(0xFF2E7D45);
    const greenLt= Color(0xFFE6F4EB);
    const amber  = Color(0xFFD97706);
    const amberLt= Color(0xFFFFF3CD);
    const cardBg = Color(0xFFF4F6F8);
    const border = Color(0xFFE4E9EE);
    const textDark = Color(0xFF111827);
    const textMid  = Color(0xFF4B5563);
    const textLight= Color(0xFF9CA3AF);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        s.isJa
            ? 'このイベントの参加費支払いに使用する決済手段を選択してください。'
            : 'Select your preferred payment method for the registration fee.',
        style: const TextStyle(fontSize: 13, color: textMid),
      ),
      const SizedBox(height: 16),

      // Direct payment (active)
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: greenLt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: green.withOpacity(0.35), width: 1.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: green, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 13),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('💵 ', style: TextStyle(fontSize: 14)),
              Expanded(child: Text(s.directPayment,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: greenLt, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: green.withOpacity(0.3))),
                child: Text(s.directActive, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: green)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              s.isJa
                  ? '主催者へ直接お支払いください。大会当日に現金または主催者指定の方法となります。'
                  : 'Pay directly to the organizer. Fees collected at the venue.',
              style: const TextStyle(fontSize: 12, color: textMid),
            ),
          ])),
        ]),
      ),

      const SizedBox(height: 10),

      // Credit card (coming soon)
      Opacity(
        opacity: 0.45,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 2)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('💳 ', style: TextStyle(fontSize: 14)),
                Expanded(child: Text(s.creditCard, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: textDark))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: cardBg, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border)),
                  child: Text('⏳ ${s.comingSoon}', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: textMid)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(s.stripeNote,
                  style: const TextStyle(fontSize: 12, color: textLight)),
            ])),
          ]),
        ),
      ),

      const SizedBox(height: 16),

      // Important note
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: amberLt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: amber.withOpacity(0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: amber, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.importantNote, style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: amber, letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(s.paymentNote,
                style: const TextStyle(fontSize: 12, color: textMid, fontStyle: FontStyle.italic)),
          ])),
        ]),
      ),

      const SizedBox(height: 28),
      _buildFormActions(
        cancelLabel: s.back,
        nextLabel: s.next,
        nextIcon: Icons.arrow_forward_rounded,
        onCancel: () => setState(() => _step = 1),
        onNext: () => setState(() => _step = 3),
      ),
    ]);
  }

  // ── Step 3: Confirm ───────────────────────────────────────────────────────
  Widget _buildStep3(_S s, BuildContext context) {
    const green    = Color(0xFF2E7D45);
    const cardBg   = Color(0xFFF4F6F8);
    const border   = Color(0xFFE4E9EE);
    const textDark = Color(0xFF111827);
    const textLight= Color(0xFF9CA3AF);

    final rows = <({String label, String value})>[
      (label: s.nameLbl,
      value: _nameCtrl.text.trim().isEmpty ? s.notProvided : _nameCtrl.text.trim()),
      (label: s.emailLbl,
      value: _emailCtrl.text.trim().isEmpty ? s.notProvided : _emailCtrl.text.trim()),
      (label: s.isJa ? '電話番号' : 'Phone Number',
      value: _phoneCtrl.text.trim().isEmpty ? s.notProvided : _phoneCtrl.text.trim()),
      (label: s.isJa ? 'メッセージ / 備考' : 'Message / Notes',
      value: _notesCtrl.text.trim().isEmpty ? s.none : _notesCtrl.text.trim()),
      (label: s.paymentMethod, value: '💵 ${s.directPayment}'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.confirmSubtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: border)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Text(rows[i].label.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: textLight, letterSpacing: 0.6))),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: Text(rows[i].value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: rows[i].label == s.paymentMethod ? green : textDark))),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 28),
      _buildFormActions(
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
    ]);
  }

  // ── Form field helper ─────────────────────────────────────────────────────
  Widget _buildFormField(
      String label,
      TextEditingController controller,
      String placeholder, {
        bool required = true,
        int maxLines = 1,
        TextInputType? keyboardType,
      }) {
    const green    = Color(0xFF2E7D45);
    const cardBg   = Color(0xFFF4F6F8);
    const border   = Color(0xFFE4E9EE);
    const textDark = Color(0xFF111827);
    const textLight= Color(0xFF9CA3AF);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label.toUpperCase(), style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: required ? green : textLight, letterSpacing: 0.6)),
        if (!required)
          const Text(' (opt)', style: TextStyle(fontSize: 10, color: textLight)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: textDark),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: textLight, fontSize: 14),
          filled: true,
          fillColor: cardBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: green, width: 1.5)),
        ),
      ),
    ]);
  }

  // ── Form action buttons ───────────────────────────────────────────────────
  Widget _buildFormActions({
    required String cancelLabel,
    required String nextLabel,
    required IconData nextIcon,
    required VoidCallback onCancel,
    required VoidCallback onNext,
  }) {
    const green   = Color(0xFF2E7D45);
    const cardBg  = Color(0xFFF4F6F8);
    const border  = Color(0xFFE4E9EE);
    const textMid = Color(0xFF4B5563);

    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: onCancel,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Center(child: Text(cancelLabel, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: textMid))),
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
              color: green,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: green.withOpacity(0.3),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Registration Success Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _RegistrationSuccessDialog extends StatelessWidget {
  final _S s;
  final bool isWaitlist;

  const _RegistrationSuccessDialog({required this.s, required this.isWaitlist});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D45);
    const amber = Color(0xFFD97706);
    final accent = isWaitlist ? amber : green;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(
              isWaitlist ? Icons.schedule_rounded : Icons.check_rounded,
              color: accent, size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(s.regSuccessTitle(isWaitlist),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 8),
          Text(s.regSuccessBody(isWaitlist),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Column(children: [
              Text(s.currentStatus,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF), letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  isWaitlist ? s.waitlistStatus : s.pendingStatus,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: accent, letterSpacing: 0.5),
                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Confirm Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDialog({
    required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor,
    required this.onConfirm, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title, style: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
    content: Text(body, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
    actions: [
      TextButton(
        onPressed: onCancel,
        child: const Text('Cancel', style: TextStyle(
            color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
      ),
      TextButton(
        onPressed: onConfirm,
        child: Text(confirmLabel, style: TextStyle(
            color: confirmColor, fontWeight: FontWeight.w700)),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class CalendarEventsScreen extends ConsumerStatefulWidget {
  const CalendarEventsScreen({super.key});

  @override
  ConsumerState<CalendarEventsScreen> createState() => _CalendarEventsScreenState();
}

class _CalendarEventsScreenState extends ConsumerState<CalendarEventsScreen>
    with TickerProviderStateMixin {

  static const Color _bg        = Color(0xFFF7F8FA);
  static const Color _surface   = Colors.white;
  static const Color _border    = Color(0xFFEEEFF1);
  static const Color _borderMd  = Color(0xFFDDDEE1);
  static const Color _cardBg    = Color(0xFFF2F3F5);
  static const Color _textDark  = Color(0xFF0D0D0D);
  static const Color _textMid   = Color(0xFF555760);
  static const Color _textLight = Color(0xFF888A90);
  static const Color _red       = Color(0xFFD32F2F);
  static const Color _redLt     = Color(0xFFFFEBEE);
  static const Color _amber     = Color(0xFFD97706);
  static const Color _amberLt   = Color(0xFFFFF3CD);

  _S get s => _S(ref.watch(appLangProvider));

  _CalFilter _filter = _CalFilter();

  static const List<String> _eventTypeKeys = [
    'Professional Tournament', 'Global Tournament', 'Japan Tournament',
    'Open Play', 'Trial Session', 'Local Event',
    'Lessons/Clinics', 'Weekly Play / Recurring Play',
  ];

  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  final Map<String, _SaveStatus> _saveStatuses = {};
  final Map<String, bool>        _savingIds    = {};
  final Map<String, _RegStatus>  _regStatuses  = {};
  final Map<String, String>      _regDocIds    = {};
  final Map<String, bool>        _regLoading   = {};

  @override
  void initState() {
    super.initState();
    final now     = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses(List<Map<String, dynamic>> events) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final uid = firebaseUser.uid;
    final db  = FirebaseFirestore.instance;

    await Future.wait(events.map((ev) async {
      final docId = (ev['_doc_id'] ?? '').toString();
      if (docId.isEmpty) return;

      try {
        final snap = await db.doc('user_events/${uid}_$docId').get();
        if (!mounted) return;
        if (snap.exists) {
          final status = (snap.data()?['status'] ?? '').toString();
          setState(() {
            _saveStatuses[docId] = status == 'my_events'
                ? _SaveStatus.myEvents
                : status == 'interested'
                ? _SaveStatus.interested
                : _SaveStatus.none;
          });
        } else {
          setState(() => _saveStatuses[docId] = _SaveStatus.none);
        }
      } catch (_) {}

      try {
        final snap = await db
            .collection('event_registrations')
            .where('event_id', isEqualTo: docId)
            .where('user_id', isEqualTo: uid)
            .limit(1)
            .get();
        if (!mounted) return;
        if (snap.docs.isEmpty) {
          setState(() => _regStatuses[docId] = _RegStatus.none);
        } else {
          final d      = snap.docs.first;
          final status = (d.data()['status'] ?? '').toString();
          setState(() {
            _regDocIds[docId]  = d.id;
            _regStatuses[docId] = status == 'approved'
                ? _RegStatus.approved
                : status == 'rejected'
                ? _RegStatus.rejected
                : status == 'waitlist'
                ? _RegStatus.waitlist
                : _RegStatus.pending;
          });
        }
      } catch (_) {}
    }));
  }

  Future<void> _handleSave(Map<String, dynamic> event, _SaveStatus next) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final docId = (event['_doc_id'] ?? '').toString();
    if (docId.isEmpty) return;

    setState(() => _savingIds[docId] = true);
    try {
      final db  = FirebaseFirestore.instance;
      final uid = firebaseUser.uid;
      await db.doc('user_events/${uid}_$docId').set({
        'user_id':     uid,
        'event_id':    docId,
        'status':      next == _SaveStatus.myEvents ? 'my_events' : 'interested',
        'event_title': (event['event_title'] ?? '').toString(),
        'event_pic':   (event['event_pic'] ??
            event['event_pic_thumbnail'] ??
            event['event_image'] ?? '').toString(),
        'saved_at':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => _saveStatuses[docId] = next);
    } catch (e) {
      debugPrint('Save failed: $e');
    } finally {
      if (mounted) setState(() => _savingIds[docId] = false);
    }
  }

  // ── UPDATED: Full registration with 3-step form ────────────────────────────
  // Mirrors the web app's handleRegister exactly:
  //   - Saves to event_registrations with all required fields
  //   - Handles both 'pending' and 'waitlist' status
  //   - Shows success dialog after submission
  Future<void> _submitRegistration({
    required Map<String, dynamic> event,
    required String name,
    required String email,
    required String phone,
    required String notes,
    required bool asWaitlist,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final docId = (event['_doc_id'] ?? '').toString();
    if (docId.isEmpty) return;

    setState(() => _regLoading[docId] = true);
    try {
      final db  = FirebaseFirestore.instance;
      final uid = firebaseUser.uid;

      // Write to event_registrations — matches web app handleRegister fields exactly
      final ref = await db.collection('event_registrations').add({
        'event_id':      docId,           // ← always the Firestore doc ID
        'user_id':       uid,
        'user_name':     name.isNotEmpty ? name : (firebaseUser.displayName ?? ''),
        'user_email':    email.isNotEmpty ? email : (firebaseUser.email ?? ''),
        'user_phone':    phone,
        'user_notes':    notes,
        'user_avatar':   firebaseUser.photoURL ?? '',
        'status':        asWaitlist ? 'waitlist' : 'pending',
        'registered_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _regDocIds[docId]   = ref.id;
          _regStatuses[docId] = asWaitlist ? _RegStatus.waitlist : _RegStatus.pending;
        });
        // Show success dialog
        _showSuccessModal(asWaitlist);
      }
    } catch (e) {
      debugPrint('[CalendarScreen] _submitRegistration error: $e');
    } finally {
      if (mounted) setState(() => _regLoading[docId] = false);
    }
  }

  // ── Show the 3-step registration form bottom sheet ─────────────────────────
  void _showRegistrationForm(Map<String, dynamic> event, {required bool asWaitlist}) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final lang = ref.read(appLangProvider);
    final ls   = _S(lang);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => _RegistrationFormSheet(
        s: ls,
        defaultName:  firebaseUser?.displayName ?? '',
        defaultEmail: firebaseUser?.email ?? '',
        asWaitlist: asWaitlist,
        onSubmit: (name, email, phone, notes) async {
          Navigator.pop(context);
          await _submitRegistration(
            event: event,
            name: name,
            email: email,
            phone: phone,
            notes: notes,
            asWaitlist: asWaitlist,
          );
        },
      ),
    );
  }

  void _showSuccessModal(bool waitlist) {
    final lang = ref.read(appLangProvider);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RegistrationSuccessDialog(s: _S(lang), isWaitlist: waitlist),
    );
  }

  // ── Register button handler — checks capacity & regOpen before showing form ─
  Future<void> _handleRegisterTap(Map<String, dynamic> event) async {
    final docId = (event['_doc_id'] ?? '').toString();
    if (docId.isEmpty) return;

    final regOpen     = event['event_registration_open'] != false;
    final eventLimit  = event['event_limit'] != null
        ? int.tryParse(event['event_limit'].toString())
        : null;
    final approvedCount = (event['event_approved_count'] ?? 0) as int;
    final isFull = eventLimit != null && approvedCount >= eventLimit;

    if (!regOpen) return; // registration closed — button shouldn't be shown

    if (isFull) {
      // Show waitlist form
      _showRegistrationForm(event, asWaitlist: true);
    } else {
      // Show normal registration form
      _showRegistrationForm(event, asWaitlist: false);
    }
  }

  Future<void> _handleCancelRegistration(Map<String, dynamic> event) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final docId    = (event['_doc_id'] ?? '').toString();
    final regDocId = _regDocIds[docId];
    if (regDocId == null) return;

    setState(() => _regLoading[docId] = true);
    try {
      final db  = FirebaseFirestore.instance;
      final uid = firebaseUser.uid;

      // If cancelling an approved reg, decrement approved count
      if (_regStatuses[docId] == _RegStatus.approved) {
        db.collection('events').doc(docId)
            .update({'event_approved_count': FieldValue.increment(-1)})
            .catchError((_) {});
      }

      await db.doc('event_registrations/$regDocId').delete();
      await db.doc('user_events/${uid}_$docId').delete().catchError((_) {});
      if (mounted) {
        setState(() {
          _regStatuses[docId]  = _RegStatus.none;
          _regDocIds.remove(docId);
          _saveStatuses[docId] = _SaveStatus.none;
        });
      }
    } catch (e) {
      debugPrint('Cancel registration failed: $e');
    } finally {
      if (mounted) setState(() => _regLoading[docId] = false);
    }
  }

  Future<void> _showSaveConfirmModal(
      Map<String, dynamic> event, _SaveStatus next) async {
    final _S ls = _S(ref.read(appLangProvider));
    final isMyEvents = next == _SaveStatus.myEvents;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: const Color(0xFF07170C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 80, offset: const Offset(0, 24),
            )],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: isMyEvents
                    ? AppColors.primary.withOpacity(0.14)
                    : const Color(0xFFF5B23B).withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMyEvents ? Icons.bookmark_rounded : Icons.star_rounded,
                color: isMyEvents ? AppColors.primary : const Color(0xFFF5B23B),
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMyEvents ? ls.saveMarkMyEvents : ls.saveMarkInterested,
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMyEvents ? ls.saveMarkMyEventsBody : ls.saveMarkInterestedBody,
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.18),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.16)),
                    ),
                  ),
                  child: Text(ls.modalCancel,
                      style: TextStyle(color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _handleSave(event, next);
                    final eventUrl = (event['event_link'] ?? event['event_url'] ?? '').toString().trim();
                    if (eventUrl.isNotEmpty && mounted) {
                      await _showVisitSiteModal(eventUrl);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMyEvents ? AppColors.primary : const Color(0xFFF5B23B),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isMyEvents ? ls.saveYes : ls.saveMark,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _showVisitSiteModal(String url) async {
    final _S ls = _S(ref.read(appLangProvider));

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.60),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: const Color(0xFF07170C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF6ABF7A).withOpacity(0.20)),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.60),
              blurRadius: 80, offset: const Offset(0, 24),
            )],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle,
              ),
              child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 16),
            Text(ls.visitSiteTitle,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(ls.visitSiteBody,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.18),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.16)),
                    ),
                  ),
                  child: Text(ls.visitSiteNo,
                      style: TextStyle(color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.open_in_new_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(ls.visitSiteYes,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _showCancelRegConfirmModal(Map<String, dynamic> event) async {
    final _S ls = _S(ref.read(appLangProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _ConfirmDialog(
        title: ls.cancelRegTitle,
        body: ls.cancelRegBody,
        confirmLabel: ls.cancelReg,
        confirmColor: _red,
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel:  () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed == true) {
      await _handleCancelRegistration(event);
    }
  }

  String get _locationLabel {
    if (_filter.prefecture.isNotEmpty) return _filter.prefecture;
    if (_filter.country.isNotEmpty)    return _filter.country;
    return s.allCountries;
  }

  bool _matchesLocation(Map<String, dynamic> event) {
    if (_filter.country.isEmpty && _filter.prefecture.isEmpty && _filter.city.isEmpty) {
      return true;
    }
    if (_filter.country.isNotEmpty) {
      final country = (event['_resolvedCountry'] ?? '').toString().toLowerCase();
      final target  = _filter.country.toLowerCase();
      if (country.isNotEmpty && !country.contains(target) && !target.contains(country)) {
        return false;
      }
    }
    if (_filter.prefecture.isNotEmpty) {
      final pref   = (event['_resolvedPrefecture'] ?? '').toString().toLowerCase();
      final target = _filter.prefecture.toLowerCase();
      if (pref.isNotEmpty && !pref.contains(target) && !target.contains(pref)) {
        return false;
      }
    }
    if (_filter.city.isNotEmpty) {
      final city   = (event['_resolvedCity'] ?? '').toString().toLowerCase();
      final target = _filter.city.toLowerCase();
      if (city.isNotEmpty && !city.contains(target) && !target.contains(city)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesAllFilters(Map<String, dynamic> e) {
    if (!_matchesLocation(e)) return false;
    if (_filter.type.isNotEmpty && (e['event_type'] ?? '').toString() != _filter.type) return false;
    if (_filter.skillPro || _filter.skillAmateur || _filter.skillBeginner) {
      final match =
          (_filter.skillPro      && e['event_skill_level_pro']      == true) ||
              (_filter.skillAmateur  && e['event_skill_level_amateur']   == true) ||
              (_filter.skillBeginner && e['event_skill_level_beginner']  == true);
      if (!match) return false;
    }
    if (_filter.catMx || _filter.catMd || _filter.catMs || _filter.catWs ||
        _filter.catWd || _filter.catSe || _filter.catJu || _filter.catCo) {
      final match =
          (_filter.catMx && e['event_category_mixeddoubles']  == true) ||
              (_filter.catMd && e['event_category_mensdoubles']   == true) ||
              (_filter.catMs && e['event_category_menssingle']    == true) ||
              (_filter.catWs && e['event_category_womenssingle']  == true) ||
              (_filter.catWd && e['event_category_womensdoubles'] == true) ||
              (_filter.catSe && e['event_category_seniors']       == true) ||
              (_filter.catJu && e['event_category_juniors']       == true) ||
              (_filter.catCo && e['event_category_collegiate']    == true);
      if (!match) return false;
    }
    if (_filter.tourist && e['event_touristfriendly'] != true) return false;
    return true;
  }

  Future<List<Map<String, dynamic>>> _enrichEvents(
      List<Map<String, dynamic>> raw) async {
    final locIds = raw
        .map((e) => (e['event_loc_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final locCache = <String, Map<String, dynamic>>{};
    for (final locId in locIds) {
      try {
        final q = await FirebaseFirestore.instance
            .collection('locations')
            .where('loc_id', isEqualTo: locId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          locCache[locId] = q.docs.first.data();
          continue;
        }
        final doc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(locId)
            .get();
        if (doc.exists) locCache[locId] = doc.data()!;
      } catch (_) {}
    }

    return raw.map((e) {
      final locId = (e['event_loc_id'] ?? '').toString().trim();
      final loc   = locId.isNotEmpty ? (locCache[locId] ?? <String, dynamic>{}) : <String, dynamic>{};

      String get(String key) =>
          ((loc.isNotEmpty ? loc[key] : null) ?? e[key] ?? '').toString().trim();

      final prefEn = [
        get('loc_prefecture_en'), get('loc_prefecture'),
        get('event_prefecture'),  get('prefecture'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

      final cityEn  = get('loc_city_en').isNotEmpty ? get('loc_city_en') : get('loc_city');
      final country = get('loc_country');

      final label = cityEn.isNotEmpty && prefEn.isNotEmpty
          ? '$cityEn, $prefEn'
          : cityEn.isNotEmpty ? cityEn
          : prefEn.isNotEmpty ? prefEn
          : country;

      final prefJp    = get('loc_prefecture_jp').isNotEmpty ? get('loc_prefecture_jp') : prefEn;
      final cityJp    = get('loc_city_jp').isNotEmpty       ? get('loc_city_jp')       : cityEn;
      final countryJp = get('loc_country_jp').isNotEmpty    ? get('loc_country_jp')    : (country == 'Japan' ? '日本' : country);
      final addrJp    = get('loc_address_jp').isNotEmpty    ? get('loc_address_jp')    : get('loc_address');

      final labelJp = cityJp.isNotEmpty && prefJp.isNotEmpty
          ? '$prefJp$cityJp'
          : cityJp.isNotEmpty ? cityJp
          : prefJp.isNotEmpty ? prefJp
          : countryJp;

      final googleLink = [
        get('loc_googlelink'), get('event_googlelink'), get('event_venue_link'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

      final orgNameEn = [get('org_name'), get('event_org_name')]
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final orgNameJp = get('org_name_jp').isNotEmpty ? get('org_name_jp') : orgNameEn;

      final fullAddr   = get('loc_address').isNotEmpty ? get('loc_address') : get('event_venue_address');
      final fullAddrJp = addrJp.isNotEmpty ? addrJp : fullAddr;

      return {
        ...e,
        'location':            label.isNotEmpty ? label : get('event_venue_name'),
        'event_address':       fullAddr,
        'event_googlelink':    googleLink,
        'org_name':            orgNameEn,
        'location_jp':         labelJp.isNotEmpty ? labelJp : get('event_venue_name'),
        'event_address_jp':    fullAddrJp,
        'org_name_jp':         orgNameJp,
        '_resolvedPrefecture': prefEn,
        '_resolvedCountry':    country,
        '_resolvedCity':       cityEn,
      };
    }).toList();
  }

  Map<String, List<Map<String, String>>> _buildLocationMap(
      List<Map<String, dynamic>> enrichedEvents) {
    final map = <String, List<Map<String, String>>>{};
    for (final e in enrichedEvents) {
      final country = (e['_resolvedCountry'] ?? '').toString().trim();
      if (country.isEmpty) continue;
      final pref = (e['_resolvedPrefecture'] ?? '').toString().trim();
      if (pref.isEmpty) continue;
      map.putIfAbsent(country, () => []);
      if (!map[country]!.any((p) => p['en'] == pref)) {
        map[country]!.add({'en': pref});
      }
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    for (final prefs in sorted.values) {
      prefs.sort((a, b) => a['en']!.compareTo(b['en']!));
    }
    return sorted;
  }

  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(
      List<Map<String, dynamic>> events) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final e in events) {
      if (!_matchesAllFilters(e)) continue;

      final tsStart = e['event_date'] ?? e['event_start_date'];
      if (tsStart == null) continue;

      DateTime dtStart;
      if (tsStart is Timestamp) {
        dtStart = tsStart.toDate();
      } else {
        continue;
      }
      final keyStart = DateTime(dtStart.year, dtStart.month, dtStart.day);

      final tsEnd  = e['event_date_end'];
      DateTime dtEnd;
      if (tsEnd is Timestamp) {
        dtEnd = tsEnd.toDate();
      } else {
        dtEnd = keyStart;
      }
      final keyEnd = DateTime(dtEnd.year, dtEnd.month, dtEnd.day);

      DateTime current = keyStart;
      int loop = 0;
      while (!current.isAfter(keyEnd) && loop < 30) {
        final key = DateTime(current.year, current.month, current.day);
        map.putIfAbsent(key, () => []).add(e);
        current = current.add(const Duration(days: 1));
        loop++;
      }
    }
    return map;
  }

  List<Map<String, dynamic>> _eventsForDate(
      Map<DateTime, List<Map<String, dynamic>>> map, DateTime date) =>
      map[DateTime(date.year, date.month, date.day)] ?? [];

  void _prevMonth() => setState(() =>
  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
  void _nextMonth() => setState(() =>
  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showFilterModal(List<Map<String, dynamic>> enrichedEvents) {
    _CalFilter temp = _filter;
    final locationMap = _buildLocationMap(enrichedEvents);

    final cities = <String>{};
    for (final e in enrichedEvents) {
      final c = (e['_resolvedCity'] ?? '').toString().trim();
      if (c.isNotEmpty) cities.add(c);
    }
    final sortedCities = cities.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final curS = _S(ref.read(appLangProvider));

        Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 3, height: 14,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
            ),
            Text(text, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800, color: _textMid, letterSpacing: 0.8)),
          ]),
        );

        Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: _borderMd),
        );

        Widget checkPill(String label, bool value, VoidCallback onTap) {
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: value ? AppColors.primary.withOpacity(0.08) : _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: value ? AppColors.primary.withOpacity(0.5) : _borderMd,
                  width: 1.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 15, height: 15,
                  decoration: BoxDecoration(
                    color: value ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: value ? AppColors.primary : _borderMd, width: 1.5),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: value ? AppColors.primary : _textMid)),
              ]),
            ),
          );
        }

        Widget dropdownField(String label, String value,
            List<String> options, String allLabel, ValueChanged<String> onChange) {
          final hasVal = value.isNotEmpty;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _textLight)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasVal ? AppColors.primary.withOpacity(0.06) : _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasVal ? AppColors.primary.withOpacity(0.4) : _borderMd),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value.isEmpty ? '' : value,
                  isExpanded: true,
                  dropdownColor: _surface,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: hasVal ? AppColors.primary : _textLight, size: 20),
                  style: TextStyle(
                      color: hasVal ? AppColors.primary : _textDark,
                      fontSize: 14, fontWeight: FontWeight.w500),
                  items: [
                    DropdownMenuItem(value: '',
                        child: Text(allLabel, style: const TextStyle(color: _textLight))),
                    ...options.map((o) => DropdownMenuItem(
                        value: o, child: Text(o, style: const TextStyle(color: _textDark)))),
                  ],
                  onChanged: (v) => onChange(v ?? ''),
                ),
              ),
            ),
          ]);
        }

        final availablePrefs = temp.country.isNotEmpty
            ? (locationMap[temp.country] ?? [])
            : <Map<String, String>>[];
        final sortedPrefs = availablePrefs.map((p) => p['en']!).toList()..sort();

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
          decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _borderMd, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(children: [
                Text(curS.filters,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: _textDark, letterSpacing: -0.4)),
                const Spacer(),
                if (_filter.isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(curS.filterActive,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: _cardBg, shape: BoxShape.circle,
                        border: Border.all(color: _borderMd)),
                    child: const Icon(Icons.close_rounded, color: _textMid, size: 18),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: _borderMd),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  sectionLabel(curS.secLocation),
                  Row(children: [
                    Expanded(child: dropdownField(
                      curS.fCountry, temp.country,
                      locationMap.keys.toList(), curS.allCountries,
                          (v) => setS(() => temp = temp.copyWith(country: v, prefecture: '', city: '')),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: dropdownField(
                      curS.fPrefecture, temp.prefecture,
                      sortedPrefs, curS.fAll,
                          (v) => setS(() => temp = temp.copyWith(prefecture: v)),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: dropdownField(
                      curS.fCity, temp.city,
                      sortedCities, curS.fAll,
                          (v) => setS(() => temp = temp.copyWith(city: v)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: dropdownField(
                      curS.fType, temp.type,
                      _eventTypeKeys, curS.fAllTypes,
                          (v) => setS(() => temp = temp.copyWith(type: v)),
                    )),
                  ]),

                  divider(),
                  sectionLabel(curS.secSkill),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    checkPill(curS.skillPro,      temp.skillPro,      () => setS(() => temp = temp.copyWith(skillPro:      !temp.skillPro))),
                    checkPill(curS.skillAmateur,   temp.skillAmateur,  () => setS(() => temp = temp.copyWith(skillAmateur:  !temp.skillAmateur))),
                    checkPill(curS.skillBeginner,  temp.skillBeginner, () => setS(() => temp = temp.copyWith(skillBeginner: !temp.skillBeginner))),
                  ]),

                  divider(),
                  sectionLabel(curS.secCat),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    checkPill(curS.catMx, temp.catMx, () => setS(() => temp = temp.copyWith(catMx: !temp.catMx))),
                    checkPill(curS.catMd, temp.catMd, () => setS(() => temp = temp.copyWith(catMd: !temp.catMd))),
                    checkPill(curS.catWd, temp.catWd, () => setS(() => temp = temp.copyWith(catWd: !temp.catWd))),
                    checkPill(curS.catMs, temp.catMs, () => setS(() => temp = temp.copyWith(catMs: !temp.catMs))),
                    checkPill(curS.catWs, temp.catWs, () => setS(() => temp = temp.copyWith(catWs: !temp.catWs))),
                    checkPill(curS.catSe, temp.catSe, () => setS(() => temp = temp.copyWith(catSe: !temp.catSe))),
                    checkPill(curS.catJu, temp.catJu, () => setS(() => temp = temp.copyWith(catJu: !temp.catJu))),
                    checkPill(curS.catCo, temp.catCo, () => setS(() => temp = temp.copyWith(catCo: !temp.catCo))),
                  ]),

                  divider(),
                  sectionLabel(curS.secOther),
                  checkPill(curS.tourist, temp.tourist,
                          () => setS(() => temp = temp.copyWith(tourist: !temp.tourist))),

                  const SizedBox(height: 28),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => temp = _CalFilter()),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderMd, width: 1.5),
                          ),
                          child: Center(child: Text(curS.clearAll,
                              style: const TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700, color: _textMid))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _filter = temp);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(
                                color: AppColors.primary.withOpacity(0.30),
                                blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Center(child: Text(curS.applyFilters,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: 0.6))),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(appLangProvider);
    final eventsAsync  = ref.watch(_calendarFetchProvider);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: eventsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rawEvents) => FutureBuilder<List<Map<String, dynamic>>>(
          future: _enrichEvents(rawEvents),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            final events       = snapshot.data ?? [];
            final eventMap     = _buildEventMap(events);
            final selectedEvts = _eventsForDate(eventMap, _selectedDate);

            if (snapshot.hasData && firebaseUser != null) {
              _loadStatuses(events);
            }

            return CustomScrollView(slivers: [

              // ── AppBar ────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: _surface,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                shadowColor: _border,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textDark, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(s.page,
                    style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800,
                        fontSize: 18, letterSpacing: -0.3)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _showFilterModal(events),
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _filter.isActive
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.location_on_rounded, size: 13,
                                color: _filter.isActive ? Colors.white : AppColors.primary),
                            const SizedBox(width: 4),
                            Text(_locationLabel,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: _filter.isActive ? Colors.white : AppColors.primary)),
                            const SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 14,
                                color: _filter.isActive ? Colors.white : AppColors.primary),
                          ]),
                        ),
                        if (_filter.hasNonLocationFilters)
                          Positioned(
                            top: -3, right: -3,
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Center(child: Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(
                                      color: Colors.orange, shape: BoxShape.circle))),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _border),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(children: [

                      // Calendar card
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: _prevMonth,
                                  icon: const Icon(Icons.chevron_left_rounded,
                                      color: AppColors.primary, size: 28),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Text(s.formatMonth(_focusedMonth),
                                    style: const TextStyle(fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _textDark, letterSpacing: -0.3)),
                                IconButton(
                                  onPressed: _nextMonth,
                                  icon: const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.primary, size: 28),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: s.weekdays.map((d) => Expanded(
                                child: Center(child: Text(d,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade400, letterSpacing: 0.5))),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            child: _buildGrid(eventMap),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // Selected date header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(children: [
                          Container(width: 4, height: 18,
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(s.formatDate(_selectedDate),
                              style: const TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800, color: _textDark)),
                          const Spacer(),
                          if (selectedEvts.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(s.eventCount(selectedEvts.length),
                                  style: const TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ),
                        ]),
                      ),

                      // Events or empty state
                      if (selectedEvts.isEmpty)
                        _buildEmptyState()
                      else
                        ...selectedEvts.map((e) {
                          final docId = (e['_doc_id'] ?? '').toString();
                          return _EventCard(
                            event: e,
                            lang: ref.watch(appLangProvider),
                            onOpenLink: _openLink,
                            isLoggedIn: firebaseUser != null,
                            saveStatus: _saveStatuses[docId] ?? _SaveStatus.none,
                            isSaving:   _savingIds[docId] ?? false,
                            regStatus:  _regStatuses[docId] ?? _RegStatus.none,
                            isRegLoading: _regLoading[docId] ?? false,
                            onTapMyEvents:   () => _showSaveConfirmModal(e, _SaveStatus.myEvents),
                            onTapInterested: () => _showSaveConfirmModal(e, _SaveStatus.interested),
                            onTapRegister:   () => _handleRegisterTap(e),
                            onTapCancelReg:  () => _showCancelRegConfirmModal(e),
                          );
                        }),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildGrid(Map<DateTime, List<Map<String, dynamic>>> eventMap) {
    final firstDay     = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth  = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final todayNorm    = DateTime.now();
    final todayKey     = DateTime(todayNorm.year, todayNorm.month, todayNorm.day);

    final cells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) cells.add(const SizedBox());

    for (int day = 1; day <= daysInMonth; day++) {
      final date       = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dayEvents  = _eventsForDate(eventMap, date);
      final hasEvents  = dayEvents.isNotEmpty;
      final isToday    = date == todayKey;
      final isSelected = date ==
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final isPast     = date.isBefore(todayKey);

      cells.add(GestureDetector(
        onTap: () => setState(() => _selectedDate = date),
        child: hasEvents
            ? _EventThumbCell(
            day: day, events: dayEvents,
            isSelected: isSelected, isToday: isToday)
            : _EmptyDayCell(
            day: day, isSelected: isSelected,
            isToday: isToday, isPast: isPast),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: cells,
    );
  }

  Widget _buildEmptyState() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEFF1))),
    child: Row(children: [
      Icon(Icons.event_available_rounded, color: Colors.grey.shade300, size: 32),
      const SizedBox(width: 16),
      Text(s.noEvents,
          style: TextStyle(fontSize: 14,
              color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar cells
// ─────────────────────────────────────────────────────────────────────────────
class _EventThumbCell extends StatelessWidget {
  final int day;
  final List<Map<String, dynamic>> events;
  final bool isSelected, isToday;
  const _EventThumbCell({
    required this.day, required this.events,
    required this.isSelected, required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final count    = events.length;
    final imageUrl = (events.first['event_pic'] ??
        events.first['event_pic_thumbnail'] ??
        events.first['event_image'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          imageUrl.isNotEmpty
              ? Image.network(imageUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.12),
                  child: const Icon(Icons.event, size: 16, color: AppColors.primary)))
              : Container(
              color: AppColors.primary.withOpacity(0.12),
              child: const Icon(Icons.event, size: 16, color: AppColors.primary)),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.06), Colors.black.withOpacity(0.50)],
              ),
            ),
          ),
          if (isSelected) Container(color: AppColors.primary.withOpacity(0.52)),
          Positioned(
            left: 5, bottom: 4,
            child: Text('$day',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))])),
          ),
          Positioned(
            top: 4, right: 4,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Center(child: Text('$count',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900,
                      color: isSelected ? AppColors.primary : Colors.white))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyDayCell extends StatelessWidget {
  final int day;
  final bool isSelected, isToday, isPast;
  const _EmptyDayCell({
    required this.day, required this.isSelected,
    required this.isToday, required this.isPast,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: isSelected
          ? AppColors.primary
          : isToday
          ? AppColors.primary.withOpacity(0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: isToday && !isSelected
          ? Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5)
          : null,
    ),
    child: Center(
      child: Text('$day',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isPast
                ? Colors.grey.shade300
                : const Color(0xFF1A1A1A),
          )),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Card — updated registration section with 3-step form
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String lang;
  final Future<void> Function(String) onOpenLink;
  final bool isLoggedIn;
  final _SaveStatus saveStatus;
  final bool isSaving;
  final _RegStatus regStatus;
  final bool isRegLoading;
  final VoidCallback onTapMyEvents;
  final VoidCallback onTapInterested;
  final VoidCallback onTapRegister;
  final VoidCallback onTapCancelReg;

  const _EventCard({
    required this.event,
    required this.lang,
    required this.onOpenLink,
    required this.isLoggedIn,
    required this.saveStatus,
    required this.isSaving,
    required this.regStatus,
    required this.isRegLoading,
    required this.onTapMyEvents,
    required this.onTapInterested,
    required this.onTapRegister,
    required this.onTapCancelReg,
  });

  bool get _isJa => lang == kLangJa;

  String get _title => _isJa
      ? (event['event_title_jp'] ?? event['event_title'] ?? 'Untitled Event').toString()
      : (event['event_title'] ?? 'Untitled Event').toString();

  String get _location => _isJa
      ? (event['location_jp'] ?? event['location'] ?? event['event_venue_name'] ?? '').toString()
      : (event['location'] ?? event['event_venue_name'] ?? '').toString();

  String get _address => _isJa
      ? (event['event_address_jp'] ?? event['event_address'] ?? event['event_venue_address'] ?? '').toString()
      : (event['event_address'] ?? event['event_venue_address'] ?? '').toString();

  String get _orgName => _isJa
      ? (event['org_name_jp'] ?? event['org_name'] ?? event['event_org_name'] ?? '').toString()
      : (event['org_name'] ?? event['event_org_name'] ?? '').toString();

  String get _imageUrl =>
      (event['event_pic'] ?? event['event_pic_thumbnail'] ?? event['event_image'] ?? '').toString();

  String get _googleLink =>
      (event['event_googlelink'] ?? event['event_venue_link'] ?? '').toString();

  String get _contact =>
      (event['event_contact'] ?? event['event_email'] ?? '').toString();

  // Capacity helpers
  int? get _eventLimit => event['event_limit'] != null
      ? int.tryParse(event['event_limit'].toString())
      : null;
  int get _approvedCount => (event['event_approved_count'] ?? 0) as int;
  bool get _isFull => _eventLimit != null && _approvedCount >= _eventLimit!;
  bool get _regOpen => event['event_registration_open'] != false;

  // Owner check
  bool get _isEventOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    final submittedBy = (event['submittedBy'] ?? '').toString();
    return submittedBy.isNotEmpty && submittedBy == currentUser.uid;
  }

  String _fee(String freeLabel) {
    final f = event['event_fee'];
    if (f == null || f.toString().isEmpty ||
        f.toString() == '0' || f.toString() == '0.0') return freeLabel;
    return '¥${f.toString()}';
  }

  DateTime? get _startDate {
    final ts = event['event_date'] ?? event['event_start_date'];
    if (ts == null) return null;
    return (ts as Timestamp).toDate();
  }

  DateTime? get _endDate {
    final ts = event['event_date_end'];
    if (ts == null) return null;
    return (ts as Timestamp).toDate();
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    if (raw is Timestamp) {
      final dt = raw.toDate();
      if (_isJa) return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      return DateFormat('h:mm a').format(dt);
    }
    return raw.toString();
  }

  List<String> _getSkillTags() {
    final tags = <String>[];
    if (event['event_skill_level_pro']      == true) tags.add(_isJa ? '上級' : 'PRO');
    if (event['event_skill_level_amateur']   == true) tags.add(_isJa ? '中級' : 'AMATEUR');
    if (event['event_skill_level_beginner']  == true) tags.add(_isJa ? '初級' : 'BEGINNER');
    return tags;
  }

  List<String> _getCategoryTags() {
    final tags = <String>[];
    if (event['event_category_menssingle']    == true) tags.add(_isJa ? '男子シングルス' : "MEN'S SINGLES");
    if (event['event_category_womenssingle']  == true) tags.add(_isJa ? '女子シングルス' : "WOMEN'S SINGLES");
    if (event['event_category_mixeddoubles']  == true) tags.add(_isJa ? 'ミックスダブルス' : 'MIXED DOUBLES');
    if (event['event_category_mensdoubles']   == true) tags.add(_isJa ? '男子ダブルス' : "MEN'S DOUBLES");
    if (event['event_category_womensdoubles'] == true) tags.add(_isJa ? '女子ダブルス' : "WOMEN'S DOUBLES");
    if (event['event_category_juniors']       == true) tags.add(_isJa ? 'ジュニア' : 'JUNIORS');
    if (event['event_category_collegiate']    == true) tags.add(_isJa ? '学生' : 'COLLEGIATE');
    if (event['event_category_seniors']       == true) tags.add(_isJa ? 'シニア' : 'SENIORS');
    return tags;
  }

  static const Color _surface   = Colors.white;
  static const Color _border    = Color(0xFFEEEFF1);
  static const Color _textDark  = Color(0xFF0D0D0D);
  static const Color _textLight = Color(0xFF888A90);
  static const Color _red       = Color(0xFFD32F2F);
  static const Color _redLt     = Color(0xFFFFEBEE);
  static const Color _amber     = Color(0xFFD97706);
  static const Color _amberLt   = Color(0xFFFFF3CD);

  @override
  Widget build(BuildContext context) {
    final _S s      = _S(lang);
    final freeLabel = s.free;
    final feeStr    = _fee(freeLabel);
    final isFree    = feeStr == freeLabel;
    final startDate = _startDate;
    final endDate   = _endDate;
    final timeRaw   = event['event_time'] ?? event['event_start_time'];
    final timeStr   = _formatTime(timeRaw);
    final hasImage  = _imageUrl.isNotEmpty;
    final hasGMap   = _googleLink.isNotEmpty;
    final hasOrg    = _orgName.isNotEmpty;
    final address   = _address;
    final location  = _location;
    final locDisplay = location.isNotEmpty ? location : address;
    final skillTags = _getSkillTags();
    final catTags   = _getCategoryTags();
    final allTags   = [...skillTags, ...catTags];
    final contact   = _contact;

    final isSavedMyEvents   = saveStatus == _SaveStatus.myEvents;
    final isSavedInterested = saveStatus == _SaveStatus.interested;

    // Capacity
    final eventLimit    = _eventLimit;
    final approvedCount = _approvedCount;
    final isFull        = _isFull;
    final regOpen       = _regOpen;
    final fillPct = eventLimit != null && eventLimit > 0
        ? (approvedCount / eventLimit).clamp(0.0, 1.0)
        : 0.0;
    final fillColor = fillPct >= 0.9
        ? _red
        : fillPct >= 0.7 ? _amber : AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        if (hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(_imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.08),
                      child: const Icon(Icons.event, size: 40, color: AppColors.primary))),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(_title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: _textDark, letterSpacing: -0.3))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isFree ? Colors.green.shade50 : AppColors.primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(feeStr,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: isFree ? Colors.green.shade600 : AppColors.primary)),
              ),
            ]),

            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Text(timeStr, style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              ]),
            ],

            if (locDisplay.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: hasGMap ? () => onOpenLink(_googleLink) : null,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.location_on_rounded, size: 14,
                      color: hasGMap ? AppColors.primary : Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Expanded(child: Text(locDisplay,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: hasGMap ? AppColors.primary : Colors.grey.shade500,
                          decoration: hasGMap ? TextDecoration.underline : TextDecoration.none,
                          decorationColor: AppColors.primary))),
                  if (hasGMap) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.primary),
                  ],
                ]),
              ),
            ],

            if (hasOrg) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Expanded(child: Text(_orgName,
                    style: TextStyle(fontSize: 13,
                        color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
              ]),
            ],

            const SizedBox(height: 20),
            Container(height: 1, color: _border),
            const SizedBox(height: 20),

            if (startDate != null) ...[
              _SectionLabel(label: s.secDateTime),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F8F4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.formatDateLong(startDate),
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w800, color: _textDark)),
                        if (timeStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(timeStr,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ),
                        if (endDate != null) ...[
                          const SizedBox(height: 6),
                          RichText(text: TextSpan(children: [
                            TextSpan(text: '${s.ends} ',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600)),
                            TextSpan(text: s.formatDateLong(endDate),
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ])),
                        ],
                        if (contact.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          RichText(text: TextSpan(children: [
                            TextSpan(text: '${s.contact} ',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600)),
                            TextSpan(text: contact,
                                style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                          ])),
                        ],
                        // ── Capacity progress bar ──
                        if (eventLimit != null) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Text('$approvedCount / $eventLimit ${_isJa ? '名参加中' : 'filled'}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            if (isFull)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _redLt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(_isJa ? '満席' : 'Full',
                                    style: const TextStyle(fontSize: 10,
                                        fontWeight: FontWeight.w800, color: _red)),
                              )
                            else
                              Text(s.slotsLeft((eventLimit - approvedCount).clamp(0, 9999)),
                                  style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w700, color: fillColor)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fillPct,
                              minHeight: 5,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  isFull ? _red : fillColor),
                            ),
                          ),
                        ],
                      ])),
                ]),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: _border),
              const SizedBox(height: 20),
            ],

            if (allTags.isNotEmpty) ...[
              _SectionLabel(label: s.secCatSkill),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: allTags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Text(tag,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                          color: AppColors.primary, letterSpacing: 0.3)),
                )).toList(),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: _border),
              const SizedBox(height: 20),
            ],

            if (locDisplay.isNotEmpty || address.isNotEmpty) ...[
              _SectionLabel(label: s.secLoc),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F8F4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(locDisplay,
                              style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w800, color: _textDark)),
                          if (address.isNotEmpty && address != locDisplay)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(address,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                            ),
                        ])),
                  ]),
                  if (hasGMap) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => onOpenLink(_googleLink),
                      child: Row(children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(s.viewOnMaps,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: _border),
              const SizedBox(height: 20),
            ],

            // SAVE section
            if (isLoggedIn) ...[
              _SectionLabel(label: s.secSave),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: isSaving ? null : onTapMyEvents,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSavedMyEvents
                        ? AppColors.primary.withOpacity(0.06)
                        : const Color(0xFFF2F8F4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSavedMyEvents
                          ? AppColors.primary.withOpacity(0.5)
                          : AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSavedMyEvents ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: AppColors.primary, size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.saveMyEvents,
                              style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w800, color: _textDark)),
                          Text(s.saveMyEventsSub,
                              style: const TextStyle(fontSize: 12, color: _textLight)),
                        ])),
                    if (isSaving)
                      const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    else if (isSavedMyEvents)
                      const Icon(Icons.check_rounded, color: AppColors.primary, size: 22)
                    else
                      const Icon(Icons.chevron_right_rounded, color: _textLight, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: isSaving ? null : onTapInterested,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSavedInterested
                        ? const Color(0xFFFFF8E7)
                        : const Color(0xFFF2F8F4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSavedInterested
                          ? const Color(0xFFD4A017).withOpacity(0.5)
                          : AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isSavedInterested
                            ? const Color(0xFFFFF0C0)
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSavedInterested ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isSavedInterested ? const Color(0xFFD4A017) : AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.saveInterested,
                              style: const TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w800, color: _textDark)),
                          Text(s.saveInterestedSub,
                              style: const TextStyle(fontSize: 12, color: _textLight)),
                        ])),
                    if (isSaving)
                      const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    else if (isSavedInterested)
                      const Icon(Icons.check_rounded, color: Color(0xFFD4A017), size: 22)
                    else
                      const Icon(Icons.chevron_right_rounded, color: _textLight, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: _border),
              const SizedBox(height: 20),
            ],

            // ── REGISTRATION section ───────────────────────────────────
            _SectionLabel(label: s.secRegistration),
            const SizedBox(height: 12),

            // Organizer viewing own event
            if (_isEventOwner)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _isJa ? 'あなたが主催するイベント' : 'You are the organizer',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isJa ? '自分のイベントへの登録は不要です。' : 'Registration is not required for your own event.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ])),
                ]),
              )

            // Not logged in
            else if (!isLoggedIn)
              Text(s.loginToRegister,
                  style: const TextStyle(fontSize: 13, color: _textLight))

            // Registration closed
            else if (!regOpen)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4E9EE)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(Icons.lock_rounded, color: Colors.grey.shade500, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.registrationClosed,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text(s.regClosedMsg,
                          style: const TextStyle(fontSize: 12, color: _textLight)),
                    ])),
                  ]),
                )

              // Has existing registration
              else if (regStatus != _RegStatus.none)
                  Column(children: [
                    // Status banner
                    _RegStatusBanner(regStatus: regStatus, s: s),
                    // Cancel button for pending/rejected/waitlist
                    if (regStatus == _RegStatus.pending ||
                        regStatus == _RegStatus.rejected ||
                        regStatus == _RegStatus.waitlist) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isRegLoading ? null : onTapCancelReg,
                          icon: isRegLoading
                              ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _red))
                              : const Icon(Icons.cancel_outlined, size: 16, color: _red),
                          label: Text(s.cancelReg,
                              style: const TextStyle(color: _red,
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: _red.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ])

                // Full event — show waitlist button
                else if (isFull)
                    Column(children: [
                      // Capacity reached banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _redLt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _red.withOpacity(0.25)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                                color: _red.withOpacity(0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.people_alt_rounded, color: _red, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.capacityReached,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: _red)),
                            const SizedBox(height: 2),
                            Text(s.capacityMsg,
                                style: const TextStyle(fontSize: 12, color: _textLight)),
                          ])),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isRegLoading ? null : onTapRegister,
                          icon: isRegLoading
                              ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.schedule_rounded, size: 18, color: Colors.white),
                          label: Text(
                            isRegLoading ? s.joiningWaitlist : s.joinWaitlist,
                            style: const TextStyle(fontWeight: FontWeight.w800,
                                color: Colors.white, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amber,
                            disabledBackgroundColor: _amber.withOpacity(0.5),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ])

                  // Normal register button
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isRegLoading ? null : onTapRegister,
                        icon: isRegLoading
                            ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.how_to_reg_rounded, size: 18, color: Colors.white),
                        label: Text(
                          isRegLoading ? s.registering : s.registerBtn,
                          style: const TextStyle(fontWeight: FontWeight.w800,
                              color: Colors.white, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Registration status banner widget
// ─────────────────────────────────────────────────────────────────────────────
class _RegStatusBanner extends StatelessWidget {
  final _RegStatus regStatus;
  final _S s;

  const _RegStatusBanner({required this.regStatus, required this.s});

  static const Color _red   = Color(0xFFD32F2F);
  static const Color _redLt = Color(0xFFFFEBEE);
  static const Color _amber = Color(0xFFD97706);
  static const Color _amberLt = Color(0xFFFFF3CD);

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    final Color border;
    final IconData icon;
    final String title;
    final String subtitle;

    switch (regStatus) {
      case _RegStatus.approved:
        color = AppColors.primary;
        bg = AppColors.primary.withOpacity(0.08);
        border = AppColors.primary.withOpacity(0.3);
        icon = Icons.check_circle_rounded;
        title = s.registrationApproved;
        subtitle = s.regApprovedMsg;
      case _RegStatus.rejected:
        color = _red; bg = _redLt; border = _red.withOpacity(0.3);
        icon = Icons.cancel_rounded;
        title = s.registrationRejected;
        subtitle = s.regRejectedMsg;
      case _RegStatus.waitlist:
        color = _amber; bg = _amberLt; border = _amber.withOpacity(0.3);
        icon = Icons.schedule_rounded;
        title = s.registrationWaitlist;
        subtitle = s.regWaitlistMsg;
      default:
        color = _amber; bg = _amberLt; border = _amber.withOpacity(0.3);
        icon = Icons.pending_rounded;
        title = s.registrationPending;
        subtitle = s.alreadyRegistered;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label widget
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
        color: AppColors.primary, letterSpacing: 1.2),
  );
}