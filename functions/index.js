const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const RECOVERY_DAYS = 90;

// Runs every day at 00:10 Bangladesh time, even when the mobile app is closed.
exports.refreshDonorAvailabilityDaily = onSchedule(
  {
    schedule: "10 0 * * *",
    timeZone: "Asia/Dhaka",
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "256MiB",
  },
  async () => {
    const snapshot = await db.collection("users").where("role", "==", "donor").get();
    const now = new Date();
    const dhakaToday = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Dhaka",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(now);
    const [year, month, day] = dhakaToday.split("-").map(Number);
    const todayUtc = Date.UTC(year, month - 1, day);

    let batch = db.batch();
    let writes = 0;
    let updated = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const raw = data.lastDonationDate;

      // No recorded date: do not guess eligibility or change the user's status.
      if (!raw) continue;

      let donationDate;
      if (typeof raw === "string") {
        const match = raw.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (!match) {
          console.warn("Skipping invalid lastDonationDate for user:", doc.id, raw);
          continue;
        }
        donationDate = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
      } else if (raw && typeof raw.toDate === "function") {
        const d = raw.toDate();
        donationDate = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
      } else {
        console.warn("Skipping unsupported lastDonationDate type for user:", doc.id);
        continue;
      }

      const daysSinceDonation = Math.floor((todayUtc - donationDate) / 86400000);
      const shouldBeAvailable = daysSinceDonation >= RECOVERY_DAYS && daysSinceDonation >= 0;

      if (data.isAvailable !== shouldBeAvailable) {
        batch.update(doc.ref, {
          isAvailable: shouldBeAvailable,
          availabilityLastEvaluatedAt: now,
        });
        writes++;
        updated++;
      }

      // Firestore batches are limited to 500 writes.
      if (writes === 450) {
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
    }

    if (writes > 0) await batch.commit();
    console.log(`Daily donor availability check complete. Users scanned: ${snapshot.size}; updated: ${updated}`);
  }
);
