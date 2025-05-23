#!/bin/bash

# Script to delete all events from nostr.db except specific kinds
# Keeps events of kinds: 0, 17375, 7375, 10019

# Parse command line arguments
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dry-run    Show what would be deleted without performing the deletion"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Path to the database
DB_PATH="./nostr.db"

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "Error: Database file $DB_PATH not found!"
    exit 1
fi

# Get total count of events before deletion
TOTAL_BEFORE=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM event;")
echo "Total events before deletion: $TOTAL_BEFORE"

# Get count of events to be deleted
TO_DELETE=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM event WHERE kind NOT IN (0, 17375, 7375, 10019);")
echo "Events to be deleted: $TO_DELETE"

# Get count of events to be kept
TO_KEEP=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM event WHERE kind IN (0, 17375, 7375, 10019);")
echo "Events to be kept: $TO_KEEP"

# If running in dry-run mode, show more details about what would be deleted
if [ "$DRY_RUN" = true ]; then
    echo -e "\n🔍 DRY RUN MODE - No changes will be made"
    echo "==========================================="

    # Show breakdown of events to be deleted by kind
    echo -e "\n📊 EVENTS TO BE DELETED (breakdown by kind):"
    echo "-----------------------------------------"
    sqlite3 -column -header "$DB_PATH" "
    SELECT
        kind AS 'Kind',
        COUNT(*) AS 'Count',
        ROUND(COUNT(*) * 100.0 / $TO_DELETE, 2) AS 'Percentage %',
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
            -- Moderated Groups NIP-72
            WHEN kind = 34550 THEN 'Group meta'
            WHEN kind = 4550 THEN 'Approve post'
            WHEN kind = 4551 THEN 'Remove post'
            WHEN kind = 4552 THEN 'Request to join group'
            WHEN kind = 4553 THEN 'Request to leave group'
            WHEN kind = 4554 THEN 'Mod Response to a report in a group'
            WHEN kind = 34550 THEN 'Mod Approved members list'
            WHEN kind = 34551 THEN 'Mod Declined members list '
            WHEN kind = 34552 THEN 'Mod Banned users lists'
            WHEN kind = 34553 THEN 'Mod Pin a post to group'
            WHEN kind = 14550 THEN 'OLD Mod Approved members list'
            WHEN kind = 14551 THEN 'OLD Mod Declined members list '
            WHEN kind = 14552 THEN 'OLD Mod Banned users lists'
            WHEN kind = 14553 THEN 'OLD User pinned group list'
            WHEN kind = 14554 THEN 'OLD Pin a post to group'
            -- Zap-related kinds
            WHEN kind = 9734 THEN 'Zap Request'
            WHEN kind = 9735 THEN 'Zap Receipt'
            WHEN kind = 9321 THEN 'Nutzap with comment'
            WHEN kind = 17375 THEN 'Nutzap wallet'
            WHEN kind = 7375 THEN 'Cashu Token'
            WHEN kind = 10019 THEN 'Nutzap info'
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
    WHERE kind NOT IN (0, 17375, 7375, 10019)
    GROUP BY kind
    ORDER BY COUNT(*) DESC;
    "

    echo -e "\n⚠️ This was only a dry run - no changes were made to the database."
    echo "To perform the actual deletion, run the script without the --dry-run option."
    exit 0
fi

# Ask for confirmation before deletion
read -p "Proceed with deletion? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Deletion aborted."
    exit 0
fi

# Begin transaction
echo "Starting deletion..."
sqlite3 "$DB_PATH" "BEGIN TRANSACTION;"

# Delete events with kinds other than those specified
sqlite3 "$DB_PATH" "DELETE FROM event WHERE kind NOT IN (0, 17375, 7375, 10019);"

# Commit transaction
sqlite3 "$DB_PATH" "COMMIT;"

# Get total count after deletion
TOTAL_AFTER=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM event;")
echo "Total events after deletion: $TOTAL_AFTER"
echo "Deleted $(($TOTAL_BEFORE - $TOTAL_AFTER)) events."

# Vacuum the database to reclaim space
echo "Vacuuming database to reclaim space..."
sqlite3 "$DB_PATH" "VACUUM;"

echo "Done."
