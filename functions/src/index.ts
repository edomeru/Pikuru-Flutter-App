import * as nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineString} from "firebase-functions/params";
import * as admin from "firebase-admin";

// Initialize Admin SDK (safe to call multiple times)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const gmailEmail = defineString("GMAIL_EMAIL");
const gmailPassword = defineString("GMAIL_PASSWORD");

/**
 * Gets the FCM token for a given uid from the registration collection.
 * @param {string} uid - The Firebase Auth user ID.
 * @return {Promise<string | null>} The FCM token or null if not found.
 */
async function getFcmToken(uid: string): Promise<string | null> {
  try {
    const doc = await admin.firestore().collection("registration").doc(uid).get();
    const token = doc.data()?.fcm_token;
    if (token) {
      console.log(`[FCM] Found token for uid=${uid}`);
      return token as string;
    }
    console.warn(`[FCM] No fcm_token found for uid=${uid} in registration collection`);
    return null;
  } catch (e) {
    console.error(`[FCM] Error fetching token for uid=${uid}:`, e);
    return null;
  }
}

/**
 * Gets the display name for a given uid from the registration collection.
 * @param {string} uid - The Firebase Auth user ID.
 * @return {Promise<string>} The display name or "Someone" if not found.
 */
async function getDisplayName(uid: string): Promise<string> {
  try {
    const doc = await admin.firestore().collection("registration").doc(uid).get();
    const data = doc.data() ?? {};
    const nickname = (data.nickname ?? "").toString().trim();
    const firstName = (data.firstName ?? "").toString().trim();
    const lastName = (data.lastName ?? "").toString().trim();

    if (nickname) return nickname;
    if (firstName || lastName) return [firstName, lastName].filter(Boolean).join(" ");
    return "Someone";
  } catch (e) {
    console.error(`[FCM] Error fetching display name for uid=${uid}:`, e);
    return "Someone";
  }
}

// ── New message in group chat ─────────────────────────────────────────────────
export const onGroupMessage = onDocumentCreated(
  "group_chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatId = event.params.chatId;
    const senderId = message.sender_id;

    console.log(`[FCM] Group message in chatId=${chatId} from senderId=${senderId}`);

    const participantsSnap = await admin.firestore()
      .collection("group_chats").doc(chatId)
      .collection("participants").get();

    const tokens: string[] = [];
    for (const p of participantsSnap.docs) {
      if (p.id === senderId) continue;
      const token = await getFcmToken(p.id);
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) {
      console.warn("[FCM] No tokens found for group chat participants");
      return;
    }

    const chatDoc = await admin.firestore().collection("group_chats").doc(chatId).get();
    const groupName = chatDoc.data()?.org_name || "Group Chat";

    console.log(`[FCM] Sending group notification to ${tokens.length} devices`);

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: groupName,
        body: message.text || "New message",
      },
      data: {
        route: `/chats/group/${chatId}`,
        chat_id: chatId,
        type: "group_message",
      },
      android: {
        notification: {channelId: "pikuru_notifications", color: "#3A7D44"},
        priority: "high",
      },
      apns: {
        payload: {aps: {sound: "default", badge: 1}},
      },
    });

    console.log("[FCM] Group notification sent successfully");
  }
);


// ── New individual chat message ───────────────────────────────────────────────
export const onIndividualMessage = onDocumentCreated(
  "individual_chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatId = event.params.chatId;
    const senderId = message.sender_id;

    console.log(`[FCM] Individual message in chatId=${chatId} from senderId=${senderId}`);

    if (!senderId) {
      console.warn("[FCM] No sender_id on message — skipping");
      return;
    }

    const chatDoc = await admin.firestore().collection("individual_chats").doc(chatId).get();
    const chatData = chatDoc.data();

    if (!chatData) {
      console.warn(`[FCM] Chat doc not found for chatId=${chatId}`);
      return;
    }

    const participants = (chatData.participants ?? []) as string[];
    const recipientId = participants.find((id: string) => id !== senderId);

    if (!recipientId) {
      console.warn("[FCM] Could not determine recipientId from participants:", participants);
      return;
    }

    console.log(`[FCM] Recipient uid=${recipientId}`);

    const token = await getFcmToken(recipientId);
    if (!token) {
      console.warn(`[FCM] No FCM token for recipientId=${recipientId} — notification skipped`);
      return;
    }

    const senderName = await getDisplayName(senderId);

    console.log(`[FCM] Sending notification from "${senderName}" to uid=${recipientId}`);

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: senderName,
          body: message.text || "New message",
        },
        data: {
          route: `/chats/individual/${chatId}`,
          chat_id: chatId,
          type: "individual_message",
          sender_id: senderId,
        },
        android: {
          notification: {channelId: "pikuru_notifications", color: "#3A7D44"},
          priority: "high",
        },
        apns: {
          payload: {aps: {sound: "default", badge: 1}},
        },
      });
      console.log(`[FCM] Notification sent successfully to uid=${recipientId}`);
    } catch (e) {
      console.error(`[FCM] Failed to send notification to uid=${recipientId}:`, e);
    }
  }
);


