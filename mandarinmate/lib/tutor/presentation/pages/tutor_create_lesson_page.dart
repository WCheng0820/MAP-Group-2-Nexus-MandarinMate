import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';

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

  final List<_DraftMaterial> _materials = <_DraftMaterial>[];
  final Set<String> _storagePathsMarkedForDeletion = <String>{};

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
      _materials.addAll(_parseStoredMaterials(data['materials']));
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
        title: Text(_isEditMode ? 'Edit Lesson' : 'Create Lesson'),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to continue.'))
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
                  const SizedBox(height: 20),
                  _buildMaterialsSection(),
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
                          : Text(_isEditMode ? 'Update Lesson' : 'Save Lesson'),
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
          return '$label is required';
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
          return '$label is required';
        }
        if (int.tryParse(text) == null) {
          return '$label must be a number';
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

  Widget _buildMaterialsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning Materials',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Add article links or upload PDF and video files to support your Mandarin lessons.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _addArticleMaterial,
                icon: const Icon(Icons.article_outlined),
                label: const Text('Add Article Link'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _pickFileMaterial(LearningMaterialType.pdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Upload PDF'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _pickFileMaterial(LearningMaterialType.video),
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Upload Video'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_materials.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBF9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No learning materials added yet.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            Column(
              children: _materials
                  .map((material) => _buildMaterialTile(material))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialTile(_DraftMaterial material) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForMaterial(material.type), color: _green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelForMaterial(material.type),
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (material.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    material.description,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  material.statusText,
                  style: TextStyle(
                    color: material.requiresUpload
                        ? Colors.orange.shade700
                        : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove material',
            onPressed: _isLoading ? null : () => _removeMaterial(material),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
          ),
        ],
      ),
    );
  }

  Future<void> _addArticleMaterial() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final urlController = TextEditingController();

    final material = await showDialog<_DraftMaterial>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Article Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  textInputAction: TextInputAction.next,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Article URL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final url = urlController.text.trim();

                if (title.isEmpty || url.isEmpty || !_isValidUrl(url)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a title and a valid article link.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _DraftMaterial.article(
                    id: _newMaterialId(),
                    title: title,
                    description: description,
                    url: url,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    urlController.dispose();

    if (material == null || !mounted) {
      return;
    }

    setState(() {
      _materials.add(material);
    });
  }

  Future<void> _pickFileMaterial(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensionsFor(type),
      withData: true,
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final pickedFile = result.files.single;
    final bytes = pickedFile.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The file could not be read. Please try again.'),
        ),
      );
      return;
    }

    final material = await _showFileDetailsDialog(
      type: type,
      fileName: pickedFile.name,
      bytes: bytes,
    );

    if (material == null || !mounted) {
      return;
    }

    setState(() {
      _materials.add(material);
    });
  }

  Future<_DraftMaterial?> _showFileDetailsDialog({
    required String type,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final titleController = TextEditingController(
      text: _stripExtension(fileName),
    );
    final descriptionController = TextEditingController();

    final material = await showDialog<_DraftMaterial>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Add ${_labelForMaterial(type)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Material title is required.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  _DraftMaterial.file(
                    id: _newMaterialId(),
                    type: type,
                    title: title,
                    description: descriptionController.text.trim(),
                    fileName: fileName,
                    bytes: bytes,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    return material;
  }

  void _removeMaterial(_DraftMaterial material) {
    setState(() {
      _materials.removeWhere((item) => item.id == material.id);
      if (material.storagePath.isNotEmpty) {
        _storagePathsMarkedForDeletion.add(material.storagePath);
      }
    });
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

    final lessons = FirebaseFirestore.instance.collection('lessons');
    final lessonRef = widget.docId != null
        ? lessons.doc(widget.docId)
        : lessons.doc();

    try {
      final materials = await _prepareMaterialsForSave(lessonId: lessonRef.id);

      final payload = <String, dynamic>{
        'unitNumber': int.parse(_unitNumberController.text.trim()),
        'order': int.parse(_orderController.text.trim()),
        'title': _titleController.text.trim(),
        'titleChinese': _titleChineseController.text.trim(),
        'description': _descriptionController.text.trim(),
        'totalLessons': int.parse(_totalLessonsController.text.trim()),
        'xpReward': int.parse(_xpRewardController.text.trim()),
        'materials': materials.map((material) => material.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      if (_isEditMode) {
        await lessonRef.update(payload);
      } else {
        await lessonRef.set({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
        });
      }

      await _deleteRemovedStorageObjects();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Lesson updated successfully.'
                : 'Lesson saved successfully.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save lesson: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<LearningMaterial>> _prepareMaterialsForSave({
    required String lessonId,
  }) async {
    final materials = <LearningMaterial>[];

    for (final material in _materials) {
      if (!material.requiresUpload) {
        materials.add(material.toLearningMaterial());
        continue;
      }

      final storagePath = _buildStoragePath(
        lessonId: lessonId,
        materialId: material.id,
        fileName: material.fileName,
      );
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      await ref.putData(
        material.bytes!,
        SettableMetadata(contentType: _contentTypeFor(material)),
      );
      final url = await ref.getDownloadURL();

      materials.add(
        material
            .copyWith(url: url, storagePath: storagePath)
            .toLearningMaterial(),
      );
    }

    return materials;
  }

  Future<void> _deleteRemovedStorageObjects() async {
    for (final storagePath in _storagePathsMarkedForDeletion) {
      if (storagePath.isEmpty) {
        continue;
      }

      try {
        await FirebaseStorage.instance.ref().child(storagePath).delete();
      } catch (_) {
        // Ignore cleanup failures so lesson changes can still be saved.
      }
    }
  }

  List<_DraftMaterial> _parseStoredMaterials(dynamic rawMaterials) {
    if (rawMaterials is! List) {
      return <_DraftMaterial>[];
    }

    return rawMaterials
        .map(
          (item) => item is Map
              ? _DraftMaterial.fromStoredMap(Map<String, dynamic>.from(item))
              : null,
        )
        .whereType<_DraftMaterial>()
        .toList();
  }

  List<String> _allowedExtensionsFor(String type) {
    if (type == LearningMaterialType.pdf) {
      return const <String>['pdf'];
    }

    return const <String>['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];
  }

  IconData _iconForMaterial(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return Icons.picture_as_pdf_outlined;
      case LearningMaterialType.video:
        return Icons.video_library_outlined;
      case LearningMaterialType.article:
      default:
        return Icons.article_outlined;
    }
  }

  String _labelForMaterial(String type) {
    switch (type) {
      case LearningMaterialType.pdf:
        return 'PDF';
      case LearningMaterialType.video:
        return 'Video';
      case LearningMaterialType.article:
      default:
        return 'Article';
    }
  }

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  String _newMaterialId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  String _buildStoragePath({
    required String lessonId,
    required String materialId,
    required String fileName,
  }) {
    final extension = _fileExtension(fileName);
    final safeName = _stripExtension(
      fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_'),
    );
    final baseName = safeName.isEmpty ? 'material' : safeName;

    return 'lesson_materials/$lessonId/${materialId}_$baseName$extension';
  }

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0) {
      return '';
    }
    return fileName.substring(dotIndex);
  }

  String _contentTypeFor(_DraftMaterial material) {
    if (material.type == LearningMaterialType.pdf) {
      return 'application/pdf';
    }
    if (material.type == LearningMaterialType.video) {
      final extension = _fileExtension(material.fileName).toLowerCase();
      switch (extension) {
        case '.mov':
          return 'video/quicktime';
        case '.webm':
          return 'video/webm';
        case '.avi':
          return 'video/x-msvideo';
        case '.mkv':
          return 'video/x-matroska';
        default:
          return 'video/mp4';
      }
    }
    return 'application/octet-stream';
  }
}

class _DraftMaterial {
  const _DraftMaterial({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.url,
    required this.fileName,
    required this.storagePath,
    this.bytes,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String url;
  final String fileName;
  final String storagePath;
  final Uint8List? bytes;

  factory _DraftMaterial.article({
    required String id,
    required String title,
    required String description,
    required String url,
  }) {
    return _DraftMaterial(
      id: id,
      type: LearningMaterialType.article,
      title: title,
      description: description,
      url: url,
      fileName: '',
      storagePath: '',
    );
  }

  factory _DraftMaterial.file({
    required String id,
    required String type,
    required String title,
    required String description,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _DraftMaterial(
      id: id,
      type: type,
      title: title,
      description: description,
      url: '',
      fileName: fileName,
      storagePath: '',
      bytes: bytes,
    );
  }

  factory _DraftMaterial.fromStoredMap(Map<String, dynamic> data) {
    final material = LearningMaterial.fromMap(data);
    return _DraftMaterial(
      id: material.id.isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : material.id,
      type: material.type,
      title: material.title,
      description: material.description,
      url: material.url,
      fileName: material.fileName,
      storagePath: material.storagePath,
    );
  }

  bool get requiresUpload =>
      type != LearningMaterialType.article && url.isEmpty && bytes != null;

  String get statusText {
    if (requiresUpload) {
      return 'Menunggu dimuat naik semasa simpan lesson';
    }
    if (type == LearningMaterialType.article) {
      return url;
    }
    return fileName.isNotEmpty ? fileName : 'File uploaded';
  }

  LearningMaterial toLearningMaterial() {
    return LearningMaterial(
      id: id,
      type: type,
      title: title,
      description: description,
      url: url,
      fileName: fileName,
      storagePath: storagePath,
    );
  }

  _DraftMaterial copyWith({String? url, String? storagePath}) {
    return _DraftMaterial(
      id: id,
      type: type,
      title: title,
      description: description,
      url: url ?? this.url,
      fileName: fileName,
      storagePath: storagePath ?? this.storagePath,
      bytes: bytes,
    );
  }
}
