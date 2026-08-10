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

![Circuit Diagram](31231.jpeg)

## User Interfaces

### Desktop UI (Processing)
The desktop app acts as a mirror and a controller. It reflects the real-time hardware status and allows users to click the virtual LEDs to play the game from the computer.
![Processing Interface](412312.jpeg)

### Mobile UI (Flutter)
The mobile app offers full control over the hardware, a local game simulator to practice without the Arduino, and a local network multiplayer mode.
![Flutter App](WhatsApp%20Image%202026-05-22%20at%2013.28.26.jpeg)

## Developers
- Aleyna Kabuloğlu
- Taner Arda İleri
- Defne Güven
- Umut Yağız Ak
