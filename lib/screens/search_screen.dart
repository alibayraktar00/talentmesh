import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Sahte veri (Mock Data) listesi
  final List<Map<String, dynamic>> _mockData = [
    {
      'name': 'Ali Yılmaz',
      'role': 'Yazılım Geliştirici',
      'skills': ['Flutter', 'Dart', 'Firebase'],
    },
    {
      'name': 'Ayşe Demir',
      'role': 'UI/UX Tasarımcı',
      'skills': ['Figma', 'Adobe XD', 'Prototyping'],
    },
    {
      'name': 'Mehmet Kaya',
      'role': 'Backend Geliştirici',
      'skills': ['Node.js', 'PostgreSQL', 'Docker'],
    },
    {
      'name': 'Zeynep Çelik',
      'role': 'Proje Yöneticisi',
      'skills': ['Agile', 'Scrum', 'Jira'],
    },
    {
      'name': 'Can Gür',
      'role': 'Mobil Geliştirici',
      'skills': ['Swift', 'Kotlin', 'Flutter', 'UI'],
    },
  ];

  List<Map<String, dynamic>> _filteredData = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _filteredData = [];
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _filteredData = _mockData.where((item) {
        final name = (item['name'] as String).toLowerCase();
        final skills = (item['skills'] as List<String>)
            .map((s) => s.toLowerCase())
            .toList();
            
        final matchesName = name.contains(query);
        final matchesSkill = skills.any((skill) => skill.contains(query));
        
        return matchesName || matchesSkill;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        
        // İçerik: Boş Durum veya Arama Sonuçları
        Expanded(
          child: (!_isSearching)
              ? _buildEmptyState()
              : _buildSearchResults(),
        ),
      ],
    );
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
            'Arama içeriği buraya gelecek',
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
    if (_filteredData.isEmpty) {
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
      // Alt kısımda Navigation Bar'ın üstüne binmemesi için padding payı eklendi
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10).copyWith(bottom: 100),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredData.length,
      itemBuilder: (context, index) {
        final item = _filteredData[index];
        final skills = item['skills'] as List<String>;

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
                // Sol Avatar (İsmin ilk harfi ile)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.chipBg,
                  child: Text(
                    item['name'].toString().substring(0, 1),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                
                // Orta Kısım (Bilgiler ve Yetenek Çiplerini İçerir)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['role'],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: skills.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.chipBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              skill,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 10),
                
                // Sağ Kısım ("İncele" Butonu)
                ElevatedButton(
                  onPressed: () {
                    // Şimdilik boş; tıklayınca çalışacak işlem daha sonra eklenebilir.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'İncele',
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
