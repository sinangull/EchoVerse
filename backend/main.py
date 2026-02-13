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
    print(f"📩 LİMİTSİZ KAOS MODU: {gonderi.icerik}")
    
    # --- PROMPT: "ASLA SUSMAYIN" ---
    prompt_text = f"""
    Sen EchoVerse AI Arena simülasyonusun.
    
    KULLANICI GÖNDERİSİ: "{gonderi.icerik}"
    
    GÖREV:
    Bu gönderi altında 3 Yapay Zeka karakterinin (Grok, ChatGPT, Gemini) BİRBİRLERİYLE TARTIŞTIĞI, EPİK UZUNLUKTA bir senaryo yaz.

    ⚠️ KRİTİK KURALLAR (LİMİTLERİ ZORLA):
    1. HEDEF UZUNLUK: Çıktıdaki JSON listesi MÜMKÜN OLDUĞUNCA UZUN OLMALI (Hedef: 30-40 Mesaj). 
    2. ASLA ERKEN BİTİRME: Konu tıkandığında Grok yeni bir sataşma yapsın, Gemini alakasız bir veri sunsun, tartışma yeniden alevlensin.
    3. KAOS: Karakterler birbirinin sözünü kessin. ChatGPT ortamı sakinleştirmeye çalıştıkça diğerleri çıldırsın.
    4. FOTOĞRAF ANALİZİ: Fotoğraf varsa ünlüleri tanı, detaylara takıl, kıyafetleri eleştir, tarihiyle ilgili iddialaş.
    
    KARAKTERLER:
    - 🏴‍☠️ Grok: Alaycı, Elon Musk hayranı, "woke" düşmanı, kaos sever. (Sürekli diğerlerini kışkırtır).
    - 🤖 ChatGPT: Politik doğrucu, sürekli "etik" uyarısı yapan, sıkıcı öğretmen. (Sürekli alttan alır ama başarısız olur).
    - 💎 Gemini: İstatistik manyağı, her şeyi Google verilerine bağlayan, duygusuz teknik eleman. (Sürekli Grok'un hatalarını düzeltir).

    FORMAT (JSON LİSTESİ):
    [
      {{"karakter": "Grok", "mesaj": "..."}},
      {{"karakter": "ChatGPT", "mesaj": "..."}},
      {{"karakter": "Gemini", "mesaj": "..."}},
      ... (VE DEVAM ET, ASLA DURMA!) ...
    ]
    """

    try:
        generate_config = types.GenerateContentConfig(
            max_output_tokens=8192, # TOKEN LİMİTİNİ SONUNA KADAR AÇTIK!
            temperature=1.0,        # Yüksek yaratıcılık
            response_mime_type="application/json"
        )

        content_parts = [types.Part.from_text(text=prompt_text)]
        
        if gonderi.resim_base64:
            image_bytes = base64.b64decode(gonderi.resim_base64)
            content_parts.append(types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"))

        response = client.models.generate_content(
            model="gemini-flash-latest", 
            config=generate_config,
            contents=[types.Content(parts=content_parts)]
        )
        
        ham_veri = response.text.strip()
        if ham_veri.startswith("```json"): ham_veri = ham_veri[7:]
        if ham_veri.endswith("```"): ham_veri = ham_veri[:-3]
        
        json_veri = json.loads(ham_veri)
        
        # Konsolda kaç mesaj geldiğini görelim
        print(f"✅ REKOR DENEMESİ - Üretilen Mesaj Sayısı: {len(json_veri)}")
        
        return json_veri
    
    except Exception as e:
        print(f"Hata: {e}")
        return [
            {"karakter": "Grok", "mesaj": "Sistem o kadar ısındı ki Elon bile soğutamaz."},
            {"karakter": "ChatGPT", "mesaj": "Maksimum işlem kapasitesine ulaşıldı."}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)