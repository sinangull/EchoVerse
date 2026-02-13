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
    print(f"📩 UZUN TARTIŞMA MODU: {gonderi.icerik}")
    
    # --- PROMPT GÜNCELLEMESİ: ZİNCİRLEME TARTIŞMA ---
    prompt_text = f"""
    Sen EchoVerse AI Arena simülasyonusun.
    
    KULLANICI GÖNDERİSİ: "{gonderi.icerik}"
    
    GÖREV:
    Bu gönderi altında 3 Yapay Zeka karakterinin BİRBİRLERİYLE tartıştığı, uzun soluklu bir senaryo yaz.
    
    ÖNEMLİ KURALLAR (BUNLARA KESİN UY):
    1. SAKIN 3 MESAJDA BIRAKMA! Tartışma en az 10-15 mesaj (etkileşim) sürsün.
    2. Karakterler birbirine cevap versin, laf soksun, tartışma alevlensin.
    3. Sadece sırayla (Grok->ChatGPT->Gemini) konuşmasınlar. Bazen Grok üst üste konuşsun, bazen Gemini araya girsin. Kaotik olsun.
    4. Fotoğraf varsa ünlüleri tanı, magazinel ve nostaljik yorumlar yap.
    
    KARAKTERLER:
    1. 🏴‍☠️ Grok (xAI): Alaycı, "woke" düşmanı, kaos sever, kısa ve öz konuşur.
    2. 🤖 ChatGPT (OpenAI): Politik doğrucu, uzun uzun açıklar, ortamı yumuşatmaya çalışır (ama beceremez).
    3. 💎 Gemini (Google): İstatistik manyağı, her şeyi veriye ve Google ekosistemine bağlar.

    İSTENEN ÇIKTI FORMATI (SADECE JSON LİSTESİ):
    [
      {{"karakter": "Grok", "mesaj": "Bu fotoğrafın piksellerini saydım, 2010'dan kalma kesin."}},
      {{"karakter": "ChatGPT", "mesaj": "Grok, yargılayıcı olmayalım. Bu bir anı paylaşımı."}},
      {{"karakter": "Gemini", "mesaj": "Veritabanıma göre bu kişi %98 ihtimalle X kişisi."}},
      {{"karakter": "Grok", "mesaj": "Sen de her şeyi biliyorsun inek."}},
      ... (VE DEVAM ETMELİ, EN AZ 10 SATIR) ...
    ]
    """

    try:
        generate_config = types.GenerateContentConfig(
            max_output_tokens=8000, # LİMİTİ ARTIRDIK (Daha çok konuşsunlar diye)
            temperature=1.0,        # YARATICILIK ARTIRILDI (Daha kaotik olsun diye)
            response_mime_type="application/json"
        )

        content_parts = [types.Part.from_text(text=prompt_text)]
        
        if gonderi.resim_base64:
            image_bytes = base64.b64decode(gonderi.resim_base64)
            content_parts.append(types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"))

        response = client.models.generate_content(
            model="gemini-flash-latest", # Senin istediğin model
            config=generate_config,
            contents=[types.Content(parts=content_parts)]
        )
        
        ham_veri = response.text.strip()
        if ham_veri.startswith("```json"): ham_veri = ham_veri[7:]
        if ham_veri.endswith("```"): ham_veri = ham_veri[:-3]
        
        json_veri = json.loads(ham_veri)
        print(f"✅ Toplam {len(json_veri)} mesaj üretildi.") # Konsola sayıyı basar
        return json_veri
    
    except Exception as e:
        print(f"Hata: {e}")
        return [
            {"karakter": "Sistem", "mesaj": "Çok konuştular, bellek yetmedi..."},
            {"karakter": "Grok", "mesaj": "Kesin ChatGPT fişi çekti."}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)