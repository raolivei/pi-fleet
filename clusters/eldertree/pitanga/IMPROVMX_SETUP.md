# ImprovMX Email Setup for contact@pitanga.cloud

This guide explains how to configure email forwarding for `contact@pitanga.cloud` using ImprovMX, a free email forwarding service.

## Overview

ImprovMX provides email forwarding without requiring a mail server. Emails sent to `contact@pitanga.cloud` will be automatically forwarded to your Gmail (or any other email address).

## Prerequisites

1. Domain `pitanga.cloud` added to Cloudflare account
2. Access to Cloudflare Dashboard
3. Gmail account (or any email address for receiving forwarded emails)
4. ImprovMX account (free tier is sufficient)

## Step 1: Create ImprovMX Account

1. **Sign Up for ImprovMX**

   - Go to https://improvmx.com
   - Click **Sign Up** (free account)
   - Create account with your email

2. **Add Domain**

   - After logging in, click **Add Domain**
   - Enter `pitanga.cloud`
   - Click **Add**

3. **Verify Domain Ownership**
   - ImprovMX will provide a TXT record to verify domain ownership
   - We'll add this in Cloudflare DNS (see Step 2)

## Step 2: Configure DNS Records in Cloudflare

### 2.1 Add Domain Verification TXT Record

1. **Log in to Cloudflare Dashboard**

   - Go to https://dash.cloudflare.com
   - Select `pitanga.cloud` domain

2. **Navigate to DNS Records**

   - Go to **DNS** → **Records**

3. **Add Verification TXT Record**

   - Click **Add record**
   - **Type**: TXT
   - **Name**: `@` (or `pitanga.cloud`)
   - **Content**: (The verification string from ImprovMX, e.g., `improvmx-verification=xxxxx`)
   - **Proxy status**: DNS only (gray cloud)
   - **TTL**: Auto
   - Click **Save**

4. **Verify in ImprovMX**
   - Go back to ImprovMX dashboard
   - Click **Verify** next to your domain
   - Wait a few minutes for DNS propagation
   - Domain should show as "Verified"

### 2.2 Add MX Records for Email Forwarding

1. **Get MX Records from ImprovMX**

   - In ImprovMX dashboard, go to your domain settings
   - Navigate to **MX Records** section
   - ImprovMX will provide MX records (typically something like `mx1.improvmx.com` with priority 10)

2. **Add MX Records in Cloudflare**

   - Go to Cloudflare Dashboard → **DNS** → **Records**

3. **Add Primary MX Record**

   - Click **Add record**
   - **Type**: MX
   - **Name**: `@` (or `pitanga.cloud`)
   - **Mail server**: `mx1.improvmx.com` (or the value from ImprovMX)
   - **Priority**: `10` (or the priority from ImprovMX)
   - **Proxy status**: DNS only (gray cloud) - **Important: MX records must be DNS only**
   - **TTL**: Auto
   - Click **Save**

4. **Add Secondary MX Record (if provided)**
   - ImprovMX may provide a second MX record (e.g., `mx2.improvmx.com` with priority 20)
   - Add it the same way with the appropriate priority

## Step 3: Configure Email Forwarding in ImprovMX

1. **Create Email Alias**

   - In ImprovMX dashboard, go to **Aliases** or **Email Forwarding**
   - Click **Add Alias** or **Create Forward**

2. **Configure Forward**

   - **Email**: `contact` (this creates `contact@pitanga.cloud`)
   - **Forward to**: Your Gmail address (e.g., `yourname@gmail.com`)
   - Click **Save** or **Create**

3. **Verify Forwarding**
   - ImprovMX will show the alias as active
   - You can test by sending an email to `contact@pitanga.cloud`

## Step 4: Configure Gmail (Optional but Recommended)

### 4.1 Send Emails as contact@pitanga.cloud

To send emails FROM `contact@pitanga.cloud` (not just receive):

1. **Open Gmail Settings**

   - Go to Gmail → **Settings** → **See all settings**
   - Click **Accounts and Import** tab

2. **Add Send Mail As**

   - Scroll to **Send mail as** section
   - Click **Add another email address**

3. **Configure SMTP**

   - **Name**: Your name
   - **Email address**: `contact@pitanga.cloud`
   - Check **Treat as an alias**
   - Click **Next Step**

