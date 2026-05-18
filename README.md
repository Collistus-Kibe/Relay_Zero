
<img width="1686" height="933" alt="c541321b-23af-44b0-9c79-14f0c02550d3" src="https://github.com/user-attachments/assets/5049f9cb-72b4-47e7-a4fc-af509c3145da" />

# Relay Zero 📡🧠

An offline-first disaster response application built with Flutter. Relay Zero transforms surviving smartphones into a self-healing emergency beacon network during infrastructure collapses, powered entirely by an on-device Gemma 4 Edge AI.

## ⚠️ Important: Download the AI Model (GGUF)

Due to GitHub file size limits, the quantized Gemma 4 model required for this application to function is **not** hosted in this repository.

You must download the model files directly from Hugging Face before running the app:
👉 **[Download Relay Zero Gemma Models Here](https://huggingface.co/nexaaii/relay-zero-gemma-4-triage)**

**Setup Instructions:**
1. Download the `.gguf` model file from the Hugging Face link above.
2. Place the downloaded file into the appropriate assets folder in your project directory (e.g., `assets/models/`).
3. Ensure the model path is correctly referenced in your `pubspec.yaml` and Dart code.

## 🚀 Core Features

* **Intelligent Semantic Compression:** Uses a localized Gemma 4 model to instantly compress chaotic SOS paragraphs into microscopic, 30-byte JSON payloads.
* **Connectionless BLE Mesh:** Broadcasts these tiny data packets over a Bluetooth Low Energy network, bypassing the need for cell towers or Wi-Fi.
* **Community Radar:** Allows uninjured citizens to intercept mesh signals and decode precise GPS coordinates to rescue neighbors.
* **Offline Survival Expert:** The on-device AI provides immediate, localized first-aid and survival instructions directly to the victim.

## 🛠️ Tech Stack

* **Frontend:** Flutter / Dart
* **Edge Inference:** `llama.cpp` integrated via Dart C++ FFI
* **AI Model:** Gemma 4 (Open-Weights, IQ3_S Quantization)
* **Networking:** Bluetooth Low Energy (BLE)

## 💻 Getting Started

1. Clone this repository.
2. Download the required GGUF model (see instructions above).
3. Run `flutter pub get` to install dependencies.
4. Connect a physical iOS or Android device (Bluetooth features will not work on an emulator/simulator).
5. Run `flutter run`.
