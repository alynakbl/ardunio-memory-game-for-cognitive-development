#include <Wire.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2); 

#define NOTE_E5   659  
#define NOTE_F5   698  
#define NOTE_GS5  831  
#define NOTE_A5   880  
#define NOTE_B5   988  
#define NOTE_C6   1047 
#define NOTE_DS5  622  
#define NOTE_G5   784  
#define NOTE_AS5  932  

byte heartShape[8] = {
  0b00000, 0b01010, 0b11111, 0b11111, 0b01110, 0b00100, 0b00000, 0b00000
};

const int btn[4] = {2, 3, 4, 5};
const int r[4] = {7, 10, 13, A2};
const int g[4] = {8, 11, A0, A3};
// 4. LED'in mavisi iptal edildi (-1). 1 Numaralı pin Processing (TX) için boşaltıldı!
const int b[4] = {9, 12, A1, -1}; 
const int buzzerPin = 6;
const int notes[4] = {262, 294, 392, 440};

int stageLengths[7] = {3, 4, 5, 6, 7, 8, 8};
int currentStage = 0;
int sequence[100];
int lives = 3;
int speedMs = 1000;
bool gameStarted = false; 
int gameMode = 1; 

int sadMelody[] = { NOTE_A5, NOTE_A5, NOTE_A5, NOTE_A5, NOTE_A5, NOTE_B5, NOTE_C6, NOTE_C6, NOTE_B5, NOTE_B5, NOTE_A5, NOTE_GS5, NOTE_B5, NOTE_A5, NOTE_GS5, NOTE_B5, NOTE_A5, NOTE_GS5, NOTE_C6, NOTE_B5, NOTE_A5, NOTE_GS5, NOTE_F5, NOTE_F5, NOTE_F5, NOTE_F5, NOTE_F5, NOTE_GS5, NOTE_A5, NOTE_A5, NOTE_A5, NOTE_GS5, NOTE_A5, NOTE_GS5, NOTE_F5, NOTE_A5, NOTE_GS5, NOTE_F5, NOTE_A5, NOTE_GS5, NOTE_F5, NOTE_B5, NOTE_A5, NOTE_GS5, NOTE_F5, NOTE_E5 };
int sadDurations[] = { 8, 8, 8, 8, 8, 8, 4, 8, 8, 8, 8, 4, 4, 8, 8, 8, 8, 4, 8, 8, 8, 8, 4, 8, 8, 8, 8, 8, 8, 4, 8, 8, 8, 8, 4, 8, 8, 8, 8, 8, 4, 8, 8, 8, 8, 2 };

int victoryMelody[] = { NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_AS5, NOTE_G5, NOTE_DS5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_C6, NOTE_DS5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_AS5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_G5, NOTE_F5, NOTE_G5, NOTE_F5, NOTE_F5, NOTE_DS5 };
int victoryDurations[] = { 8, 8, 8, 8, 8, 8, 4, 8, 4, 8, 8, 8, 8, 8, 8, 4, 4, 8, 8, 8, 8, 8, 8, 2, 8, 8, 8, 8, 8, 8, 8, 8, 2 };

void playKumGibi() {
  Serial.println("LOSE"); 
  lcd.clear(); lcd.setCursor(3, 0); lcd.print("OYUN BITTI"); lcd.setCursor(0, 1); lcd.print("Acimasiz Olma...");
  turnOffAll(); for(int j = 0; j < 4; j++) digitalWrite(r[j], HIGH); 
  int len = sizeof(sadMelody) / sizeof(sadMelody[0]);
  for (int i = 0; i < len; i++) {
    int noteDuration = 1200 / sadDurations[i]; 
    tone(buzzerPin, sadMelody[i], noteDuration);
    delay(noteDuration * 1.30); noTone(buzzerPin);
  }
  turnOffAll();
}

void playVictory() {
  Serial.println("WIN"); 
  lcd.clear(); lcd.setCursor(3, 0); lcd.print("TEBRIKLER!"); lcd.setCursor(1, 1); lcd.print("OYUNU KAZANDIN");
  turnOffAll(); for(int j = 0; j < 4; j++) digitalWrite(g[j], HIGH); 
  int len = sizeof(victoryMelody) / sizeof(victoryMelody[0]);
  for (int i = 0; i < len; i++) {
    int noteDuration = 1400 / victoryDurations[i]; 
    tone(buzzerPin, victoryMelody[i], noteDuration);
    delay(noteDuration * 1.30); noTone(buzzerPin);
  }
  turnOffAll();
}

void updateLCDPlaying() {
  lcd.clear(); lcd.setCursor(0, 0); lcd.print("Seviye: "); lcd.print(currentStage + 1); lcd.print("/7");
  lcd.setCursor(0, 1); lcd.print("Can: ");
  for (int i = 0; i < lives; i++) lcd.write(0); 
  
  Serial.print("STAGE,"); Serial.print(currentStage + 1); Serial.print(","); Serial.println(lives);
}

void updateLCDStandby() {
  lcd.clear(); lcd.setCursor(0, 0); lcd.print("Mod 1: Klasik"); lcd.setCursor(0, 1); lcd.print("Mod 2: Zor (Ses)");
}

void turnOffAll() {
  for(int i = 0; i < 4; i++) {
    digitalWrite(r[i], LOW); digitalWrite(g[i], LOW);
    if(b[i] != -1) digitalWrite(b[i], LOW); 
  }
}

