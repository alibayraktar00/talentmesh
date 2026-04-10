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

  // ── Modüler Filtre Değişkenleri ──
  String _filterSchool = '';
  String _filterDepartment = '';
  String _filterYear = '';
  String _filterDegree = '';
  Set<String> _filterSkills = {};
  Set<String> _filterRoles = {};

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

    final hasActiveFilter = _filterSchool.isNotEmpty ||
        _filterDepartment.isNotEmpty ||
        _filterYear.isNotEmpty ||
        _filterDegree.isNotEmpty ||
        _filterSkills.isNotEmpty ||
        _filterRoles.isNotEmpty;

    if (query.isEmpty && !hasActiveFilter) {
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
      // Dinamik PostgREST Query Builder
      var queryBuilder = _client.from('profiles').select('id, username, full_name, school, department, education_year, degree, skills, looking_for');

      // İsim Filtresi (full_name üzerinden ilike)
      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('full_name', '%$query%');
      }

      // Eğitim Filtreleri
      if (_filterSchool.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('school', '%$_filterSchool%');
      }
      if (_filterDepartment.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('department', '%$_filterDepartment%');
      }
      if (_filterYear.isNotEmpty) {
        // education_year sütunu text olduğu varsayımıyla eq veya ilike kullanılabilir
        queryBuilder = queryBuilder.eq('education_year', _filterYear);
      }
      if (_filterDegree.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('degree', '%$_filterDegree%');
      }

      // Array (Dizi) Filtreleri
      if (_filterSkills.isNotEmpty) {
        queryBuilder = queryBuilder.overlaps('skills', _filterSkills.toList());
      }
      if (_filterRoles.isNotEmpty) {
        queryBuilder = queryBuilder.overlaps('looking_for', _filterRoles.toList());
      }

      // Kendimizi (aktif kullanıcıyı) her zaman dışarıda bırak
      queryBuilder = queryBuilder.neq('id', myId);

      // Çalıştır ve sınırlandır
      final response = await queryBuilder.order('username', ascending: true).limit(30);

      final data = List<Map<String, dynamic>>.from(response);

      final listedUserIds = data.map((item) => item['id'].toString()).toList();
      final relations = await _loadRelationsForListedUsers(
        myId: myId,
        listedUserIds: listedUserIds,
      );

      if (!mounted) return;
      setState(() {
        _results = data;
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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.mutedText),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list, 
                        color: (_filterSchool.isNotEmpty || _filterDepartment.isNotEmpty || _filterYear.isNotEmpty || _filterDegree.isNotEmpty || _filterSkills.isNotEmpty || _filterRoles.isNotEmpty)
                          ? AppColors.primaryAccent 
                          : AppColors.mutedText
                      ),
                      onPressed: _showFilterSheet,
                    ),
                  ],
                ),
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

  void _showFilterSheet() {
    // Geçici state kopyaları
    String tempSchool = _filterSchool;
    String tempDepartment = _filterDepartment;
    String tempYear = _filterYear;
    String tempDegree = _filterDegree;
    Set<String> tempSkills = Set.from(_filterSkills);
    Set<String> tempRoles = Set.from(_filterRoles);

    // Seçilebilir yetenekler (Kendi projendeki sabit listene göre güncelleyebilirsin)
    final availableSkills = [
      'Python', 'Dart', 'Flutter', 'JavaScript', 'TypeScript',
      'React', 'Node.js', 'Figma', 'AWS', 'Docker'
    ];
    // Seçilebilir aranan roller
    final availableRoles = [
      'Flutter Dev', 'Backend Dev', 'Frontend Dev',
      'UI/UX Designer', 'Data Scientist', 'DevOps'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final sC = TextEditingController(text: tempSchool);
          final dC = TextEditingController(text: tempDepartment);
          final yC = TextEditingController(text: tempYear);
          final deC = TextEditingController(text: tempDegree);

          Widget buildSectionTitle(String title) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text(
                title, 
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.headingText)
              ),
            );
          }

          Widget buildTextField(TextEditingController ctrl, String hint) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextField(
                controller: ctrl,
                onChanged: (v) {
                  if (hint == 'Okul') tempSchool = v.trim();
                  if (hint == 'Bölüm') tempDepartment = v.trim();
                  if (hint == 'Yıl (Örn: 2024)') tempYear = v.trim();
                  if (hint == 'Derece (Örn: Lisans)') tempDegree = v.trim();
                },
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                  filled: true,
                  fillColor: AppColors.chipBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            );
          }

          Widget buildChips(List<String> items, Set<String> selected) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final isSelected = selected.contains(item);
                return FilterChip(
                  label: Text(
                    item, 
                    style: GoogleFonts.inter(
                      fontSize: 12, 
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.white : AppColors.bodyText
                    )
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryAccent,
                  backgroundColor: AppColors.chipBg,
                  checkmarkColor: AppColors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : AppColors.inputBorder)),
                  onSelected: (val) {
                    setSheetState(() {
                      if (val) selected.add(item);
                      else selected.remove(item);
                    });
                  },
                );
              }).toList(),
            );
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inputBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gelişmiş Filtreleme', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingText)),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          tempSchool = ''; tempDepartment = ''; tempYear = ''; tempDegree = '';
                          tempSkills.clear(); tempRoles.clear();
                          sC.clear(); dC.clear(); yC.clear(); deC.clear();
                        });
                      },
                      child: Text('Temizle', style: GoogleFonts.inter(color: AppColors.primaryAccent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionTitle('Eğitim Bilgisi'),
                        buildTextField(sC, 'Okul'),
                        buildTextField(dC, 'Bölüm'),
                        Row(
                          children: [
                            Expanded(child: buildTextField(yC, 'Yıl (Örn: 2024)')),
                            const SizedBox(width: 12),
                            Expanded(child: buildTextField(deC, 'Derece (Örn: Lisans)')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        buildSectionTitle('Yetenekler'),
                        buildChips(availableSkills, tempSkills),
                        const SizedBox(height: 16),
                        buildSectionTitle('Aranan Roller'),
                        buildChips(availableRoles, tempRoles),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // State'i güncelle
                    setState(() {
                      _filterSchool = tempSchool;
                      _filterDepartment = tempDepartment;
                      _filterYear = tempYear;
                      _filterDegree = tempDegree;
                      _filterSkills = Set.from(tempSkills);
                      _filterRoles = Set.from(tempRoles);
                    });
                    Navigator.pop(ctx);
                    // Yeni sorguyu başlat
                    _searchUsers(_searchController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Filtreleri Uygula', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white)),
                ),
                SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom),
              ],
            ),
          );
        },
      ),
    );
  }
}
