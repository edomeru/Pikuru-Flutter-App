import * as nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {defineString} from "firebase-functions/params";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const gmailEmail = defineString("GMAIL_EMAIL");
const gmailPassword = defineString("GMAIL_PASSWORD");

// Line 15 — getFcmToken
/**
 * Retrieves the FCM token for a given user ID.
 * @param {string} uid - The user ID.
 * @return {Promise<string | null>} The FCM token or null.
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

// Line 33 — getDisplayName
/**
 * Returns the display name for a given user ID.
 * @param {string} uid - The user ID.
 * @return {Promise<string>} The display name.
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

// Line 51 — getGroupName
/**
 * Resolves the display name and metadata from a group_chats document.
 * Returns an object with the resolved title and event-chat flags.
 * @param {string} chatId - The chat document ID.
 * @return {Promise<object>} The chat metadata.
 */
async function getGroupChatMeta(chatId: string): Promise<{
  name: string;
  chatType: string;
  notifRoute: string;
  notifTab: string;
  notifTitle: string;
}> {
  const defaults = {
    name: "Group Chat",
    chatType: "group",
    notifRoute: `/chats/group/${chatId}`,
    notifTab: "general",
    notifTitle: "",
  };

  try {
    const chatDoc = await admin.firestore().collection("group_chats").doc(chatId).get();
    const chatData = chatDoc.data() ?? {};

    const chatType = (chatData.chat_type ?? "").toString().trim();
    const isEventChat =
      chatType === "event" ||
      chatId.startsWith("event_") ||
      (chatData.notification_route ?? "").toString().startsWith("/chats/event/");

    // Resolve the best human-readable title
    let name: string = defaults.name;
    const notifTitle = (chatData.notification_title ?? chatData.event_name ?? chatData.name ?? "").toString().trim();
    if (notifTitle) {
      name = notifTitle;
    } else if (!isEventChat) {
      // For regular group chats fall back to org_name lookup
      const directName = (chatData.org_name ?? "").toString().trim();
      if (directName) {
        name = directName;
      } else {
        const orgId = (chatData.org_id ?? chatId).toString().trim();
        if (orgId) {
          const orgDoc = await admin.firestore().collection("organizations").doc(orgId).get();
          if (orgDoc.exists) {
            const n = (orgDoc.data()?.org_name ?? "").toString().trim();
            if (n) name = n;
          }
          if (name === defaults.name) {
            const orgSnap = await admin.firestore()
              .collection("organizations")
              .where("org_id", "==", orgId)
              .limit(1)
              .get();
            if (!orgSnap.empty) {
              const n = (orgSnap.docs[0].data()?.org_name ?? "").toString().trim();
              if (n) name = n;
            }
          }
        }
      }
    }

    const notifRoute = isEventChat ?
      `/chats/event/${chatId}` :
      `/chats/group/${chatId}`;

    return {
      name,
      chatType: isEventChat ? "event" : "group",
      notifRoute,
      notifTab: defaults.notifTab, // resolved per-message in the trigger
      notifTitle,
    };
  } catch (e) {
    console.error(`[FCM] getGroupChatMeta error for chatId=${chatId}:`, e);
    return defaults;
  }
}

/**
 * Sends a multicast FCM notification and logs detailed success/failure states.
 * @param {admin.messaging.MulticastMessage} payload - The multicast message payload.
 * @return {Promise<void>}
 */
async function sendMulticastAndLog(
  payload: admin.messaging.MulticastMessage
): Promise<void> {
  try {
    const res = await admin.messaging().sendEachForMulticast(payload);
    console.log(`[FCM] Multicast stats: successCount=${res.successCount}, failureCount=${res.failureCount}`);
    if (res.failureCount > 0) {
      res.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`  [FCM] Token index ${idx} failed (${payload.tokens[idx].substring(0, 15)}...):`, resp.error);
        }
      });
    }
  } catch (e) {
    console.error("[FCM] Multicast execution crashed:", e);
  }
}

