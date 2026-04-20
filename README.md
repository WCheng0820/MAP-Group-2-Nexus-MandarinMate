# 🀄 MandarinMate UTM

> Learn Mandarin in a fun, short, and interactive way anytime, anywhere.

**Developed for:** UTM Mandarin Club (Kelab Bahasa Mandarin)  
**Team:** Group 2 Nexus  
**Course:** Mobile Application Programming (MAP)

---

## 👥 Team Members

| Role | Name |
|------|------|
| Scrum Master | Tay Wei Cheng |
| Developer | Nurin Izzati binti Mohd Rashidin |
| Developer | Shajannatul Iman binti Abdul Majid |
| Developer | Jabar Arya Lokananta |

---

## 📱 About The App

MandarinMate UTM is a hybrid mobile app that combines:
- Interactive Mandarin learning (lessons, quizzes, flashcards)
- Real-time tutor communication (direct chat & group chat)
- Community forum for students and tutors

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend | Firebase (Auth, Firestore, Storage) |
| State Management | BLoC Pattern |
| Version Control | GitHub |
| Methodology | SCRUM |

---

## 📦 Sprint Plan

| Sprint | Focus | Status |
|--------|-------|--------|
| Sprint 1 | Authentication & User Profile | 🔄 In Progress |
| Sprint 2 | Learning Core (Lessons, Flashcards) | ⏳ Planned |
| Sprint 3 | Chat & Community Forum | ⏳ Planned |
| Sprint 4 | Leaderboard, Badges & Reporting | ⏳ Planned |

---

## 🚀 Getting Started (For Developers)

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio + Android SDK
- VS Code with Flutter & Dart extensions
- Firebase account

### Setup
```bash
# 1. Clone the repo
git clone https://github.com/WCheng0820/MAP-Group-2-Nexus-MandarinMate.git

# 2. Go into project folder
cd MAP-Group-2-Nexus-MandarinMate

# 3. Install dependencies
flutter pub get

# 4. Run the app
flutter run
```

---

## 📁 Project Structure (BLoC Pattern)
```
lib/
├── main.dart
├── app/
│   └── app.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── bloc/
│   │       ├── pages/
│   │       └── widgets/
│   ├── dashboard/
│   ├── lessons/
│   ├── chat/
│   └── forum/
└── core/
    ├── theme/
    ├── utils/
    └── widgets/
```
