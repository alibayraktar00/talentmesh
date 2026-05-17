import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/theme/app_colors.dart';
import '../core/services/notification_service.dart';
import '../core/services/profile_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'inbox_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _client = Supabase.instance.client;
  final _notificationService = NotificationService();
  final _profileService = ProfileService();

  bool _isIncomingLoading = true;
  bool _isFriendsLoading = true;
  bool _isMarkingRead = false;
  int _unreadCount = 0;

  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _actionLoadingIds = {};

  RealtimeChannel? _realtimeChannel;
  StreamSubscription<List<Map<String, dynamic>>>? _unreadMessagesSub;
  Map<String, int> _unreadCountByFriendId = {};
  Map<String, DateTime> _lastMessageAtByFriendId = {};
  bool _isUpdatingDelivered = false;

  String? get _myUserId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _unreadMessagesSub?.cancel();
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadIncomingRequests(), _loadFriends()]);
    _setupRealtime();
    _setupUnreadMessagesStream();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadIncomingRequests() async {
    final myId = _myUserId;
    if (myId == null) return;

    setState(() => _isIncomingLoading = true);
    try {
      // Türkçe yorum (Aşama 1): Önce sadece bana gelen pending istekleri çekiyoruz.
      // request_type kolonu varsa friend filtreliyoruz; yoksa fallback ile filtresiz devam ediyoruz.
      dynamic rows;
      try {
        rows = await _client
            .from('friend_requests')
            .select()
            .eq('addressee_id', myId)
            .eq('status', 'pending')
            .eq('request_type', 'friend')
            .order('id', ascending: false);
      } on PostgrestException {
        rows = await _client
            .from('friend_requests')
            .select()
            .eq('addressee_id', myId)
            .eq('status', 'pending')
            .order('id', ascending: false);
      }

      final requestRows = List<Map<String, dynamic>>.from(rows);

      if (requestRows.isEmpty) {
        if (!mounted) return;
        setState(() {
          _incomingRequests = [];
          _unreadCount = 0;
        });
        return;
      }

      // Türkçe yorum (Aşama 2): İstek atan kişilerin id listesini çıkarıp profilleri çekiyoruz.
      final requesterIds = requestRows
          .map((r) => (r['requester_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesById = {};
      if (requesterIds.isNotEmpty) {
        final profileRows = await _client
            .from('profiles')
            .select()
            .inFilter('id', requesterIds);
        for (final p in List<Map<String, dynamic>>.from(profileRows)) {
          final id = (p['id'] ?? '').toString();
          if (id.isNotEmpty) {
            profilesById[id] = p;
          }
        }
      }

      final unread = requestRows.where((r) => r['is_read'] == false).length;

      if (!mounted) return;
      setState(() {
        // Türkçe yorum (Aşama 3): requests + profiles verisini requester_id ile Dart tarafında birleştiriyoruz.
        _incomingRequests = requestRows.map((r) {
          final requesterId = (r['requester_id'] ?? '').toString();
          return {
            ...r,
            'requester_profile':
                profilesById[requesterId] ?? <String, dynamic>{},
          };
        }).toList();
        _unreadCount = unread;
      });

      // Türkçe yorum: Kullanıcı listeyi gördüğünde okunmamış istekleri okundu yapıyoruz.
      await _markIncomingAsRead();
    } on PostgrestException catch (e) {
      _showError('friends.error_incoming'.tr(args: [e.message]));
    } catch (_) {
      _showError('friends.error_incoming_generic'.tr());
    } finally {
      if (mounted) setState(() => _isIncomingLoading = false);
    }
  }

  Future<void> _markIncomingAsRead() async {
    final myId = _myUserId;
    if (myId == null || _isMarkingRead) return;
    if (_incomingRequests.isEmpty) return;
    if (!_incomingRequests.any((r) => r['is_read'] == false)) return;

    _isMarkingRead = true;
    try {
      await _client
          .from('friend_requests')
          .update({'is_read': true})
          .eq('addressee_id', myId)
          .eq('status', 'pending')
          .eq('request_type', 'friend')
          .eq('is_read', false);

      if (!mounted) return;
      setState(() {
        _incomingRequests = _incomingRequests
            .map((r) => {...r, 'is_read': true})
            .toList();
        _unreadCount = 0;
      });
    } catch (_) {
      // Sessiz geçiyoruz; badge bir sonraki fetch'te düzelir.
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _loadFriends() async {
    final myId = _myUserId;
    if (myId == null) return;

    setState(() => _isFriendsLoading = true);
    try {
      // Türkçe yorum: Sadece accepted + request_type=friend kayıtlarını çekiyoruz.
      final outgoing = await _client
          .from('friend_requests')
          .select('requester_id, addressee_id')
          .eq('requester_id', myId)
          .eq('status', 'accepted')
          .eq('request_type', 'friend');

      final incoming = await _client
          .from('friend_requests')
          .select('requester_id, addressee_id')
          .eq('addressee_id', myId)
          .eq('status', 'accepted')
          .eq('request_type', 'friend');

      final friendIds = <String>{};
      for (final row in List<Map<String, dynamic>>.from(outgoing)) {
        final otherId = (row['addressee_id'] ?? '').toString();
        if (otherId.isNotEmpty && otherId != myId) friendIds.add(otherId);
      }
      for (final row in List<Map<String, dynamic>>.from(incoming)) {
        final otherId = (row['requester_id'] ?? '').toString();
        if (otherId.isNotEmpty && otherId != myId) friendIds.add(otherId);
      }

      List<Map<String, dynamic>> friends = [];
      if (friendIds.isNotEmpty) {
        final rows = await _client
            .from('profiles')
            .select('id, username, full_name')
            .inFilter('id', friendIds.toList())
            .order('username', ascending: true);
        friends = List<Map<String, dynamic>>.from(rows);
      }

      if (!mounted) return;
      setState(() {
        _friends = friends;
        _sortFriendsByPriority();
      });
    } on PostgrestException catch (e) {
      _showError('friends.error_friends'.tr(args: [e.message]));
    } catch (_) {
      _showError('friends.error_friends_generic'.tr());
    } finally {
      if (mounted) setState(() => _isFriendsLoading = false);
    }
  }

  Future<void> _setRequestStatus({
    required String requestId,
    required String newStatus,
  }) async {
    if (_actionLoadingIds.contains(requestId)) return;
    setState(() => _actionLoadingIds.add(requestId));

    Map<String, dynamic>? matchedRequest;
    for (final r in _incomingRequests) {
      if (r['id'].toString() == requestId) {
        matchedRequest = r;
        break;
      }
    }
    final requesterId = (matchedRequest?['requester_id'] ?? '').toString();

    try {
      await _client
          .from('friend_requests')
          .update({'status': newStatus, 'is_read': true})
          .eq('id', requestId);

      if (newStatus == 'accepted' && requesterId.isNotEmpty) {
        await _notificationService.notifyFriendAccepted(
          requesterId: requesterId,
        );
      }

      if (!mounted) return;
      setState(() {
        _incomingRequests.removeWhere((r) => r['id'].toString() == requestId);
      });
      await _loadFriends();
    } on PostgrestException catch (e) {
      _showError('friends.error_update_request'.tr(args: [e.message]));
    } catch (_) {
      _showError('friends.error_update_request_generic'.tr());
    } finally {
      if (mounted) {
        setState(() => _actionLoadingIds.remove(requestId));
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    if (_myUserId == null) return;

    setState(() => _actionLoadingIds.add(friendId));
    try {
      final removed = await _profileService.removeFriend(friendId);
      if (!removed) {
        _showError(
          'friends.error_remove_not_found'.tr(),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _friends.removeWhere((f) => f['id'].toString() == friendId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('friends.success_removed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      _showError('friends.error_remove'.tr(args: [e.message]));
    } catch (e) {
      _showError('friends.error_remove_generic'.tr());
    } finally {
      if (mounted) setState(() => _actionLoadingIds.remove(friendId));
    }
  }

  void _setupRealtime() {
    final myId = _myUserId;
    if (myId == null) return;
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
    }

    // Türkçe yorum: Yeni friend request geldiğinde badge ve listeleri anlık güncelliyoruz.
    _realtimeChannel = _client
        .channel('friends-realtime-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) async {
            final row = (payload.newRecord.isNotEmpty
                ? payload.newRecord
                : payload.oldRecord);
            final addresseeId = (row['addressee_id'] ?? '').toString();
            final requesterId = (row['requester_id'] ?? '').toString();
            final type = (row['request_type'] ?? '').toString();
            if (type != 'friend') return;

            if (addresseeId == myId || requesterId == myId) {
              await _loadIncomingRequests();
              await _loadFriends();
            }
          },
        )
        .subscribe();
  }

  void _setupUnreadMessagesStream() {
    final myId = _myUserId;
    if (myId == null) return;

    _unreadMessagesSub?.cancel();

    // Türkçe yorum: Bana gelen ve okunmamış mesajları anlık dinleyip sender_id bazında gruplayarak sayaç üretiyoruz.
    _unreadMessagesSub = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          final toDeliveredIds = <dynamic>[];
          final grouped = <String, int>{};
          final lastMessageMap = <String, DateTime>{};
          for (final row in rows) {
            final senderId = (row['sender_id'] ?? '').toString();
            final receiverId = (row['receiver_id'] ?? '').toString();
            if (senderId.isEmpty || receiverId.isEmpty) continue;

            final otherId = senderId == myId ? receiverId : senderId;
            final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
            if (createdAt != null) {
              final existing = lastMessageMap[otherId];
              if (existing == null || createdAt.isAfter(existing)) {
                lastMessageMap[otherId] = createdAt;
              }
            }

            final status = (row['status'] ?? 'sent').toString();
            final isUnreadForMe =
                receiverId == myId && status != 'read';
            if (isUnreadForMe) {
              grouped[senderId] = (grouped[senderId] ?? 0) + 1;
            }

            // Türkçe yorum: Uygulama açıkken bana gelen "sent" mesajları "delivered" yapıyoruz.
            if (receiverId == myId && status == 'sent') {
              toDeliveredIds.add(row['id']);
            }
          }
          if (!mounted) return;
          setState(() {
            _unreadCountByFriendId = grouped;
            _lastMessageAtByFriendId = lastMessageMap;
            _sortFriendsByPriority();
          });

          if (toDeliveredIds.isNotEmpty && !_isUpdatingDelivered) {
            _markMessagesDelivered(toDeliveredIds);
          }
        });
  }

  Future<void> _markMessagesDelivered(List<dynamic> messageIds) async {
    if (_isUpdatingDelivered || messageIds.isEmpty) return;
    _isUpdatingDelivered = true;
    try {
      await _client
          .from('messages')
          .update({'status': 'delivered'})
          .inFilter('id', messageIds)
          .eq('status', 'sent');
    } catch (_) {
      // Sessiz geçiyoruz.
    } finally {
      _isUpdatingDelivered = false;
    }
  }

  void _sortFriendsByPriority() {
    _friends.sort((a, b) {
      final aId = (a['id'] ?? '').toString();
      final bId = (b['id'] ?? '').toString();
      final aUnread = _unreadCountByFriendId[aId] ?? 0;
      final bUnread = _unreadCountByFriendId[bId] ?? 0;

      // Önce okunmamış mesajı olanlar üste.
      if ((aUnread > 0) != (bUnread > 0)) {
        return aUnread > 0 ? -1 : 1;
      }

      // Son mesaj zamanı daha yeni olan üste.
      final aLast = _lastMessageAtByFriendId[aId];
      final bLast = _lastMessageAtByFriendId[bId];
      if (aLast != null && bLast != null) {
        final cmp = bLast.compareTo(aLast);
        if (cmp != 0) return cmp;
      } else if (aLast != null) {
        return -1;
      } else if (bLast != null) {
        return 1;
      }

      // Son fallback: username alfabetik.
      final aName = (a['username'] ?? '').toString().toLowerCase();
      final bName = (b['username'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _buildIncomingHeader(),
          const SizedBox(height: 10),
          _buildIncomingSection(),
          const SizedBox(height: 20),
          Text(
            'friends.my_friends'.tr(),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          _buildFriendsSection(),
        ],
      ),
    );
  }

  Widget _buildIncomingHeader() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'friends.incoming_requests'.tr(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none,
              color: AppColors.primaryAccent,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        IconButton(
          tooltip: 'friends.messages'.tr(),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InboxScreen()),
            );
          },
          icon: const Icon(Icons.chat_bubble_outline,
              color: AppColors.primaryAccent),
        ),
      ],
    );
  }

  Widget _buildIncomingSection() {
    final theme = Theme.of(context);
    if (_isIncomingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incomingRequests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            'friends.no_incoming'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: theme.textTheme.bodySmall?.color),
          ),
        ),
      );
    }

    // Türkçe yorum: Column içinde güvenli kullanım için shrinkWrap + NeverScrollableScrollPhysics.
    return ListView.builder(
      itemCount: _incomingRequests.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final request = _incomingRequests[index];
        final id = request['id'].toString();
        final p =
            (request['requester_profile'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
        final username = (p['username'] ?? '').toString();
        final fullName = (p['full_name'] ?? '').toString();
        final isBusy = _actionLoadingIds.contains(id);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceVariant,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      fullName.isEmpty ? 'friends.no_name_info'.tr() : fullName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TextButton(
                      onPressed: () => _setRequestStatus(
                        requestId: id,
                        newStatus: 'rejected',
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text('friends.reject'.tr()),
                    ),
                    ElevatedButton(
                      onPressed: () => _setRequestStatus(
                        requestId: id,
                        newStatus: 'accepted',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text('friends.accept'.tr()),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendsSection() {
    final theme = Theme.of(context);
    if (_isFriendsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return _buildEmptyCard('friends.no_friends'.tr());
    }

    return Column(
      children: _friends.map((friend) {
        final friendId = (friend['id'] ?? '').toString();
        final username = (friend['username'] ?? '').toString();
        final fullName = (friend['full_name'] ?? '').toString();
        final id = (friend['id'] ?? '').toString();
        final displayName = fullName.isNotEmpty ? fullName : '@$username';
        final unreadCount = _unreadCountByFriendId[friendId] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceVariant,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      fullName.isEmpty ? 'friends.no_name_info'.tr() : fullName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: friendId.isEmpty
                    ? null
                    : () async {
                        final myId = _myUserId;
                        // Türkçe yorum: Kullanıcı sohbeti açtığında badge anında kaybolsun (optimistic).
                        // DB update gecikse bile UX düzgün olur; stream kısa süre içinde doğru state'i getirir.
                        if (mounted) {
                          setState(() {
                            _unreadCountByFriendId.remove(friendId);
                            _sortFriendsByPriority();
                          });
                        }
                        if (myId != null) {
                          // Türkçe yorum: Sohbete girerken bu arkadaştan gelen read olmayan mesajları read yap.
                          await _client
                              .from('messages')
                              .update({'status': 'read'})
                              .eq('sender_id', friendId)
                              .eq('receiver_id', myId)
                              .neq('status', 'read');
                        }
                        if (!mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: friendId,
                              receiverName: displayName,
                            ),
                          ),
                        );
                      },
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text('friends.send_message'.tr()),
              ),
              if (_actionLoadingIds.contains(friendId))
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.textTheme.bodySmall?.color),
                  onSelected: (value) async {
                    if (value == 'profile') {
                      if (id.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: id),
                          ),
                        );
                      }
                    } else if (value == 'remove') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('friends.remove_confirm_title'.tr()),
                          content: Text('friends.remove_confirm_desc'.tr(args: [username])),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('friends.cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text('friends.yes_remove'.tr()),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _removeFriend(friendId);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Text('friends.view_profile'.tr()),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('friends.remove_friend'.tr(), style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyCard(String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, color: theme.textTheme.bodySmall?.color),
      ),
    );
  }
}
