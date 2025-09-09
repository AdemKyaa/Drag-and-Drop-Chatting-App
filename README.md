# 💬 Drag-and-Drop-Chatting-App

A cross-platform realtime chat application with modern features such as drag-and-drop messaging, realtime translation, and user management.  
Built with Flutter, Node.js, Socket.io, and PostgreSQL.

---

## 🚀 Features
- 🔑 Login / Register: User authentication with username, email, and password.  
- 👥 User Selection: Choose from registered users to start a chat.  
- 💬 Chat Window:  
  - Previous conversations are stored.  
  - Text, stickers, and photos can be added via drag & drop.  
  - Each object’s position, angle, and size are customizable.  
- ⚡ Realtime Messaging: All messages and objects are instantly synchronized.  
- 🌍 Realtime Translation: Messages are automatically translated into the recipient’s chosen language.  
- 👀 Read Receipts: Seen (✓) and read indicators for messages.  
- ➕ User Adding: Add new friends using username and ID.  

---

## 🖥️ UI (Flutter)
- WhatsApp-like interface.  
- 6 Pages:  
  - Profile (edit name, email, language, profile picture)  
  - Add User (by name & ID)  
  - Users (list of all contacts)  
  - Chats (list of conversations & groups)  
  - Chat Window (full conversation with text, images, stickers)  
  - Photo/Sticker Adding  

---

## 🛠️ Tech Stack
- Flutter – Cross-platform frontend  
- Socket.io – Realtime communication  
- Node.js – Backend (authentication, user management, APIs)  
- PostgreSQL – Database (users, chats, stickers, object states)  
- LibreTranslate / Hugging Face – Realtime translation  

---

## 💾 Data Management
- Objects (text, image, sticker) → stored with position, rotation, and size.  
- Chat Loading → Lazy loading; past messages fetched as user scrolls back.  
- Contacts & Groups → Stored and auto-loaded at app start.  
- Profile Data → Name, email, language, and picture saved.  
- Auto Login → Last session opens automatically unless logged out.  

---

## ⚙️ Build & Deployment
- Build:  
  flutter build appbundle
- Performance:  
  - Native Flutter build ensures high performance.  
  - Realtime messaging depends on internet stability.  
- Challenges:  
  - Device compatibility (different Android versions).  
  - Permissions (camera, gallery, internet).  
  - Keeping socket connections stable in background.  

---

## 📌 Roadmap
- [ ] Admin dashboard for monitoring chats.  
- [ ] Advanced group chat features.  
- [ ] Push notifications for new messages.  
- [ ] Improved offline support.  

---

## 👨‍💻 Author
Developed as part of my internship project, focusing on frontend and realtime systems.
