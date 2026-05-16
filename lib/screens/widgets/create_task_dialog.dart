import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/task_provider.dart';

/// Görev oluşturma dialog'unu gösterir.
Future<void> showCreateTaskDialog(
  BuildContext context, {
  required String teamId,
  required TaskProvider taskProvider,
  required Color teamColor,
  required List<Map<String, dynamic>> members,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateTaskSheet(
      teamId: teamId,
      taskProvider: taskProvider,
      teamColor: teamColor,
      members: members,
    ),
  );
}

class _CreateTaskSheet extends StatefulWidget {
  final String teamId;
  final TaskProvider taskProvider;
  final Color teamColor;
  final List<Map<String, dynamic>> members;

  const _CreateTaskSheet({
    required this.teamId,
    required this.taskProvider,
    required this.teamColor,
    required this.members,
  });

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedAssignees = {};
  DateTime? _dueDate;
  final List<TextEditingController> _subtaskControllers = [TextEditingController()];
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev başlığı boş olamaz.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final subtasks = _subtaskControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .map((text) => {'title': text, 'is_completed': false})
          .toList();

      await widget.taskProvider.createTask(
        teamId: widget.teamId,
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _dueDate,
        subtasks: subtasks,
        assignedTo: _selectedAssignees.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Görev oluşturuldu!'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: const Color(0xFFE53E3E),
          ),
        );
      }
    }
  }

  void _toggleAssignee(String userId) {
    setState(() {
      if (_selectedAssignees.contains(userId)) {
        _selectedAssignees.remove(userId);
      } else {
        _selectedAssignees.add(userId);
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.teamColor,
              onPrimary: Colors.white,
              onSurface: AppColors.headingText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _addSubtaskField() {
    setState(() {
      _subtaskControllers.add(TextEditingController());
    });
  }

  void _removeSubtaskField(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.teamColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_task_rounded,
                      color: widget.teamColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yeni Görev',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Takım görev panosuna yeni bir görev ekle',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Title field
              Text(
                'Görev Başlığı *',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Örn: Tasarım dosyasını güncelle',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.mutedText.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.teamColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description field
              Text(
                'Açıklama (Opsiyonel)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Görev detaylarını yazın...',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.mutedText.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.teamColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Due Date field
              Text(
                'Bitiş Tarihi (Opsiyonel)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: widget.teamColor),
                      const SizedBox(width: 10),
                      Text(
                        _dueDate == null
                            ? 'Tarih seçin'
                            : '${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _dueDate == null ? AppColors.mutedText.withValues(alpha: 0.5) : AppColors.headingText,
                        ),
                      ),
                      if (_dueDate != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Subtasks field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Alt Görevler / Maddeler (Opsiyonel)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingText,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSubtaskField,
                    icon: Icon(Icons.add_rounded, size: 16, color: widget.teamColor),
                    label: Text('Madde Ekle', style: TextStyle(color: widget.teamColor, fontSize: 12)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_subtaskControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.radio_button_unchecked_rounded, size: 16, color: AppColors.mutedText.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _subtaskControllers[index],
                          decoration: InputDecoration(
                            hintText: '${index + 1}. madde',
                            hintStyle: GoogleFonts.inter(color: AppColors.mutedText.withValues(alpha: 0.5), fontSize: 13),
                            filled: true,
                            fillColor: AppColors.chipBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      if (_subtaskControllers.length > 1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFE53E3E), size: 20),
                          onPressed: () => _removeSubtaskField(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Multi-select assignees
              Row(
                children: [
                  Text(
                    'Görevliler (Opsiyonel)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingText,
                    ),
                  ),
                  if (_selectedAssignees.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.teamColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_selectedAssignees.length} kişi',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.teamColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Member chips
              if (widget.members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Takımda henüz üye yok.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedText,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.members.map((member) {
                    final profiles =
                        member['profiles'] as Map<String, dynamic>? ?? {};
                    final userId = member['user_id']?.toString() ?? '';
                    final username =
                        profiles['username']?.toString() ?? 'Bilinmeyen';
                    final fullName =
                        profiles['full_name']?.toString() ?? '';
                    final isSelected = _selectedAssignees.contains(userId);
                    final displayName = fullName.isNotEmpty
                        ? fullName
                        : '@$username';

                    return GestureDetector(
                      onTap: () => _toggleAssignee(userId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.teamColor.withValues(alpha: 0.12)
                              : AppColors.chipBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? widget.teamColor
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: isSelected
                                  ? widget.teamColor
                                  : widget.teamColor.withValues(alpha: 0.15),
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : widget.teamColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? widget.teamColor
                                    : AppColors.bodyText,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: widget.teamColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.teamColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Görev Oluştur',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
