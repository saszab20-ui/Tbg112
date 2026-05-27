const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const FieldValue = admin.firestore.FieldValue;

const VALID_SOUNDS = new Set([
  "cool_sms_tone",
  "door_knock",
  "e7_mms",
  "ninja_tone",
  "unique_sms",
]);

exports.notifyChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data && event.data.data();
    if (!message) return;
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = message.senderId || "";
    const chatDoc = await db.collection("chats").doc(chatId).get();
    const chat = chatDoc.exists ? chatDoc.data() : {};
    const chatType = chat.type || chat.chatKind || message.chatType || "main";
    const route = routeForChat(chatId, chatType, chat);
    const tokens = await tokensForChat(chatId, chat, senderId, message.createdAt);
    if (tokens.length === 0) return;

    const sound = soundForChat(chat, chatType);
    const title = chat && chat.name ? chat.name : "Tarnobrzeg 112";
    const body =
      message.text && message.text.trim()
        ? `${message.senderDisplayName || "Użytkownik"}: ${message.text}`
        : `${message.senderDisplayName || "Użytkownik"} wysłał załącznik`;

    await sendTokenBatches(tokens, {
      notification: { title, body },
      data: {
        type: "message",
        chatId,
        messageId,
        chatType,
        senderId,
        route,
        sound,
      },
      android: {
        priority: "high",
        collapseKey: `chat_${chatId}`,
        notification: {
          channelId: channelIdForSound(sound),
          sound,
          tag: `chat_${chatId}`,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: { aps: { sound: `${sound}.mp3` } },
      },
    });

    const mentionTokens = await tokensForMentionedUsers(
      message.mentions,
      senderId,
    );
    if (mentionTokens.length > 0) {
      const mentionSound = soundForChat(chat, chatType);
      await sendTokenBatches(mentionTokens, {
        notification: {
          title: "Zostałeś oznaczony w wiadomości",
          body,
        },
        data: {
          type: "mention",
          chatId,
          messageId,
          chatType,
          senderId,
          route,
          sound: mentionSound,
        },
        android: {
          priority: "high",
          collapseKey: `mention_${chatId}`,
          notification: {
            channelId: channelIdForSound(mentionSound),
            sound: mentionSound,
            tag: `chat_${chatId}`,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: { aps: { sound: `${mentionSound}.mp3` } },
        },
      });
    }
  },
);

