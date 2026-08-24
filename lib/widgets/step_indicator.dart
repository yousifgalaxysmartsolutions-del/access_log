import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';

class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.steps, required this.current});
  final List<String> steps;
  final int current;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < current ? AppColors.orange : AppColors.border,
              ),
            );
          }
          final index = i ~/ 2;
          final active = index <= current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active ? AppColors.orange : Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.orange : AppColors.border,
                width: 2,
              ),
            ),
            child: Center(
              child: active
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${index + 1}', style: AppTypography.meta),
            ),
          );
        }),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: steps
            .map(
              (s) => Flexible(
                child: Text(
                  s,
                  textAlign: TextAlign.center,
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}
