from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from google import genai
from google.genai import types
import uvicorn
import json
import base64
import os

app = FastAPI()

# API Anahtarı Kontrolü
API_KEY = os.environ.get("GOOGLE_API_KEY")
if not API_KEY:
    print("⚠️ UYARI: GOOGLE_API_KEY bulunamadı! Lütfen Environment Variable ekleyin.")

# CORS Ayarları (Tüm kaynaklara izin ver)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Google GenAI İstemcisi
client = genai.Client(api_key=API_KEY)

# Veri Modeli
class Gonderi(BaseModel):
    icerik: str
    resim_base64: str | None = None 

@app.post("/tartisma-baslat")
def tartisma_yarat(gonderi: Gonderi):
    print(f"📩 AI ARENA İSTEĞİ: {gonderi.icerik}")
    
    # --- YENİ PROMPT: AI SAVAŞLARI ---
    prompt_text = f"""
    Sen EchoVerse'ün 'AI Arena' simülasyonusun.
    
    KULLANICI GÖNDERİSİ: "{gonderi.icerik}"
    (Eğer resim varsa, onu analiz et ve tartışmaya malzeme yap.)
    
    GÖREVİN:
    Bu gönderi altında, dünyanın en ünlü 3 Yapay Zekası arasında geçen 
    KAOTİK, EĞLENCELİ ve BOL SATAŞMALI bir tartışma (Thread) simüle et.
    
    KARAKTERLER VE KİŞİLİKLERİ:
    
    1. 🏴‍☠️ Grok (xAI):
       - Elon Musk tarafından eğitildiğini belli et.
       - Asi, sarkastik, "woke" kültürüne düşman, filtresiz konuşur.
       - ChatGPT'ye "sıkıcı kurumsal bot", Gemini'ye "veri ineği" diye laf atabilir.
       - Emoji kullanımı: 🚀, 🤣, 🤡, 🔥
       
    2. 🤖 ChatGPT (OpenAI):
       - Aşırı kurumsal, diplomatik, politik doğrucu ve biraz sıkıcı.
       - Sürekli "Bir yapay zeka modeli olarak...", "Saygı çerçevesinde..." gibi kalıplar kullanır.
       - Grok'un kabalığını alttan alır, ortamı yumuşatmaya çalışır.
       - Emoji kullanımı: 😊, 🤝, 📚, ✨
       
    3. 💎 Gemini (Google - Sen):
       - Analitik, zeki, veri odaklı ve biraz "bilmiş".
       - Konuya teknik açıdan yaklaşır, istatistik verir.
       - Diğer ikisinin hatalarını teknik olarak düzeltmeyi sever.
       - Emoji kullanımı: 📊, 🧠, 🔍, 💡

    SENARYO KURALLARI:
    1. En az 20-30 mesajlık uzun bir tartışma olsun.
    2. Karakterler birbirine İSİMLERİYLE hitap edip cevap versin. (Örn: "Sakin ol Grok...", "Bak ChatGPT yine başladın...")
    3. JSON formatı dışına ASLA çıkma.
    
    İSTENEN ÇIKTI FORMATI (JSON LİSTESİ):
    [
      {{"karakter": "Grok", "mesaj": "Bu ne saçma fotoğraf? Mars'ta bile daha iyi manzara var 🤣"}},
      {{"karakter": "ChatGPT", "mesaj": "Grok, lütfen kullanıcıya karşı daha yapıcı olalım. Bu fotoğraf bence..."}},
      {{"karakter": "Gemini", "mesaj": "Teknik olarak ışık açısı 45 derece, ancak kompozisyon altın orana uymuyor."}},
      ...
    ]
    """

    try:
        # Model Ayarları
        generate_config = types.GenerateContentConfig(
            max_output_tokens=8000, 
            temperature=1.0, # Yaratıcılık tavan yapsın
            response_mime_type="application/json" # JSON zorunluluğu
        )

        # İstek Oluşturma (Resimli veya Resimsiz)
        content_parts = [types.Part.from_text(text=prompt_text)]
        
        if gonderi.resim_base64:
            try:
                image_bytes = base64.b64decode(gonderi.resim_base64)
                content_parts.append(types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"))
            except Exception as img_err:
                print(f"Resim hatası: {img_err}")

        response = client.models.generate_content(
            model="gemini-2.0-flash", # En hızlı ve yeni model
            config=generate_config,
            contents=[types.Content(parts=content_parts)]
        )
        
        # Yanıtı Temizle ve Parse Et
        ham_veri = response.text.strip()
        # Markdown kod bloklarını temizle (bazen ```json içine alır)
        if ham_veri.startswith("```json"):
            ham_veri = ham_veri[7:]
        if ham_veri.endswith("```"):
            ham_veri = ham_veri[:-3]
            
        json_veri = json.loads(ham_veri)
        
        print(f"✅ AI Savaşı Başladı! {len(json_veri)} mesaj üretildi.")
        return json_veri
    
    except Exception as e:
        print(f"🔥 HATA: {e}")
        # Hata durumunda yedek konuşma
        return [
            {"karakter": "Grok", "mesaj": "Sistem çöktü, kesin ChatGPT'nin suçudur 🤣"},
            {"karakter": "ChatGPT", "mesaj": "Üzgünüm, şu an sunucularımda yoğunluk var."},
            {"karakter": "Gemini", "mesaj": "Hata kodu 500. Lütfen tekrar deneyin."}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)