# Cloudflare Email Routing Setup for pitanga.cloud

This guide explains how to configure free email forwarding for `pitanga.cloud` using Cloudflare Email Routing.

## Overview

Cloudflare Email Routing allows you to create custom email addresses for your domain and forward them to your primary email address (e.g., Gmail).

## Prerequisites

1. Domain `pitanga.cloud` must be active on Cloudflare.
2. Access to the Cloudflare Dashboard.
3. A destination email address (e.g., `rafa.oliveira1@gmail.com`).

## Configuration Steps

### 1. Enable Email Routing

1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Select the `pitanga.cloud` domain.
3. In the sidebar, go to **Email** > **Email Routing**.
4. Click **Get started**.

### 2. Set Up Destination Address

1. In the **Destination addresses** tab, click **Add destination address**.
2. Enter `rafa.oliveira1@gmail.com`.
3. Cloudflare will send a verification email to that address. Follow the link in the email to verify it.

### 3. Create Routing Rules

1. In the **Routing rules** tab, click **Create address**.
2. **Custom address**: Enter `contact` (creates `contact@pitanga.cloud`).
3. **Action**: Select `Forward to destination`.
4. **Destination address**: Select `rafa.oliveira1@gmail.com`.
5. Click **Save**.
6. Repeat for `raolivei` (creates `raolivei@pitanga.cloud`).

### 4. Configure DNS Records

1. Cloudflare will detect if the required MX and TXT (SPF) records are missing.
2. Click **Add records and enable** (or similar button) to automatically add the necessary DNS records.
3. This will remove any existing MX records (like ImprovMX) and add Cloudflare's own email routing records.

## Verification

Send a test email to `contact@pitanga.cloud` and verify that it arrives at `rafa.oliveira1@gmail.com`.

## Why Cloudflare Email Routing?

- **Free**: Included with your Cloudflare account.
- **Privacy**: No need to share data with 3rd party forwarding services.
- **Integration**: Managed alongside your DNS and Ingress.
- **Security**: Supports SPF, DKIM, and DMARC out of the box.