void showBlueWithNote(int index) {
  turnOffAll();
  
  // Eğer mavi pin varsa maviyi yak, iptal edilmişse (-1) yeşili yak
  if(b[index] != -1) {
    digitalWrite(b[index], HIGH);
  } else {
    digitalWrite(g[index], HIGH); 
  }
  
  tone(buzzerPin, notes[index]);
  Serial.print("LED,"); Serial.println(index);
}

void playNoteOnly(int index) {
  turnOffAll(); tone(buzzerPin, notes[index]);
}

void stopNote() { noTone(buzzerPin); }

void showError() {
  lcd.clear(); lcd.setCursor(4, 0); lcd.print("HATALI"); lcd.setCursor(4, 1); lcd.print("SECIM!");
  turnOffAll(); for(int i = 0; i < 4; i++) digitalWrite(r[i], HIGH);
  tone(buzzerPin, 150, 1000); 
}

void showSuccess() {
  Serial.println("SUCCESS"); 
  lcd.clear(); lcd.setCursor(4, 0); lcd.print("DOGRU!");
  turnOffAll(); for(int i = 0; i < 4; i++) digitalWrite(g[i], HIGH);
  tone(buzzerPin, 523, 200); delay(200); tone(buzzerPin, 659, 200); delay(200); tone(buzzerPin, 784, 400); 
}

void generateSequence() {
  for(int i = 0; i < 100; i++) 
  sequence[i] = random(0, 4);
}

void countdown() {
  for(int i = 3; i > 0; i--) {
    lcd.clear(); lcd.setCursor(1, 0); lcd.print("Oyun Basliyor!"); lcd.setCursor(7, 1); lcd.print(i);
    tone(buzzerPin, 523, 200); delay(1000);
  }
  lcd.clear(); lcd.setCursor(5, 0); lcd.print("BASLA!"); tone(buzzerPin, 1046, 400); delay(500);
}

void setup() {
  Serial.begin(9600); 
  randomSeed(analogRead(A0));
  lcd.init(); lcd.backlight(); lcd.createChar(0, heartShape);
  
  for(int i = 0; i < 4; i++) {
    pinMode(btn[i], INPUT_PULLUP); pinMode(r[i], OUTPUT); pinMode(g[i], OUTPUT);
    if(b[i] != -1) pinMode(b[i], OUTPUT);
  }
  generateSequence(); updateLCDStandby();
}

void playSequence() {
  delay(1000); updateLCDPlaying(); 
  int steps = stageLengths[currentStage];
  for(int i = 0; i < steps; i++) {
    if (gameMode == 1) showBlueWithNote(sequence[i]);
    else if (gameMode == 2) playNoteOnly(sequence[i]);
    delay(speedMs); turnOffAll(); stopNote(); delay(speedMs / 2);
  }
}

bool checkInput() {
  int steps = stageLengths[currentStage];
  for(int i = 0; i < steps; i++) {
    int expected = sequence[i]; int pressed = -1;
    while(pressed == -1) {
      for(int j = 0; j < 4; j++) {
        if(digitalRead(btn[j]) == LOW) {
          pressed = j; showBlueWithNote(pressed); delay(200);
          while(digitalRead(btn[j]) == LOW) {}
          turnOffAll(); stopNote(); delay(50); break;
        }
      }
    }
    if(pressed != expected) return false;
  }
  return true;
}

void startGame(int mode) {
  gameMode = mode;
  Serial.print("START,"); Serial.println(mode); 
  
  if(mode == 1) {
    lcd.clear(); lcd.setCursor(2, 0); lcd.print("Klasik Mod"); lcd.setCursor(4, 1); lcd.print("Secildi");
    tone(buzzerPin, 880, 150); delay(150); tone(buzzerPin, 988, 150); delay(150); tone(buzzerPin, 1046, 300); delay(300);
  } else {
    lcd.clear(); lcd.setCursor(4, 0); lcd.print("Zor Mod"); lcd.setCursor(1, 1); lcd.print("Sesleri Dinle!");
    tone(buzzerPin, 1046, 150); delay(150); tone(buzzerPin, 988, 150); delay(150); tone(buzzerPin, 880, 300); delay(300); delay(500); 
    for(int i = 0; i < 4; i++) { showBlueWithNote(i); delay(600); turnOffAll(); stopNote(); delay(200); }
  }
  delay(500); countdown();
  gameStarted = true; currentStage = 0; lives = 3; speedMs = 1000; generateSequence();
}

void loop() {
  if (!gameStarted) {
    if (digitalRead(btn[0]) == LOW) { while(digitalRead(btn[0]) == LOW) {} startGame(1); }
    else if (digitalRead(btn[1]) == LOW) { while(digitalRead(btn[1]) == LOW) {} startGame(2); }
    return; 
  }

  playSequence();
  bool success = checkInput();
  
  if(success) {
    showSuccess(); delay(1000); turnOffAll(); currentStage++;
    if(currentStage >= 7) { playVictory(); gameStarted = false; updateLCDStandby(); } 
    else { speedMs = speedMs * 0.85; if(speedMs < 200) speedMs = 200; }
    generateSequence(); 
  } else {
    showError(); delay(1000); turnOffAll(); lives--;
    if(lives <= 0) { playKumGibi(); gameStarted = false; updateLCDStandby(); } 
    else { delay(1000); }
  }
}