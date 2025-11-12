# Bitbucket Server - Google Cloud Build Integration

## 🔗 Creating Personal Access Tokens in Bitbucket Server

### Step 1: Access Token Settings
1. Log into your Bitbucket Server: `https://bitbucket.schwab.com`
2. Click your profile avatar (top-right)
3. Go to **Manage Account** → **Personal Access Tokens**
4. Click **Create a token**

### Step 2: Create Read Access Token
**Token Name**: `gcp-cloud-build-read`
**Permissions**:
- ✅ **Repositories**: Read
- ✅ **Projects**: Read

**Expiry**: Set appropriate expiration (e.g., 1 year)
**Save the token** - you'll need it for the "Read access token" field

### Step 3: Create Admin Access Token  
**Token Name**: `gcp-cloud-build-admin`
**Permissions**:
- ✅ **Repositories**: Admin
- ✅ **Projects**: Admin
- ✅ **Webhooks**: Admin (for triggers)

**Expiry**: Set appropriate expiration (e.g., 1 year)
**Save the token** - you'll need it for the "Admin access token" field

## 🌐 Network Configuration

### Private Network Setup
Since you selected **Private network**:

1. **Project**: `cs-venugopal-kurapati-cds2768` ✅
2. **Network**: Select your VPC network (likely the one you created in Terraform)
3. **IP Range**: Provide IP range for the connection (e.g., `10.0.0.0/16`)

### Network Requirements
- Ensure your Bitbucket server is reachable from the selected VPC
- Configure firewall rules to allow Cloud Build access
- Verify DNS resolution if using private DNS

## 🚀 Completing the Setup

### Fill the Form:
```
Name: bitbucket-connection
Host URL: https://bitbucket.schwab.com
Username: [your-bitbucket-username]
Read access token: [token-from-step-2]
Admin access token: [token-from-step-3]
Network: [your-vpc-network]
IP range: [your-ip-range]
```

### Test Connection:
After creating, test the connection by:
1. Clicking "Connect repository" 
2. Selecting your new host connection
3. Browsing available repositories

## 🔒 Security Best Practices

1. **Token Security**:
   - Store tokens securely
   - Use minimum required permissions
   - Set reasonable expiration dates
   - Rotate tokens regularly

2. **Network Security**:
   - Use private networks when possible
   - Restrict IP ranges appropriately
   - Configure proper firewall rules

3. **Access Control**:
   - Limit who can create/modify host connections
   - Use IAM roles for Cloud Build access
   - Monitor connection usage

## 🛠️ Troubleshooting

### Common Issues:
- **Certificate errors**: Upload CA certificate if using self-signed certs
- **Network timeouts**: Check VPC connectivity and firewall rules
- **Authentication failures**: Verify token permissions and expiration
- **Repository access**: Ensure tokens have access to target repositories

### Testing Commands:
```bash
# Test Bitbucket connectivity from Cloud Build
curl -H "Authorization: Bearer [your-token]" \
  https://bitbucket.schwab.com/rest/api/1.0/projects

# Test network connectivity
ping bitbucket.schwab.com
telnet bitbucket.schwab.com 443
```

