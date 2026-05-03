import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnswerInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final String expectedAnswer;
  final Function(String) onAnswerSubmitted;
  final bool isAnswered;

  const AnswerInputWidget({
    Key? key,
    required this.controller,
    required this.expectedAnswer,
    required this.onAnswerSubmitted,
    this.isAnswered = false,
  }) : super(key: key);

  @override
  State<AnswerInputWidget> createState() => _AnswerInputWidgetState();
}

class _AnswerInputWidgetState extends State<AnswerInputWidget> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.isAnswered ? Colors.green.shade50 : Colors.white,
          border: Border.all(
            color: widget.isAnswered ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isAnswered) ...[
                // Doğru cevap gösterimi
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Doğru Cevap!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.expectedAnswer,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Cevap girişi
                Text(
                  'Cevabınızı yazın',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: 'Cevabınızı buraya yazın...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: _submitAnswer,
                ),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _submitAnswer(widget.controller.text),
                    icon: _isSubmitting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Kontrol ediliyor...' : 'Cevabı Gönder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submitAnswer(String answer) async {
    if (answer.trim().isEmpty || _isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Kısa gecikme ile submit (kullanıcı deneyimi için)
    await Future.delayed(const Duration(milliseconds: 300));
    
    widget.onAnswerSubmitted(answer.trim());
    
    setState(() {
      _isSubmitting = false;
    });
  }
}
