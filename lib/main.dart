import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'services/llm_controller.dart';
import 'services/ble_mesh_service.dart';
import 'models/triage_payload.dart';
import 'screens/community_radar_screen.dart';

void main() {
  runApp(const RelayZeroApp());
}

class RelayZeroApp extends StatelessWidget {
  const RelayZeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relay Zero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final BleMeshService _bleService = BleMeshService();
  final LLMController _llmController = LLMController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Continuously scan for other mesh payloads in the background
    _bleService.startScanning();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        elevation: 0,
        title: const Text("RELAY ZERO", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 20, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.white.withOpacity(0.1), height: 1.0),
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF161622),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.cell_tower, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text("Relay Zero Mesh", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.tealAccent),
              title: const Text('Survival AI Chat', style: TextStyle(color: Colors.white)),
              selected: _currentIndex == 0,
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.radar, color: Colors.redAccent),
              title: const Text('Community Radar', style: TextStyle(color: Colors.white)),
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          VictimNodeScreen(bleService: _bleService, llmController: _llmController),
          CommunityRadarScreen(interceptedPayloads: _bleService.interceptedPayloads),
        ],
      ),
    );
  }
}

enum MessageType { user, triage, expert, system }

class ChatMessage {
  final MessageType type;
  final String text;
  final TriagePayload? payload;

  ChatMessage({required this.type, this.text = "", this.payload});
}

class VictimNodeScreen extends StatefulWidget {
  final BleMeshService bleService;
  final LLMController llmController;

  const VictimNodeScreen({super.key, required this.bleService, required this.llmController});

  @override
  State<VictimNodeScreen> createState() => _VictimNodeScreenState();
}

class _VictimNodeScreenState extends State<VictimNodeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isProcessing = false;
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      type: MessageType.system, 
      text: "Gemma 4 Offline AI initialized. Type your emergency situation below to broadcast an SOS and receive immediate survival advice."
    ));
  }

  Future<void> _handleSend() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(type: MessageType.user, text: input));
      _isProcessing = true;
    });
    
    _textController.clear();
    _scrollToBottom();

    // 1. Process SOS Payload
    final payload = await widget.llmController.processSOS(input);

    if (payload != null) {
      // Broadcast via BLE
      try {
        widget.bleService.startBroadcasting(payload.toJsonString());
      } catch (e) {
        print("BLE Mock mode: \$e");
      }
      
      setState(() {
        _messages.add(ChatMessage(type: MessageType.triage, payload: payload));
      });
      _scrollToBottom();

      // 2. Query Survival Expert
      final response = await widget.llmController.querySurvivalGuide(input);
      setState(() {
        _messages.add(ChatMessage(type: MessageType.expert, text: response));
      });
      _scrollToBottom();
      
    } else {
      setState(() {
        _messages.add(ChatMessage(type: MessageType.system, text: "Error parsing SOS. Please try again."));
      });
      _scrollToBottom();
    }

    setState(() {
      _isProcessing = false;
    });
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.type == MessageType.system) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    if (message.type == MessageType.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    }

    if (message.type == MessageType.expert) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withOpacity(0.05),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 16),
                  const SizedBox(width: 8),
                  Text("SURVIVAL AI", style: TextStyle(color: Colors.tealAccent.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
            ],
          ),
        ),
      );
    }

    if (message.type == MessageType.triage && message.payload != null) {
      final p = message.payload!;
      final threatColor = p.triageLevel == 'R' ? Colors.redAccent : p.triageLevel == 'Y' ? Colors.orangeAccent : Colors.greenAccent;
      
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: threatColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: threatColor.withOpacity(0.5)),
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cell_tower, color: threatColor, size: 16),
                    const SizedBox(width: 8),
                    Text("BROADCASTED TO MESH", style: TextStyle(color: threatColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: threatColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("STATUS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            Text(p.triageLevel == 'R' ? 'CRITICAL' : p.triageLevel == 'Y' ? 'URGENT' : 'MINOR', style: TextStyle(color: threatColor, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("PEOPLE", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            Text("${p.headcount}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("HAZARD", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            Text(p.primaryHazard.toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (p.medicalFlag) ...[
                        const Divider(color: Colors.white10),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("MEDICAL", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                              Text("REQUIRED", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0F),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24, height: 24, 
                child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2)
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Describe emergency or ask expert...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isProcessing ? null : _handleSend,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
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


