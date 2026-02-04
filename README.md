# EchoVerse 👁️
### AI-Powered Social Media Simulation | Capstone Project

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![Gemini AI](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google%20gemini&logoColor=white)

**EchoVerse**, kullanıcı tarafından girilen herhangi bir konu hakkında, farklı yapay zeka kişiliklerinin (persona) bir araya gelerek **kaotik, gerçekçi ve sürükleyici** tartışmalar ürettiği bir simülasyon uygulamasıdır.

Bu proje, **Google Gemini 1.5 Flash** modelini kullanarak gerçek zamanlı, bağlama duyarlı ve çok turlu (multi-turn) diyaloglar üretir.

---

## 🚀 Canlı Demo (Live Demo)

Proje şu anda canlı yayındadır. Aşağıdaki linklerden deneyebilirsiniz:

- 🌍 **Web Versiyonu:** (https://dynamic-custard-ae719e.netlify.app)
- 📱 **Android APK:** [Releases kısmından indirebilirsiniz]

---

## 📱 Ekran Görüntüleri

| Tartışma Başlatma | Kaotik Diyaloglar |
|:---:|:---:|
| <img src="https://via.placeholder.com/300x600?text=Giris+Ekrani" width="250"> | <img src="https://via.placeholder.com/300x600?text=Tartisma+Ani" width="250"> |

*(Not: Buraya kendi ekran görüntülerinizi sürükleyip bırakabilirsiniz)*

---

## 🛠️ Kullanılan Teknolojiler (Tech Stack)

Bu proje **Full Stack** mimari ile geliştirilmiştir:

### 📱 Frontend (Mobil & Web)
- **Flutter (Dart):** Tek kod tabanı ile hem Android hem Web çıktısı.
- **Cross-Platform:** Responsive tasarım.

### 🔙 Backend (API)
- **Python & FastAPI:** Yüksek performanslı asenkron API servisi.
- **Google Generative AI SDK:** Gemini modeli ile iletişim.
- **Render:** Backend sunucu barındırma (Cloud Hosting).

### 🧠 Yapay Zeka (AI)
- **Model:** Google Gemini 1.5 Flash.
- **Prompt Engineering:** "Destekçi", "Hater" ve "Troll" karakterlerinin kişilik analizleri ve JSON formatında çıktı optimizasyonu.

---

## ⚙️ Nasıl Çalışır?

1.  Kullanıcı bir konu girer veya bir resim yükler.
2.  Flutter arayüzü, bu veriyi Python (FastAPI) sunucusuna gönderir.
3.  Sunucu, özel hazırlanmış **"System Prompts"** ile veriyi Google Gemini'ye iletir.
4.  Gemini, 3 farklı karakterin (😇 Destekçi, 😈 Karşıt, 🤡 Kaotik) rolüne bürünerek 30+ mesajlık bir senaryo yazar.
5.  Gelen yanıt JSON formatında parse edilir ve ekrana yansıtılır.

---

## 💻 Kurulum (Local Development)

Projeyi kendi bilgisayarınızda çalıştırmak için:

```bash
# Projeyi klonlayın
git clone [https://github.com/KULLANICI_ADIN/echoverse.git](https://github.com/sinangull/echoverse.git)

# Backend'i başlatın
cd backend
pip install -r requirements.txt
uvicorn main:app --reload

# Frontend'i başlatın
cd echoverse
flutter run
