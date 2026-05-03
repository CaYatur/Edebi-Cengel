import 'package:flutter/material.dart';

class CustomKeyboard extends StatefulWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onClearPressed;

  const CustomKeyboard({
    Key? key,
    required this.onKeyPressed,
    required this.onDeletePressed,
    required this.onClearPressed,
  }) : super(key: key);

  @override
  State<CustomKeyboard> createState() => _CustomKeyboardState();
}

class _CustomKeyboardState extends State<CustomKeyboard> {
  bool _isNumberMode = false;

  // Türkçe alfabesi - her zaman büyük harfler kullanılacak
  static const List<List<String>> _letters = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç'],
  ];

  // Sayılar ve işaretler
  static const List<List<String>> _numbers = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '(', ')', '&', '@', '"', '.', ',', '?', '!'],
    [':', ';', '/', '+', '=', '%', '*', '#', "'", '"'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode indicator
            Container(
              width: 30,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Mode buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModeButton(
                  'ABC',
                  !_isNumberMode,
                  () => setState(() => _isNumberMode = false),
                ),
                _buildModeButton(
                  '123',
                  _isNumberMode,
                  () => setState(() => _isNumberMode = true),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Keyboard rows
            ..._buildKeyboardRows(),
            
            const SizedBox(height: 6),
            
            // Bottom action buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    'Temizle',
                    Icons.clear_all,
                    Colors.red,
                    widget.onClearPressed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildActionButton(
                    'Boşluk',
                    Icons.space_bar,
                    Colors.blue,
                    () => widget.onKeyPressed(' '),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    'Sil',
                    Icons.backspace,
                    Colors.orange,
                    widget.onDeletePressed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildKeyboardRows() {
    List<List<String>> currentLayout = _isNumberMode 
        ? _numbers 
        : _letters;
    
    return currentLayout.map((row) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((key) => Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: _buildKeyButton(key),
          ),
        )).toList(),
      ),
    )).toList();
  }

  Widget _buildKeyButton(String key) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      elevation: 1,
      child: InkWell(
        onTap: () => widget.onKeyPressed(key),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 24),
          alignment: Alignment.center,
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String text, bool isActive, VoidCallback onPressed) {
    return Material(
      color: isActive ? Colors.blue : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(8),
      elevation: isActive ? 4 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 3),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
