import 'package:flutter/material.dart';

class MediaDialog extends StatelessWidget {
  final String mediaPath;
  final String mediaType;

  const MediaDialog({
    super.key,
    required this.mediaPath,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Medya: $mediaType',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Dosya Yolu: $mediaPath'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}
