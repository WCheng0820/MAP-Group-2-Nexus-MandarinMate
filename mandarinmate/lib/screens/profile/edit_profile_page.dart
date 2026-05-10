import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.roleColor,
    this.isFirstTime = false,
  });

  final Color roleColor;
  final bool isFirstTime;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _facultyController = TextEditingController();
  final _bioController = TextEditingController();

  // Password change
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  UserRole _role = UserRole.student;
  String _profileImageUrl = '';
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!);
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _ageController.text = profile.age ?? '';
        _studentIdController.text = profile.studentId ?? '';
        _facultyController.text = profile.faculty ?? '';
        _bioController.text = profile.bio ?? '';
        _role = profile.role;
        _profileImageUrl = profile.profileImageUrl;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profiles')
          .child('$uid.jpg');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // 1. Change Password if filled
      final newPass = _newPasswordController.text;
      final confirmPass = _confirmPasswordController.text;
      if (newPass.isNotEmpty) {
        if (newPass == confirmPass) {
          await user.updatePassword(newPass);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Passwords do not match.');
        }
      }

      // 2. Upload image
      String newImageUrl = _profileImageUrl;
      if (_imageFile != null) {
        final uploadedUrl = await _uploadImage(user.uid);
        if (uploadedUrl != null) newImageUrl = uploadedUrl;
      }

      // 3. Update Firestore
      final updates = <String, dynamic>{
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profileImageUrl': newImageUrl,
        'updatedAt': DateTime.now().toIso8601String(),
        'isProfileComplete': true,
      };

      if (_role == UserRole.student) {
        updates['age'] = _ageController.text.trim();
        updates['studentId'] = _studentIdController.text.trim();
        updates['faculty'] = _facultyController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      await user.updateDisplayName(fullName);

      // Tell AuthBloc to reload user profile
      if (mounted) {
        context.read<AuthBloc>().add(AuthUserChanged(user));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.isFirstTime) {
          // GoRouter redirect handler will automatically pick up the complete profile
          // But to be safe, we can trigger a hard refresh or navigation:
          context.go('/');
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _studentIdController.dispose();
    _facultyController.dispose();
    _bioController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: widget.roleColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.roleColor, width: 2),
          ),
        ),
        validator: isRequired
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFirstTime ? 'Complete Your Profile' : 'Edit Profile',
        ),
        automaticallyImplyLeading: !widget.isFirstTime,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.roleColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_profileImageUrl.isNotEmpty
                                          ? NetworkImage(_profileImageUrl)
                                          : null)
                                      as ImageProvider?,
                            child:
                                _imageFile == null && _profileImageUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.roleColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Universal Fields
                    const Text(
                      'Basic Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _firstNameController,
                      'First Name',
                      Icons.person,
                      isRequired: true,
                    ),
                    _buildTextField(
                      _lastNameController,
                      'Last Name',
                      Icons.person_outline,
                      isRequired: true,
                    ),

                    // Role Specific
                    if (_role == UserRole.student) ...[
                      _buildTextField(_ageController, 'Age', Icons.cake),
                      _buildTextField(
                        _studentIdController,
                        'Student/Staff ID',
                        Icons.badge,
                      ),
                      _buildTextField(
                        _facultyController,
                        'Faculty',
                        Icons.school,
                      ),
                    ],

                    if (_role == UserRole.tutor ||
                        _role == UserRole.student) ...[
                      _buildTextField(_bioController, 'Bio', Icons.info),
                    ],

                    const SizedBox(height: 16),
                    // Role Locked notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Role: ${_role.name.toUpperCase()}\n(Role cannot be changed. If you want to change, please ask our admin)',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Password section
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Leave blank if you do not want to change.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _newPasswordController,
                      'New Password',
                      Icons.lock,
                      isPassword: true,
                    ),
                    _buildTextField(
                      _confirmPasswordController,
                      'Confirm New Password',
                      Icons.lock_outline,
                      isPassword: true,
                    ),

                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.roleColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isFirstTime
                              ? 'Complete Setup'
                              : 'Save Changes',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
