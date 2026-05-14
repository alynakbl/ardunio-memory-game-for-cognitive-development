import processing.serial.*;

Serial myPort;
String val;

int currentStage = 0;
int lives = 3;
String statusMsg = "OYNAMAK ICIN BUTONA BASINIZ";
int activeLed = -1;
int ledTimer = 0;

void setup() {
  size(800, 400); // Masaüstü pencere boyutu
  
  // Bilgisayarına bağlı açık portları alttaki konsola yazdırır (Portunu bulmana yardımcı olur)
  printArray(Serial.list()); 
  
  // DİKKAT: AŞAĞIDAKİ "COM3" YAZISINI KENDİ ARDUINO PORTUNLA DEĞİŞTİRMELİSİN!
  myPort = new Serial(this, "COM3", 9600); 
  myPort.bufferUntil('\n'); // Yeni satıra kadar veriyi bekle
}

void draw() {
  background(40, 44, 52); // Modern koyu gri arka plan

  // Üst Bilgi Yazıları
  fill(255);
  textSize(32);
  textAlign(CENTER);
  text(statusMsg, width/2, 60);

  textSize(24);
  text("Seviye: " + currentStage + " / 7      Can: " + lives, width/2, 100);

  // 4 Adet Sanal LED'i Çiz
  for (int i = 0; i < 4; i++) {
    int x = 160 + (i * 160);
    int y = 250;

    // Varsayılan LED görünümü (Sönük)
    fill(80); 
    stroke(255);
    strokeWeight(3);

    // Durumlara göre LED renklerini değiştir
    if (statusMsg.equals("OYUN BITTI - KAYBETTIN")) {
      fill(255, 50, 50); // Tüm LED'ler Kırmızı (Kum Gibi çaldığında)
    } else if (statusMsg.equals("TEBRIKLER - KAZANDIN!")) {
      fill(50, 255, 50); // Tüm LED'ler Yeşil (Zafer melodisi çaldığında)
    } else if (statusMsg.equals("DOGRU HAMLE!")) {
      fill(50, 255, 50); // Doğru bildiğinde tüm LED'ler anlık Yeşil
    } else if (activeLed == i && millis() < ledTimer) {
      // 4. LED'in donanımsal durumu bilgisayara da yansıtıldı
      if (i == 3) {
        fill(50, 255, 50); // 4. LED için Mavi yerine Yeşil yanar
      } else {
        fill(50, 150, 255); // 1, 2 ve 3. LED'ler Mavi yanar
      }
    }

    circle(x, y, 110); // Sanal LED Yuvarlağı
    
    // LED Numaraları
    fill(255);
    textSize(20);
    text(i + 1, x, y + 80);
  }
}

// Arduino'dan gelen veriyi yakalayan olay dinleyicisi
// Arduino'dan gelen veriyi yakalayan olay dinleyicisi
void serialEvent(Serial p) {
  val = p.readStringUntil('\n');
  if (val != null) {
    val = trim(val);
    String[] data = split(val, ','); // Virgülle ayrılmış veriyi parçala

    if (data[0].equals("START")) {
      statusMsg = "MOD " + data[1] + " BASLIYOR...";
      currentStage = 1;
      lives = 3;
    } 
    else if (data[0].equals("STAGE")) {
      // int() yerine saf Java metodu olan Integer.parseInt() kullanıyoruz
      currentStage = Integer.parseInt(data[1].trim());
      lives = Integer.parseInt(data[2].trim());
      statusMsg = "SIRA SENDE...";
    } 
    else if (data[0].equals("LED")) {
      // Aynı şekilde burayı da güncelledik
      activeLed = Integer.parseInt(data[1].trim());
      ledTimer = millis() + 400; // Ekranda 400 milisaniye yanık kalsın
    } 
    else if (data[0].equals("SUCCESS")) {
      statusMsg = "DOGRU HAMLE!";
    } 
    else if (data[0].equals("LOSE")) {
      statusMsg = "OYUN BITTI - KAYBETTIN";
    } 
    else if (data[0].equals("WIN")) {
      statusMsg = "TEBRIKLER - KAZANDIN!";
    }
  }
}
