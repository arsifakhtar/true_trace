// backend/index.js
// TrueTrace backend - Updated to match API Specification

const express = require("express");
const admin = require("firebase-admin");
const cors = require("cors");
const dotenv = require("dotenv");
const path = require("path");

dotenv.config();

const app = express();
app.use(express.json());
app.use(cors());

// Serve static files from 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// ---------- Firebase Admin init ----------
if (!process.env.SERVICE_ACCOUNT_PATH) {
    console.error("SERVICE_ACCOUNT_PATH not set in .env");
    // For testing without firebase, we might want to mock, but for now we exit
    // process.exit(1); 
    console.warn("⚠️ WARNING: Firebase Admin NOT initialized. API calls will fail.");
} else {
    try {
        const saPath = path.resolve(process.env.SERVICE_ACCOUNT_PATH);
        admin.initializeApp({
            credential: admin.credential.cert(require(saPath)),
        });
        console.log("✅ Firebase Admin initialized.");
    } catch (err) {
        console.error("❌ Failed to init Firebase Admin:", err);
    }
}

const db = admin.firestore();

// ---------- Middleware: verify ID token ----------
async function verifyIdToken(req, res, next) {
    const auth = req.headers.authorization;
    if (!auth) return res.status(401).json({ error: "Missing Authorization header" });
    const parts = auth.split(" ");
    if (parts.length !== 2) return res.status(401).json({ error: "Invalid Authorization header" });
    const token = parts[1];
    try {
        const decoded = await admin.auth().verifyIdToken(token);
        req.user = decoded;
        next();
    } catch (err) {
        console.error("verifyIdToken error:", err);
        return res.status(401).json({ error: "Invalid ID token" });
    }
}

// ---------- Helper: send big notification (topic or token) ----------
async function sendBigNotification({ toTopic = null, toToken = null, title, body, imageUrl = null, data = {}, priority = "high", fullScreen = false }) {
    // Build Android-specific message
    const message = {
        android: {
            priority: priority, // high or normal
            notification: {
                title: title,
                body: body,
                imageUrl: imageUrl || undefined,
                channelId: "lost_mode_channel", // Match the channel ID in Flutter app
                // Add fullScreenIntent support if requested
                ...(fullScreen ? { priority: "max", visibility: "public" } : {}),
            },
            ttl: 60 * 60 * 1000, // 1 hour in ms
        },
        notification: {
            title,
            body,
            imageUrl: imageUrl || undefined,
        },
        data: Object.assign({}, data),
    };

    try {
        if (toTopic) {
            message.topic = toTopic;
            return await admin.messaging().send(message);
        } else if (toToken) {
            message.token = toToken;
            return await admin.messaging().send(message);
        } else {
            throw new Error("Must provide toTopic or toToken");
        }
    } catch (e) {
        console.error("Notification send error:", e);
    }
}

// ---------- Root ----------
app.get("/", (req, res) => res.json({ ok: true, service: "TrueTrace Backend v2" }));

