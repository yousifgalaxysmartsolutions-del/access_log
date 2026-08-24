import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.icon,
    this.suffix,
    this.multiline = false,
    this.enabled = true,
    this.errorText,
  });
  final String label;
  final String? hint, errorText;
  final IconData? icon, suffix;
  final bool multiline, enabled;
  @override
  Widget build(BuildContext context) => TextField(
    enabled: enabled,
    maxLines: multiline ? 3 : 1,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixIcon: suffix == null ? null : Icon(suffix),
    ),
  );
}
