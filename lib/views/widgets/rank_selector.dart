import 'package:flutter/material.dart';

class RankSelector extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const RankSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = value >= 0 ? '+$value' : '$value';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          displayText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: value > 0
                ? Colors.red
                : value < 0
                    ? Colors.blue
                    : colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _smallButton('MIN', () => onChanged(-6)),
            _smallButton('-', () {
              if (value > -6) onChanged(value - 1);
            }),
            _smallButton('+', () {
              if (value < 6) onChanged(value + 1);
            }),
            _smallButton('MAX', () => onChanged(6)),
          ],
        ),
      ],
    );
  }

  Widget _smallButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: text.length > 1 ? 40 : 32,
        height: 28,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
