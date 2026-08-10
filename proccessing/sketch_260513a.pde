/* =====================================================================
   BILISSEL GELISIM HAFIZA OYUNU - Processing Masaustu Arayuzu
   ---------------------------------------------------------------------
   GENEL MANTIK:
   Oyunun beyni ARDUINO'dadir. Processing yalnizca bir AYNA + KUMANDA gorevi gorur:
     - Arduino "su an ne oluyor" bilgisini USB seri port uzerinden yollar,
       Processing bunu ekrana cizer.  (ALMA yonu  -> serialEvent)
     - Kullanici ekrana tiklayinca, Processing bunu Arduino'ya iletir.
       (GONDERME yonu -> mousePressed)

   RENK SEMASI (donanimla birebir ayni):
     - LED yanmasi (sira gosterimi)  : KIRMIZI
     - Dogru hamle / Kazanma         : MOR  (kirmizi + mavi)
     - Kaybetme                      : MAVI
     - Yesil YOK -> Arduino'nun pini yetmedigi icin yesil pinler iptal edildi
   ===================================================================== */

import processing.serial.*;   // Arduino ile seri haberlesme kutuphanesi

Serial myPort;                // Arduino baglantisini temsil eden nesne
String val;                   // Arduino'dan gelen ham metin satiri

// --- OYUN DURUMUNU TUTAN DEGISKENLER ---
int currentStage = 0;         // icinde bulunulan seviye
int lives = 3;                // kalan can sayisi
String statusMsg = "BASLAMAK ICIN 1. VEYA 2. BUTONA BASIN";  // ekrandaki durum yazisi

// --- GORSEL (sanal LED dairesi) AYARLARI ---
int activeLed = -1;           // su an yanan dairenin numarasi (-1 = hicbiri)
int ledTimer = 0;             // dairenin ne zamana kadar yanacagi (ms)
int[] btnX = {160, 320, 480, 640};  // 4 dairenin yatay (x) konumlari
int btnY = 250;               // dairelerin dikey (y) konumu
int btnRadius = 55;           // daire yaricapi

void setup() {
  size(800, 400);             // 800x400 piksel pencere ac
  printArray(Serial.list());  // bilgisayardaki seri portlari konsola yazdir

  try {
    myPort = new Serial(this, "COM3", 9600);  // Arduino'ya baglan (port COM3, hiz 9600)
    myPort.bufferUntil('\n');                 // KRITIK: satir sonu gelene kadar bekle, sonra oku
  } catch (Exception e) {
    println("HATA");          // baglanti kurulamazsa hata mesaji ver
  }
}

void draw() {
  // draw() saniyede ~60 kez OTOMATIK calisir; ekrani surekli yeniden cizer.
  background(40, 44, 52);     // koyu gri arka plan
  fill(255);
  textSize(32);
  textAlign(CENTER);
  text(statusMsg, width/2, 60);   // ust kisim: durum mesaji
  textSize(24);
  text("Seviye: " + currentStage + " / 7      Can: " + lives, width/2, 100);  // seviye + can

  for (int i = 0; i < 4; i++) {   // 4 sanal LED dairesini sirayla ciz
    fill(80);                     // varsayilan: sonuk gri
    stroke(255);
    strokeWeight(3);

    // KRITIK: dairenin rengi oyunun durumuna gore degisir
    if (statusMsg.equals("OYUN BITTI - KAYBETTIN")) {
      fill(50, 50, 255);          // KAYBETME -> MAVI
    } else if (statusMsg.equals("TEBRIKLER - KAZANDIN!")) {
      fill(255, 50, 255);         // KAZANMA -> MOR
    } else if (statusMsg.equals("DOGRU HAMLE!")) {
      fill(255, 50, 255);         // DOGRU HAMLE -> MOR
    } else if (activeLed == i && millis() < ledTimer) {
      fill(255, 50, 50);          // LED YANMASI -> KIRMIZI (sadece suresi dolmadiysa)
    }

    circle(btnX[i], btnY, btnRadius * 2);  // daireyi ekrana ciz
    fill(255);
    textSize(20);
    text(i + 1, btnX[i], btnY + 80);       // dairenin altina numarasini (1-4) yaz
  }
}

void mousePressed() {
  // Kullanici fareyle bir daireye tikladiginda OTOMATIK calisir. (GONDERME yonu)
  for (int i = 0; i < 4; i++) {
    if (dist(mouseX, mouseY, btnX[i], btnY) <= btnRadius) {  // KRITIK: tiklama daire icinde mi?
      println("Tiklandi: " + (i + 1));

      activeLed = i;              // tiklanan daireyi
      ledTimer = millis() + 200;  // kisa sure (200 ms) yak (gorsel geri bildirim)

      if (myPort != null) {       // baglanti varsa Arduino'ya komut yolla
        if (statusMsg.equals("SIRA SENDE...")) {
          myPort.write("CLICK," + i + "\n");        // oyun sirasinda: tiklamayi bildir
        }
        else if (statusMsg.equals("BASLAMAK ICIN 1. VEYA 2. BUTONA BASIN") ||
                 statusMsg.equals("OYUN BITTI - KAYBETTIN") ||
                 statusMsg.equals("TEBRIKLER - KAZANDIN!")) {
          // baslangic / oyun sonu ekranindaysa: ilk iki daire mod secer
          if (i == 0) {
            myPort.write("START_MODE,1\n");          // 1. daire -> Klasik mod
          } else if (i == 1) {
            myPort.write("START_MODE,2\n");          // 2. daire -> Zor mod
          }
        }
      }
    }
  }
}

void serialEvent(Serial p) {
  // Arduino'dan satir sonu ('\n') ile biten bir komut gelince OTOMATIK calisir. (ALMA yonu)
  val = p.readStringUntil('\n');     // gelen satiri oku
  if (val != null) {
    val = trim(val);                 // bastaki/sondaki bosluklari temizle
    String[] data = split(val, ',');  // KRITIK: virgulden bol -> "STAGE,3,2" = ["STAGE","3","2"]

    if (data[0].equals("START")) {              // oyun basladi
      statusMsg = "MOD " + data[1] + " BASLIYOR...";
      currentStage = 1;
      lives = 3;
    }
    else if (data[0].equals("STAGE")) {         // yeni seviye + can bilgisi geldi
      currentStage = Integer.valueOf(data[1].trim());  // 2. parca = seviye
      lives = Integer.valueOf(data[2].trim());         // 3. parca = can
      statusMsg = "SIRA SENDE...";
    }
    else if (data[0].equals("LED")) {           // belirtilen LED'i yak
      activeLed = Integer.valueOf(data[1].trim());  // hangi LED (0-3)
      ledTimer = millis() + 400;                    // 400 ms boyunca yansin
    }
    else if (data[0].equals("SUCCESS")) {       // dogru hamle
      statusMsg = "DOGRU HAMLE!";
    }
    else if (data[0].equals("LOSE")) {          // oyun kaybedildi
      statusMsg = "OYUN BITTI - KAYBETTIN";
    }
    else if (data[0].equals("WIN")) {           // oyun kazanildi
      statusMsg = "TEBRIKLER - KAZANDIN!";
    }
  }
}
