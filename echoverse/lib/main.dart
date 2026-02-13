import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Rastgelelik için ekledik
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const EchoVerseApp());
}

class EchoVerseApp extends StatelessWidget {
  const EchoVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EchoVerse AI Arena',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: const Color(0xFF6C63FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool isLoading = false;
  bool isTyping = false;
  String? currentTypingRole;
  
  List<dynamic> messages = [];
  
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage; 

  // --- Yardımcı: Karakter Renkleri ---
  Color getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    String r = role.toLowerCase();
    
    if (r.contains("grok")) return const Color(0xFFFFFFFF);
    if (r.contains("chatgpt")) return const Color(0xFF10A37F);
    if (r.contains("gemini")) return const Color(0xFF4285F4);
    
    if (r.contains("destekçi")) return Colors.greenAccent;
    if (r.contains("karşıt")) return Colors.redAccent;
    return Colors.purpleAccent;
  }

  // --- Yardımcı: Karakter İkonları ---
  Widget getRoleIcon(String? role) {
    String r = role?.toLowerCase() ?? "";
    if (r.contains("grok")) return const Icon(Icons.close, color: Colors.black, size: 20);
    if (r.contains("chatgpt")) return const Icon(Icons.bolt, color: Colors.white, size: 20);
    if (r.contains("gemini")) return const Icon(Icons.auto_awesome, color: Colors.white, size: 20);
    return const Icon(Icons.person, color: Colors.white, size: 20);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> tartismaBaslat() async {
    final String promptText = _controller.text;
    final XFile? imageToSend = _selectedImage;

    if (promptText.isEmpty && imageToSend == null) return;

    setState(() {
      isLoading = true;
      messages = [];
      _controller.clear();   
      _selectedImage = null; 
    });
    
    FocusScope.of(context).unfocus();

    final url = Uri.parse('https://echoverse-api-8r8z.onrender.com/tartisma-baslat');

    try {
      String? base64Image;
      if (imageToSend != null) {
        final bytes = await imageToSend.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'icerik': promptText.isEmpty ? "Bu resim hakkında ne düşünüyorsunuz?" : promptText,
          'resim_base64': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final List<dynamic> incomingMessages = jsonDecode(decodedBody);

        if (!mounted) return;
        setState(() {
          isLoading = false;
        });

        // --- SİNEMATİK AKIŞ DÖNGÜSÜ (YAVAŞLATILMIŞ VERSİYON) ---
        for (var msg in incomingMessages) {
          if (!mounted) return;

          setState(() {
            isTyping = true;
            currentTypingRole = msg['karakter'];
          });
          _scrollToBottom();

          // --- YENİ HIZ AYARI BURADA ---
          String mesajMetni = msg['mesaj'].toString();
          
          // Karakter başına 60ms (Eskiden 40ms idi) -> Daha yavaş okuma
          int beklemeSuresi = mesajMetni.length * 60; 
          
          // Rastgelelik ekle (Her mesaj robot gibi aynı hızda gelmesin)
          // 0 ile 1000ms arasında rastgele bir süre ekliyoruz.
          beklemeSuresi += Random().nextInt(1000);

          // Minimum bekleme: 2 saniye (Okumaya vakit kalsın)
          if (beklemeSuresi < 2000) beklemeSuresi = 2000;
          
          // Maksimum bekleme: 6 saniye (Çok da baymasın)
          if (beklemeSuresi > 6000) beklemeSuresi = 6000;

          await Future.delayed(Duration(milliseconds: beklemeSuresi));

          if (!mounted) return;
          setState(() {
            isTyping = false;
            messages.add(msg);
          });
          _scrollToBottom();
          
          // İki mesaj arasında da minik bir nefes payı (500ms ile 1000ms arası)
          await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500))); 
        }

      } else {
        if (!mounted) return;
        showError("Sunucu Hatası: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      showError("Bağlantı Hatası: $e");
      setState(() => isLoading = false);
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hub, color: Colors.white),
            SizedBox(width: 8),
            Text("AI ARENA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !isLoading && !isTyping
                ? Center(
                    child: Opacity(
                      opacity: 0.5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.psychology, size: 100, color: Colors.grey[800]),
                          const SizedBox(height: 20),
                          const Text(
                            "Grok vs ChatGPT vs Gemini",
                            style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          const Text("Kaos başlatmak için bir şeyler yaz...", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isTyping && index == messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(messages[index]);
                    },
                  ),
          ),

          if (isLoading)
            const LinearProgressIndicator(
              color: Color(0xFF6C63FF), 
              backgroundColor: Colors.transparent,
              minHeight: 2,
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              children: [
                if (_selectedImage != null)
                  Container(
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              kIsWeb 
                                ? Image.network(_selectedImage!.path) 
                                : Image.file(File(_selectedImage!.path)),
                              Positioned.fill(
                                child: Container(color: Colors.black26),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => setState(() => _selectedImage = null),
                        )
                      ],
                    ),
                  ),

                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_photo_alternate, color: _selectedImage != null ? Colors.greenAccent : Colors.grey),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) => tartismaBaslat(),
                        decoration: InputDecoration(
                          hintText: _selectedImage != null ? "Görseli yorumlasınlar..." : "Bir tartışma başlat...",
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      mini: true,
                      elevation: 0,
                      onPressed: (isLoading || isTyping) ? null : tartismaBaslat,
                      backgroundColor: (isLoading || isTyping) ? Colors.grey[800] : const Color(0xFF6C63FF),
                      child: (isLoading) 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.arrow_upward, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg) {
    final role = msg['karakter'] ?? "Bilinmeyen";
    final text = msg['mesaj'] ?? "...";
    final color = getRoleColor(role);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: role.toLowerCase().contains("grok") ? Colors.white : color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(child: getRoleIcon(role)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role, 
                  style: TextStyle(
                    color: color, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    letterSpacing: 0.5
                  )
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      )
                    ]
                  ),
                  child: Text(
                    text, 
                    style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final color = getRoleColor(currentTypingRole);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
             child: Center(child: getRoleIcon(currentTypingRole)),
          ),
          Text(
            "$currentTypingRole yanıtlıyor...",
            style: TextStyle(color: color, fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ],
      ),
    );
  }
}