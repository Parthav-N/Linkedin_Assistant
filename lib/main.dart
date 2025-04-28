import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LinkedIn Post Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isGeneratingPost = false;
  String? _generatedPost;

  Future<void> _makeNetworkRequest(String endpoint, Map<String, dynamic> requestBody, Function(String) onSuccess, Function(String) onError) async {
    setState(() {
      _isGeneratingPost = true;
    });

    try {
      // Try multiple base URLs if one fails
      List<String> baseUrls = [
        'https://linkedin-post-generator-backend.onrender.com',
        'http://linkedin-post-generator-backend.onrender.com',
      ];
      
      http.Response? response;
      String errorMsg = "";
      
      // Try each URL until one works
      for (String baseUrl in baseUrls) {
        try {
          response = await http.post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          ).timeout(const Duration(seconds: 15));
          
          // If successful, break the loop
          if (response.statusCode == 200) {
            break;
          }
        } catch (e) {
          errorMsg = e.toString();
          // Continue to the next URL if this one failed
          continue;
        }
      }

      // Check if any request was successful
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        onSuccess(data['post']);
      } else {
        onError('Server error: Unable to connect to the server. $errorMsg');
      }
    } on SocketException catch (e) {
      print('Socket Exception: $e');
      onError('Network error: Cannot connect to server. Please check your internet connection.');
    } on TimeoutException catch (e) {
      print('Timeout Exception: $e');
      onError('Connection timed out. Please try again later.');
    } on http.ClientException catch (e) {
      print('Client Exception: $e');
      onError('Connection error: ${e.message}');
    } catch (e) {
      print('General Error: $e');
      onError('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPost = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final String messageText = _controller.text;
    setState(() {
      _messages.add(ChatMessage(
        text: messageText,
        isUser: true,
      ));
      _controller.clear();
    });

    _makeNetworkRequest(
      'generate_post',
      {'context': messageText},
      (result) {
        setState(() {
          _generatedPost = result;
          _messages.add(ChatMessage(
            text: _generatedPost!,
            isUser: false,
            isPost: true,
          ));
        });
      },
      (errorMessage) {
        setState(() {
          _messages.add(ChatMessage(
            text: errorMessage,
            isUser: false,
          ));
        });
      }
    );
  }
  
  Future<void> _regeneratePost() async {
    if (_messages.isEmpty) return;
    
    try {
      final lastUserMessage = _messages.lastWhere((message) => message.isUser).text;
      
      _makeNetworkRequest(
        'regenerate_post',
        {'context': lastUserMessage},
        (result) {
          setState(() {
            _generatedPost = result;
            // Replace the last AI message with the new one
            _messages.removeWhere((message) => !message.isUser && message.isPost);
            _messages.add(ChatMessage(
              text: _generatedPost!,
              isUser: false,
              isPost: true,
            ));
          });
        },
        (errorMessage) {
          setState(() {
            _messages.add(ChatMessage(
              text: errorMessage,
              isUser: false,
            ));
          });
        }
      );
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Error: Unable to find previous message.',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _modifyPost(String action) async {
    if (_messages.isEmpty || _generatedPost == null) return;
    
    try {
      final lastUserMessage = _messages.lastWhere((message) => message.isUser).text;
      
      _makeNetworkRequest(
        'modify_post',
        {
          'context': lastUserMessage,
          'current_post': _generatedPost,
          'action': action,
        },
        (result) {
          setState(() {
            _generatedPost = result;
            // Replace the last AI message with the new one
            _messages.removeWhere((message) => !message.isUser && message.isPost);
            _messages.add(ChatMessage(
              text: _generatedPost!,
              isUser: false,
              isPost: true,
            ));
          });
        },
        (errorMessage) {
          setState(() {
            _messages.add(ChatMessage(
              text: errorMessage,
              isUser: false,
            ));
          });
        }
      );
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Error: Unable to modify post.',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _shareToLinkedIn() async {
    if (_generatedPost == null) return;
    
    // Copy to clipboard first so the user can paste it
    await Clipboard.setData(ClipboardData(text: _generatedPost!));
    
    // Show a snackbar to inform user that content was copied
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post copied to clipboard. You can paste it in LinkedIn after it opens.'),
        duration: Duration(seconds: 4),
      ),
    );
    
    // Use LinkedIn's feed URL to open compose box directly
    final String linkedInComposeUrl = 'https://www.linkedin.com/feed/?shareActive=true';
    
    try {
      // Launch LinkedIn
      final Uri uri = Uri.parse(linkedInComposeUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open LinkedIn')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open LinkedIn: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkedIn Post Generator'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                return _messages[index];
              },
            ),
          ),
          if (_isGeneratingPost)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Share your context to generate a LinkedIn post...',
                      border: InputBorder.none,
                    ),
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isPost;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isPost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.blue[700],
              child: const Icon(Icons.smart_toy, color: Colors.white),
            ),
            const SizedBox(width: 8.0),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: isPost ? () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } : null,
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[700] : (isPost ? Colors.white : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(12.0),
                      border: isPost ? Border.all(color: Colors.blue[300]!) : null,
                      boxShadow: isPost
                          ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isPost) ...[
                          Row(
                            children: [
                              const Text(
                                'Generated LinkedIn Post',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const Spacer(),
                              Tooltip(
                                message: 'Long press to copy',
                                child: Icon(
                                  Icons.content_copy,
                                  color: Colors.blue[300],
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isPost) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.blue),
                                tooltip: 'Regenerate',
                                onPressed: () {
                                  final chatScreenState = context.findAncestorStateOfType<_ChatScreenState>();
                                  chatScreenState?._regeneratePost();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.blue),
                                tooltip: 'Reduce',
                                onPressed: () {
                                  final chatScreenState = context.findAncestorStateOfType<_ChatScreenState>();
                                  chatScreenState?._modifyPost('reduce');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.blue),
                                tooltip: 'Elaborate',
                                onPressed: () {
                                  final chatScreenState = context.findAncestorStateOfType<_ChatScreenState>();
                                  chatScreenState?._modifyPost('elaborate');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              final chatScreenState = context.findAncestorStateOfType<_ChatScreenState>();
                              chatScreenState?._shareToLinkedIn();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.share, color: Colors.blue),
                                SizedBox(width: 4),
                                Text('Share to LinkedIn'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}