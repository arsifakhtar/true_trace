# API Specification for TrueTrace Mobile App

## Overview
This document lists the REST endpoints the Flutter mobile app will consume. All endpoints are assumed to be hosted under a base URL (e.g., `https://api.truetrace.com`). The API uses JSON payloads and standard HTTP status codes.

---

## 1. Device Registration
- **Endpoint**: `POST /api/devices`
- **Description**: Register a new device or update existing registration details.
- **Request Body**:
  ```json
  {
    "androidId": "string",
    "model": "string",
    "manufacturer": "string",
    "osVersion": "string",
    "sdkInt": 30,
    "deviceToken": "string",
    "publicPhone": "string",
    "deviceId": "string"
  }
  ```
- **Response**: `201 Created` with the stored device record.

---

## 2. Set Lost Mode
- **Endpoint**: `POST /api/set-lost`
- **Description**: Toggle the lost state of a device.
- **Request Body**:
  ```json
  {
    "deviceId": "string",
    "isLost": true
  }
  ```
- **Response**: `200 OK` with a confirmation message.

---

## 3. Get Device Status
- **Endpoint**: `GET /api/device-status/{deviceId}`
- **Description**: Retrieve the current lost/found status for a device.
- **Response**:
  ```json
  {
    "deviceId": "string",
    "isLost": true,
    "lastSeen": "2025-11-29T12:34:56Z"
  }
  ```

---

## 4. Report Found Device (Finder Mode)
- **Endpoint**: `POST /api/found`
- **Description**: Notify the backend that a lost device has been detected by a finder.
- **Request Body**:
  ```json
  {
    "token": "string",               // BLE token of the lost device
    "message": "Detected nearby",
    "finderLocation": {
      "lat": 12.3456,
      "lng": 78.9012
    },
    "isBackground": true             // NEW: Indicates if detection happened in background
  }
  ```
- **Response**: `200 OK` with a success acknowledgment.

---

## 5. Telemetry Upload
- **Endpoint**: `POST /api/telemetry`
- **Description**: Periodic upload of device telemetry data.
- **Request Body**:
  ```json
  {
    "deviceId": "string",
    "battery": 87,
    "isLocked": false,
    "gps": { "lat": 12.34, "lng": 56.78 },
    "network": "wifi",
    "timestamp": "2025-11-29T12:34:56Z"
  }
  ```
- **Response**: `200 OK`.

---

## 6. List Devices (Admin / Dashboard)
- **Endpoint**: `GET /api/devices`
- **Description**: Retrieve a list of all registered devices (used by the web dashboard).
- **Response**: Array of device objects.

---

## 7. Notify Device (Push Notification)
- **Endpoint**: `POST /api/notify`
- **Description**: Send a high-priority push notification to a specific device. Used to trigger "Lost Mode" alerts that appear on the lock screen.
- **Request Body**:
  ```json
  {
    "deviceId": "string",
    "title": "Device Lost",
    "body": "Your device is now in Lost Mode",
    "priority": "high",              // NEW: Request high priority delivery
    "fullScreen": true               // NEW: Request full screen intent (lock screen)
  }
  ```
- **Response**: `200 OK`.

---

## Authentication & Security
- All endpoints require a valid Firebase ID token in the `Authorization: Bearer <token>` header.
- Use HTTPS for all communication.

---

*Generated for the TrueTrace mobile application – ready for backend implementation.*
