import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Rastgelelik ve matematik işlemleri için
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
      title: 'EchoVerse',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: const Color(0xFF6C63FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
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

  // --- Otomatik Kaydırma (Daha Agresif) ---
  void _scrollToBottom() {
    // Biraz gecikmeli çalıştırıyoruz ki UI çizilsin, sonra kaysın
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

        // --- GELİŞMİŞ AKIŞ DÖNGÜSÜ ---
        for (var msg in incomingMessages) {
          if (!mounted) return;

          // 1. Yazıyor animasyonunu başlat
          setState(() {
            isTyping = true;
            currentTypingRole = msg['karakter'];
          });
          _scrollToBottom(); // Yazıyor balonu görünsün

          // 2. AKILLI BEKLEME SÜRESİ
          // Mesajın uzunluğuna göre süre belirliyoruz.
          // Karakter sayısı * 50 milisaniye. 
          // Ama en az 1.5 saniye, en fazla 4 saniye beklesin.
          String mesajMetni = msg['mesaj'].toString();
          int beklemeSuresi = mesajMetni.length * 50;
          
          if (beklemeSuresi < 1500) beklemeSuresi = 1500;
          if (beklemeSuresi > 4000) beklemeSuresi = 4000;

          await Future.delayed(Duration(milliseconds: beklemeSuresi));

          // 3. Mesajı ekle
          if (!mounted) return;
          setState(() {
            isTyping = false;
            messages.add(msg);
          });
          _scrollToBottom(); // Yeni mesaj görünsün
          
          // Mesajlar arasında çok minik bir "okuma payı" da bırakabiliriz (Opsiyonel)
          await Future.delayed(const Duration(milliseconds: 500)); 
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

  Color getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    if (role.contains("Destekçi")) return Colors.greenAccent;
    if (role.contains("Karşıt")) return Colors.redAccent;
    if (role.contains("Kaotik")) return Colors.orangeAccent;
    return Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EchoVerse 🔥", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !isLoading && !isTyping
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 80, color: Colors.grey[800]),
                        const SizedBox(height: 10),
                        const Text("Ortaya bir laf at...", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
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
            const LinearProgressIndicator(color: Color(0xFF6C63FF), backgroundColor: Colors.transparent),

          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                if (_selectedImage != null)
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: kIsWeb 
                            ? Image.network(_selectedImage!.path) 
                            : Image.file(File(_selectedImage!.path)),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        )
                      ],
                    ),
                  ),

                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.photo_library, color: _selectedImage != null ? Colors.greenAccent : Colors.grey),
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
                          hintText: _selectedImage != null ? "Resim hakkında yaz..." : "Mesaj gönder...",
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      mini: true,
                      onPressed: (isLoading || isTyping) ? null : tartismaBaslat,
                      backgroundColor: (isLoading || isTyping) ? Colors.grey : const Color(0xFF6C63FF),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
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
    final role = msg['karakter'];
    final text = msg['mesaj'];
    final color = getRoleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Text(role[0], style: TextStyle(color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12).copyWith(topLeft: Radius.zero),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final color = getRoleColor(currentTypingRole);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
           CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: const Icon(Icons.more_horiz, size: 20, color: Colors.white54),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20).copyWith(topLeft: Radius.zero),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$currentTypingRole yazıyor", 
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontStyle: FontStyle.italic)
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 15, 
                  height: 15, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}