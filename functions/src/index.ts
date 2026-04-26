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


// ── New message in group chat ─────────────────────────────────────────────────
export const onGroupMessage = onDocumentCreated(
  "group_chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatId = event.params.chatId;
    const senderId = message.sender_id;

    // Get all participants
    const participantsSnap = await admin.firestore()
      .collection("group_chats").doc(chatId)
      .collection("participants").get();

    const tokens: string[] = [];
    for (const p of participantsSnap.docs) {
      if (p.id === senderId) continue; // don't notify sender
      const userDoc = await admin.firestore().collection("users").doc(p.id).get();
      const token = userDoc.data()?.fcm_token;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    // Get group name
    const chatDoc = await admin.firestore().collection("group_chats").doc(chatId).get();
    const groupName = chatDoc.data()?.org_name || "Group Chat";

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

    const chatDoc = await admin.firestore().collection("individual_chats").doc(chatId).get();
    const chatData = chatDoc.data();
    const participants = chatData?.participants || [];
    const recipientId = participants.find((id: string) => id !== senderId);

    if (!recipientId) return;

    // Get recipient's FCM token from users collection
    const recipientDoc = await admin.firestore().collection("users").doc(recipientId).get();
    const token = recipientDoc.data()?.fcm_token;
    if (!token) return;

    // ── Get sender display name from registration collection ──────────────
    // registration stores firstName/lastName (email signup) or nickname (SSO)
    const senderRegDoc = await admin.firestore()
      .collection("registration").doc(senderId).get();
    const senderData = senderRegDoc.data() ?? {};

    let senderName = "Someone";
    const nickname = (senderData.nickname ?? "").toString().trim();
    const firstName = (senderData.firstName ?? "").toString().trim();
    const lastName = (senderData.lastName ?? "").toString().trim();

    if (nickname) {
      senderName = nickname;
    } else if (firstName || lastName) {
      senderName = [firstName, lastName].filter(Boolean).join(" ");
    }

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
  }
);


// ── New event notification (for all users) ────────────────────────────────────
export const onNewEvent = onDocumentCreated(
  "events/{eventId}",
  async (event) => {
    const eventData = event.data?.data();
    if (!eventData) return;

    // Only notify when an event becomes active
    if (!eventData.event_active) return;

    const eventId = event.params.eventId;

    // Get all user tokens
    const usersSnap = await admin.firestore()
      .collection("users")
      .where("fcm_token", "!=", null)
      .get();

    const tokens: string[] = usersSnap.docs
      .map((d) => d.data().fcm_token as string)
      .filter(Boolean);

    if (tokens.length === 0) return;

    // Send in batches of 500 (FCM multicast limit)
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
    "<div style=\"background:#3BB273;padding:32px;" +
    "text-align:center;\">" +
    "<h1 style=\"color:white;margin:0\">Pikuru</h1>" +
    "</div>" +
    "<div style=\"background:#f9f9f9;padding:32px\">" +
    "<p>Hi <strong>" + greeting + "</strong>,</p>" +
    "<p>Use the code below to complete registration.</p>" +
    "<div style=\"text-align:center;padding:24px;" +
    "border:2px solid #3BB273;border-radius:12px\">" +
    "<p style=\"color:#888\">Your verification code</p>" +
    "<h2 style=\"font-size:42px;color:#3BB273;" +
    "letter-spacing:12px\">" + otp + "</h2>" +
    "</div>" +
    "<p style=\"color:#999;text-align:center\">" +
    "Expires in <strong>10 minutes</strong>.</p>" +
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
    throw new HttpsError(
      "internal",
      "Failed to send OTP email. Please try again."
    );
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
    console.log(`Email updated for uid=${uid} → ${newEmail}`);
    return {success: true};
  } catch (error: unknown) {
    console.error("Error updating email:", error);
    const err = error as { code?: string; message?: string };
    if (err.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "This email is already used by another account."
      );
    }
    throw new HttpsError(
      "internal",
      "Failed to update email. Please try again."
    );
  }
});
