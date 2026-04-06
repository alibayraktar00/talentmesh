import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  final Set<String> _actionLoadingIds = {};
  List<Map<String, dynamic>> _requests = [];
  String? _lastLoadedUserId;

  String? get _myUserId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
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

  Future<void> _loadPendingRequests() async {
    final myId = _myUserId;
    if (myId == null) {
      _showError('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Türkçe yorum: Önce pending istekleri çekiyoruz.
      final response = await _client
          .from('friend_requests')
          .select('*')
          .eq('addressee_id', myId)
          .eq('status', 'pending')
          .order('id', ascending: false);

      final requestRows = List<Map<String, dynamic>>.from(response);
      final requesterIds = requestRows
          .map((row) => (row['requester_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesById = {};
      if (requesterIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select('id, username, full_name')
            .inFilter('id', requesterIds);
        for (final p in List<Map<String, dynamic>>.from(profiles)) {
          final id = (p['id'] ?? '').toString();
          if (id.isNotEmpty) {
            profilesById[id] = p;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _lastLoadedUserId = myId;
        _requests = requestRows.map((row) {
          final requesterId = (row['requester_id'] ?? '').toString();
          return {
            ...row,
            'requester': profilesById[requesterId] ?? <String, dynamic>{},
          };
        }).toList();
      });
    } on PostgrestException catch (e) {
      print('Friend requests read error: ${e.message}');
      _showError('İstekler alınamadı: ${e.message}');
    } catch (e) {
      print('Friend requests read unexpected error: $e');
      _showError('İstekler yüklenemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateRequestStatus({
    required String requestId,
    required String newStatus,
  }) async {
    if (_actionLoadingIds.contains(requestId)) return;

    setState(() => _actionLoadingIds.add(requestId));
    try {
      await _client
          .from('friend_requests')
          .update({'status': newStatus}).eq('id', requestId);

      if (!mounted) return;
      setState(() {
        // Türkçe yorum: İşlem yapılan isteği listeden kaldırıyoruz.
        _requests.removeWhere((r) => r['id'].toString() == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'accepted'
              ? 'Arkadaşlık isteği kabul edildi.'
              : 'Arkadaşlık isteği reddedildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      _showError('İşlem başarısız: ${e.message}');
    } catch (_) {
      _showError('İşlem başarısız. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _actionLoadingIds.remove(requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _myUserId;
    if (currentUserId != null && currentUserId != _lastLoadedUserId && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadPendingRequests();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Gelen İstekler',
          style: GoogleFonts.inter(
            color: AppColors.headingText,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.headingText,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return Center(
        child: Text(
          'Henüz bir arkadaşlık isteğiniz yok',
          style: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingRequests,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          final reqId = req['id'].toString();
          final profile = (req['requester'] as Map<String, dynamic>?) ?? {};
          final username = (profile['username'] ?? '').toString();
          final fullName = (profile['full_name'] ?? '').toString();
          final isActionLoading = _actionLoadingIds.contains(reqId);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: AppColors.chipBg,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(
                '@$username',
                style: GoogleFonts.inter(
                  color: AppColors.headingText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                fullName.isEmpty ? 'İsim bilgisi yok' : fullName,
                style: GoogleFonts.inter(color: AppColors.mutedText),
              ),
              trailing: isActionLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _updateRequestStatus(
                            requestId: reqId,
                            newStatus: 'rejected',
                          ),
                          child: const Text('Reddet'),
                        ),
                        ElevatedButton(
                          onPressed: () => _updateRequestStatus(
                            requestId: reqId,
                            newStatus: 'accepted',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Kabul Et'),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