// ── New event notification (for all users) ────────────────────────────────────
export const onNewEvent = onDocumentCreated(
  "events/{eventId}",
  async (event) => {
    const eventData = event.data?.data();
    if (!eventData) return;

    if (!eventData.event_active) return;

    const eventId = event.params.eventId;

    const regSnap = await admin.firestore()
      .collection("registration")
      .where("fcm_token", "!=", null)
      .get();

    const tokens: string[] = regSnap.docs
      .map((d) => d.data().fcm_token as string)
      .filter(Boolean);

    if (tokens.length === 0) return;

    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: {
          title: "🎾 New Event in " + (eventData.event_prefecture || "Japan"),
          body: eventData.event_title || "A new pickleball event was added!",
        },
        data: {
          route: `/events/${eventId}`,
          event_id: eventId,
          type: "new_event",
        },
        android: {
          notification: {channelId: "pikuru_notifications", color: "#3A7D44"},
        },
        apns: {
          payload: {aps: {sound: "default"}},
        },
      });
    }
  }
);


// ── Send OTP ──────────────────────────────────────────────────────────────────
export const sendOtp = onCall(async (request) => {
  const data = request.data;
  const email = data.email as string;
  const otp = data.otp as string;

  const nickname = (data.nickname ?? "").toString().trim();
  const firstName = (data.firstName ?? "").toString().trim();
  const greeting = nickname || firstName || "there";

  if (!email || !otp) {
    throw new HttpsError("invalid-argument", "Missing required fields");
  }

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailEmail.value(),
      pass: gmailPassword.value(),
    },
  });

  const html =
    "<div style=\"font-family:Arial,sans-serif\">" +
    "<div style=\"background:#3BB273;padding:32px;text-align:center;\">" +
    "<h1 style=\"color:white;margin:0\">Pikuru</h1>" +
    "</div>" +
    "<div style=\"background:#f9f9f9;padding:32px\">" +
    "<p>Hi <strong>" + greeting + "</strong>,</p>" +
    "<p>Use the code below to complete registration.</p>" +
    "<div style=\"text-align:center;padding:24px;border:2px solid #3BB273;border-radius:12px\">" +
    "<p style=\"color:#888\">Your verification code</p>" +
    "<h2 style=\"font-size:42px;color:#3BB273;letter-spacing:12px\">" + otp + "</h2>" +
    "</div>" +
    "<p style=\"color:#999;text-align:center\">Expires in <strong>10 minutes</strong>.</p>" +
    "</div></div>";

  const mailOptions = {
    from: "\"Pikuru App\" <" + gmailEmail.value() + ">",
    to: email,
    subject: "Your Pikuru Verification Code",
    html,
  };

  try {
    await transporter.sendMail(mailOptions);
    return {success: true, message: "OTP sent successfully"};
  } catch (error) {
    console.error("Error sending email:", error);
    throw new HttpsError("internal", "Failed to send OTP email. Please try again.");
  }
});


// ── Update User Email ─────────────────────────────────────────────────────────
export const updateUserEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = request.auth.uid;
  const newEmail = request.data.newEmail as string;

  if (!newEmail) {
    throw new HttpsError("invalid-argument", "newEmail is required.");
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(newEmail)) {
    throw new HttpsError("invalid-argument", "Invalid email format.");
  }

  try {
    await admin.auth().updateUser(uid, {email: newEmail});
    console.log(`Email updated for uid=${uid}`);
    return {success: true};
  } catch (error: unknown) {
    console.error("Error updating email:", error);
    const err = error as { code?: string; message?: string };
    if (err.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already used by another account.");
    }
    throw new HttpsError("internal", "Failed to update email. Please try again.");
  }
});
