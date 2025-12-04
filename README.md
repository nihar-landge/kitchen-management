# 🍽️ Kitchen Management App (Student's Kitchen Mess)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Gemini AI](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google%20gemini&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

A smart, voice-enabled Flutter application designed to streamline the management of a student mess. This app handles attendance tracking, fee payments, student management, and provides real-time insights, all enhanced with **Gemini AI** for natural voice interactions in multiple languages (English, Hindi, Marathi).

---

## ✨ Key Features

### 🎙️ AI-Powered Voice Assistant
- **Hands-Free Operation:** Mark attendance or check dues using voice commands.
- **Multi-Language Support:** Understands commands in **English**, **Hindi**, and **Marathi**.
- **Smart Intent Recognition:** Powered by **Google Gemini 2.5 Flash** to accurately parse intents like "Mark Rahul present" or "Rahul ki attendance lagao".
- **Interactive Feedback:** Speaks back to confirm actions or ask for clarifications (e.g., "Did you mean Rahul Sharma?").
- **Lunch/Dinner Count:** Ask "How many people remaining?" to get a live count of students who haven't eaten yet.

### 📊 Dashboard & Analytics
- **Real-Time Overview:** View active students, payments due, and daily attendance stats at a glance.
- **Meal Tracking:** Automatically switches between "Morning" (Lunch) and "Night" (Dinner) cycles based on time of day.
- **Notifications:** Alerts for upcoming subscription expiries and overdue payments.

### 👥 Student Management
- **Detailed Profiles:** Manage student details, contact info, and subscription dates.
- **Attendance History:** View detailed logs of student attendance.
- **Archive System:** Archive inactive students while preserving their history.

### 💰 Payment & Dues
- **Automated Calculations:** Automatically calculates monthly dues based on subscription start dates.
- **Payment Tracking:** Record payments and track outstanding balances.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **Backend:** [Firebase](https://firebase.google.com/) (Firestore, Auth)
- **AI/LLM:** [Google Gemini API](https://ai.google.dev/) (via `google_generative_ai` package)
- **Voice:** `speech_to_text` (STT) and `flutter_tts` (TTS)
- **State Management:** Provider
- **UI/UX:** Google Fonts (Inter, Poppins, Montserrat), Animations, Glassmorphism elements.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed (v3.0+)
- Git installed
- A Firebase project set up
- A Google Cloud project with **Gemini API** enabled

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/nihar-landge/kitchen-management.git
    cd kitchen-management
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Configure Firebase**
    - Install the FlutterFire CLI:
      ```bash
      dart pub global activate flutterfire_cli
      ```
    - Configure the app:
      ```bash
      flutterfire configure
      ```
    - This will generate `lib/firebase_options.dart` and `android/app/google-services.json`.

4.  **Setup Secrets**
    - Create a file `lib/secrets.dart`.
    - Add your Gemini API key:
      ```dart
      // lib/secrets.dart
      const String geminiApiKey = "YOUR_GEMINI_API_KEY_HERE";
      ```
    - *Note: `lib/secrets.dart` is git-ignored for security.*

5.  **Run the App**
    ```bash
    flutter run
    ```

---

## 🗣️ Voice Command Examples

The app understands natural language. Try saying:

| Intent | English | Hindi | Marathi |
| :--- | :--- | :--- | :--- |
| **Mark Attendance** | "Mark attendance for Rahul" | "Rahul ki attendance lagao" | "Rahul chi attendance lawa" |
| **Check Dues** | "Check dues for Amit" | "Amit ka kitna baaki hai?" | "Amit kade kiti baaki ahet?" |
| **Lunch Count** | "Who hasn't eaten yet?" | "Kitne log baaki hai?" | "Kiti lok baaki ahet?" |
| **Confirmation** | "Yes" / "Confirm" | "Ha" / "Sahi hai" | "Ho" / "Barobar" |

---

## 📂 Project Structure

```
lib/
├── models/          # Data models (Student, Attendance, etc.)
├── screens/         # UI Screens (Dashboard, Students, Settings)
├── services/        # Logic (Firestore, VoiceCommand, etc.)
├── utils/           # Helpers (Payment calculations, formatting)
├── widgets/         # Reusable UI components
├── main.dart        # Entry point
└── secrets.dart     # API Keys (Not in version control)
```

---

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

Made with ❤️ by [Nihar Landge](https://github.com/nihar-landge)
