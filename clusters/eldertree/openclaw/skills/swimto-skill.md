# SwimTO Skill

Query Toronto pool schedules and find swimming activities.

## Tools

### swimto_search
Search for pools with specific activities.

Parameters:
- activity: string (optional) - Activity type: "lane_swim", "leisure_swim", "aquafit", "family_swim"
- date: string (optional) - Date in YYYY-MM-DD format (default: today)

Example: "Find pools with lane swim today"

### swimto_pool_schedule  
Get the schedule for a specific pool.

Parameters:
- pool_name: string - Name of the pool (partial match supported)
- days: number (optional) - Number of days to show (default: 7)

Example: "Show me Regent Park pool schedule"

### swimto_nearby
Find pools near a location.

Parameters:
- location: string - Address or neighborhood in Toronto
- activity: string (optional) - Filter by activity type

Example: "Find pools near High Park with family swim"

## Implementation

The SwimTO API is available at: http://swimto-api.swimto.svc.cluster.local:8000

Endpoints:
- GET /api/pools - List all pools
- GET /api/pools/{id}/schedule - Get pool schedule
- GET /api/search?activity={type}&date={date} - Search by activity
- GET /api/nearby?lat={lat}&lng={lng}&radius={km} - Find nearby pools

## Example Conversations

User: "What pools have lane swim tonight?"
Assistant: *calls swimto_search with activity="lane_swim" and today's date*

User: "Show me Riverdale pool schedule for this week"
Assistant: *calls swimto_pool_schedule with pool_name="Riverdale"*