exports.notifyPendingAccount = onDocumentCreated("users/{uid}", async (event) => {
  const user = event.data && event.data.data();
  if (!user || user.accountStatus !== "pending") return;
  const tokens = await adminTokens();
  if (tokens.length === 0) return;

  await sendTokenBatches(tokens, {
    notification: {
      title: "Nowe konto do akceptacji",
      body: `${user.nickname || user.login || "Użytkownik"} oczekuje na decyzję.`,
    },
    data: {
      type: "pending_account",
      uid: event.params.uid,
      route: "/admin/users?filter=pending",
      sound: "unique_sms",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "tbg112_admin",
        sound: "unique_sms",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
    apns: {
      payload: { aps: { sound: "unique_sms.mp3" } },
    },
  });
});

exports.processPasswordResetRequest = onDocumentCreated(
  "password_reset_requests/{requestId}",
  async (event) => {
    const request = event.data && event.data.data();
    if (!request) return;

    const actorUid = String(request.createdBy || "").trim();
    const targetUid = String(request.targetUid || "").trim();
    const temporaryPassword = String(request.temporaryPassword || "").trim();
    const requestRef = db
      .collection("password_reset_requests")
      .doc(event.params.requestId);

    try {
      if (!actorUid || !targetUid || temporaryPassword.length < 8) {
        throw new Error("Invalid password reset request.");
      }
      const actor = await db.collection("users").doc(actorUid).get();
      const actorData = actor.exists ? actor.data() : {};
      const isAdmin = actorData.role === "admin";
      if (!isAdmin) {
        throw new Error("Only admin can reset passwords.");
      }
      const targetRef = db.collection("users").doc(targetUid);
      const target = await targetRef.get();
      if (!target.exists) {
        throw new Error("Target user not found.");
      }
      const targetData = target.data() || {};

      await admin.auth().updateUser(targetUid, { password: temporaryPassword });
      await targetRef.set(
        {
          mustChangePassword: true,
          mustSetPassword: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await db.collection("moderation_logs").add({
        action: "reset_password",
        targetUserId: targetUid,
        targetUserLogin: targetData.login || request.targetUserLogin || "",
        performedBy: actorUid,
        performedByLogin: actorData.login || request.createdByLogin || "",
        oldValue: null,
        newValue: "temporary_password_set",
        createdAt: FieldValue.serverTimestamp(),
      });
      await requestRef.set(
        {
          status: "done",
          temporaryPassword: FieldValue.delete(),
          processedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (error) {
      logger.error("Password reset request failed", error);
      await requestRef.set(
        {
          status: "error",
          error: String(error.message || error),
          temporaryPassword: FieldValue.delete(),
          processedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);

async function tokensForChat(chatId, chat, senderId, messageCreatedAt) {
  const type = (chat && (chat.type || chat.chatKind)) || "main";
  if (type === "main" || chatId === "main") {
    const snapshot = await db
      .collection("users")
      .where("accountStatus", "==", "active")
      .limit(1000)
      .get();
    return tokensFromUsers(
      snapshot.docs
        .filter((doc) => doc.id !== senderId)
        .map((doc) => doc.data()),
    );
  }

  if (type === "unit") {
    let query = db.collection("users").where("accountStatus", "==", "active");
    if (chat.unitId) query = query.where("unitId", "==", chat.unitId);
    else if (chat.unitName) query = query.where("unitName", "==", chat.unitName);
    else return [];
    const snapshot = await query.limit(1000).get();
    return tokensFromUsers(
      snapshot.docs
        .filter((doc) => doc.id !== senderId)
        .map((doc) => doc.data()),
    );
  }

  const participantIds = Array.isArray(chat.participants)
    ? chat.participants
    : Array.isArray(chat.participantIds)
      ? chat.participantIds
      : [];
  const messageDate = firestoreDate(messageCreatedAt);
  const joinedAt = chat && chat.joinedAt && typeof chat.joinedAt === "object"
    ? chat.joinedAt
    : {};
  const recipientIds = participantIds.filter((uid) => {
    if (!uid || uid === senderId) return false;
    const joinedDate = firestoreDate(joinedAt[uid]);
    return !messageDate || !joinedDate || messageDate >= joinedDate;
  });
  const users = await Promise.all(
    recipientIds.map((uid) => db.collection("users").doc(uid).get()),
  );
  return tokensFromUsers(
    users.filter((doc) => doc.exists).map((doc) => doc.data()),
  );
}

function firestoreDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "number") return new Date(value);
  return null;
}

function routeForChat(chatId, type, chat) {
  if (type === "main" || chatId === "main") return "/chat/global";
  if (type === "unit") {
    const unitId = chat.unitId || String(chatId).replace(/^unit[_-]/, "");
    return `/chat/unit/${unitId}`;
  }
  if (type === "private" || type === "group") return `/private/${chatId}`;
  return "/chats";
}

function soundForChat(chat, type) {
  const value = type === "private" ? chat.privateSound : chat.incomingSound;
  return sanitizeSound(value || "unique_sms");
}

function sanitizeSound(value) {
  const sound = String(value || "").trim();
  return VALID_SOUNDS.has(sound) ? sound : "unique_sms";
}

function channelIdForSound(sound) {
  return `tbg112_chat_${sanitizeSound(sound)}`;
}

async function adminTokens() {
  const snapshot = await db
    .collection("users")
    .where("accountStatus", "==", "active")
    .where("role", "==", "admin")
    .limit(200)
    .get();
  return tokensFromUsers(snapshot.docs.map((doc) => doc.data()));
}

async function tokensForMentionedUsers(mentions, senderId) {
  const recipientIds = Array.isArray(mentions)
    ? [...new Set(mentions.filter((uid) => uid && uid !== senderId))]
    : [];
  if (recipientIds.length === 0) return [];
  const users = await Promise.all(
    recipientIds
      .slice(0, 50)
      .map((uid) => db.collection("users").doc(uid).get()),
  );
  return tokensFromUsers(
    users
      .filter((doc) => doc.exists)
      .map((doc) => doc.data())
      .filter((user) => user.accountStatus === "active"),
  );
}

function tokensFromUsers(users) {
  return [
    ...new Set(
      users.flatMap((user) =>
        Array.isArray(user.fcmTokens) ? user.fcmTokens.filter(Boolean) : [],
      ),
    ),
  ];
}

async function sendTokenBatches(tokens, payload) {
  for (let index = 0; index < tokens.length; index += 500) {
    const batch = tokens.slice(index, index + 500);
    try {
      await messaging.sendEachForMulticast({ ...payload, tokens: batch });
    } catch (error) {
      logger.error("FCM batch failed", error);
    }
  }
}