4. **SMTP Settings**

   - **SMTP Server**: `smtp.gmail.com`
   - **Port**: `587`
   - **Username**: Your Gmail address
   - **Password**: Your Gmail app password (see below)
   - **Secured connection**: TLS
   - Click **Add Account**

5. **Verify Email**
   - Gmail will send a verification email to `contact@pitanga.cloud`
   - Check ImprovMX dashboard or your forwarded email
   - Click the verification link

### 4.2 Create Gmail App Password

Gmail requires an app password for SMTP (not your regular password):

1. **Enable 2-Step Verification** (if not already enabled)

   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification

2. **Generate App Password**
   - Go to https://myaccount.google.com/apppasswords
   - Select **Mail** and **Other (Custom name)**
   - Enter name: "Pitanga SMTP"
   - Click **Generate**
   - Copy the 16-character password
   - Use this in Gmail SMTP settings (Step 4.1)

## Step 5: Verify Email Configuration

### Test Email Reception

1. **Send Test Email**

   - Send an email from any email account to `contact@pitanga.cloud`
   - Check your Gmail inbox
   - Email should arrive within a few minutes

2. **Check ImprovMX Logs**
   - Go to ImprovMX dashboard → **Logs** or **Activity**
   - Verify email was received and forwarded

### Test Email Sending (if configured)

1. **Compose Email in Gmail**
   - Click **Compose**
   - Click **From** dropdown
   - Select `contact@pitanga.cloud`
   - Send test email
   - Verify it's sent from the correct address

## Troubleshooting

### MX Records Not Working

1. **Verify MX Records**

   ```bash
   # Check MX records
   dig MX pitanga.cloud

   # Should show ImprovMX MX records
   ```

2. **Check DNS Propagation**

   - Use online tools like https://mxtoolbox.com
   - Enter `pitanga.cloud` and check MX records

3. **Verify Proxy Status**
   - MX records MUST be DNS only (gray cloud)
   - If proxied (orange cloud), email won't work
   - Go to Cloudflare DNS and ensure MX records are gray cloud

### Emails Not Arriving

1. **Check ImprovMX Dashboard**

   - Go to **Logs** or **Activity**
   - Look for incoming emails
   - Check for any error messages

2. **Verify Forwarding Configuration**

   - Ensure alias `contact` is created
   - Verify forwarding address is correct
   - Check for typos in email address

3. **Check Spam Folder**
   - Forwarded emails might go to spam
   - Check Gmail spam folder
   - Mark as "Not Spam" if found

### Gmail SMTP Not Working

1. **Verify App Password**

   - Ensure you're using app password, not regular password
   - Regenerate if needed

2. **Check SMTP Settings**

   - Server: `smtp.gmail.com`
   - Port: `587`
   - Security: TLS
   - Username: Full Gmail address

3. **Check 2-Step Verification**
   - Must be enabled for app passwords
   - Verify it's active in Google Account settings

### Domain Verification Failed

1. **Check TXT Record**

   ```bash
   # Verify TXT record exists
   dig TXT pitanga.cloud
   ```

2. **Wait for Propagation**

   - DNS changes can take time
   - Wait 5-10 minutes and try again

3. **Verify Record Content**
   - Ensure TXT record content matches exactly what ImprovMX provided
   - Check for extra spaces or typos

## Security Considerations

- **MX Records**: Always keep DNS only (not proxied) for email to work
- **App Passwords**: Use app passwords for SMTP, not your main Gmail password
- **Spam Filtering**: ImprovMX free tier has basic spam filtering
- **Rate Limits**: Free tier has limits on number of forwards per day

## Upgrading to Mailu (Future)

When you're ready for more control, you can migrate to Mailu running in the ElderTree cluster:

1. Deploy Mailu in the `pitanga` namespace
2. Update MX records to point to Mailu
3. Configure Mailu with your domain
4. Set up proper mail server with SPF, DKIM, DMARC records

See Mailu documentation for details.

## References

- [ImprovMX Documentation](https://improvmx.com/help)
- [Cloudflare MX Records](https://developers.cloudflare.com/dns/manage-dns-records/reference/mx-records/)
- [Gmail SMTP Settings](https://support.google.com/mail/answer/7126229)
- [Gmail App Passwords](https://support.google.com/accounts/answer/185833)

