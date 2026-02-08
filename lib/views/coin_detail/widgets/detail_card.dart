import 'package:blockly/core/extensions/context_extension.dart';
import 'package:flutter/material.dart';

/// [DetailCard] is a reusable widget that displays a title and a value in a card format.
/// It can be used to show various details about a coin, such as price, volume,
class DetailCard extends StatelessWidget {
  /// Constructor with required title and value parameters, and an optional valueColor
  const DetailCard({
    required this.title,
    required this.value,
    this.valueColor,
    super.key,
  });

  /// The title of the detail (e.g. "24s Highest")
  final String title;

  /// The value to display (e.g. "50000 USDT")
  final String value;

  /// Optional color for the value text, can be used to indicate positive/negative changes
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colorScheme.surfaceContainerHigh,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
