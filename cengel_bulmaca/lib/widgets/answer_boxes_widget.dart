import 'package:flutter/material.dart';
import 'custom_keyboard.dart';

class AnswerBoxesWidget extends StatefulWidget {
  final String expectedAnswer;
  final String maskedAnswer;
  final Function(String) onAnswerSubmitted;
  final Function(String)? onInputChanged; // Yeni callback
  final String? initialInput; // Başlangıç değeri
  final bool isAnswered;

  const AnswerBoxesWidget({
    super.key,
    required this.expectedAnswer,
    required this.maskedAnswer,
    required this.onAnswerSubmitted,
    this.onInputChanged,
    this.initialInput,
    this.isAnswered = false,
  });

  @override
  State<AnswerBoxesWidget> createState() => _AnswerBoxesWidgetState();
}

class _AnswerBoxesWidgetState extends State<AnswerBoxesWidget> {
  List<String> _userInput = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeBoxes();
  }

  @override
  void didUpdateWidget(AnswerBoxesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expectedAnswer != widget.expectedAnswer ||
        oldWidget.initialInput != widget.initialInput ||
        oldWidget.isAnswered != widget.isAnswered) {
      _initializeBoxes();
    }
  }

  void _initializeBoxes() {
    _userInput = List.filled(widget.expectedAnswer.length, '');
    _currentIndex = 0;
    
    // Eğer soru cevaplanmışsa, doğru cevabı göster
    if (widget.isAnswered) {
      for (int i = 0; i < widget.expectedAnswer.length; i++) {
        _userInput[i] = widget.expectedAnswer[i];
      }
      return;
    }
    
    // Önceden gösterilen harfleri doldur
    for (int i = 0; i < widget.maskedAnswer.length; i++) {
      if (i < _userInput.length && widget.maskedAnswer[i] != '_') {
        _userInput[i] = widget.maskedAnswer[i];
      }
    }
    
    // Daha önce girilmiş harfleri yükle
    if (widget.initialInput != null && widget.initialInput!.isNotEmpty) {
      for (int i = 0; i < widget.initialInput!.length && i < _userInput.length; i++) {
        if (widget.maskedAnswer[i] == '_') { // Sadece boş yerleri doldur
          _userInput[i] = widget.initialInput![i];
        }
      }
    }
    
    // İlk boş kutuyu bul
    _findNextEmptyBox();
  }

  void _findNextEmptyBox() {
    for (int i = 0; i < _userInput.length; i++) {
      if (_userInput[i] == '' || _userInput[i] == '_') {
        _currentIndex = i;
        return;
      }
    }
  }

  void _addLetter(String letter) {
    if (_currentIndex < _userInput.length) {
      setState(() {
        _userInput[_currentIndex] = letter;
        _moveToNextBox();
      });
      _notifyInputChanged();
      _checkAnswer();
    }
  }

  void _notifyInputChanged() {
    if (widget.onInputChanged != null) {
      widget.onInputChanged!(_userInput.join(''));
    }
  }

  void _checkAndSubmitAnswer() {
    String userAnswer = _userInput.join('').replaceAll('_', '').replaceAll(' ', '');
    widget.onAnswerSubmitted(userAnswer);
  }

  void _moveToNextBox() {
    for (int i = _currentIndex + 1; i < _userInput.length; i++) {
      if (_userInput[i] == '' || _userInput[i] == '_') {
        _currentIndex = i;
        return;
      }
    }
    // Sonuna ulaştıysak, ilk boş kutuyu bul
    _findNextEmptyBox();
  }

  void _deleteLetter() {
    setState(() {
      if (_userInput[_currentIndex].isNotEmpty && _userInput[_currentIndex] != widget.expectedAnswer[_currentIndex]) {
        _userInput[_currentIndex] = '';
      } else {
        // Önceki boş kutuyu bul
        for (int i = _currentIndex - 1; i >= 0; i--) {
          if (_userInput[i] != widget.expectedAnswer[i] && _userInput[i].isNotEmpty) {
            _userInput[i] = '';
            _currentIndex = i;
            break;
          }
        }
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (int i = 0; i < _userInput.length; i++) {
        if (_userInput[i] != widget.expectedAnswer[i] || widget.maskedAnswer[i] == '_') {
          _userInput[i] = '';
        }
      }
      _findNextEmptyBox();
    });
  }

  void _checkAnswer() {
    String userAnswer = _userInput.join('');
    if (userAnswer.toLowerCase().replaceAll(' ', '') == 
        widget.expectedAnswer.toLowerCase().replaceAll(' ', '')) {
      widget.onAnswerSubmitted(userAnswer);
    }
  }

  void _handleLetterInput(String letter) {
    if (_currentIndex < _userInput.length && _userInput[_currentIndex] != widget.expectedAnswer[_currentIndex]) {
      setState(() {
        _userInput[_currentIndex] = letter.toUpperCase();
        _findNextEmptyBox();
      });
    }
  }

  void _deleteLastLetter() {
    _deleteLetter();
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Answer boxes
          Container(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 4,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _buildAnswerBoxes(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Kontrol Et butonu
          if (!widget.isAnswered) ...[
            ElevatedButton.icon(
              onPressed: _checkAndSubmitAnswer,
              icon: const Icon(Icons.check),
              label: const Text('Kontrol Et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
        
        // Success message for answered questions
        if (widget.isAnswered) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Doğru Cevap!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
          
          // Spacer ile klavyeyi aşağıya it
          const Spacer(),
          
          // Custom keyboard - en altta
          CustomKeyboard(
            onKeyPressed: _handleLetterInput,
            onDeletePressed: _deleteLastLetter,
            onClearPressed: _clearAll,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAnswerBoxes() {
    List<Widget> boxes = [];
    
    for (int i = 0; i < widget.expectedAnswer.length; i++) {
      if (widget.expectedAnswer[i] == ' ') {
        // Boşluk için özel widget
        boxes.add(
          Container(
            width: 8,
            height: 35,
            alignment: Alignment.center,
            child: const Text(
              '',
              style: TextStyle(fontSize: 14),
            ),
          ),
        );
      } else {
        // Harf kutusu
        bool isVisible = widget.maskedAnswer.length > i && widget.maskedAnswer[i] != '_';
        bool isFilled = _userInput[i].isNotEmpty;
        bool isCurrent = i == _currentIndex && !widget.isAnswered;
        bool isCorrect = widget.isAnswered && _userInput[i].toLowerCase() == widget.expectedAnswer[i].toLowerCase();
        
        boxes.add(
          GestureDetector(
            onTap: () {
              if (!widget.isAnswered && !isVisible) {
                setState(() {
                  _currentIndex = i;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: _getBoxColor(isVisible, isFilled, isCurrent, isCorrect),
                border: Border.all(
                  color: _getBorderColor(isVisible, isFilled, isCurrent, isCorrect),
                  width: isCurrent ? 3 : 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: isCurrent ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                _userInput[i].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getTextColor(isVisible, isCorrect),
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return boxes;
  }

  Color _getBoxColor(bool isVisible, bool isFilled, bool isCurrent, bool isCorrect) {
    if (widget.isAnswered && isCorrect) return Colors.green.shade100;
    if (widget.isAnswered && !isCorrect) return Colors.red.shade100;
    if (isVisible) return Colors.blue.shade50;
    if (isCurrent) return Colors.blue.shade50.withOpacity(0.8);
    if (isFilled) return Colors.grey.shade100;
    return Colors.white;
  }

  Color _getBorderColor(bool isVisible, bool isFilled, bool isCurrent, bool isCorrect) {
    if (widget.isAnswered && isCorrect) return Colors.green.shade400;
    if (widget.isAnswered && !isCorrect) return Colors.red.shade400;
    if (isCurrent) return Colors.blue.shade600;
    if (isVisible) return Colors.blue.shade300;
    if (isFilled) return Colors.grey.shade400;
    return Colors.grey.shade300;
  }

  Color _getTextColor(bool isVisible, bool isCorrect) {
    if (widget.isAnswered && isCorrect) return Colors.green.shade800;
    if (widget.isAnswered && !isCorrect) return Colors.red.shade800;
    if (isVisible) return Colors.blue.shade800;
    return Colors.black87;
  }

  // Dışarıdan harf ekleme için public method
  void addLetter(String letter) {
    _addLetter(letter);
  }

  void deleteLetter() {
    _deleteLetter();
  }
}
