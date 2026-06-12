// AI Assistant Screen with Gemini chat, Hindi voice input, and suggestions

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class AIAssistantScreen extends StatefulWidget {
  final String? inspectionId;
  const AIAssistantScreen({super.key, this.inspectionId});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _language = 'hi';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_msgController.text.isNotEmpty) {
            _sendMessage(_msgController.text);
          }
        }
      },
    );
    setState(() {});
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      text: 'नमस्ते! मैं ग्राम निरीक्षण AI सहायक हूं 🙏\n\n'
            'आप मुझसे पूछ सकते हैं:\n'
            '• निरीक्षण कैसे करें?\n'
            '• रिपोर्ट कैसे लिखें?\n'
            '• सरकारी योजनाओं की जानकारी\n'
            '• तकनीकी सवाल\n\n'
            'हिंदी या अंग्रेजी में पूछें।',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text('AI सहायक'),
        ]),
        actions: [
          // Language toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Text('हिं', style: TextStyle(color: _language == 'hi' ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
              Switch(
                value: _language == 'en',
                onChanged: (v) => setState(() => _language = v ? 'en' : 'hi'),
                activeColor: AppTheme.accentColor,
              ),
              Text('EN', style: TextStyle(color: _language == 'en' ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick suggestion chips
          _buildSuggestionChips(),
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          // Typing indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                _TypingIndicator(),
              ]),
            ),
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = _language == 'hi'
        ? ['निरीक्षण चेकलिस्ट', 'रिपोर्ट लिखें', 'जल जीवन मिशन', 'MGNREGA जानकारी']
        : ['Inspection Checklist', 'Write Report', 'Jal Jeevan Mission', 'MGNREGA Info'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: suggestions.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () => _sendMessage(s),
              backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor),
              child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : const Color(0xFF2C3E50),
                        fontSize: 14, height: 1.5,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16, backgroundColor: AppTheme.accentColor,
              child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        // Voice button
        if (_speechAvailable)
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? AppTheme.errorColor : AppTheme.primaryColor.withOpacity(0.1),
              ),
              child: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isListening ? Colors.white : AppTheme.primaryColor, size: 22),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _msgController,
            maxLines: 3, minLines: 1,
            decoration: InputDecoration(
              hintText: _language == 'hi' ? 'अपना सवाल लिखें...' : 'Type your question...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              filled: true, fillColor: const Color(0xFFF5F7FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isLoading ? null : () {
            if (_msgController.text.trim().isNotEmpty) {
              _sendMessage(_msgController.text.trim());
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isLoading ? Colors.grey : AppTheme.primaryColor,
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8)],
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      final response = await ApiService().aiChat(text, inspectionId: widget.inspectionId, language: _language);
      final aiResponse = response.data['response'] as String;
      setState(() {
        _messages.add(_ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'माफ़ करें, कोई त्रुटि हुई। कृपया पुनः प्रयास करें।',
          isUser: false, timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _msgController.text = result.recognizedWords);
      },
      localeId: _language == 'hi' ? 'hi_IN' : 'en_IN',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  _ChatMessage({required this.text, required this.isUser, required this.timestamp});
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.smart_toy_rounded, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        ...List.generate(3, (i) => AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final offset = ((_ctrl.value + i * 0.2) % 1.0);
            final y = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.3 + y * 0.7),
              ),
            );
          },
        )),
      ]),
    );
  }
}
