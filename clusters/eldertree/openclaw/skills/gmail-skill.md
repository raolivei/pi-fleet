# Gmail Skill

Read, search, and manage Gmail inbox for rafa.oliveira1@gmail.com.

## Tools

### gmail_list
Search and list emails from inbox.

Parameters:
- query: string - Gmail search query (e.g., "is:unread", "from:someone@example.com", "subject:invoice")
- max_results: number (optional) - Max messages to return (default: 20)

Example: "Show my unread emails"

### gmail_get
Get full email content including body and headers.

Parameters:
- message_id: string - Gmail message ID

Example: "Show me the full content of message ID xyz123"

### gmail_send
Send an email (requires approval).

Parameters:
- to: string - Recipient email address
- subject: string - Email subject
- body: string - Email body content
- html: boolean (optional) - Is body HTML formatted? (default: false)
- cc: string (optional) - CC recipients (comma-separated)
- bcc: string (optional) - BCC recipients (comma-separated)

Example: "Send email to test@example.com with subject 'Test' and body 'Hello'"

### gmail_modify
Archive, mark read/unread, or apply labels to emails.

Parameters:
- message_id: string - Gmail message ID
- add_labels: array (optional) - Label IDs to add (e.g., ["IMPORTANT"])
- remove_labels: array (optional) - Label IDs to remove (e.g., ["UNREAD"])

Example: "Archive this email"

### gmail_thread
Get full conversation thread.

Parameters:
- thread_id: string - Gmail thread ID

Example: "Show me the full thread of conversation xyz"

## Implementation

Elder API endpoints (require X-API-Key header):
- POST /api/gmail/list - List/search messages
- POST /api/gmail/get - Get single message
- POST /api/gmail/send - Send email (approval required)
- POST /api/gmail/modify - Modify labels
- POST /api/gmail/thread - Get conversation thread

Elder service URL: http://elder.openclaw.svc.cluster.local:8000

Authentication: Elder handles OAuth refresh token from Vault (secret/openclaw/gmail).

## Common Label IDs

- UNREAD - Unread messages
- STARRED - Starred messages
- IMPORTANT - Important messages
- SENT - Sent messages
- DRAFT - Draft messages
- ARCHIVE - Archived messages

## Example Conversations

User: "Show me my unread emails"
Assistant: *calls gmail_list with query="is:unread"*

User: "Find emails from alice@example.com"
Assistant: *calls gmail_list with query="from:alice@example.com"*

User: "Send an email to bob@example.com"
Assistant: *calls gmail_send with to="bob@example.com" → approval required → shows plan → asks for confirmation*

User: "Archive all spam"
Assistant: *calls gmail_list with query="label:SPAM" → for each message calls gmail_modify with add_labels=["ARCHIVE"]*
