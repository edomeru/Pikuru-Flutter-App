import * as nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineString} from "firebase-functions/params";
import * as admin from "firebase-admin";

// Initialize Admin SDK (safe to call multiple times)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const gmailEmail    = defineString("GMAIL_EMAIL");
const gmailPassword = defineString("GMAIL_PASSWORD");

// ── Send OTP ──────────────────────────────────────────────────────────────────
// Accepts either 'nickname' (new) or 'firstName' (legacy) for the greeting.
// Both Flutter and web callers pass one of these; we prefer nickname so the
// email feels natural for users who chose a username-style display name.
export const sendOtp = onCall(async (request) => {
  const data      = request.data;
  const email     = data.email     as string;
  const otp       = data.otp       as string;

  // ── Greeting resolution: prefer nickname, fall back to firstName ──────────
  const nickname  = (data.nickname  ?? "").toString().trim();
  const firstName = (data.firstName ?? "").toString().trim();
  const greeting  = nickname || firstName || "there";

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
    from:    "\"Pikuru App\" <" + gmailEmail.value() + ">",
    to:      email,
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
// Called after OTP is verified on the client. Uses Admin SDK to update
// the email in Firebase Auth directly, bypassing client-side restrictions.
export const updateUserEmail = onCall(async (request) => {
  // Must be authenticated
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid      = request.auth.uid;
  const newEmail = request.data.newEmail as string;

  if (!newEmail) {
    throw new HttpsError("invalid-argument", "newEmail is required.");
  }

  // Basic email format check
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(newEmail)) {
    throw new HttpsError("invalid-argument", "Invalid email format.");
  }

  try {
    // Admin SDK updates Auth email directly — no confirmation link needed
    await admin.auth().updateUser(uid, {email: newEmail});
    console.log(`Email updated for uid=${uid} → ${newEmail}`);
    return {success: true};
  } catch (error: unknown) {
    console.error("Error updating email:", error);
    const err = error as {code?: string; message?: string};
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