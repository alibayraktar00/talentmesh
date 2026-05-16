import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';

Future<void> showTaskDetailDialog(
  BuildContext context, {
  required TeamTask task,
  required TaskProvider taskProvider,
  required Color teamColor,
  required bool isMember,
  required bool isAdmin,
  required String currentUserId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskDetailSheet(
      task: task,
      taskProvider: taskProvider,
      teamColor: teamColor,
      isMember: isMember,
      isAdmin: isAdmin,
      currentUserId: currentUserId,
    ),
  );
}

class _TaskDetailSheet extends StatefulWidget {
  final TeamTask task;
  final TaskProvider taskProvider;
  final Color teamColor;
  final bool isMember;
  final bool isAdmin;
  final String currentUserId;

  const _TaskDetailSheet({
    required this.task,
    required this.taskProvider,
    required this.teamColor,
    required this.isMember,
    required this.isAdmin,
    required this.currentUserId,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late TeamTask _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  void _updateTask() {
    // Bulunan görevi güncel listeden tekrar al
    final updated = widget.taskProvider.tasks.firstWhere(
      (t) => t.id == _currentTask.id,
      orElse: () => _currentTask,
    );
    if (mounted) {
      setState(() {
        _currentTask = updated;
      });
    }
  }

  Future<void> _changeStatus(TaskStatus newStatus) async {
    try {
      await widget.taskProvider.updateTaskStatus(
        taskId: _currentTask.id,
        teamId: _currentTask.teamId,
        newStatus: newStatus,
      );
      _updateTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görev durumu güncellendi: ${newStatus.label}'),
            backgroundColor: AppColors.onlineGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: const Color(0xFFE53E3E)),
        );
      }
    }
  }

  Future<void> _toggleSubtask(int index, bool newValue) async {
    try {
      await widget.taskProvider.toggleSubtask(
        task: _currentTask,
        subtaskIndex: index,
        isCompleted: newValue,
      );
      _updateTask();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: const Color(0xFFE53E3E)),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Görevi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('"${_currentTask.title}" görevini silmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53E3E)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.taskProvider.deleteTask(taskId: _currentTask.id, teamId: _currentTask.teamId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev silindi.'), backgroundColor: AppColors.onlineGreen));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.isMember;
    final canDelete = widget.isAdmin || _currentTask.createdBy == widget.currentUserId;

    int completedSubtasks = _currentTask.subtasks.where((s) => s['is_completed'] == true).length;
    int totalSubtasks = _currentTask.subtasks.length;
    double progress = totalSubtasks == 0 ? 0.0 : completedSubtasks / totalSubtasks;

    final isOverdue = _currentTask.status != TaskStatus.done &&
        _currentTask.dueDate != null &&
        _currentTask.dueDate!.isBefore(DateTime.now());

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Text(
                        'Görev Detayı',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.headingText),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53E3E)),
                    onPressed: _deleteTask,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _currentTask.title,
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.headingText),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  if (_currentTask.description != null && _currentTask.description!.isNotEmpty)
                    Text(
                      _currentTask.description!,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.bodyText, height: 1.5),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Info Row (Due date & Status)
                  Row(
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentTask.status == TaskStatus.done
                              ? AppColors.onlineGreen.withValues(alpha: 0.1)
                              : _currentTask.status == TaskStatus.inProgress
                                  ? const Color(0xFF4299E1).withValues(alpha: 0.1)
                                  : const Color(0xFFF6AD55).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentTask.status.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _currentTask.status == TaskStatus.done
                                ? AppColors.onlineGreen
                                : _currentTask.status == TaskStatus.inProgress
                                    ? const Color(0xFF4299E1)
                                    : const Color(0xFFF6AD55),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Due Date
                      if (_currentTask.dueDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOverdue ? const Color(0xFFE53E3E).withValues(alpha: 0.1) : AppColors.chipBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: isOverdue ? const Color(0xFFE53E3E) : AppColors.mutedText),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentTask.dueDate!.day}.${_currentTask.dueDate!.month}.${_currentTask.dueDate!.year}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue ? const Color(0xFFE53E3E) : AppColors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),

                  // Durum Değiştirme Menüsü
                  if (canEdit) ...[
                    Text('Durumu Güncelle', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingText)),
                    const SizedBox(height: 12),
                    Row(
                      children: TaskStatus.values.map((status) {
                        final isSelected = _currentTask.status == status;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!isSelected) _changeStatus(status);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? widget.teamColor : AppColors.chipBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? widget.teamColor : Colors.transparent,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                status.label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.bodyText,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Assignees
                  if (_currentTask.assignees.isNotEmpty) ...[
                    Text('Görevliler', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingText)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _currentTask.assignees.map((a) {
                        final username = a.username ?? 'Bilinmeyen';
                        final fullName = a.fullName ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.teamColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: widget.teamColor.withValues(alpha: 0.2),
                                child: Text(username[0].toUpperCase(), style: TextStyle(color: widget.teamColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text(fullName.isNotEmpty ? fullName : '@$username', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: widget.teamColor)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Subtasks (Checklist)
                  if (totalSubtasks > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Maddeler', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingText)),
                        Text('$completedSubtasks / $totalSubtasks', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: widget.teamColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.chipBg,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.teamColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(totalSubtasks, (index) {
                      final subtask = _currentTask.subtasks[index];
                      final isCompleted = subtask['is_completed'] == true;
                      final title = subtask['title'] ?? '';

                      return GestureDetector(
                        onTap: canEdit ? () => _toggleSubtask(index, !isCompleted) : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCompleted ? AppColors.onlineGreen.withValues(alpha: 0.05) : AppColors.chipBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCompleted ? AppColors.onlineGreen.withValues(alpha: 0.3) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isCompleted ? AppColors.onlineGreen : AppColors.mutedText.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isCompleted ? AppColors.mutedText : AppColors.headingText,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
