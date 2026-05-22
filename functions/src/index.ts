import * as nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineString} from "firebase-functions/params";
import * as admin from "firebase-admin";

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
    console.warn(`[FCM] No fcm_token found for uid=${uid}`);
    return null;
  } catch (e) {
    console.error(`[FCM] Error fetching token for uid=${uid}:`, e);
    return null;
  }
}

/**
 * Removes a stale/invalid FCM token from Firestore.
 * @param {string} uid - The Firebase Auth user ID.
 * @param {string} token - The stale token to remove.
 * @return {Promise<void>}
 */
async function removeStaleToken(uid: string, token: string): Promise<void> {
  try {
    await admin.firestore().collection("registration").doc(uid).update({
      fcm_token: admin.firestore.FieldValue.delete(),
      fcm_tokens: admin.firestore.FieldValue.arrayRemove(token),
    });
    console.log(`[FCM] Removed stale token for uid=${uid}`);
  } catch (e) {
    console.error(`[FCM] Failed to remove stale token for uid=${uid}:`, e);
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
    const senderId = message.sender_id as string;

    console.log(`[FCM] Group message in chatId=${chatId} from senderId=${senderId}`);

    // Get the org_id from the group_chats doc
    const chatDoc = await admin.firestore()
      .collection("group_chats").doc(chatId).get();
    const chatData = chatDoc.data();

    if (!chatData) {
      console.warn(`[FCM] group_chats doc not found for chatId=${chatId}`);
      return;
    }

    const orgId = (chatData.org_id ?? "").toString();

    // org_name is not stored in group_chats doc — look it up from organizations
    let groupName = "Group Chat";
    if (orgId) {
      try {
        // Try direct doc lookup first (org_id may be the Firestore doc ID)
        const orgDoc = await admin.firestore()
          .collection("organizations").doc(orgId).get();
        if (orgDoc.exists) {
          groupName = (orgDoc.data()?.org_name ?? "Group Chat").toString();
        } else {
          // Fallback: query by org_id field
          const orgSnap = await admin.firestore()
            .collection("organizations")
            .where("org_id", "==", orgId)
            .limit(1)
            .get();
          if (!orgSnap.empty) {
            groupName = (orgSnap.docs[0].data().org_name ?? "Group Chat").toString();
          }
        }
      } catch (e) {
        console.error(`[FCM] Failed to fetch org name for orgId=${orgId}:`, e);
      }
    }

    console.log(`[FCM] orgId=${orgId}, groupName=${groupName}`);

    // KEY FIX: Get recipients from user_groups collection.
    // user_groups stores every user who has joined the org/group.
    // participants subcollection only stores users who opened the chat,
    // which misses simulator users and users who have not opened the chat yet.
    let recipientUids: string[] = [];

    if (orgId) {
      const userGroupsSnap = await admin.firestore()
        .collection("user_groups")
        .where("group_id", "==", orgId)
        .where("status", "==", "active")
        .get();

      recipientUids = userGroupsSnap.docs
        .map((d) => (d.data().user_id ?? "").toString())
        .filter((uid) => uid && uid !== senderId);

      console.log(
        `[FCM] Found ${recipientUids.length} recipients from user_groups for orgId=${orgId}`
      );
    }

    // Fallback: also check participants subcollection in case user_groups is empty
    if (recipientUids.length === 0) {
      console.warn("[FCM] No recipients in user_groups -- falling back to participants");
      const participantsSnap = await admin.firestore()
        .collection("group_chats").doc(chatId)
        .collection("participants").get();

      recipientUids = participantsSnap.docs
        .map((d) => d.id)
        .filter((uid) => uid !== senderId);

      console.log(`[FCM] Fallback: ${recipientUids.length} recipients from participants`);
    }

    if (recipientUids.length === 0) {
      console.warn("[FCM] No recipients found anywhere -- skipping notification");
      return;
    }

    // Build token map
    const tokenMap: { uid: string; token: string }[] = [];
    for (const uid of recipientUids) {
      const token = await getFcmToken(uid);
      if (token) {
        tokenMap.push({uid, token});
      } else {
        console.warn(`[FCM] No token for uid=${uid} -- skipping`);
      }
    }

    if (tokenMap.length === 0) {
      console.warn("[FCM] No FCM tokens found for any recipient");
      return;
    }

    const senderName = await getDisplayName(senderId);

    console.log(`[FCM] Sending group notification to ${tokenMap.length} devices`);

    const tokens = tokenMap.map((t) => t.token);
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: groupName,
        body: `${senderName}: ${message.text || "New message"}`,
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

    // Clean up stale tokens
    for (let idx = 0; idx < response.responses.length; idx++) {
      const res = response.responses[idx];
      if (!res.success) {
        const code = res.error?.code ?? "";
        console.error(`[FCM] Group send failed for uid=${tokenMap[idx].uid}: ${code}`);
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          await removeStaleToken(tokenMap[idx].uid, tokenMap[idx].token);
        }
      }
    }

    console.log(
      `[FCM] Group notification done. Success=${response.successCount} Fail=${response.failureCount}`
    );
  }
);


// ── New individual chat message ───────────────────────────────────────────────
export const onIndividualMessage = onDocumentCreated(
  "individual_chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatId = event.params.chatId;
    const senderId = message.sender_id as string;

    console.log(`[FCM] Individual message in chatId=${chatId} from senderId=${senderId}`);

    if (!senderId) {
      console.warn("[FCM] No sender_id on message -- skipping");
      return;
    }

    const chatDoc = await admin.firestore()
      .collection("individual_chats").doc(chatId).get();
    const chatData = chatDoc.data();

    if (!chatData) {
      console.warn(`[FCM] Chat doc not found for chatId=${chatId}`);
      return;
    }

    const participants = (chatData.participants ?? []) as string[];
    console.log(`[FCM] participants: ${JSON.stringify(participants)}`);

    const recipientId = participants.find((id: string) => id !== senderId);

    if (!recipientId) {
      console.warn("[FCM] Could not determine recipientId");
      return;
    }

    console.log(`[FCM] Recipient uid=${recipientId}`);

    const token = await getFcmToken(recipientId);
    if (!token) {
      console.warn(`[FCM] No FCM token for recipientId=${recipientId} -- skipping`);
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
    } catch (e: unknown) {
      const err = e as { code?: string; message?: string };
      console.error(`[FCM] Failed to send to uid=${recipientId}: code=${err.code} msg=${err.message}`);
      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.code === "messaging/invalid-registration-token"
      ) {
        await removeStaleToken(recipientId, token);
      }
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
