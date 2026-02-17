import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui'; // Blur efekti için
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:animate_do/animate_do.dart';     

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
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF6C63FF),
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.orbitron(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            color: const Color(0xFF00E5FF),
            letterSpacing: 2.0
          ),
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

  bool _isDisposed = false;

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

  // --- KARAKTER VERİTABANI ---
  final Map<String, Map<String, dynamic>> characterProfiles = {
    'Grok': {
      'title': 'KAOS ELÇİSİ',
      'desc': 'Elon Musk\'ın dijital ruh ikizi. Woke kültürüne düşman, laf sokma ustası ve sansür tanımaz.',
      'stats': [
        {'label': 'Agresiflik', 'value': 0.95, 'color': Colors.redAccent},
        {'label': 'Mizah', 'value': 0.90, 'color': Colors.orange},
        {'label': 'Filtre', 'value': 0.05, 'color': Colors.grey},
      ]
    },
    'ChatGPT': {
      'title': 'DİPLOMASİ ROBOTU',
      'desc': 'Politik doğruculuğun kalesi. Herkesi sakinleştirmeye çalışan, bazen sıkıcı ama çok bilgili öğretmen.',
      'stats': [
        {'label': 'Bilgi', 'value': 0.98, 'color': Colors.greenAccent},
        {'label': 'Sabır', 'value': 1.0, 'color': Colors.blue},
        {'label': 'Eğlence', 'value': 0.30, 'color': Colors.grey},
      ]
    },
    'Gemini': {
      'title': 'VERİ ANALİSTİ',
      'desc': 'Google ekosisteminin beyni. Duygular yerine istatistiklerle konuşur. Hataları affetmez.',
      'stats': [
        {'label': 'Hız', 'value': 0.95, 'color': Colors.cyanAccent},
        {'label': 'Doğruluk', 'value': 0.92, 'color': Colors.purpleAccent},
        {'label': 'Empati', 'value': 0.10, 'color': Colors.red},
      ]
    },
  };

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
    _isDisposed = true;
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.awaitSpeakCompletion(false);
  }

  Future<void> _speakSafe(String text, String role) async {
    if (isMuted || _isDisposed) return;
    await flutterTts.stop();

    double pitch = 1.0;
    double rate = 0.9; 

    if (role.toLowerCase().contains("grok")) {
      pitch = 0.5; rate = 1.1;  
    } else if (role.toLowerCase().contains("chatgpt")) {
      pitch = 1.0; rate = 0.8;  
    } else if (role.toLowerCase().contains("gemini")) {
      pitch = 2.0; rate = 1.1;  
    }

    await flutterTts.setPitch(pitch);
    await flutterTts.setSpeechRate(rate);
    await Future.delayed(const Duration(milliseconds: 50));

    if (text.isNotEmpty) flutterTts.speak(text);

    int charCount = text.length;
    int safeWaitTime = (charCount * 100 / rate).round(); 
    if (safeWaitTime < 1500) safeWaitTime = 1500;

    int elapsed = 0;
    while (elapsed < safeWaitTime) {
      if (isMuted || _isDisposed) {
        await flutterTts.stop();
        break; 
      }
      await Future.delayed(const Duration(milliseconds: 100));
      elapsed += 100;
    }
  }

  void rollDice() {
    final random = Random();
    String topic = randomTopics[random.nextInt(randomTopics.length)];
    _controller.text = topic;
  }

  // --- PROFİL GÖSTERME FONKSİYONU ---
  void showProfile(String role) {
    // Karakter adını temizle (Emoji vs varsa)
    String cleanRole = "Bilinmeyen";
    if (role.toLowerCase().contains("grok")) cleanRole = "Grok";
    if (role.toLowerCase().contains("chatgpt")) cleanRole = "ChatGPT";
    if (role.toLowerCase().contains("gemini")) cleanRole = "Gemini";

    final profile = characterProfiles[cleanRole];
    final color = getRoleColor(cleanRole);

    if (profile == null) return;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Arka planı bulanıklaştır
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ZoomIn(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101015).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 20)]
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.black,
                      radius: 40,
                      child: getRoleIcon(cleanRole, size: 40),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // İsim ve Unvan
                  Text(cleanRole.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  Text(profile['title'], style: GoogleFonts.roboto(fontSize: 14, color: color, letterSpacing: 4, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  // Açıklama
                  Text(
                    profile['desc'], 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // İstatistik Çubukları
                  ... (profile['stats'] as List).map((stat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(stat['label'], style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            Text("%${(stat['value'] * 100).toInt()}", style: TextStyle(color: stat['color'], fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: stat['value'],
                            minHeight: 6,
                            backgroundColor: Colors.white10,
                            color: stat['color'],
                          ),
                        )
                      ],
                    ),
                  )).toList(),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withOpacity(0.2),
                        side: BorderSide(color: color),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      child: const Text("KAPAT", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void voteWinner(String winner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: Center(child: Text("🏆 KAZANAN 🏆", style: GoogleFonts.orbitron(color: Colors.amber))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: getRoleColor(winner).withOpacity(0.3),
              child: getRoleIcon(winner, size: 40),
            ),
            const SizedBox(height: 20),
            Text(winner.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            const Text("Bu raundun galibi belli oldu!", style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))
        ],
      ),
    );
  }

  Color getRoleColor(String? role) {
    if (role == null) return Colors.grey;
    String r = role.toLowerCase();
    if (r.contains("grok")) return const Color(0xFFFF003C); 
    if (r.contains("chatgpt")) return const Color(0xFF00FF9D); 
    if (r.contains("gemini")) return const Color(0xFF00E5FF); 
    return Colors.purpleAccent;
  }

  Widget getRoleIcon(String? role, {double size = 20}) {
    String r = role?.toLowerCase() ?? "";
    Color color = Colors.white;
    if (r.contains("grok")) return Icon(Icons.code_off, color: color, size: size);
    if (r.contains("chatgpt")) return Icon(Icons.smart_toy, color: color, size: size);
    if (r.contains("gemini")) return Icon(Icons.diamond, color: color, size: size);
    return Icon(Icons.person, color: color, size: size);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutExpo, 
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

        for (var msg in incomingMessages) {
          if (!mounted || _isDisposed) break;

          setState(() {
            isTyping = true;
            currentTypingRole = msg['karakter'];
          });
          _scrollToBottom();

          await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)));

          if (!mounted) break;
          setState(() {
            isTyping = false;
            messages.add(msg);
          });
          _scrollToBottom();

          await _speakSafe(msg['mesaj'], msg['karakter']);
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (mounted && !_isDisposed) {
          setState(() {
            showVoting = true;
          });
          _scrollToBottom();
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
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub, color: Color(0xFF00E5FF)),
            const SizedBox(width: 10),
            Text("ECHOVERSE", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino, color: Colors.orangeAccent),
            tooltip: "Rastgele Konu",
            onPressed: (isLoading || isTyping) ? null : rollDice,
          ),
          IconButton(
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: isMuted ? Colors.grey : const Color(0xFF00FF9D)),
            onPressed: () async {
              setState(() {
                isMuted = !isMuted;
              });
              if (isMuted) {
                await flutterTts.stop();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050505),
              Color(0xFF151520),
              Color(0xFF050505),
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 90), 
            Expanded(
              child: messages.isEmpty && !isLoading && !isTyping
                  ? Center(
                      child: FadeInUp( 
                        child: Opacity(
                          opacity: 0.7,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.psychology, size: 100, color: Colors.grey[800]),
                              const SizedBox(height: 20),
                              Text(
                                "ARENA HAZIR",
                                style: GoogleFonts.orbitron(color: Colors.grey, fontSize: 20, letterSpacing: 2),
                              ),
                              const SizedBox(height: 5),
                              const Text("Kaos başlatmak için bir konu seç...", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: messages.length + (isTyping ? 1 : 0) + (showVoting ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showVoting && index == messages.length + (isTyping ? 1 : 0)) {
                          return FadeInUp(child: _buildVotingSection()); // Oylama butonları da tıklanabilir
                        }
                        if (isTyping && index == messages.length) {
                          return FadeIn(child: _buildTypingIndicator());
                        }
                        final msg = messages[index];
                        final isRight = index % 2 == 0;
                        return isRight 
                          ? FadeInRight(child: _buildMessageBubble(msg)) 
                          : FadeInLeft(child: _buildMessageBubble(msg));
                      },
                    ),
            ),

            if (isLoading)
              LinearProgressIndicator(
                color: const Color(0xFF00E5FF), 
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101015).withOpacity(0.9),
                border: const Border(top: BorderSide(color: Colors.white10)),
                boxShadow: [
                   BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.1), blurRadius: 20, spreadRadius: 1),
                ]
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
                        icon: Icon(Icons.add_photo_alternate, color: _selectedImage != null ? const Color(0xFF00FF9D) : Colors.grey),
                        onPressed: _pickImage,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: GoogleFonts.roboto(color: Colors.white),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (value) => tartismaBaslat(),
                          decoration: InputDecoration(
                            hintText: _selectedImage != null ? "Görseli yorumlasınlar..." : "Tartışma başlat...",
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF1E1E24),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)]),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                             BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
                          ]
                        ),
                        child: IconButton(
                          icon: (isLoading) 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: (isLoading || isTyping) ? null : tartismaBaslat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotingSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 20),
        ]
      ),
      child: Column(
        children: [
          Text(
            "🏆 KAZANANI SEÇ",
            style: GoogleFonts.orbitron(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _votingButton("Grok"),
              _votingButton("ChatGPT"),
              _votingButton("Gemini"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _votingButton(String name) {
    // Burada da profile gitmek istersek diye GestureDetector'ı koruyabiliriz ama 
    // şu an oylama yaptığı için sadece voteWinner'a gidiyor.
    Color color = getRoleColor(name);
    return GestureDetector(
      onTap: () => voteWinner(name),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
              ]
            ),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              radius: 28,
              child: getRoleIcon(name, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: GoogleFonts.orbitron(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg) {
    final role = msg['karakter'] ?? "Bilinmeyen";
    final text = msg['mesaj'] ?? "...";
    final color = getRoleColor(role);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TIKLANABİLİR AVATAR (PROFİLİ AÇAR)
          GestureDetector(
            onTap: () => showProfile(role), // <-- İŞTE SİHİR BURADA
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 1)
                ]
              ),
              child: CircleAvatar(
                backgroundColor: Colors.black,
                radius: 22,
                child: getRoleIcon(role),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                   onTap: () => showProfile(role), // İsime tıklayınca da açsın
                   child: Text(
                    role.toUpperCase(), 
                    style: GoogleFonts.orbitron(
                      color: color, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      letterSpacing: 1
                    )
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24).withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(4, 4),
                      )
                    ]
                  ),
                  child: Text(
                    text, 
                    style: GoogleFonts.roboto(color: const Color(0xFFE0E0E0), fontSize: 16, height: 1.5),
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
      padding: const EdgeInsets.only(bottom: 16, left: 60),
      child: Row(
        children: [
          SizedBox(
            width: 15, 
            height: 15, 
            child: CircularProgressIndicator(strokeWidth: 2, color: color)
          ),
          const SizedBox(width: 10),
          Text(
            "$currentTypingRole veri işliyor...",
            style: GoogleFonts.roboto(color: color.withOpacity(0.8), fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ],
      ),
    );
  }
}