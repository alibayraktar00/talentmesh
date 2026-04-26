import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import 'profile_screen.dart';
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _client = Supabase.instance.client;

  bool _isIncomingLoading = true;
  bool _isFriendsLoading = true;
  bool _isMarkingRead = false;
  int _unreadCount = 0;

  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _actionLoadingIds = {};

  RealtimeChannel? _realtimeChannel;

  String? get _myUserId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadIncomingRequests(),
      _loadFriends(),
    ]);
    _setupRealtime();
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
            'requester_profile': profilesById[requesterId] ?? <String, dynamic>{},
          };
        }).toList();
        _unreadCount = unread;
      });

      // Türkçe yorum: Kullanıcı listeyi gördüğünde okunmamış istekleri okundu yapıyoruz.
      await _markIncomingAsRead();
    } on PostgrestException catch (e) {
      _showError('Gelen istekler alınamadı: ${e.message}');
    } catch (_) {
      _showError('Gelen istekler alınamadı.');
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
      setState(() => _friends = friends);
    } on PostgrestException catch (e) {
      _showError('Arkadaş listesi alınamadı: ${e.message}');
    } catch (_) {
      _showError('Arkadaş listesi alınamadı.');
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

    try {
      await _client
          .from('friend_requests')
          .update({'status': newStatus, 'is_read': true}).eq('id', requestId);

      if (!mounted) return;
      setState(() {
        _incomingRequests.removeWhere((r) => r['id'].toString() == requestId);
      });
      await _loadFriends();
    } on PostgrestException catch (e) {
      _showError('İstek güncellenemedi: ${e.message}');
    } catch (_) {
      _showError('İstek güncellenemedi.');
    } finally {
      if (mounted) {
        setState(() => _actionLoadingIds.remove(requestId));
      }
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
            final row =
                (payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord);
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

  @override
  Widget build(BuildContext context) {
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
            'Arkadaşlarım',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.headingText,
            ),
          ),
          const SizedBox(height: 10),
          _buildFriendsSection(),
        ],
      ),
    );
  }

  Widget _buildIncomingHeader() {
    return Row(
      children: [
        Text(
          'Gelen İstekler',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none, color: AppColors.primaryAccent),
            if (_unreadCount > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
      ],
    );
  }

  Widget _buildIncomingSection() {
    if (_isIncomingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incomingRequests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            'Henüz gelen bir istek yok.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.mutedText,
            ),
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
            (request['requester_profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final username = (p['username'] ?? '').toString();
        final fullName = (p['full_name'] ?? '').toString();
        final isBusy = _actionLoadingIds.contains(id);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
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
                backgroundColor: AppColors.chipBg,
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
                        color: AppColors.headingText,
                      ),
                    ),
                    Text(
                      fullName.isEmpty ? 'İsim bilgisi yok' : fullName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText,
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
                      onPressed: () =>
                          _setRequestStatus(requestId: id, newStatus: 'rejected'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Reddet'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _setRequestStatus(requestId: id, newStatus: 'accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Kabul Et'),
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
    if (_isFriendsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return _buildEmptyCard('Henüz arkadaşın yok.');
    }

    return Column(
      children: _friends.map((friend) {
        final username = (friend['username'] ?? '').toString();
        final fullName = (friend['full_name'] ?? '').toString();
        final id = (friend['id'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
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
                backgroundColor: AppColors.chipBg,
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
                        color: AppColors.headingText,
                      ),
                    ),
                    Text(
                      fullName.isEmpty ? 'İsim bilgisi yok' : fullName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Mesaj Gönder'),
              ),
              OutlinedButton(
                onPressed: () {
                  if (id.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: id),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Profil'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.mutedText,
        ),
      ),
    );
  }
}