// ── New message in group chat ─────────────────────────────────────────────────
export const onGroupMessage = onDocumentCreated(
  "group_chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = message.sender_id;

    console.log(`[FCM] Group message in chatId=${chatId} from senderId=${senderId}`);

    // ── Determine if this message is a broadcast / announcement ───────────
    const isBroadcast: boolean =
      message.is_broadcast === true ||
      (message.type ?? "").toString() === "broadcast" ||
      (message.type ?? "").toString() === "announcement";

    // ── Resolve chat metadata (name, type, route) ─────────────────────────
    const chatMeta = await getGroupChatMeta(chatId);
    console.log(`[FCM] Resolved chat meta: name="${chatMeta.name}", type=${chatMeta.chatType}`);

    // For event chats the route and tab must reflect the message's broadcast flag.
    const notifTab: string = isBroadcast ? "announcements" : "general";
    const notifRoute: string =
      chatMeta.chatType === "event" ?
        `${chatMeta.notifRoute}?tab=${notifTab}` :
        chatMeta.notifRoute;

    // Use the per-message notification_title if available, else fall back to the chat name.
    const notifTitle: string =
      ((message.notification_title ?? message.event_name ?? chatMeta.notifTitle) || chatMeta.name).toString().trim();

    // ── Resolve recipients ────────────────────────────────────────────────
    // The participants subcollection holds per-user silenced state. Membership,
    // however, is defined differently per chat type:
    //   • EVENT chats → approved event_registrations + the creator/organizer.
    //     (Deliberately NOT the raw participants list, so stale participant docs
    //      from non-registered users can never receive notifications.)
    //   • GROUP chats → the participants subcollection.
    const participantsSnap = await admin.firestore()
      .collection("group_chats").doc(chatId)
      .collection("participants").get();

    // Map of uid -> isSilenced (from participant docs).
    const silencedByUid: Record<string, boolean> = {};
    for (const p of participantsSnap.docs) {
      silencedByUid[p.id] = p.data()?.is_silenced === true;
    }

    const recipientIds = new Set<string>();

    if (chatMeta.chatType === "event" && chatId.startsWith("event_")) {
      const eventId = chatId.substring("event_".length);
      // Approved registrants
      try {
        const regsSnap = await admin.firestore()
          .collection("event_registrations")
          .where("event_id", "==", eventId)
          .where("status", "==", "approved")
          .get();
        for (const r of regsSnap.docs) {
          const uid = (r.data()?.user_id ?? "").toString();
          if (uid) recipientIds.add(uid);
        }
        console.log(`[FCM] Event ${eventId}: ${regsSnap.size} approved registrants`);
      } catch (e) {
        console.error(`[FCM] Failed to fetch approved registrations for eventId=${eventId}:`, e);
      }
      // Creator / organizer of the chat
      try {
        const chatSnap = await admin.firestore().collection("group_chats").doc(chatId).get();
        const createdBy = (chatSnap.data()?.created_by ?? "").toString();
        if (createdBy) recipientIds.add(createdBy);
      } catch (e) {
        console.error(`[FCM] Failed to fetch chat creator for chatId=${chatId}:`, e);
      }
    } else {
      // Group chat: participants are the members.
      for (const p of participantsSnap.docs) {
        recipientIds.add(p.id);
      }
    }
    console.log(`[FCM] ${recipientIds.size} total recipients for chatId=${chatId}`);

    const normalTokens: string[] = [];
    const silentTokens: string[] = [];

    for (const uid of recipientIds) {
      if (uid === senderId) continue;

      const token = await getFcmToken(uid);
      if (!token) continue;

      if (silencedByUid[uid] === true) {
        console.log(`[FCM] uid=${uid} silenced — queuing silent notification`);
        silentTokens.push(token);
      } else {
        normalTokens.push(token);
      }
    }

    // Build the shared data payload — all values must be strings for FCM.
    const sharedData: Record<string, string> = {
      chat_id: chatId,
      message_id: messageId,
      chat_type: chatMeta.chatType,
      notification_route: notifRoute,
      notification_tab: notifTab,
      is_broadcast: isBroadcast ? "true" : "false",
      ...(chatMeta.chatType === "event" ?
        {route: notifRoute} :
        {route: `/chats/group/${chatId}`}),
      ...(notifTitle ? {notification_title: notifTitle} : {}),
    };

    // ── Normal notifications (sound + vibration) ──────────────────────────
    if (normalTokens.length > 0) {
      console.log(`[FCM] Sending normal notification to ${normalTokens.length} device(s), broadcast=${isBroadcast}`);
      await sendMulticastAndLog({
        tokens: normalTokens,
        notification: {
          title: notifTitle || chatMeta.name,
          body: message.text || (isBroadcast ? "New announcement" : "New message"),
        },
        data: {
          ...sharedData,
          silenced: "false",
          type: (message.type ?? (isBroadcast ? "broadcast" : "group_message")).toString(),
        },
        android: {
          notification: {
            channelId: "pikuru_notifications",
            color: "#3A7D44",
          },
          priority: "high",
        },
        apns: {
          payload: {aps: {sound: "default", badge: 1}},
        },
      });
    }

    // ── Silent notifications (no sound, no vibration) ─────────────────────
    if (silentTokens.length > 0) {
      console.log(`[FCM] Sending silent notification to ${silentTokens.length} device(s), broadcast=${isBroadcast}`);
      await sendMulticastAndLog({
        tokens: silentTokens,
        data: {
          ...sharedData,
          silenced: "true",
          type: (message.type ?? (isBroadcast ? "broadcast" : "group_message")).toString(),
          title: notifTitle || chatMeta.name,
          body: message.text || (isBroadcast ? "New announcement" : "New message"),
        },
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              "content-available": 1,
            },
          },
          headers: {
            "apns-priority": "5",
          },
        },
      });
    }

    if (normalTokens.length === 0 && silentTokens.length === 0) {
      console.warn("[FCM] No tokens found for any participant");
    } else {
      console.log("[FCM] Group notifications dispatched successfully");
    }
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
      console.warn("[FCM] Could not determine recipientId:", participants);
      return;
    }

    const token = await getFcmToken(recipientId);
    if (!token) {
      console.warn(`[FCM] No FCM token for recipientId=${recipientId}`);
      return;
    }

    const senderName = await getDisplayName(senderId);
    console.log(`[FCM] Sending individual notification from "${senderName}" to uid=${recipientId}`);

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
          silenced: "false",
        },
        android: {
          notification: {channelId: "pikuru_notifications", color: "#3A7D44"},
          priority: "high",
        },
        apns: {
          payload: {aps: {sound: "default", badge: 1}},
        },
      });
      console.log(`[FCM] Individual notification sent to uid=${recipientId}`);
    } catch (e) {
      console.error(`[FCM] Failed to send notification to uid=${recipientId}:`, e);
    }
  }
);

