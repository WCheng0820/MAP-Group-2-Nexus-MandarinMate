import 'package:flutter/material.dart';
import 'tutor_manage_units_page.dart';
import 'tutor_lessons_page.dart';
import 'tutor_manage_flashcards_page.dart';
import 'tutor_generate_unit_page.dart';
import 'tutor_create_lesson_page.dart';
import 'tutor_create_flashcards_page.dart';

class TutorManageLessonsHubPage extends StatelessWidget {
  const TutorManageLessonsHubPage({super.key});

  static const Color _green = Color(0xFF0F6E56);
  static const Color _purple = Color(0xFF6C3BFF);
  static const Color _orange = Color(0xFFFF8A21);

  void _openCreateMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.book_rounded, color: _green),
                  title: const Text('Add Vocab Unit (AI Generate)'),
                  subtitle: const Text('Let AI create vocabulary from a title'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorGenerateUnitPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded, color: _purple),
                  title: const Text('Create Learning Materials'),
                  subtitle: const Text('Create a new material set (PDFs, videos, links)'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorCreateLearningMaterialsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.style_rounded, color: _orange),
                  title: const Text('Add New Flashcard Set'),
                  subtitle: const Text('Create a new flashcard level and add cards'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TutorCreateFlashcardsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Manage Lessons'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openCreateMenu(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose what to manage:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _ManageCard(
                    icon: Icons.book_rounded,
                    title: 'Manage Vocabulary Units',
                    subtitle: 'Create, edit, or delete vocabulary lessons',
                    color: _green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorManageUnitsPage(),
                        ),
                      );
                    },
                  ),
                  _ManageCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Manage Learning Materials',
                    subtitle: 'Add, edit, or delete material sets (PDFs, links, videos)',
                    color: _purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorLessonsPage(),
                        ),
                      );
                    },
                  ),
                  _ManageCard(
                    icon: Icons.style_rounded,
                    title: 'Manage Flashcards',
                    subtitle: 'Create, edit, or delete flashcard sets for vocabulary practice',
                    color: _orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorManageFlashcardsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ManageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
