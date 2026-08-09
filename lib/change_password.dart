import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'validators.dart';
import 'widgets/app_ui.dart';

/// Opens the shared "Change Password" dialog for the currently signed-in user.
///
/// The dialog asks for the current password (to re-authenticate — Firebase
/// requires a recent sign-in for `updatePassword`), then the new password and
/// a confirmation. Returns `true` if the password was successfully changed,
/// `false` if it was cancelled or failed.
Future<bool> showChangePasswordDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const ChangePasswordDialog(),
  );
  return changed ?? false;
}

/// Modal dialog that lets any signed-in user change their own password.
///
/// Used from the Settings area of the Expert, Department Head and Dean
/// portals. Re-authenticates with the current password first so
/// `FirebaseAuth.updatePassword` never fails with `requires-recent-login`.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        setState(() {
          _busy = false;
          _errorText = 'You are not signed in. Please sign in again.';
        });
        return;
      }

      // Re-authenticate so updatePassword is allowed even if the user signed
      // in more than a few minutes ago (Firebase requires a recent login).
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newCtrl.text);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = _authErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = 'Unexpected error: $e';
      });
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'Current password is incorrect. Please try again.';
      case 'weak-password':
        return 'New password is too weak — use at least 6 characters.';
      case 'user-disabled':
      case 'user-not-found':
        return 'This account is no longer available.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Could not update password: ${e.message ?? e.code}';
    }
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    required bool obscure,
    required ValueChanged<bool> onToggle,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: validator,
      decoration: appInputDecoration(
        label: label,
        hint: hint,
        icon: icon,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: AppPalette.textMuted,
          ),
          onPressed: () => setState(() => onToggle(!obscure)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: AppPalette.primary, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text('Change Password', textAlign: TextAlign.center),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your current password to confirm it\'s you, then set a new one.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppPalette.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 18),
                _passwordField(
                  _currentCtrl,
                  'Current Password',
                  Icons.lock_outline,
                  obscure: _obscureCurrent,
                  onToggle: (v) => _obscureCurrent = v,
                  validator: passwordField,
                ),
                const SizedBox(height: 14),
                _passwordField(
                  _newCtrl,
                  'New Password',
                  Icons.password_rounded,
                  obscure: _obscureNew,
                  onToggle: (v) => _obscureNew = v,
                  hint: 'At least 6 characters',
                  validator: (v) {
                    final err = passwordField(v);
                    if (err != null) return err;
                    if (v == _currentCtrl.text) {
                      return 'New password must be different from the current one';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _passwordField(
                  _confirmCtrl,
                  'Confirm New Password',
                  Icons.verified_user_outlined,
                  obscure: _obscureConfirm,
                  onToggle: (v) => _obscureConfirm = v,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (v != _newCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: AppPalette.textMuted)),
        ),
        GradientButton(
          label: _busy ? 'Updating…' : 'Update Password',
          icon: _busy ? null : Icons.lock_reset_rounded,
          width: 170,
          height: 44,
          fontSize: 13,
          onPressed: _busy ? null : _submit,
        ),
      ],
      ),
    );
  }
}
