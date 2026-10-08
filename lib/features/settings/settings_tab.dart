import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import 'user_name_validator.dart';
import 'user_profile_repository.dart';

/// Mock terms URL (decision: example.com placeholder).
const kTermsOfServiceUrl = 'https://example.com/terms';

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.authService,
    required this.session,
    this.profileRepository,
  });

  final AuthService authService;
  final Session session;
  final UserProfileRepository? profileRepository;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final UserProfileRepository _profileRepository;
  final _nameController = TextEditingController();
  bool _isLoadingProfile = true;
  bool _isSavingName = false;
  bool _isSigningOut = false;
  String? _errorMessage;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _profileRepository = widget.profileRepository ?? UserProfileRepository();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = null;
    });
    try {
      final profile = await _profileRepository.fetchProfile();
      if (!mounted) return;
      _nameController.text = profile?.userName ?? 'ユーザー';
      setState(() => _isLoadingProfile = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _errorMessage = 'プロフィールを読み込めませんでした。';
      });
    }
  }

  Future<void> _saveUserName() async {
    final validation = validateUserName(_nameController.text);
    setState(() => _nameError = validation);
    if (validation != null) return;

    setState(() {
      _isSavingName = true;
      _errorMessage = null;
    });
    try {
      await _profileRepository.updateUserName(_nameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ユーザー名を保存しました。')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'ユーザー名を保存できませんでした。');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse(kTermsOfServiceUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('モックURL（接続できませんでした）')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('モックURL（接続できませんでした）')));
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.signOut();
    } on AuthException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(error.toString());
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const Text(
          'アカウント',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (widget.session.user.email != null)
          ListTile(
            title: const Text('メールアドレス'),
            subtitle: Text(widget.session.user.email!),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'ユーザー名',
            errorText: _nameError,
            border: const OutlineInputBorder(),
          ),
          maxLength: 50,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _isSavingName ? null : _saveUserName,
            child: Text(_isSavingName ? '保存中...' : 'ユーザー名を保存'),
          ),
        ),
        const SizedBox(height: 24),
        const Text('利用規約', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('利用規約を確認'),
          subtitle: const Text(kTermsOfServiceUrl),
          onTap: _openTerms,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isSigningOut ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: Text(_isSigningOut ? 'ログアウト中...' : 'ログアウト'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
