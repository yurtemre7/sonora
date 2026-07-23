import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sonora/services/permission_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final void Function(String? selectedFolder, String userName) onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  var _currentPage = 0;

  // Permissions State
  var _storageGranted = false;
  var _notificationGranted = false;

  // Folder State
  String? _selectedFolder;
  final _nameController = TextEditingController(text: 'User');

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    if (!Platform.isAndroid) return;

    var sdkInt = await PermissionService().getAndroidSdk();
    bool storageOk;
    if (sdkInt >= 33) {
      storageOk =
          (await Permission.audio.isGranted) &&
          (await Permission.photos.isGranted);
    } else {
      storageOk = await Permission.storage.isGranted;
    }

    var notificationOk = await Permission.notification.isGranted;

    if (mounted) {
      setState(() {
        _storageGranted = storageOk;
        _notificationGranted = notificationOk;
      });
    }
  }

  Future<void> _requestPermissions() async {
    var service = PermissionService();
    var result = await service.requestAllPermissions();
    await _checkInitialPermissions();

    if (result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions configured successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Automatically advance to the next step
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickFolder() async {
    try {
      var folderPath = await FilePicker.getDirectoryPath();
      if (folderPath != null && mounted) {
        setState(() {
          _selectedFolder = folderPath;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select directory. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Premium Glowing Ambient Background
          Positioned.fill(child: Container(color: theme.colorScheme.surface)),
          Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.22),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.tertiary.withValues(alpha: 0.18),
                    theme.colorScheme.tertiary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Onboarding Page Container
          SafeArea(
            child: Column(
              children: [
                // Top Header (Skip Button)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SONORA',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Page Slider Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildWelcomeSlide(theme, size),
                      _buildPermissionSlide(theme, size),
                      _buildFolderSlide(theme, size),
                    ],
                  ),
                ),

                // Footer (Progress Dots & Navigation Button)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Animated Indicator Dots
                      Row(
                        children: List.generate(3, (index) {
                          var active = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            height: 8.0,
                            width: active ? 24.0 : 8.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.0),
                              color: active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.3),
                            ),
                          );
                        }),
                      ),

                      // Next/Finish Action Button
                      _currentPage == 2
                          ? FloatingActionButton.extended(
                              onPressed: _selectedFolder == null
                                  ? null
                                  : () => widget.onComplete(
                                      _selectedFolder!,
                                      _nameController.text.trim().isEmpty
                                          ? 'User'
                                          : _nameController.text.trim(),
                                    ),
                              icon: const Icon(Icons.done_rounded),
                              label: const Text('Get Started'),
                            )
                          : FloatingActionButton(
                              onPressed:
                                  (_currentPage == 1 &&
                                      !(_storageGranted &&
                                          _notificationGranted))
                                  ? null // Require permissions to proceed
                                  : () {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                              backgroundColor:
                                  (_currentPage == 1 &&
                                      !(_storageGranted &&
                                          _notificationGranted))
                                  ? theme.colorScheme.surfaceContainerHigh
                                  : theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  (_currentPage == 1 &&
                                      !(_storageGranted &&
                                          _notificationGranted))
                                  ? theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5)
                                  : theme.colorScheme.onPrimaryContainer,
                              child: const Icon(Icons.arrow_forward_rounded),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSlide(ThemeData theme, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration Space
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size.width * 0.65,
                  height: size.width * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        theme.colorScheme.tertiaryContainer.withValues(
                          alpha: 0.2,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: size.width * 0.48,
                  height: size.width * 0.48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHigh,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                ),
                // Orbit rings
                Container(
                  width: size.width * 0.56,
                  height: size.width * 0.56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              'Welcome to Sonora',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Your Name (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'A premium offline music experience built with beautiful Material 3 Expressive elements.\n\nEnjoy fluid, stutter-free playback and fast background syncing.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSlide(ThemeData theme, Size size) {
    var allGranted = _storageGranted && _notificationGranted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Permissions card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        _storageGranted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: _storageGranted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: const Text('Access Audio & Image Files'),
                      subtitle: const Text(
                        'Required to index audio tracks and scan local cover images (artist.jpg / cover.jpg) on your device.',
                      ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      leading: Icon(
                        _notificationGranted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: _notificationGranted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: const Text('Show Notifications'),
                      subtitle: const Text(
                        'Required to show lockscreen & notification shade media playback controls.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Permissions Needed',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'To play and control your music, Sonora needs runtime authorization permissions from your device.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: allGranted ? null : _requestPermissions,
              icon: Icon(
                allGranted ? Icons.done_all_rounded : Icons.security_rounded,
              ),
              label: Text(
                allGranted
                    ? 'All Permissions Granted'
                    : 'Configure Permissions',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSlide(ThemeData theme, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Directory Picker view
            Container(
              width: size.width * 0.44,
              height: size.width * 0.44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedFolder == null
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Icon(
                _selectedFolder == null
                    ? Icons.folder_open_rounded
                    : Icons.folder_copy_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Setup Music Directory',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFolder == null
                  ? 'Choose the primary folder containing your audio tracks (MP3, FLAC, M4A, etc.) to build your initial library database.'
                  : 'Selected Directory:',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedFolder != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _selectedFolder!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFolder,
              icon: Icon(
                _selectedFolder == null
                    ? Icons.create_new_folder_rounded
                    : Icons.folder_shared_rounded,
              ),
              label: Text(
                _selectedFolder == null ? 'Select Folder' : 'Change Folder',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
