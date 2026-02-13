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

API_KEY = os.environ.get("GOOGLE_API_KEY")

# API Anahtarı kontrolü
if not API_KEY:
    print("UYARI: API Anahtarı bulunamadı! Environment Variable kontrol edin.")

# CORS Ayarları
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

client = genai.Client(api_key=API_KEY)

class Gonderi(BaseModel):
    icerik: str
    resim_base64: str | None = None 

@app.post("/tartisma-baslat")
def tartisma_yarat(gonderi: Gonderi):
    print(f"📩 SAĞLAM MOD (1.5 Flash): {gonderi.icerik}")
    
    # --- PROMPT: AI ARENA & MAGAZİN ---
    prompt_text = f"""
    Sen EchoVerse sosyal medya simülasyonusun.
    
    KULLANICI GÖNDERİSİ: "{gonderi.icerik}"
    
    ÖZEL GÖREV (FOTOĞRAF ANALİZİ):
    Eğer bir fotoğraf varsa:
    1. Fotoğraftaki kişilerin kim olduğunu (Türk ünlüler, oyuncular, fenomenler dahil) tespit etmeye çalış.
    2. Eğer tanırsan İSİMLERİNİ KULLANARAK yorum yap. (Örn: "Bu Oğuzhan Koç değil mi?")
    3. Fotoğraf eskiyse nostalji yap.
    
    KARAKTERLER:
    1. 🏴‍☠️ Grok (xAI): Magazinel, alaycı, sivri dilli. (Örn: "Zeynep Koçak ile Oğuzhan Koç mu? O zamanlar iyiydi...")
    2. 🤖 ChatGPT (OpenAI): Diplomatik, tarihsel bilgi veren. (Örn: "Bu fotoğraf muhtemelen BKM Mutfak dönemine ait.")
    3. 💎 Gemini (Google): Veri odaklı, detaycı. (Örn: "Görsel analize göre yıl 2010 civarı.")

    İSTENEN ÇIKTI (SADECE JSON LİSTESİ):
    [
      {{"karakter": "Grok", "mesaj": "..."}},
      {{"karakter": "ChatGPT", "mesaj": "..."}},
      {{"karakter": "Gemini", "mesaj": "..."}}
    ]
    """

    try:
        generate_config = types.GenerateContentConfig(
            max_output_tokens=2000, 
            temperature=0.8,
            response_mime_type="application/json"
        )

        content_parts = [types.Part.from_text(text=prompt_text)]
        
        if gonderi.resim_base64:
            image_bytes = base64.b64decode(gonderi.resim_base64)
            content_parts.append(types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"))

        # --- İŞTE O SAĞLAM MODEL: gemini-1.5-flash ---
        # (gemini-flash-latest yerine direkt sürüm adını yazmak daha garantidir)
        response = client.models.generate_content(
            model="gemini-flash-latest", 
            config=generate_config,
            contents=[types.Content(parts=content_parts)]
        )
        
        ham_veri = response.text.strip()
        if ham_veri.startswith("```json"): ham_veri = ham_veri[7:]
        if ham_veri.endswith("```"): ham_veri = ham_veri[:-3]
            
        return json.loads(ham_veri)
    
    except Exception as e:
        print(f"Hata: {e}")
        return [
            {"karakter": "Grok", "mesaj": "Sistemde ufak bir arıza var ama ben buradayım!"},
            {"karakter": "ChatGPT", "mesaj": "Sunucularımız şu an yoğun, lütfen tekrar deneyin."},
            {"karakter": "Gemini", "mesaj": "Bağlantı hatası tespit edildi. (Kod: 1.5)"}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)