// ── New event notification ────────────────────────────────────────────────────
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
    const err = error as {code?: string; message?: string};
    if (err.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already used by another account.");
    }
    throw new HttpsError("internal", "Failed to update email. Please try again.");
  }
});

// ── Delete User by Admin ──────────────────────────────────────────────────────
export const deleteUserByAdmin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const callerUid = request.auth.uid;

  // Verify caller is an admin
  try {
    const callerDoc = await admin.firestore().collection("registration").doc(callerUid).get();
    const callerData = callerDoc.data();
    if (!callerData || callerData.is_admin !== true) {
      throw new HttpsError("permission-denied", "Only administrators can delete users.");
    }
  } catch (error) {
    throw new HttpsError("permission-denied", "Authorization check failed.");
  }

  const targetUid = request.data.uid as string;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Target user ID is required.");
  }

  try {
    // 1. Delete from Firebase Auth
    await admin.auth().deleteUser(targetUid);
    console.log(`[Admin] Deleted Auth user: ${targetUid}`);

    // 2. Delete from Firestore registration collection
    await admin.firestore().collection("registration").doc(targetUid).delete();
    console.log(`[Admin] Deleted registration document for: ${targetUid}`);

    return {success: true, message: "User deleted successfully"};
  } catch (error: unknown) {
    console.error("Error deleting user:", error);
    const err = error as {code?: string; message?: string};
    throw new HttpsError("internal", err.message || "Failed to delete user. Please try again.");
  }
});

// ── Auto-populate loc_image when a review with images is approved ─────────────
// When an admin approves a court review that contains images, and the linked
// court (locations collection) currently has no loc_image, the first image
// from the review is written to loc_image, making it the court's cover photo.
export const onReviewApproved = onDocumentUpdated(
  "reviews/{reviewId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    // Only act when the review just became approved:
    //   review_pending_review went true → false AND review_checked went * → true
    const justApproved =
      before.review_pending_review === true &&
      after.review_pending_review === false &&
      after.review_checked === true &&
      after.rejected !== true;

    if (!justApproved) return;

    // Collect images (support both array and single-URL formats)
    const rawImages: string[] =
      Array.isArray(after.image_urls) ? after.image_urls :
        (typeof after.image_url === "string" && after.image_url ? [after.image_url] : []);

    const locId: string | undefined = after.loc_id;

    if (!locId || rawImages.length === 0) {
      console.log(`[onReviewApproved] Skipped — no locId or no images (locId=${locId}, images=${rawImages.length})`);
      return;
    }

    const db = admin.firestore();

    // Try to find the court document: first by document ID, then by loc_id field
    let courtRef: FirebaseFirestore.DocumentReference | null = null;
    let courtData: FirebaseFirestore.DocumentData | null = null;

    const directRef = db.collection("locations").doc(locId);
    const directSnap = await directRef.get();
    if (directSnap.exists) {
      courtRef = directRef;
      courtData = directSnap.data() ?? null;
    } else {
      const q = await db
        .collection("locations")
        .where("loc_id", "==", locId)
        .limit(1)
        .get();
      if (!q.empty) {
        courtRef = q.docs[0].ref;
        courtData = q.docs[0].data();
      }
    }

    if (!courtRef || !courtData) {
      console.warn(`[onReviewApproved] Court not found for locId=${locId}`);
      return;
    }

    // Only set if the court has no image yet
    if (courtData.loc_image) {
      console.log(`[onReviewApproved] Court already has loc_image — skipping (locId=${locId})`);
      return;
    }

    await courtRef.update({loc_image: rawImages[0]});
    console.log(`[onReviewApproved] Set loc_image on court locId=${locId} from approved review`);
  }
);
