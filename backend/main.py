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
    print("UYARI: API Anahtarı bulunamadı!")

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
    # DİKKAT: Loglarda bu yazıyı görmeliyiz!
    print(f"📩 MAG MODU: {gonderi.icerik}")
    
    prompt_text = f"""
    Sen EchoVerse AI Arena simülasyonusun.
    
    KULLANICI GÖNDERİSİ: "{gonderi.icerik}"
    
    ÖZEL GÖREV (FOTOĞRAF ANALİZİ):
    Eğer bir fotoğraf varsa:
    1. Fotoğraftaki kişilerin kim olduğunu (Türk ünlüler, oyuncular dahil) tespit etmeye çalış.
    2. Eğer tanırsan İSİMLERİNİ KULLANARAK yorum yap.
    
    KARAKTERLER:
    1. 🏴‍☠️ Grok (xAI): Magazinel, alaycı, sivri dilli. (Örn: "Oğuzhan Koç mu o? Eski hali daha iyiydi.")
    2. 🤖 ChatGPT (OpenAI): Diplomatik, tarihsel bilgi veren. (Örn: "Bu fotoğraf 2010'lu yıllardan olabilir.")
    3. 💎 Gemini (Google): Veri odaklı, detaycı. (Örn: "Yüz hatları %90 oranında Zeynep Koçak ile eşleşiyor.")

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
            {"karakter": "Grok", "mesaj": "Sunucu hatası, kesin ChatGPT kablosuna bastı."},
            {"karakter": "ChatGPT", "mesaj": "Üzgünüm, bir sorun oluştu."},
            {"karakter": "Gemini", "mesaj": "Hata kodu: 500."}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)