# API Credentials Setup

To enable real-time data collection, you'll need to set up API credentials for various data sources.

## Environment Variables

Create a `.env` file or set these environment variables:

```bash
# Twitter/X API v2 Bearer Token
# Get from: https://developer.twitter.com/en/portal/dashboard
export TWITTER_BEARER_TOKEN="your_twitter_bearer_token_here"

# Reddit API Credentials  
# Get from: https://www.reddit.com/prefs/apps
export REDDIT_CLIENT_ID="your_reddit_client_id"
export REDDIT_CLIENT_SECRET="your_reddit_client_secret"
export REDDIT_USERNAME="your_reddit_username"
export REDDIT_PASSWORD="your_reddit_password"

# NewsAPI.org API Key
# Get from: https://newsapi.org/register
export NEWSAPI_KEY="your_newsapi_key_here"
```

## API Setup Instructions

### Twitter/X API v2
1. Go to [Twitter Developer Portal](https://developer.twitter.com/en/portal/dashboard)
2. Create a new app or use existing one
3. Generate Bearer Token from the "Keys and tokens" tab
4. Free tier allows 300 requests per 15 minutes

### Reddit API
1. Go to [Reddit Apps](https://www.reddit.com/prefs/apps) 
2. Create a new "script" application
3. Note the client ID (under the app name) and client secret
4. Use your Reddit username/password for authentication
5. Free tier allows 60 requests per minute

### NewsAPI.org
1. Register at [NewsAPI.org](https://newsapi.org/register)
2. Get your API key from the dashboard
3. Free tier allows 1,000 requests per day

## Free Alternatives

If you don't want to set up APIs immediately:

- **Google News RSS**: Works without API key (built-in)
- **Yahoo Finance RSS**: Works without API key (built-in)
- **Sample Data Mode**: The system will continue using sample data

## Configuration

The system will automatically detect missing API credentials and:
1. Log warnings about unavailable data sources
2. Continue operating with available sources
3. Show status in the Data Collection dashboard at `/data-collection`

## Testing Setup

To test if your APIs are working:
1. Start the application
2. Go to `/data-collection` in your browser
3. Click "Force Run" on any collector
4. Check the status and logs for any errors