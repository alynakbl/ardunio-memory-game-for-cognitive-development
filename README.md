# Cognitive Development Memory Game

A hardware and software integrated memory game designed to improve short-term visual and auditory memory. Built with Arduino, Processing, and Flutter.

This project was developed for the BİL210 course at Başkent University.

## Features
- **Classic Mode:** Follow and repeat the visual (LED) and audio (Buzzer) sequence.
- **Hard Mode:** Audio only. Follow the notes without visual LED hints.
- **Desktop Interface (Processing):** Real-time game tracking and control using a desktop UI connected via USB Serial.
- **Mobile App (Flutter):** An Android application featuring Bluetooth (HM-10 BLE) hardware control, a local standalone simulator, and a LAN multiplayer (P2P) mode.

## System Architecture & Circuit
The core system is powered by an Arduino Uno. It uses 4 RGB LEDs, 4 push buttons, a buzzer for audio feedback, a 16x2 I2C LCD for status messages, and an HM-10 Bluetooth module for mobile connectivity. 

*(Note: Green pins on the RGB LEDs are disabled due to Arduino pin limitations. The system uses Red, Blue, and Purple combinations for feedback).*

<img width="1010" height="633" alt="31231" src="https://github.com/user-attachments/assets/58b2af7d-95fd-4f3f-89e4-6f09ef1b1f3a" />

## User Interfaces

### Desktop UI (Processing)
The desktop app acts as a mirror and a controller. It reflects the real-time hardware status and allows users to click the virtual LEDs to play the game from the computer.

<img width="998" height="526" alt="412312" src="https://github.com/user-attachments/assets/c5c8ad03-1b6d-4c88-90fb-48991108da1c" />

### Mobile UI (Flutter)
The mobile app offers full control over the hardware, a local game simulator to practice without the Arduino, and a local network multiplayer mode.

<img width="2048" height="1280" alt="WhatsApp Image 2026-05-22 at 13 28 26" src="https://github.com/user-attachments/assets/495d24d3-4294-4c37-8e1e-d5002ce8efcd" />

## Developers
- Aleyna Kabuloğlu
- Taner Arda İleri
- Defne Güven
- Umut Yağız Ak