// ---------- 1. Device Registration ----------
// Matches POST /api/devices
app.post("/api/devices", verifyIdToken, async (req, res) => {
    try {
        const {
            deviceId,
            model,
            manufacturer,
            osVersion,
            sdkInt,
            imei,
            androidId,
            fcmToken,
            publicPhone,
            deviceToken, // BLE Token (Critical for Finder Mode)
        } = req.body;

        if (!deviceId) return res.status(400).json({ error: "deviceId required" });

        const now = new Date().toISOString();
        const deviceRef = db.collection("devices").doc(deviceId);

        // Save/merge
        await deviceRef.set(
            {
                ownerUid: req.user.uid,
                model: model || null,
                manufacturer: manufacturer || null,
                osVersion: osVersion || null,
                sdkInt: sdkInt || null,
                imei: imei || null,
                androidId: androidId || null,
                fcmToken: fcmToken || null,
                publicPhone: publicPhone || null,
                deviceToken: deviceToken || null, // Saved!
                status: "active", // Default status
                createdAt: now, // Should use serverTimestamp in real app but this is fine
                updatedAt: now,
            },
            { merge: true }
        );

        res.json({ ok: true, deviceId, message: "Device registered" });
    } catch (err) {
        console.error("/api/devices error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 2. Set Lost Mode ----------
// Matches POST /api/set-lost
app.post("/api/set-lost", verifyIdToken, async (req, res) => {
    try {
        const { deviceId, isLost, message } = req.body;

        if (!deviceId || isLost === undefined) {
            return res.status(400).json({ error: "deviceId and isLost required" });
        }

        const deviceRef = db.collection("devices").doc(deviceId);
        const deviceSnap = await deviceRef.get();
        if (!deviceSnap.exists) return res.status(404).json({ error: "device_not_found" });

        const deviceData = deviceSnap.data();

        // ENFORCE OWNER
        if (deviceData.ownerUid !== req.user.uid) {
            return res.status(403).json({ error: "not_owner" });
        }

        const now = new Date().toISOString();
        const status = isLost ? "lost" : "active";

        await deviceRef.update({
            status: status,
            lostMessage: isLost ? (message || null) : null,
            updatedAt: now,
        });

        if (isLost) {
            // Create Lost Report
            await db.collection("lost_reports").add({
                deviceId,
                ownerUid: req.user.uid,
                message: message || "",
                status: "open",
                timestamp: now,
            });

            // Notify Finders (Topic: finders)
            const notifTitle = `Lost: ${deviceData.model || "Device"}`;
            const notifBody = message || "A device has been reported lost. Keep an eye out!";

            await sendBigNotification({
                toTopic: "finders",
                title: notifTitle,
                body: notifBody,
                data: { deviceId, type: "device_lost" }
            });

            // CRITICAL: Notify the device itself to lock screen!
            if (deviceData.fcmToken) {
                await sendBigNotification({
                    toToken: deviceData.fcmToken,
                    title: "🔴 LOST MODE ACTIVATED",
                    body: "This device has been marked as lost.",
                    priority: "high",
                    fullScreen: true,
                    data: {
                        deviceId,
                        type: "lost_mode_enable",
                        message: message || ""
                    }
                });
            }
        } else {
            // Close open reports
            const reports = await db.collection("lost_reports")
                .where("deviceId", "==", deviceId)
                .where("status", "==", "open")
                .get();

            const batch = db.batch();
            reports.forEach(doc => batch.update(doc.ref, { status: "closed", closedAt: now }));
            await batch.commit();
        }

        res.json({ ok: true, message: `Device marked as ${status}` });
    } catch (err) {
        console.error("/api/set-lost error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 3. Get Device Status ----------
// Matches GET /api/device-status/{deviceId}
app.get("/api/device-status/:deviceId", async (req, res) => {
    try {
        const { deviceId } = req.params;
        const doc = await db.collection("devices").doc(deviceId).get();

        if (!doc.exists) return res.status(404).json({ error: "not_found" });

        const data = doc.data();
        res.json({
            deviceId,
            isLost: data.status === "lost",
            isLocked: data.isLocked || false,
            lastSeen: data.lastSeen || null,
            status: data.status,
            batteryLevel: data.batteryLevel || "Unknown",
            lastLocation: data.lastLocation || null,
            model: data.model || "Unknown"
        });
    } catch (err) {
        console.error("/api/device-status error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 4. Report Found Device (Finder Mode) ----------
// Matches POST /api/found
app.post("/api/found", verifyIdToken, async (req, res) => {
    try {
        const { deviceToken, message, finderLocation, isBackground } = req.body;

        if (!deviceToken) return res.status(400).json({ error: "deviceToken required" });

        // 1. Find device by BLE token
        const snapshot = await db.collection("devices").where("deviceToken", "==", deviceToken).limit(1).get();

        if (snapshot.empty) {
            return res.status(404).json({ error: "device_not_registered" });
        }

        const deviceDoc = snapshot.docs[0];
        const deviceData = deviceDoc.data();
        const deviceId = deviceDoc.id;

        const now = new Date().toISOString();

        // 2. Create Found Report
        await db.collection("found_reports").add({
            deviceId,
            deviceToken,
            finderUid: req.user.uid,
            message: message || "",
            finderLocation: finderLocation || null,
            isBackground: isBackground || false,
            timestamp: now,
        });

        // 3. Update Device Last Seen
        await deviceDoc.ref.update({
            lastSeen: now,
            lastSeenLocation: finderLocation || null
        });

        // 4. Notify Owner
        if (deviceData.fcmToken) {
            await sendBigNotification({
                toToken: deviceData.fcmToken,
                title: "🎉 Device Found!",
                body: `Your ${deviceData.model || "device"} was detected nearby!`,
                data: {
                    deviceId,
                    type: "device_found",
                    lat: finderLocation?.lat?.toString(),
                    lng: finderLocation?.lng?.toString()
                },
                priority: "high",
                fullScreen: true // Try to wake up owner's phone
            });
        }

        res.json({ ok: true, message: "Report submitted" });
    } catch (err) {
        console.error("/api/found error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 5. Telemetry Upload ----------
// Matches POST /api/telemetry
app.post("/api/telemetry", verifyIdToken, async (req, res) => {
    try {
        const { deviceId, telemetry } = req.body; // telemetry object contains battery, gps, etc.

        if (!deviceId) return res.status(400).json({ error: "deviceId required" });

        // Save to subcollection or top-level collection
        await db.collection("devices").doc(deviceId).collection("telemetry").add({
            ...telemetry,
            serverTimestamp: new Date().toISOString()
        });

        // Optionally update main device doc with latest battery/location
        const updates = {};
        if (telemetry?.battery) updates.batteryLevel = telemetry.battery;
        if (telemetry?.gps) updates.lastLocation = telemetry.gps;

        if (Object.keys(updates).length > 0) {
            await db.collection("devices").doc(deviceId).update(updates);
        }

        res.json({ ok: true });
    } catch (err) {
        console.error("/api/telemetry error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 6. Notify Device (Manual Push) ----------
// Matches POST /api/notify
app.post("/api/notify", verifyIdToken, async (req, res) => {
    try {
        const { deviceId, title, body, priority, fullScreen } = req.body;

        const doc = await db.collection("devices").doc(deviceId).get();
        if (!doc.exists) return res.status(404).json({ error: "not_found" });

        const data = doc.data();
        if (!data.fcmToken) return res.status(400).json({ error: "no_fcm_token" });

        if (data.ownerUid !== req.user.uid) return res.status(403).json({ error: "not_owner" });

        await sendBigNotification({
            toToken: data.fcmToken,
            title: title || "Notification",
            body: body || "Alert from TrueTrace",
            priority: priority || "high",
            fullScreen: fullScreen || false,
            data: { deviceId, type: "manual_alert" }
        });

        res.json({ ok: true });
    } catch (err) {
        console.error("/api/notify error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 7. List User Devices ----------
// Matches GET /api/devices
app.get("/api/devices", verifyIdToken, async (req, res) => {
    try {
        const snapshot = await db.collection("devices")
            .where("ownerUid", "==", req.user.uid)
            .get();

        const devices = [];
        snapshot.forEach(doc => {
            devices.push({ id: doc.id, ...doc.data() });
        });

        res.json({ ok: true, devices });
    } catch (err) {
        console.error("/api/devices GET error:", err);
        res.status(500).json({ error: "server_error" });
    }
});

// ---------- 404 Handler (Must be last) ----------
app.use((req, res) => {
    res.status(404).json({ error: "endpoint_not_found" });
});

// ---------- Start Server ----------
const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`TrueTrace Backend running on port ${PORT}`));
