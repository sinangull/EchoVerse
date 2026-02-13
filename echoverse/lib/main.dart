import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

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
  final FlutterTts flutterTts = FlutterTts();
  
  bool isLoading = false;
  bool isTyping = false;
  bool isMuted = false;
  bool showVoting = false;
  String? currentTypingRole;
  
  List<dynamic> messages = [];
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage; 

  final List<String> randomTopics = [
    "Pizzaya ananas konur mu?",
    "Yapay zeka dünyayı ele geçirecek mi?",
    "Menemen soğanlı mı olur soğansız mı?",
    "Elon Musk vs Mark Zuckerberg kafes dövüşü?",
    "Matrix'te mi yaşıyoruz?",
    "Kediler aslında uzaylı mı?",
    "Tavuk mu yumurtadan, yumurta mı tavuktan?",
    "iOS mu Android mi?",
    "Marvel mı DC mi?",
    "Lahmacun elle mi yenir çatal bıçakla mı?",
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("tr-TR");
    // iOS ve Android için konuşma bitmesini bekleme ayarı
    await flutterTts.awaitSpeakCompletion(true);
    
    // Ses motorunun hazır olduğundan emin olalım
    await flutterTts.setSpeechRate(0.5); 
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  // --- GELİŞMİŞ SES AYARLARI ---
  Future<void> _speak(String text, String role) async {
    if (isMuted) return;

    double pitch = 1.0;
    double rate = 0.5; // Web'de 0.5 normal hızdır (0.0 - 1.0 arası)

    // Karakterlere göre RADİKAL ses değişiklikleri
    if (role.toLowerCase().contains("grok")) {
      pitch = 0.5; // ÇOK KALIN (Erkek Sesi Gibi)
      rate = 0.6;  // Biraz hızlı
    } else if (role.toLowerCase().contains("chatgpt")) {
      pitch = 1.0; // NORMAL (Haber spikeri gibi)
      rate = 0.45; // Yavaş ve sakin
    } else if (role.toLowerCase().contains("gemini")) {
      pitch = 1.6; // İNCE (Robotik/Kadın sesi gibi)
      rate = 0.55; // Orta hızlı
    }

    await flutterTts.setPitch(pitch);
    await flutterTts.setSpeechRate(rate);
    
    // Konuş ve BİTMESİNİ BEKLE (await burada kritik)
    await flutterTts.speak(text);
  }

  void rollDice() {
    final random = Random();
    String topic = randomTopics[random.nextInt(randomTopics.length)];
    _controller.text = topic;
  }

  void voteWinner(String winner) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("👑 Kazanan seçildi: $winner! Konfetiler patlıyor! 🎉"),
        backgroundColor: Colors.amber,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    String r = role.toLowerCase();
    if (r.contains("grok")) return const Color(0xFFFFFFFF);
    if (r.contains("chatgpt")) return const Color(0xFF10A37F);
    if (r.contains("gemini")) return const Color(0xFF4285F4);
    return Colors.purpleAccent;
  }

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
      showVoting = false;
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

        // --- TAM SENKRON AKIŞ ---
        for (var msg in incomingMessages) {
          if (!mounted) return;

          // 1. Önce "Yazıyor..." göster
          setState(() {
            isTyping = true;
            currentTypingRole = msg['karakter'];
          });
          _scrollToBottom();

          // Kısa bir yapay "düşünme" süresi (Doğallık için)
          await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));

          // 2. Mesaj balonunu ekrana BAS (Ama ses henüz başlamadı)
          setState(() {
            isTyping = false;
            messages.add(msg);
          });
          _scrollToBottom();

          // 3. ŞİMDİ KONUŞ (Ve bitene kadar bekle)
          // Burada await kullanarak kodun aşağı inmesini engelliyoruz.
          if (!isMuted) {
             await _speak(msg['mesaj'], msg['karakter']);
          } else {
             // Ses kapalıysa okuma süresi kadar bekle
             String mesajMetni = msg['mesaj'].toString();
             int okumaSuresi = mesajMetni.length * 60;
             if (okumaSuresi < 2000) okumaSuresi = 2000;
             await Future.delayed(Duration(milliseconds: okumaSuresi));
          }
          
          // Konuşma bittikten sonra diğer karaktere geçmeden önce minik bir nefes
          await Future.delayed(const Duration(milliseconds: 500));
        }

        setState(() {
          showVoting = true;
        });
        _scrollToBottom();

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
        actions: [
          IconButton(
            icon: const Icon(Icons.casino, color: Colors.orangeAccent),
            tooltip: "Rastgele Konu",
            onPressed: (isLoading || isTyping) ? null : rollDice,
          ),
          IconButton(
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: isMuted ? Colors.grey : Colors.greenAccent),
            onPressed: () {
              setState(() {
                isMuted = !isMuted;
                if (isMuted) flutterTts.stop();
              });
            },
          ),
        ],
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
                    itemCount: messages.length + (isTyping ? 1 : 0) + (showVoting ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (showVoting && index == messages.length + (isTyping ? 1 : 0)) {
                        return _buildVotingSection();
                      }
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

  Widget _buildVotingSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            "🏆 BU TARTIŞMAYI KİM KAZANDI?",
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _votingButton("Grok", Colors.white),
              _votingButton("ChatGPT", const Color(0xFF10A37F)),
              _votingButton("Gemini", const Color(0xFF4285F4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _votingButton(String name, Color color) {
    return GestureDetector(
      onTap: () => voteWinner(name),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: 25,
            child: getRoleIcon(name),
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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
            "$currentTypingRole yazıyor...",
            style: TextStyle(color: color, fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ],
      ),
    );
  }
}