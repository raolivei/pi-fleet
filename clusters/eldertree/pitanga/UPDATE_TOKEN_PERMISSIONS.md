# Update Cloudflare API Token for Tunnel Permissions

## Current Token

**Token Name**: `eldertree-terraform-full`

## Steps to Add Tunnel Permissions

1. **Click the three dots (⋯) next to `eldertree-terraform-full` token**

   - Select **"Edit"**

2. **Add Account Permissions**:

   - Scroll to **"Account Permissions"** section
   - Click **"Add"** or **"Edit"**
   - Add:
     - ✅ **Cloudflare Tunnel** → **Edit**
     - ✅ **Account** → **Read** (if not already present)

3. **Keep Existing Permissions**:

   - ✅ Account → SSL and Certificates → Edit (already present)
   - ✅ Zone → Zone → Read
   - ✅ Zone → DNS → Edit

4. **Account Resources**:

   - Should be set to **"All accounts"** or your specific account
   - Keep as is

5. **Click "Continue to summary"** → **"Update Token"**

6. **Copy the token value** (you'll need to regenerate it - Cloudflare will show the new token)

## After Updating

Once you have the updated token, I'll:

1. Update the tunnel configuration via API
2. Add routes for pitanga.cloud, www.pitanga.cloud, and northwaysignal.pitanga.cloud
3. Verify the configuration

**Just let me know when the token is updated, or paste the new token here!**
