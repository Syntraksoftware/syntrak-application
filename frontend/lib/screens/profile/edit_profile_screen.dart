import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/models/profile.dart';
import 'package:syntrak/providers/auth_provider.dart';
import 'package:syntrak/services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _skiLevelController = TextEditingController();
  final _homeController = TextEditingController();

  Profile? _currentProfile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _skiLevelController.dispose();
    _homeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();

      if (authProvider.session != null) {
        apiService.setToken(authProvider.session!.accessToken);
      }

      final profile = await apiService.getCurrentUserProfile();

      setState(() {
        _currentProfile = profile;
        _fullNameController.text = profile.fullName ?? '';
        _usernameController.text = profile.username ?? '';
        _bioController.text = profile.bio ?? '';
        _skiLevelController.text = profile.skiLevel ?? '';
        _homeController.text = profile.home ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();

      if (authProvider.session != null) {
        apiService.setToken(authProvider.session!.accessToken);
      }

      // Upload avatar first if image was selected
      String? avatarUrl = _currentProfile?.avatarUrl;
      if (_selectedImage != null) {
        final updatedProfile = await apiService.uploadAvatar(_selectedImage!);
        avatarUrl = updatedProfile.avatarUrl;
      }

      // Update profile with form data
      final updatedProfile = await apiService.updateProfile(
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        avatarUrl: avatarUrl,
        skiLevel: _skiLevelController.text.trim().isEmpty
            ? null
            : _skiLevelController.text.trim(),
        home: _homeController.text.trim().isEmpty
            ? null
            : _homeController.text.trim(),
      );

      // Refresh user data in auth provider
      await authProvider.refreshUserData();

      if (mounted) {
        Navigator.pop(context, updatedProfile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to update profile';
      if (e is Exception) {
        final message = e.toString();
        if (message.startsWith('Exception: ')) {
          errorMessage = message.substring(11);
        } else {
          errorMessage = message;
        }
      }

      setState(() {
        _error = errorMessage;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SyntrakColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: Text(
                'Save',
                style: SyntrakTypography.labelLarge.copyWith(
                  color: SyntrakColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _currentProfile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: SyntrakTypography.bodyMedium.copyWith(
                          color: SyntrakColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: SyntrakSpacing.md),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(SyntrakSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar section
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor:
                                    SyntrakColors.primary.withOpacity(0.2),
                                backgroundImage: _selectedImage != null
                                    ? FileImage(_selectedImage!)
                                    : (_currentProfile?.avatarUrl != null
                                        ? NetworkImage(
                                            _currentProfile!.avatarUrl!)
                                        : null) as ImageProvider?,
                                child: _selectedImage == null &&
                                        (_currentProfile?.avatarUrl == null ||
                                            _currentProfile!.avatarUrl!.isEmpty)
                                    ? Text(
                                        _fullNameController.text.isNotEmpty
                                            ? _fullNameController.text[0]
                                                .toUpperCase()
                                            : 'U',
                                        style: SyntrakTypography.headlineMedium
                                            .copyWith(
                                          color: SyntrakColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: SyntrakColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.white),
                                    onPressed: _pickImage,
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: SyntrakSpacing.xl),

                        // Error message
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(SyntrakSpacing.md),
                            margin: const EdgeInsets.only(
                                bottom: SyntrakSpacing.md),
                            decoration: BoxDecoration(
                              color: SyntrakColors.error.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                            child: Text(
                              _error!,
                              style: SyntrakTypography.bodySmall.copyWith(
                                color: SyntrakColors.error,
                              ),
                            ),
                          ),

                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                          ),
                        ),
                        const SizedBox(height: SyntrakSpacing.md),

                        // Username
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: '@username',
                            prefixText: '@',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: SyntrakSpacing.md),

                        // Bio
                        TextFormField(
                          controller: _bioController,
                          decoration: InputDecoration(
                            labelText: 'Bio',
                            hintText: 'Tell us about yourself...',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                          ),
                          maxLines: 4,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: SyntrakSpacing.md),

                        // Ski Level
                        TextFormField(
                          controller: _skiLevelController,
                          decoration: InputDecoration(
                            labelText: 'Ski Level',
                            hintText: 'e.g., Beginner, Intermediate, Advanced',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: SyntrakSpacing.md),

                        // Home/Nationality
                        TextFormField(
                          controller: _homeController,
                          decoration: InputDecoration(
                            labelText: 'Home / Nationality',
                            hintText: 'e.g., New York, USA',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: SyntrakSpacing.xl),

                        // Save button
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SyntrakColors.primary,
                            foregroundColor: SyntrakColors.textOnPrimary,
                            padding: const EdgeInsets.symmetric(
                                vertical: SyntrakSpacing.md),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SyntrakRadius.md),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Save Changes',
                                  style: SyntrakTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w600,
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
