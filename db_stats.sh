#!/bin/bash

# Script to generate statistics about events in nostr.db
# Shows detailed breakdown by kind, author distribution, time-based stats, and more

# Path to the database
DB_PATH="./nostr.db"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: Database file $DB_PATH not found!"
    exit 1
fi

# Set up SQLite to output in column mode for better readability
SQLITE_CMD="sqlite3 -column -header"

echo "==========================================="
echo "📊 NOSTR DATABASE STATISTICS 📊"
echo "==========================================="

# Total number of events
echo -e "\n📋 TOTAL EVENTS"
echo "-------------------------------------------"
$SQLITE_CMD "$DB_PATH" "SELECT COUNT(*) AS 'Total Events' FROM event;"

# Events by kind
echo -e "\n📊 EVENTS BY KIND"
echo "-------------------------------------------"
$SQLITE_CMD "$DB_PATH" "
SELECT
    kind AS 'Kind',
    COUNT(*) AS 'Count',
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM event), 2) AS 'Percentage %',
    CASE
        WHEN kind = 0 THEN 'Metadata'
        WHEN kind = 1 THEN 'Short Text Note'
        WHEN kind = 2 THEN 'Recommend Relay'
        WHEN kind = 3 THEN 'Contacts'
        WHEN kind = 4 THEN 'Encrypted Direct Message'
        WHEN kind = 5 THEN 'Event Deletion'
        WHEN kind = 6 THEN 'Repost'
        WHEN kind = 7 THEN 'Reaction'
        WHEN kind = 11 THEN 'Thread'
        WHEN kind = 40 THEN 'Channel Creation'
        WHEN kind = 41 THEN 'Channel Metadata'
        WHEN kind = 42 THEN 'Channel Message'
        WHEN kind = 43 THEN 'Channel Hide Message'
        WHEN kind = 44 THEN 'Channel Mute User'
        WHEN kind = 1111 THEN 'Comment'
        WHEN kind = 1984 THEN 'Reporting'
        -- NIP-70 Auction Event Kinds
        WHEN kind = 30070 THEN 'Auction (NIP-70)'
        WHEN kind = 30071 THEN 'Auction Feedback (NIP-70)'
        WHEN kind = 30072 THEN 'Auction Time Extension (NIP-70)'
        WHEN kind = 30073 THEN 'Auction Bid (NIP-70)'
        WHEN kind = 30074 THEN 'Auction Sealed Bid (NIP-70)'
        WHEN kind = 30075 THEN 'Auction Settlement (NIP-70)'
        -- Zap-related kinds
        WHEN kind = 9734 THEN 'Zap Request'
        WHEN kind = 9735 THEN 'Zap Receipt'
        -- Article-related kinds
        WHEN kind = 7375 THEN 'Article Highlight'
        WHEN kind = 17375 THEN 'Article Status'
        -- Other specific kinds
        WHEN kind = 10002 THEN 'Relay List Metadata'
        WHEN kind = 10019 THEN 'Weight List'
        WHEN kind = 30023 THEN 'Long-form Content'
        ELSE 'Other'
    END AS 'Description'
FROM event
GROUP BY kind
ORDER BY COUNT(*) DESC;
"

# Top 20 authors by event count
echo -e "\n👥 TOP 20 AUTHORS BY EVENT COUNT"
echo "-------------------------------------------"
$SQLITE_CMD "$DB_PATH" "
SELECT
    HEX(author) AS 'Author (Hex)',
    COUNT(*) AS 'Events',
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM event), 2) AS 'Percentage %'
FROM event
GROUP BY author
ORDER BY COUNT(*) DESC
LIMIT 20;
"

# Time-based metrics
echo -e "\n⏱️ TIME-BASED METRICS"
echo "-------------------------------------------"
echo "Events by creation month:"
$SQLITE_CMD "$DB_PATH" "
SELECT
    strftime('%Y-%m', datetime(created_at, 'unixepoch')) AS 'Month',
    COUNT(*) AS 'Events'
FROM event
GROUP BY strftime('%Y-%m', datetime(created_at, 'unixepoch'))
ORDER BY Month DESC;
"

# Event age stats
echo -e "\nEvent age statistics (days):"
$SQLITE_CMD "$DB_PATH" "
SELECT
    MIN(ROUND((strftime('%s', 'now') - created_at) / 86400.0, 2)) AS 'Newest (days)',
    AVG(ROUND((strftime('%s', 'now') - created_at) / 86400.0, 2)) AS 'Average (days)',
    MAX(ROUND((strftime('%s', 'now') - created_at) / 86400.0, 2)) AS 'Oldest (days)'
FROM event;
"

# Expiring events
echo -e "\n⏳ EXPIRING EVENTS"
echo "-------------------------------------------"
$SQLITE_CMD "$DB_PATH" "
SELECT
    COUNT(*) AS 'Expiring Events',
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM event), 2) AS 'Percentage %'
FROM event
WHERE expires_at IS NOT NULL;
"

# Tag statistics
echo -e "\n🏷️ TAG STATISTICS"
echo "-------------------------------------------"
echo "Most common tag types:"
$SQLITE_CMD "$DB_PATH" "
SELECT
    name AS 'Tag Name',
    COUNT(*) AS 'Count'
FROM tag
GROUP BY name
ORDER BY COUNT(*) DESC
LIMIT 15;
"

echo -e "\nEvents per tag count:"
$SQLITE_CMD "$DB_PATH" "
SELECT
    tag_count AS 'Tags Per Event',
    COUNT(*) AS 'Event Count'
FROM (
    SELECT
        event_id,
        COUNT(*) AS tag_count
    FROM tag
    GROUP BY event_id
)
GROUP BY tag_count
ORDER BY tag_count;
"

# Database size and statistics
echo -e "\n💾 DATABASE STATISTICS"
echo "-------------------------------------------"

# Get database file size
DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
echo "Database file size: $DB_SIZE"

# Get table sizes
echo -e "\nRow counts by table:"
$SQLITE_CMD "$DB_PATH" "
SELECT 'event' AS 'Table Name', COUNT(*) AS Count FROM event
UNION ALL
SELECT 'tag' AS 'Table Name', COUNT(*) AS Count FROM tag
UNION ALL
SELECT 'user_verification' AS 'Table Name', COUNT(*) AS Count FROM user_verification
UNION ALL
SELECT 'account' AS 'Table Name', COUNT(*) AS Count FROM account
UNION ALL
SELECT 'invoice' AS 'Table Name', COUNT(*) AS Count FROM invoice
ORDER BY Count DESC;
"

# Storage efficiency
echo -e "\nAverage content size (bytes):"
$SQLITE_CMD "$DB_PATH" "SELECT ROUND(AVG(LENGTH(content))) AS 'Avg Content Size' FROM event;"

echo "==========================================="
echo "📊 END OF STATISTICS 📊"
echo "==========================================="
