import 'package:flutter/material.dart';

class PasswordRequirementsWidget extends StatelessWidget {
  final String password;
  final int minLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireNumber;
  final bool requireSpecialChar;

  const PasswordRequirementsWidget({
    super.key,
    required this.password,
    this.minLength = 8,
    this.requireUppercase = false,
    this.requireLowercase = false,
    this.requireNumber = false,
    this.requireSpecialChar = false,
  });

  bool get _hasMinLength => password.length >= minLength;
  bool get _hasUppercase => password.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => password.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _RequirementItem(
            text: 'At least $minLength characters',
            isMet: _hasMinLength,
          ),
          if (requireUppercase)
            _RequirementItem(
              text: 'Contains uppercase letter (A-Z)',
              isMet: _hasUppercase,
            ),
          if (requireLowercase)
            _RequirementItem(
              text: 'Contains lowercase letter (a-z)',
              isMet: _hasLowercase,
            ),
          if (requireNumber)
            _RequirementItem(
              text: 'Contains number (0-9)',
              isMet: _hasNumber,
            ),
          if (requireSpecialChar)
            _RequirementItem(
              text: 'Contains special character (!@#\$%^&*)',
              isMet: _hasSpecialChar,
            ),
        ],
      ),
    );
  }

  /// 모든 조건 충족 여부
  bool get isValid {
    bool valid = _hasMinLength;
    if (requireUppercase) valid = valid && _hasUppercase;
    if (requireLowercase) valid = valid && _hasLowercase;
    if (requireNumber) valid = valid && _hasNumber;
    if (requireSpecialChar) valid = valid && _hasSpecialChar;
    return valid;
  }
}

class _RequirementItem extends StatelessWidget {
  final String text;
  final bool isMet;

  const _RequirementItem({
    required this.text,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isMet ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? Colors.green[700] : Colors.grey[600],
                decoration: isMet ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
