import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNotification {
  final String id;
  final String type; // 'group_invite' | 'invite_response' | 'registration' | 'org_reg_request' | 'org_group_join' | 'admin_event' | 'admin_group' | 'admin_court' | 'admin_inquiry' | 'admin_review' | 'admin_user'
  final String title;
  final String titleJp;
  final String subtitle;
  final String subtitleJp;
  final DateTime? createdAt;
  final String targetId;
  final String? status;
  final Map<String, dynamic> rawData;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.titleJp,
    required this.subtitle,
    required this.subtitleJp,
    this.createdAt,
    required this.targetId,
    this.status,
    required this.rawData,
  });
}

final notificationProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final controller = StreamController<List<AppNotification>>();

  final authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) {
      controller.add([]);
      return;
    }

    final uid = user.uid;
    final List<StreamSubscription> activeSubs = [];

    List<AppNotification> groupInvites = [];
    List<AppNotification> inviteResponses = [];
    List<AppNotification> registrations = [];
    List<AppNotification> orgRegRequests = [];
    List<AppNotification> orgGroupJoins = [];

    List<AppNotification> adminEvents = [];
    List<AppNotification> adminGroups = [];
    List<AppNotification> adminCourts = [];
    List<AppNotification> adminInquiries = [];
    List<AppNotification> adminReviews = [];
    List<AppNotification> adminUsers = [];

    bool isAdmin = false;

    void rebuild() {
      if (controller.isClosed) return;

      final combined = [
        ...groupInvites,
        ...inviteResponses,
        ...registrations,
        ...orgRegRequests,
        ...orgGroupJoins,
        if (isAdmin) ...[
          ...adminEvents,
          ...adminGroups,
          ...adminCourts,
          ...adminInquiries,
          ...adminReviews,
          ...adminUsers,
        ]
      ];

      // Sort by date descending
      combined.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      controller.add(combined);
    }

    // 1. Group Invites
    final groupInvitesSub = FirebaseFirestore.instance
        .collection('group_invites')
        .where('recipient_uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      groupInvites = snap.docs.map((docSnap) {
        final data = docSnap.data();
        final date = (data['invited_at'] as Timestamp?)?.toDate();
        return AppNotification(
          id: docSnap.id,
          type: 'group_invite',
          title: 'Group Invite Received',
          titleJp: 'グループ招待',
          subtitle: 'You are invited to join "${data['group_name'] ?? 'Unnamed Group'}" by ${data['invited_by_name'] ?? 'someone'}.',
          subtitleJp: '${data['invited_by_name'] ?? 'どなたか'}から「${data['group_name'] ?? '名称未設定'}」への招待があります。',
          createdAt: date,
          targetId: (data['group_id'] ?? '').toString(),
          status: 'pending',
          rawData: data,
        );
      }).toList();
      rebuild();
    }, onError: (e) => debugPrint('groupInvitesSub error: $e'));
    activeSubs.add(groupInvitesSub);

    // 2. Invite Responses
    final inviteResponsesSub = FirebaseFirestore.instance
        .collection('group_invites')
        .where('invited_by', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final all = snap.docs.map((docSnap) {
        final data = docSnap.data();
        final date = (data['responded_at'] as Timestamp?)?.toDate();
        final status = (data['status'] ?? '').toString();
        final groupName = (data['group_name'] ?? 'group').toString();
        final seen = data['organizer_seen'] == true;

        if (seen) return null;

        if (status == 'accepted') {
          return AppNotification(
            id: docSnap.id,
            type: 'invite_response',
            title: 'Invite Accepted',
            titleJp: '招待承認',
            subtitle: '${data['accepted_by_name'] ?? 'Someone'} joined your group "$groupName".',
            subtitleJp: '${data['accepted_by_name'] ?? '誰か'}が「$groupName」に参加しました！',
            createdAt: date,
            targetId: (data['group_id'] ?? '').toString(),
            status: status,
            rawData: data,
          );
        } else if (status == 'declined') {
          return AppNotification(
            id: docSnap.id,
            type: 'invite_response',
            title: 'Invite Declined',
            titleJp: '招待辞退',
            subtitle: '${data['declined_by_name'] ?? 'Someone'} declined your invite to "$groupName".',
            subtitleJp: '${data['declined_by_name'] ?? '誰か'}が「$groupName」への招待を辞退しました。',
            createdAt: date,
            targetId: (data['group_id'] ?? '').toString(),
            status: status,
            rawData: data,
          );
        }
        return null;
      }).whereType<AppNotification>().toList();
      inviteResponses = all;
      rebuild();
    }, onError: (e) => debugPrint('inviteResponsesSub error: $e'));
    activeSubs.add(inviteResponsesSub);

    // 3. Registrations (participant updates)
    final registrationsSub = FirebaseFirestore.instance
        .collection('event_registrations')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      registrations = snap.docs.map((docSnap) {
        final data = docSnap.data();
        final date = (data['updated_at'] as Timestamp?)?.toDate();
        final status = (data['status'] ?? '').toString();
        final seen = data['user_seen'] == true;
        final eventTitle = (data['event_title'] ?? 'event').toString();
        final eventTitleJp = (data['event_title_jp'] ?? eventTitle).toString();

        if (seen || !['approved', 'rejected', 'waitlist'].contains(status)) {
          return null;
        }

        String title = 'Registration Approved';
        String titleJp = '登録承認済み';
        String subtitle = 'Your registration for "$eventTitle" has been approved!';
        String subtitleJp = '「$eventTitleJp」の参加申し込みが承認されました！';

        if (status == 'rejected') {
          title = 'Registration Rejected';
          titleJp = '登録却下';
          subtitle = 'Your registration for "$eventTitle" was rejected.';
          subtitleJp = '「$eventTitleJp」の参加申し込みは承認されませんでした。';
        } else if (status == 'waitlist') {
          title = 'On Waitlist';
          titleJp = 'ウェイティングリスト待機中';
          subtitle = 'You have been placed on the waitlist for "$eventTitle".';
          subtitleJp = '「$eventTitleJp」のウェイティングリストに移動しました。';
        }

        return AppNotification(
          id: docSnap.id,
          type: 'registration',
          title: title,
          titleJp: titleJp,
          subtitle: subtitle,
          subtitleJp: subtitleJp,
          createdAt: date,
          targetId: (data['event_id'] ?? '').toString(),
          status: status,
          rawData: data,
        );
      }).whereType<AppNotification>().toList();
      rebuild();
    }, onError: (e) => debugPrint('registrationsSub error: $e'));
    activeSubs.add(registrationsSub);

    // 4. Organizer Reg Requests
    final orgRegRequestsSub = FirebaseFirestore.instance
        .collection('event_registrations')
        .where('organizer_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      orgRegRequests = snap.docs.map((docSnap) {
        final data = docSnap.data();
        final date = (data['registered_at'] as Timestamp?)?.toDate();
        final status = (data['status'] ?? '').toString();
        final seen = data['organizer_seen'] == true;
        final eventTitle = (data['event_title'] ?? 'event').toString();
        final eventTitleJp = (data['event_title_jp'] ?? eventTitle).toString();
        final userName = (data['user_name'] ?? 'Someone').toString();

        if (seen || status != 'pending') {
          return null;
        }

        return AppNotification(
          id: docSnap.id,
          type: 'org_reg_request',
          title: 'Registration Request',
          titleJp: '参加申込リクエスト',
          subtitle: '$userName requested to join "$eventTitle".',
          subtitleJp: '$userNameさんが「$eventTitleJp」への参加を申し込みました。',
          createdAt: date,
          targetId: (data['event_id'] ?? '').toString(),
          status: status,
          rawData: data,
        );
      }).whereType<AppNotification>().toList();
      rebuild();
    }, onError: (e) => debugPrint('orgRegRequestsSub error: $e'));
    activeSubs.add(orgRegRequestsSub);

    // 5. Organizer Group Joins
    final orgGroupJoinsSub = FirebaseFirestore.instance
        .collection('user_groups')
        .where('organizer_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      orgGroupJoins = snap.docs.map((docSnap) {
        final data = docSnap.data();
        final date = (data['joined_at'] as Timestamp?)?.toDate();
        final seen = data['organizer_seen'] == true;
        final groupName = (data['group_name'] ?? 'group').toString();
        final userName = (data['user_name'] ?? 'Someone').toString();

        if (seen) return null;

        return AppNotification(
          id: docSnap.id,
          type: 'org_group_join',
          title: 'New Group Member',
          titleJp: '新しいメンバー',
          subtitle: '$userName joined "$groupName".',
          subtitleJp: '$userNameさんが「$groupName」に参加しました。',
          createdAt: date,
          targetId: (data['group_id'] ?? '').toString(),
          status: 'joined',
          rawData: data,
        );
      }).whereType<AppNotification>().toList();
      rebuild();
    }, onError: (e) => debugPrint('orgGroupJoinsSub error: $e'));
    activeSubs.add(orgGroupJoinsSub);

    // 6. Admin notifications handling
    StreamSubscription? profileSub;
    StreamSubscription? adminEventsSub;
    StreamSubscription? adminGroupsSub;
    StreamSubscription? adminCourtsSub;
    StreamSubscription? adminInquiriesSub;
    StreamSubscription? adminReviewsSub;
    StreamSubscription? adminUsersSub;

    void cleanupAdminSubs() {
      adminEventsSub?.cancel();
      adminGroupsSub?.cancel();
      adminCourtsSub?.cancel();
      adminInquiriesSub?.cancel();
      adminReviewsSub?.cancel();
      adminUsersSub?.cancel();
    }

    profileSub = FirebaseFirestore.instance
        .collection('registration')
        .doc(uid)
        .snapshots()
        .listen((profileSnap) {
      if (!profileSnap.exists) {
        isAdmin = false;
        cleanupAdminSubs();
        rebuild();
        return;
      }

      final profileData = profileSnap.data()!;
      final nextIsAdmin = profileData['is_admin'] == true;

      if (nextIsAdmin == isAdmin) return; // No change in role

      isAdmin = nextIsAdmin;
      cleanupAdminSubs();

      if (isAdmin) {
        // Admin Event requests
        adminEventsSub = FirebaseFirestore.instance
            .collection('events')
            .where('admin_seen', isEqualTo: false)
            .snapshots()
            .listen((snap) {
          adminEvents = snap.docs.map((d) {
            final data = d.data();
            final date = (data['event_created'] ?? data['event_added'] ?? data['createdAt'] as Timestamp?)?.toDate();
            final title = (data['event_title'] ?? 'Untitled').toString();
            final titleJp = (data['event_title_jp'] ?? title).toString();
            return AppNotification(
              id: d.id,
              type: 'admin_event',
              title: 'Event Approval Request',
              titleJp: 'イベント承認リクエスト',
              subtitle: '"$title" is pending review.',
              subtitleJp: '「$titleJp」が承認待ちです。',
              createdAt: date,
              targetId: d.id,
              rawData: data,
            );
          }).toList();
          rebuild();
        }, onError: (e) => debugPrint('adminEventsSub error: $e'));

        // Admin Group requests
        adminGroupsSub = FirebaseFirestore.instance
            .collection('organizations')
            .where('admin_seen', isEqualTo: false)
            .snapshots()
            .listen((snap) {
          adminGroups = snap.docs.map((d) {
            final data = d.data();
            final date = (data['org_created_at'] ?? data['org_added'] ?? data['createdAt'] as Timestamp?)?.toDate();
            final title = (data['org_name'] ?? 'Unnamed').toString();
            final titleJp = (data['org_name_jp'] ?? title).toString();
            return AppNotification(
              id: d.id,
              type: 'admin_group',
              title: 'Group Approval Request',
              titleJp: 'グループ承認リクエスト',
              subtitle: '"$title" is pending review.',
              subtitleJp: '「$titleJp」が承認待ちです。',
              createdAt: date,
              targetId: d.id,
              rawData: data,
            );
          }).toList();
          rebuild();
        }, onError: (e) => debugPrint('adminGroupsSub error: $e'));

        // Admin Court requests
        adminCourtsSub = FirebaseFirestore.instance
            .collection('locations')
            .where('admin_seen', isEqualTo: false)
            .snapshots()
            .listen((snap) {
          adminCourts = snap.docs.map((d) {
            final data = d.data();
            final date = (data['loc_added'] ?? data['createdAt'] as Timestamp?)?.toDate();
            final title = (data['loc_name'] ?? 'Unnamed').toString();
            final titleJp = (data['loc_name_jp'] ?? title).toString();
            return AppNotification(
              id: d.id,
              type: 'admin_court',
              title: 'Court Approval Request',
              titleJp: 'コート承認リクエスト',
              subtitle: '"$title" is pending review.',
              subtitleJp: '「$titleJp」が承認待ちです。',
              createdAt: date,
              targetId: d.id,
              rawData: data,
            );
          }).toList();
          rebuild();
        }, onError: (e) => debugPrint('adminCourtsSub error: $e'));

        // Admin Inquiries
        adminInquiriesSub = FirebaseFirestore.instance
            .collection('contact_us')
            .where('admin_seen', isEqualTo: false)
            .snapshots()
            .listen((snap) {
          adminInquiries = snap.docs.map((d) {
            final data = d.data();
            final date = (data['submitted_at'] as Timestamp?)?.toDate();
            final name = (data['name'] ?? 'Anonymous').toString();
            final msg = (data['message'] ?? '').toString();
            return AppNotification(
              id: d.id,
              type: 'admin_inquiry',
              title: 'New Inquiry',
              titleJp: '新しいお問い合わせ',
              subtitle: 'Message from $name: "$msg"',
              subtitleJp: '$nameさんからのメッセージ: 「$msg」',
              createdAt: date,
              targetId: d.id,
              rawData: data,
            );
          }).toList();
          rebuild();
        }, onError: (e) => debugPrint('adminInquiriesSub error: $e'));

        // Admin Reviews
        adminReviewsSub = FirebaseFirestore.instance
            .collection('reviews')
            .where('admin_seen', isEqualTo: false)
            .snapshots()
            .listen((snap) {
          adminReviews = snap.docs.map((d) {
            final data = d.data();
            final date = (data['created_at'] as Timestamp?)?.toDate();
            final text = (data['text'] ?? 'Photo only').toString();
            final userName = (data['user_name'] ?? 'User').toString();
            return AppNotification(
              id: d.id,
              type: 'admin_review',
              title: 'Review Moderation Request',
              titleJp: 'レビュー承認リクエスト',
              subtitle: '"$text" posted by $userName.',
              subtitleJp: '$userNameさんが投稿: 「$text」',
              createdAt: date,
              targetId: d.id,
              rawData: data,
            );
          }).toList();
          rebuild();
        }, onError: (e) => debugPrint('adminReviewsSub error: $e'));

        // Admin Users
        adminUsersSub = FirebaseFirestore.instance
            .collection('registration')
            .where('admin_seen', isEqualTo: false)
            .snapshots()
            .listen((snap) {
          adminUsers = snap.docs.map((d) {
            final data = d.data();
            final date = (data['createdAt'] as Timestamp?)?.toDate();
            final name = (data['nickname'] ?? 'No name').toString();
            final email = (data['email'] ?? 'No email').toString();
            return AppNotification(
              id: d.id,
              type: 'admin_user',
              title: 'New User Registered',
              titleJp: '新しいユーザー登録',
              subtitle: 'User $name ($email) signed up.',
              subtitleJp: 'ユーザー「$name」 ($email) が登録しました。',
              createdAt: date,
              targetId: d.id,
              rawData: data,
            );
          }).toList();
          rebuild();
        }, onError: (e) => debugPrint('adminUsersSub error: $e'));
      } else {
        rebuild();
      }
    }, onError: (e) => debugPrint('profileSub error: $e'));

    // Cleanup callback on auth changes / provider dispose
    ref.onDispose(() {
      for (final sub in activeSubs) sub.cancel();
      profileSub?.cancel();
      cleanupAdminSubs();
    });
  });

  ref.onDispose(() {
    authSub.cancel();
    controller.close();
  });

  return controller.stream;
});
