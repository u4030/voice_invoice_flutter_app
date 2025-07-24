import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_invoice_app/providers/speech_provider.dart'; // العودة إلى SpeechProvider
import 'package:voice_invoice_app/utils/app_theme.dart';
import 'package:voice_invoice_app/utils/app_constants.dart';

class VoiceControlWidget extends StatefulWidget {
  final Function(String) onVoiceCommand;
  final Function(String) onTextRecognized;

  const VoiceControlWidget({
    super.key,
    required this.onVoiceCommand,
    required this.onTextRecognized,
  });

  @override
  State<VoiceControlWidget> createState() => _VoiceControlWidgetState();
}

class _VoiceControlWidgetState extends State<VoiceControlWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  bool _hasTriggeredSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _showSuccessAnimation() {
    print('Triggering success animation');
    _successController.forward().then((_) => _successController.reset());
    _hasTriggeredSuccessAnimation = true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeechProvider>(
      builder: (context, speechProvider, child) {
        if (speechProvider.isListening && _hasTriggeredSuccessAnimation) {
          _hasTriggeredSuccessAnimation = false;
        }

        if (speechProvider.isListening) {
          _pulseController.repeat(reverse: true);
          _waveController.repeat();
        } else {
          _pulseController.stop();
          _waveController.stop();
        }

        if (speechProvider.recognizedText.isNotEmpty &&
            !speechProvider.isListening &&
            !_hasTriggeredSuccessAnimation &&
            (speechProvider.containsNewInvoiceCommand(speechProvider.recognizedText) ||
                speechProvider.parseInvoiceItem(speechProvider.recognizedText) != null ||
                speechProvider.containsPrintCommand(speechProvider.recognizedText) ||
                speechProvider.containsSaveCommand(speechProvider.recognizedText))) {
          print('Showing success animation for recognized text: ${speechProvider.recognizedText}');
          _showSuccessAnimation();
        }

        return Column(
          children: [
            if (speechProvider.errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: AppConstants.smallPadding),
                    Expanded(
                      child: Text(
                        speechProvider.errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  if (speechProvider.isListening)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppConstants.defaultPadding),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  AnimatedBuilder(
                    animation: _successController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _successController.value,
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 40,
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () => _toggleListening(context, speechProvider),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: speechProvider.isListening ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: speechProvider.isListening
                                  ? Colors.red
                                  : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: speechProvider.isListening
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.2),
                                  blurRadius: speechProvider.isListening ? 20 : 10,
                                  spreadRadius: speechProvider.isListening ? 5 : 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              speechProvider.isListening
                                  ? Icons.mic
                                  : Icons.mic_none,
                              size: 40,
                              color: speechProvider.isListening
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultPadding),
                  if (speechProvider.isListening)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
                      child: LinearProgressIndicator(
                        value: speechProvider.micLevel,
                        minHeight: 10,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    ),
                  const SizedBox(height: AppConstants.defaultPadding),
                  Text(
                    _getStatusText(speechProvider),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  if (speechProvider.isListening)
                    AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 300 + (index * 100)),
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                width: 4,
                                height: 10 + (30 * _waveAnimation.value * (index % 2 == 0 ? 1 : 0.7)),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            if (speechProvider.recognizedText.isNotEmpty ||
                speechProvider.partialText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.text_fields,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: AppConstants.smallPadding),
                        const Text(
                          'النص المحول:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        if (speechProvider.recognizedText.isNotEmpty)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () => _confirmText(speechProvider),
                                tooltip: 'تأكيد',
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                onPressed: () => _clearText(speechProvider),
                                tooltip: 'مسح',
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.smallPadding),
                    Text(
                      speechProvider.recognizedText.isNotEmpty
                          ? speechProvider.recognizedText
                          : speechProvider.partialText,
                      style: TextStyle(
                        fontSize: 16,
                        color: speechProvider.recognizedText.isNotEmpty
                            ? Colors.black
                            : Colors.grey,
                        fontStyle: speechProvider.recognizedText.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            if (!speechProvider.isListening && speechProvider.recognizedText.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: AppConstants.defaultPadding),
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Column(
                  children: [
                    const Text(
                      'أمثلة على الأوامر الصوتية:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.smallPadding),
                    const Text(
                      '• "فاتورة جديدة" أو "فاتوره جديده" - لإنشاء فاتورة جديدة\n'
                          '• "حساب سيارة 15 دينار" أو "أضف سيارة 15 دينار" - لإضافة عنصر\n'
                          '• "مصروف طعام 10" - لإضافة مصروف\n',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _getStatusText(SpeechProvider speechProvider) {
    if (speechProvider.isListening) {
      return 'أتحدث الآن... اضغط لإيقاف التسجيل';
    } else if (speechProvider.recognizedText.isNotEmpty) {
      return 'جاري المعالجة...';
    } else if (speechProvider.errorMessage.isNotEmpty) {
      return 'حدث خطأ، اضغط للمحاولة مرة أخرى';
    } else {
      return 'اضغط على الميكروفون أو قل "فاتورة جديدة"';
    }
  }

  void _toggleListening(BuildContext context, SpeechProvider speechProvider) {
    if (speechProvider.isListening) {
      speechProvider.stopListening().then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إيقاف الاستماع'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      });
    } else {
      speechProvider.startListening(
        context: context,
        onResult: (text) {
          print('Recognized text: $text');
          widget.onTextRecognized(text);
        },
        onCommand: (text) {
          print('Command text: $text');
          widget.onVoiceCommand(text);
        },
      );
    }
  }

  void _confirmText(SpeechProvider speechProvider) {
    if (speechProvider.recognizedText.isNotEmpty) {
      print('Confirming text in VoiceControlWidget: ${speechProvider.recognizedText}');
      widget.onTextRecognized(speechProvider.recognizedText);
      speechProvider.clearText();
    }
  }

  void _clearText(SpeechProvider speechProvider) {
    print('Clearing text in VoiceControlWidget');
    speechProvider.clearText();
  }
}