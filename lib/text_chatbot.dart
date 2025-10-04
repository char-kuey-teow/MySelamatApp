import 'package:flutter/material.dart';
import 'chatbot.dart';
import 'config.dart';

// --- Text-Only Chatbot Screen ---

class TextChatbotScreen extends StatefulWidget {
  const TextChatbotScreen({super.key});

  @override
  State<TextChatbotScreen> createState() => _TextChatbotScreenState();
}

class _TextChatbotScreenState extends State<TextChatbotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;
  
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    ChatbotService.initialize();
    
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    setState(() {
      _isTyping = true;
    });

    _typingController.repeat();

    try {
      await ChatbotService.processUserMessage(message);
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
    }
  }

  Future<void> _handleQuickAction(String action) async {
    setState(() {
      _isTyping = true;
    });

    _typingController.repeat();

    try {
      await ChatbotService.processQuickAction(action);
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      _typingController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 30.0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'SelamatBot',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF2254C5),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: Container(
            height: 10.0,
            color: const Color(0xFF2254C5),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showDebugInfo(),
            tooltip: 'Debug Info',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                ChatbotService.clearMessages();
              });
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: ChatbotService.getMessages().length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == ChatbotService.getMessages().length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(ChatbotService.getMessages()[index]);
              },
            ),
          ),
          
          // Quick Actions
          if (ChatbotService.getMessages().isNotEmpty && 
              ChatbotService.getMessages().last.quickActions != null)
            _buildQuickActions(),
          
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2254C5),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFF2254C5) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isUser ? Colors.white70 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2254C5),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _typingAnimation,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3 + (_typingAnimation.value * 0.7)),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final quickActions = ChatbotService.getMessages().last.quickActions ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickActions.map((action) {
              return ActionChip(
                label: Text(action.text),
                avatar: Icon(action.icon, size: 16),
                onPressed: () => _handleQuickAction(action.action),
                backgroundColor: Colors.white,
                side: BorderSide(color: const Color(0xFF2254C5).withOpacity(0.3)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          
          // Send button
          CircleAvatar(
            backgroundColor: const Color(0xFF2254C5),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    final sessionInfo = ChatbotService.getSessionInfo();
    final configStatus = _getConfigStatus();
    final setupInstructions = _getSetupInstructions();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session Info:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Session ID: ${sessionInfo['sessionId']}'),
              Text('User ID: ${sessionInfo['userId']}'),
              Text('Demo Mode: ${sessionInfo['isDemoMode']}'),
              Text('Config Valid: ${sessionInfo['isConfigValid']}'),
              const SizedBox(height: 16),
              
              const Text('Configuration:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(configStatus),
              const SizedBox(height: 16),
              
              const Text('Setup Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(setupInstructions),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _printConfigStatus();
            },
            child: const Text('Print to Console'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getConfigStatus() {
    return 'AWS Amplify Configuration:\n'
        '• Bot Name: ${Config.lexBotName}\n'
        '• Bot ID: ${Config.lexBotId}\n'
        '• Bot Alias: ${Config.lexBotAlias}\n'
        '• Region: ${Config.amplifyRegion}\n'
        '• Use Amplify: ${Config.useAmplify}\n'
        '• Config Valid: ${Config.isAmplifyConfigValid}';
  }

  String _getSetupInstructions() {
    return 'Setup Instructions:\n'
        '1. Configure AWS Amplify backend\n'
        '2. Set up Amazon Lex bot\n'
        '3. Update configuration in config.dart\n'
        '4. Deploy with amplify push';
  }

  void _printConfigStatus() {
    print('=== Configuration Status ===');
    print(_getConfigStatus());
    print('\n=== Setup Instructions ===');
    print(_getSetupInstructions());
  }
}

