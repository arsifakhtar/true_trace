# TrueTrace

TrueTrace is a Bluetooth Low Energy (BLE) based Lost & Found platform designed to help users recover lost devices securely through ownership verification and finder-assisted recovery workflows.

## Overview

Losing personal devices is a common problem, and existing solutions are often limited to specific ecosystems. TrueTrace aims to provide a platform-independent recovery system that allows device owners to register devices, activate lost mode, and securely reconnect with finders while protecting ownership information.

## Features

### Device Registration

* Register BLE-enabled devices.
* Store ownership information securely.
* Generate unique device identifiers.

### Lost Mode

* Mark devices as lost.
* Allow nearby users to detect lost devices.
* Notify owners when a lost device is discovered.

### Finder Mode

* Detect registered lost devices using BLE.
* Submit recovery information securely.
* Enable communication without exposing personal details.

### Ownership Verification

* OTP-based verification process.
* Secure ownership transfer workflow.
* Protection against unauthorized claims.

### User Authentication

* Secure login and registration.
* User profile management.
* Device ownership management.

## Technology Stack

### Mobile Application

* Flutter

### Backend

* Node.js
* Express.js

### Database

* Firebase Firestore

### Connectivity

* Bluetooth Low Energy (BLE)

### Authentication

* Firebase Authentication

## System Architecture

User App
↓
Flutter Mobile Application
↓
Firebase Authentication
↓
Node.js Backend APIs
↓
Firebase Firestore Database
↓
BLE Communication Layer

## Project Status

Current Progress:

* Device Registration System ✅
* User Authentication ✅
* Lost Mode 🚧
* Finder Mode 🚧
* Ownership Verification 🚧
* Device Recovery Workflow 🚧

## Challenges Solved

* Secure device ownership verification.
* BLE-based device discovery.
* Privacy-preserving finder communication.
* Cross-platform mobile development.

## Future Enhancements

* Real-time recovery notifications.
* Geofencing support.
* Device location analytics.
* QR-based ownership verification.
* End-to-end encrypted recovery communication.

## Installation

### Clone Repository

```bash
git clone https://github.com/arsifakhtar/truetrace.git
cd truetrace
```

### Install Dependencies

```bash
flutter pub get
```

### Run Application

```bash
flutter run
```

## Screenshots

Add screenshots here:

* Login Screen
* Device Registration
* Lost Mode
* Finder Mode
* User Dashboard

## Author

Arsif Akhtar

GitHub: https://github.com/arsifakhtar

LinkedIn: https://linkedin.com/in/arsif

## License

This project is licensed under the MIT License.
