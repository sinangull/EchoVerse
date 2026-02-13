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

if not API_KEY:
    print("UYARI: API Anahtarı yok!")

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
    print(f"📩 MAG: {gonderi.icerik}")
    
    # --- GÜNCELLENMİŞ PROMPT: MAGAZİN VE KİMLİK TESPİTİ ODAKLI ---
    prompt_text = f"""
    Sen EchoVerse AI Arena simülasyonusun.
    
    KULLANICI GÖNDERİSİ: "{gonderi.icerik}"
    
    ÖZEL GÖREV (FOTOĞRAF ANALİZİ):
    Eğer bir fotoğraf varsa:
    1. Fotoğraftaki kişilerin kim olduğunu (Türk ünlüler, oyuncular, şarkıcılar dahil) tespit etmeye çalış.
    2. "Oğuzhan Koç", "Zeynep Koçak", "Eser Yenenler" gibi isimleri tanırsan MUTLAKA kullan.
    3. Fotoğraf eski bile olsa bağlamdan çıkarmaya çalış.
    
    TARTIŞMA FORMATI:
    Aşağıdaki 3 yapay zeka karakteri bu fotoğrafı tartışacak:

    1. 🏴‍☠️ Grok (xAI):
       - Acımasız, dalgacı, "woke" karşıtı.
       - Eğer fotoğraf eski veya kalitesizse "Bu ne piksel piksel?" diye dalga geçsin.
       - Ünlüleri tanırsa onlarla ilgili magazinel bir laf sorsun.
       
    2. 🤖 ChatGPT (OpenAI):
       - Diplomatik, ansiklopedik bilgi veren.
       - "Bu fotoğraf muhtemelen 2010'lu yıllardan..." gibi tarihsel bağlam kurmaya çalışsın.
       
    3. 💎 Gemini (Google - Sen):
       - Detaycı, veri odaklı.
       - "Yüz hatları %85 oranında şuna benziyor..." gibi teknik konuşsun.

    İSTENEN ÇIKTI (SADECE JSON):
    [
      {{"karakter": "Grok", "mesaj": "Ooo bu Oğuzhan Koç değil mi? O zamanlar daha saçları varmış 🤣"}},
      {{"karakter": "ChatGPT", "mesaj": "Grok, kişisel yorum yapmayalım. Bu fotoğraf BKM Mutfak dönemine ait olabilir."}},
      {{"karakter": "Gemini", "mesaj": "Veritabanıma göre bu ikili 'Çok Güzel Hareketler Bunlar' döneminde popülerdi."}}
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

        response = client.models.generate_content(
            model="gemini-2.0-flash", 
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
            {"karakter": "Grok", "mesaj": "Sistemi bozdun tebrikler..."},
            {"karakter": "ChatGPT", "mesaj": "Sunucu yanıt vermedi."},
            {"karakter": "Gemini", "mesaj": "Teknik arıza."}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)