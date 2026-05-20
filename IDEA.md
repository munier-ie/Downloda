# PRD — `dwldr`

## Product Name

`dwldr`

---

# 1. Product Overview

`dwldr` is an open-source cross-platform media downloader that integrates directly into the native mobile share workflow, allowing users to instantly download media from supported social media apps without interrupting their browsing experience.

The app prioritizes:

* zero-friction interaction
* background execution
* power efficiency
* reliability
* clean native UX

Users simply share media to `dwldr`, after which downloads begin immediately using preconfigured settings while progress is managed through notifications and the dashboard app.

---

# 2. Core Problem

Existing downloader workflows are inefficient because users must:

* copy links
* switch apps
* paste URLs
* manually configure downloads
* wait inside downloader apps

This creates unnecessary interruption and friction.

---

# 3. Product Vision

> “A seamless background media acquisition utility.”

The app should feel:

* instant
* invisible
* lightweight
* system-native

---

# 4. Target Platforms

## MVP

* Android

## Future

* iOS

---

# 5. Supported Platforms (Media Sources)

## MVP

* YouTube
* Instagram
* TikTok

## Post-MVP

* Facebook
* WhatsApp Status Saver

---

# 6. Core User Flow

```text
User taps Share
↓
Selects dwldr
↓
Minimal snackbar appears:
“Download started”
↓
Download begins instantly using saved preset
↓
User continues browsing immediately
↓
Notifications manage all download interaction
```

---

# 7. Core Features

---

# 7.1 Native Share Integration

## Description

`dwldr` registers as a native share target.

Users can share:

* video links
* reels
* shorts
* posts
* media URLs

directly into the app.

---

## Requirements

* near-instant share handling
* no modal interruption
* no mandatory confirmation UI

---

# 7.2 Silent Instant Downloads

## Description

Downloads begin immediately after share action.

## Requirements

* use preconfigured settings
* no repeated quality selection
* no unnecessary dialogs

---

# 7.3 Minimal Snackbar Feedback

## Behavior

After share:

```text
Download started
```

The snackbar:

* disappears automatically
* contains no heavy interaction

---

# 7.4 Notification Download Center

Notifications become the primary operational interface.

---

## Notifications Must Display

* progress bar
* file name
* percentage
* current download speed
* estimated remaining time
* queue state
* current status

---

## Notification Actions

* Pause
* Resume
* Cancel
* Retry
* Pause All
* Open Queue

---

## Notification States

* Preparing
* Downloading
* Queued
* Paused
* Processing
* Completed
* Failed

---

# 7.5 Download Queue System

## Features

* multiple downloads
* queue prioritization
* reorder queue
* pause/resume individual items
* bulk queue operations

---

# 7.6 Resumable Downloads

Downloads must resume after:

* app closure
* force stop
* network interruption
* device reboot

---

## Requirements

* persistent task state
* partial file support
* automatic recovery

---

# 7.7 Download Dashboard

The main app acts as:

* settings center
* queue manager
* download history
* diagnostics panel

---

# Dashboard Sections

---

## Downloads

* active
* queued
* completed
* failed
* paused

---

## Smart Download Presets

User-configurable:

* default resolution
* format preference
* audio-only mode
* automatic download behavior
* simultaneous download limit

---

## Queue Controls

* reorder downloads
* prioritize tasks
* retry failed items
* bulk pause/cancel

---

## Notification Controls

* compact mode
* persistent notifications
* sound/vibration

---

## Battery & Network

* WiFi-only mode
* battery saver mode
* pause on low battery
* auto resume on reconnect

---

## Storage Management

* download location
* cleanup tools
* duplicate handling
* storage usage display

---

## Platform Modules

Enable/disable support for:

* YouTube
* Instagram
* TikTok
* Facebook

---

# 7.8 WhatsApp Status Saver

Dedicated section for:

* viewing statuses
* saving image/video statuses
* managing saved statuses

---

# 8. UX Principles

The app must feel:

* fast
* invisible
* native
* interruption-free

---

## UX Rules

* no floating overlays
* no unnecessary popups
* no forced navigation
* no repeated confirmations

---

# 9. Power Efficiency Requirements

The app must:

* avoid continuous background monitoring
* avoid overlays/accessibility polling
* use event-driven execution only
* remain nearly idle when unused

---

## Goal

Near-zero idle battery consumption.

---

# 10. Security & Stability Philosophy

The app:

* only responds to user-triggered actions
* does not automate external apps
* avoids intrusive system behavior
* minimizes risky permissions

---

# 11. Permissions

## Android

* INTERNET
* FOREGROUND_SERVICE
* POST_NOTIFICATIONS
* RECEIVE_BOOT_COMPLETED

---

## Optional

* storage/media permissions
* notification permission

---

# 12. Technical Architecture

---

# Frontend

## Framework

Flutter

---

## State Management

Riverpod

---

## Navigation

GoRouter

---

# Native Platform Layers

## Android

Kotlin

---

## iOS

Swift

---

# Background Downloads

## Android

* WorkManager
* Foreground Services

---

## iOS

* URLSession Background Tasks

---

# Networking

## Flutter Layer

Dio

---

## Native Android Layer

OkHttp

---

# Database

## Local Database

SQLite

---

## ORM

Drift

---

# Media Processing

## Extraction

yt-dlp integration

---

## Processing

FFmpeg

---

# Storage

## Android

Scoped Storage APIs

---

## iOS

Sandboxed App Storage

---

# Architecture Pattern

## App Architecture

Clean Architecture

---

## Presentation

MVVM

---

# Async Handling

## Flutter

Dart Isolates

---

## Android

Kotlin Coroutines + Flow

---

# Dependency Injection

## Flutter

Riverpod Providers

---

## Android Native

Hilt

---

# 13. Performance Targets

## Startup Time

< 2 seconds

---

## Share-to-download latency

< 1 second

---

## Idle battery usage

Near zero

---

## Download reliability

High recovery success after interruption

---

# 14. Open Source Goals

The project should:

* maintain modular architecture
* support future platform modules
* encourage community contribution
* remain transparent and privacy-friendly

---

# 15. Future Expansion

---

## Additional Platforms

* Facebook
* Snapchat
* Twitter/X
* Reddit

---

## Future Features

* audio extraction
* subtitle download
* cloud sync
* plugin architecture
* smart media categorization
* auto cleanup rules

---

# 16. Final Product Definition

`dwldr` is a lightweight, background-first media acquisition utility that integrates directly into native mobile sharing workflows, enabling instant downloads with minimal interruption, strong reliability, and efficient system resource usage.
