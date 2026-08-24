import 'package:flutter/material.dart';
import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import '../models/models.dart';

class QuestionnaireField extends StatefulWidget {
  const QuestionnaireField({super.key, required this.item});
  final QuestionnaireItem item;
  @override
  State<QuestionnaireField> createState() => _QuestionnaireFieldState();
}

class _QuestionnaireFieldState extends State<QuestionnaireField> {
  bool value = false;
  String? selected;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (item.type == QuestionType.yesNo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: AppTypography.label),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(context.tr('Yes', 'نعم')),
                icon: const Icon(Icons.check),
              ),
              ButtonSegment(
                value: false,
                label: Text(context.tr('No', 'لا')),
                icon: const Icon(Icons.close),
              ),
            ],
            selected: {value},
            onSelectionChanged: (v) => setState(() => value = v.first),
          ),
        ],
      );
    }
    if (item.type == QuestionType.checkbox) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        title: Text(item.label, style: AppTypography.label),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() => value = v ?? false),
      );
    }
    if (item.type == QuestionType.dropdown) {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selected,
        decoration: InputDecoration(
          labelText: item.label,
          prefixIcon: const Icon(Icons.tune),
        ),
        items: item.options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => selected = v),
      );
    }
    return TextField(
      keyboardType: item.type == QuestionType.number
          ? TextInputType.number
          : null,
      decoration: InputDecoration(
        labelText: item.label,
        prefixIcon: Icon(
          item.type == QuestionType.number
              ? Icons.numbers
              : Icons.edit_outlined,
        ),
      ),
    );
  }
}
