import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TutorCreateLessonPage extends StatefulWidget {
  const TutorCreateLessonPage({super.key, this.docId, this.existingData});

  final String? docId;
  final Map<String, dynamic>? existingData;

  @override
  State<TutorCreateLessonPage> createState() => _TutorCreateLessonPageState();
}

class _TutorCreateLessonPageState extends State<TutorCreateLessonPage> {
  static const Color _green = Color(0xFF0F6E56);

  final _formKey = GlobalKey<FormState>();
  final _unitNumberController = TextEditingController();
  final _orderController = TextEditingController();
  final _titleController = TextEditingController();
  final _titleChineseController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalLessonsController = TextEditingController();
  final _xpRewardController = TextEditingController();

  bool _isLoading = false;

  bool get _isEditMode => widget.docId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    if (data != null) {
      _unitNumberController.text = (data['unitNumber'] ?? '').toString();
      _orderController.text = (data['order'] ?? '').toString();
      _titleController.text = (data['title'] ?? '').toString();
      _titleChineseController.text = (data['titleChinese'] ?? '').toString();
      _descriptionController.text = (data['description'] ?? '').toString();
      _totalLessonsController.text = (data['totalLessons'] ?? '').toString();
      _xpRewardController.text = (data['xpReward'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _unitNumberController.dispose();
    _orderController.dispose();
    _titleController.dispose();
    _titleChineseController.dispose();
    _descriptionController.dispose();
    _totalLessonsController.dispose();
    _xpRewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text(_isEditMode ? 'Edit Lesson' : 'Cipta Lesson'),
      ),
      body: user == null
          ? const Center(child: Text('Sila log masuk semula untuk meneruskan.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildNumberField(
                    controller: _unitNumberController,
                    label: 'Unit Number',
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    controller: _orderController,
                    label: 'Order',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(controller: _titleController, label: 'Title'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _titleChineseController,
                    label: 'Title Chinese',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    controller: _totalLessonsController,
                    label: 'Total Lessons',
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    controller: _xpRewardController,
                    label: 'XP Reward',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveLesson,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditMode
                                  ? 'Kemaskini Lesson'
                                  : 'Simpan Lesson',
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return '$label wajib diisi';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) {
          return '$label wajib diisi';
        }
        if (int.tryParse(text) == null) {
          return '$label mesti nombor';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _saveLesson() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final payload = <String, dynamic>{
      'unitNumber': int.parse(_unitNumberController.text.trim()),
      'order': int.parse(_orderController.text.trim()),
      'title': _titleController.text.trim(),
      'titleChinese': _titleChineseController.text.trim(),
      'description': _descriptionController.text.trim(),
      'totalLessons': int.parse(_totalLessonsController.text.trim()),
      'xpReward': int.parse(_xpRewardController.text.trim()),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    };

    try {
      if (_isEditMode) {
        await FirebaseFirestore.instance
            .collection('lessons')
            .doc(widget.docId)
            .update(payload);
      } else {
        await FirebaseFirestore.instance.collection('lessons').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Lesson berjaya dikemaskini.'
                : 'Lesson berjaya disimpan.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan lesson.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
