import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';

enum _RelationType { none, accepted, pendingOutgoing, pendingIncoming }

class _RelationState {
  final _RelationType type;
  final String? requestId;

  const _RelationState(this.type, {this.requestId});
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _results = [];
  final Set<String> _sendingRequestIds = {};
  final Map<String, _RelationState> _relationsByUserId = {};
  String? _activeUserId;

  String? get _myUserId => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchUsers(_searchController.text);
    });
  }

  void _resetStateForUserChange() {
    _results = [];
    _relationsByUserId.clear();
    _sendingRequestIds.clear();
    _hasSearched = false;
    _isLoading = false;
    _searchController.clear();
  }

  int _relationPriority(_RelationType type) {
    switch (type) {
      case _RelationType.accepted:
        return 3;
      case _RelationType.pendingIncoming:
        return 2;
      case _RelationType.pendingOutgoing:
        return 1;
      case _RelationType.none:
        return 0;
    }
  }

  Future<Map<String, _RelationState>> _loadRelationsForListedUsers({
    required String myId,
    required List<String> listedUserIds,
  }) async {
    if (listedUserIds.isEmpty) return {};

    // Türkçe yorum: Çift yönlü kontrol için hem giden hem gelen request kayıtlarını çekiyoruz.
    final outgoingRows = await _client
        .from('friend_requests')
        .select('id, requester_id, addressee_id, status')
        .eq('requester_id', myId)
        .eq('request_type', 'friend')
        .inFilter('addressee_id', listedUserIds)
        .inFilter('status', ['pending', 'accepted']);

    final incomingRows = await _client
        .from('friend_requests')
        .select('id, requester_id, addressee_id, status')
        .eq('addressee_id', myId)
        .eq('request_type', 'friend')
        .inFilter('requester_id', listedUserIds)
        .inFilter('status', ['pending', 'accepted']);

    final allRows = [
      ...List<Map<String, dynamic>>.from(outgoingRows),
      ...List<Map<String, dynamic>>.from(incomingRows),
    ];

    final Map<String, _RelationState> map = {};
    for (final row in allRows) {
      final requesterId = (row['requester_id'] ?? '').toString();
      final addresseeId = (row['addressee_id'] ?? '').toString();
      final status = (row['status'] ?? '').toString();
      final requestId = (row['id'] ?? '').toString();
      final otherId = requesterId == myId ? addresseeId : requesterId;
      if (otherId.isEmpty) continue;

      _RelationState next;
      if (status == 'accepted') {
        next = const _RelationState(_RelationType.accepted);
      } else if (status == 'pending' && requesterId == myId) {
        next = _RelationState(_RelationType.pendingOutgoing, requestId: requestId);
      } else if (status == 'pending' && addresseeId == myId) {
        next = _RelationState(_RelationType.pendingIncoming, requestId: requestId);
      } else {
        next = const _RelationState(_RelationType.none);
      }

      final current = map[otherId];
      if (current == null ||
          _relationPriority(next.type) > _relationPriority(current.type)) {
        map[otherId] = next;
      }
    }
    return map;
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

  Future<void> _searchUsers(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasSearched = false;
        _isLoading = false;
        _results = [];
        _relationsByUserId.clear();
      });
      return;
    }

    final myId = _myUserId;
    if (myId == null) {
      _showError('Oturum bulunamadı. Lütfen tekrar giriş yapın.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Türkçe yorum: username alanında ilike ile arama yapıyoruz.
      final response = await _client
          .from('profiles')
          .select('id, username, full_name')
          .ilike('username', '%$query%')
          .order('username', ascending: true)
          .limit(30);

      final data = List<Map<String, dynamic>>.from(response);
      final filtered = data.where((item) => item['id'] != myId).toList();

      final listedUserIds =
          filtered.map((item) => item['id'].toString()).toList();
      final relations = await _loadRelationsForListedUsers(
        myId: myId,
        listedUserIds: listedUserIds,
      );

      if (!mounted) return;
      setState(() {
        // Türkçe yorum: mevcut kullanıcıyı listede göstermiyoruz.
        _results = filtered;
        _relationsByUserId
          ..clear()
          ..addAll(relations);
      });
    } on PostgrestException catch (e) {
      _showError('Arama sırasında hata oluştu: ${e.message}');
    } catch (_) {
      _showError('Arama yapılamadı. İnternet bağlantınızı kontrol edin.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> profile) async {
    final myId = _myUserId;
    final addresseeId = profile['id']?.toString();

    if (myId == null || addresseeId == null || addresseeId.isEmpty) {
      _showError('İstek gönderilemedi.');
      return;
    }

    if (_sendingRequestIds.contains(addresseeId)) {
      return;
    }

    final relation = _relationsByUserId[addresseeId] ??
        const _RelationState(_RelationType.none);
    if (relation.type == _RelationType.accepted ||
        relation.type == _RelationType.pendingOutgoing) {
      return;
    }

    setState(() => _sendingRequestIds.add(addresseeId));

    try {
      await _client.from('friend_requests').insert({
        'requester_id': myId,
        'addressee_id': addresseeId,
        'status': 'pending',
        // Türkçe yorum: Arkadaşlık akışı için tipi ve okunma durumunu açık yazıyoruz.
        'request_type': 'friend',
        'is_read': false,
      });

      if (!mounted) return;
      setState(() {
        _relationsByUserId[addresseeId] =
            const _RelationState(_RelationType.pendingOutgoing);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arkadaşlık isteği gönderildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      _showError('İstek gönderilemedi: ${e.message}');
    } catch (_) {
      _showError('İstek gönderilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _sendingRequestIds.remove(addresseeId));
      }
    }
  }

  Future<void> _acceptIncomingRequest({
    required String otherUserId,
    required String requestId,
  }) async {
    if (_sendingRequestIds.contains(otherUserId)) return;
    setState(() => _sendingRequestIds.add(otherUserId));

    try {
      await _client
          .from('friend_requests')
          .update({'status': 'accepted'}).eq('id', requestId);

      if (!mounted) return;
      setState(() {
        _relationsByUserId[otherUserId] =
            const _RelationState(_RelationType.accepted);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arkadaşlık isteği kabul edildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      _showError('İstek kabul edilemedi: ${e.message}');
    } catch (_) {
      _showError('İstek kabul edilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _sendingRequestIds.remove(otherUserId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _myUserId;
    if (currentUserId != _activeUserId) {
      _activeUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_resetStateForUserChange);
      });
    }

    return Column(
      children: [
        // Arama Çubuğu (TextField)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'İsim veya yetenek ara...',
                hintStyle: GoogleFonts.inter(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryAccent,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.mutedText),
                        onPressed: () {
                          _searchController.clear();
                          // Çıkış yaparken klavyeyi de kapatalım
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: GoogleFonts.inter(
                color: AppColors.headingText,
                fontSize: 15,
              ),
            ),
          ),
        ),
        
        // İçerik: İlk durum / Yükleniyor / Sonuçlar
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return _buildEmptyState();
    }
    return _buildSearchResults();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.mutedText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Kullanıcı adı ile arama yap',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Sonuç bulunamadı.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.mutedText,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        final userId = item['id']?.toString() ?? '';
        final username = (item['username'] ?? '').toString();
        final fullName = (item['full_name'] ?? '').toString();
        final isSending = _sendingRequestIds.contains(userId);
        final relation = _relationsByUserId[userId] ??
            const _RelationState(_RelationType.none);

        String buttonText;
        bool buttonEnabled;
        Color buttonColor;

        switch (relation.type) {
          case _RelationType.accepted:
            buttonText = 'Takımda/Arkadaş';
            buttonEnabled = false;
            buttonColor = Colors.green;
            break;
          case _RelationType.pendingOutgoing:
            buttonText = 'İstek Gönderildi';
            buttonEnabled = false;
            buttonColor = Colors.orange;
            break;
          case _RelationType.pendingIncoming:
            buttonText = 'Kabul Et';
            buttonEnabled = true;
            buttonColor = AppColors.primaryAccent;
            break;
          case _RelationType.none:
            buttonText = 'İstek At';
            buttonEnabled = true;
            buttonColor = AppColors.primaryAccent;
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Sol Avatar (username ilk harfi)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.chipBg,
                  child: Text(
                    username.isNotEmpty
                        ? username.substring(0, 1).toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Orta kısım (username + full_name)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullName.isEmpty ? 'İsim bilgisi yok' : fullName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Sağ kısım (istek butonu / gönderildi durumu)
                ElevatedButton(
                  onPressed: (!buttonEnabled || isSending)
                      ? null
                      : () {
                          if (relation.type == _RelationType.pendingIncoming &&
                              relation.requestId != null &&
                              relation.requestId!.isNotEmpty) {
                            _acceptIncomingRequest(
                              otherUserId: userId,
                              requestId: relation.requestId!,
                            );
                          } else {
                            _sendFriendRequest(item);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          buttonText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
