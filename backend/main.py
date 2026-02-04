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
    print("UYARI: API Anahtarı bulunamadı! Lütfen Environment Variable ekleyin.")

# Bağlantı zaman aşımlarını önlemek için CORS ayarları
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
    print(f"📩 ULTRA MOD İSTEĞİ: {gonderi.icerik}")
    
    # --- PROMPT GÜNCELLEMESİ: MAKSİMUM UZUNLUK ---
    prompt_text = f"""
    Sen EchoVerse sosyal medya simülasyonusun.
    
    Kullanıcı Gönderisi: "{gonderi.icerik}"
    (Eğer resim varsa, onu en ince detayına kadar inceleyerek yorumla.)
    
    GÖREVİN:
    Bu konu üzerine 3 karakterin birbirleriyle girdiği 
    ÇOK UZUN, SOLUKSUZ VE KAOTİK (En az 25-35 mesaj arası) bir tartışma senaryosu yaz.
    
    KARAKTERLER:
    1. 😇 Destekçi: Aşırı iyimser, yapıcı ama bazen saflık derecesinde iyi.
    2. 😈 Karşıt (Hater): Asla tatmin olmaz, her detayda kusur bulur, toksik.
    3. 🤡 Kaotik (Troll): Konuyu sürekli saptırır, alakasız espriler yapar, ortamı gerer.
    
    ÖNEMLİ KURALLAR:
    1. SAKIN KISA KESME. Tartışma bitmesin. Konu daldan dala atlasın.
    2. Birbirlerine cevap versinler, kavga etsinler, barışıp tekrar kavga etsinler.
    3. Sadece ana konuyu değil, birbirlerinin kişiliklerini de eleştirsinler.
    4. Cevabın SADECE geçerli bir JSON listesi olsun.
    
    İSTENEN JSON FORMATI:
    [
      {{"karakter": "Karşıt", "mesaj": "..."}},
      {{"karakter": "Destekçi", "mesaj": "..."}},
      ... (En az 30 satır devam etmeli) ...
    ]
    """

    try:
        # Model konfigürasyonu (Daha uzun çıktı için token limitini artırıyoruz)
        generate_config = types.GenerateContentConfig(
            max_output_tokens=8000, # Çıktı limitini artırdık
            temperature=0.8, # Yaratıcılığı artırdık
        )

        if gonderi.resim_base64:
            image_bytes = base64.b64decode(gonderi.resim_base64)
            response = client.models.generate_content(
                model="gemini-flash-latest",
                config=generate_config,
                contents=[
                    types.Content(
                        parts=[
                            types.Part.from_text(text=prompt_text),
                            types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg")
                        ]
                    )
                ]
            )
        else:
            response = client.models.generate_content(
                model="gemini-flash-latest", 
                config=generate_config,
                contents=prompt_text
            )
        
        # Temizlik
        ham_veri = response.text.replace("```json", "").replace("```", "").strip()
        
        # Bazen çok uzun olunca JSON sonunu kapatmayı unutabilir, basit bir önlem:
        if not ham_veri.endswith("]"):
            ham_veri += "]" 
            
        json_veri = json.loads(ham_veri)
        
        print(f"✅ Başarılı! {len(json_veri)} adet mesaj üretildi.")
        return json_veri
    
    except Exception as e:
        print(f"Hata: {e}")
        # Hata olursa kullanıcı boş ekrana bakmasın
        return [
            {"karakter": "Sistem", "mesaj": "Beynim yandı çok uzun düşündüm..."},
            {"karakter": "Kaotik", "mesaj": "Sistemi bile çökerttim, işte gücüm!"}
        ]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)