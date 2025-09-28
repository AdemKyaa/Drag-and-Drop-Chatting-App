const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// Mesaj kaydedildiğinde çalışır
exports.sendChatNotification = onDocumentCreated(
  "messages/{messageId}", // 🔹 artık direkt "messages" koleksiyonunu dinliyoruz
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const senderId = data.senderId;
    const receiverId = data.receiverId;

    if (!senderId || !receiverId) return;

    try {
      // Kullanıcı bilgilerini al
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();

      if (!receiverDoc.exists) return;

      const fcmToken = receiverDoc.data().fcmToken;
      const lang = receiverDoc.data().lang || "tr";
      const senderName = senderDoc.exists ? (senderDoc.data().displayName || "Biri") : "Biri";

      // Mesajı dile göre hazırla
      let messageBody = "";
      if (lang === "tr") {
        messageBody = `${senderName} kullanıcısından bir mesaj var`;
      } else {
        messageBody = `You have a new message from ${senderName}`;
      }

      // Bildirimi gönder
      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: lang === "tr" ? "📩 Yeni Mesaj" : "📩 New Message",
            body: messageBody,
          },
        });
      }
    } catch (err) {
      console.error("❌ Bildirim gönderilemedi:", err);
    }
  }
);
