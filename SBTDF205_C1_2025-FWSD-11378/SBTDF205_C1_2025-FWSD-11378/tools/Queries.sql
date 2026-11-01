-- SBT-DF205-C1 — SQL Queries Used
-- Case: Google Pixel 3, Android 10 (Joshua Hickman dataset, Digital Corpora)
-- Examiner note: queries run with sqlite3 CLI (version bundled with Kali Rolling)
-- against read-only working copies. Original evidence files were never opened
-- directly; copies were made under working/ and set read-only after extraction.
-- Column/table names below are exactly as they appear in each app's schema;
-- several required a first "PRAGMA table_info()" / schema probe because the
-- expected AOSP column names did not exist in that app's own database
-- (see Report Section 9, Issues Encountered).

-- =====================================================================
-- TASK 2 — Device identity and profiles
-- Target DB: filesystem (no sqlite tables) — build.prop and
--            data/system/users/{userlist,0,11}.xml examined as flat files.
-- =====================================================================
-- (no SQL; text/XML parsing only — see raw_task2_device_identity.txt)


-- =====================================================================
-- TASK 3 — Settings and connectivity
-- Target DB: filesystem XML (settings_secure.xml, settings_global.xml,
--            settings_system.xml, WifiConfigStore.xml) — no sqlite tables.
-- =====================================================================
-- (no SQL; XML parsing only — see raw_task3_settings.txt)


-- =====================================================================
-- TASK 4.1 / 4.2 — Telephony Provider: mmssms.db (CE copy, authoritative)
-- Target DB: data/data/com.android.providers.telephony/databases/mmssms.db
-- =====================================================================

-- Purpose: SMS direction distribution
SELECT type, COUNT(*) AS count
FROM sms
GROUP BY type;

-- Purpose: SMS read/unread distribution
SELECT read, COUNT(*) AS count
FROM sms
GROUP BY read;

-- Purpose: enumerate all threads (for identifying genuine vs. automated conversations)
SELECT _id, date, message_count, recipient_ids, snippet, read, has_attachment
FROM threads
ORDER BY _id;

-- Purpose: extract all messages in thread 13 (Facebook notification thread)
SELECT _id, address, datetime(date/1000,'unixepoch') AS utc_time, type, read, body
FROM sms
WHERE thread_id = 13
ORDER BY date;

-- Purpose: extract thread 17 (the only non-automated / human-authored thread)
SELECT _id, address, datetime(date/1000,'unixepoch') AS utc_time, type, read, body
FROM sms
WHERE thread_id = 17
ORDER BY date;

-- Purpose: timestamp-convention verification (confirms `date` is UTC epoch ms)
SELECT _id, date AS raw_ms, datetime(date/1000,'unixepoch') AS utc
FROM sms
WHERE _id = 2;

-- Purpose: canonical address lookup table (normalises formatted vs. unformatted numbers)
SELECT _id, address
FROM canonical_addresses
ORDER BY _id;

-- Purpose: individually verify the row at the centre of the Thread-13
--          Evidence_ID mismatch found between CLI output and the DB Browser
--          GUI screenshot (see Report Section 9, Issue I-03)
SELECT _id, thread_id, address, datetime(date/1000,'unixepoch') AS utc_time, type, read, body
FROM sms
WHERE _id IN (12, 13);


-- =====================================================================
-- TASK 4.3 — contacts2.db and calllog.db
-- Target DB: data/data/com.android.providers.contacts/databases/{contacts2,calllog}.db
-- =====================================================================

-- Purpose: enumerate synced account types feeding the aggregated contact
SELECT _id, account_name, account_type
FROM accounts;

-- Purpose: show all raw_contacts rows and which aggregate contact_id they resolve to
SELECT _id, account_id, display_name, deleted, contact_id
FROM raw_contacts
ORDER BY _id;

-- Purpose: per-app identifiers/handles attached to the aggregated contact (data1-15 + mimetype)
SELECT d._id, m.mimetype, d.raw_contact_id, d.data1, d.data2, d.data3
FROM data d
JOIN mimetypes m ON m._id = d.mimetype_id
ORDER BY d._id;

-- Purpose: full call log with UTC conversion and direction labelling
SELECT _id, number,
       datetime(date/1000,'unixepoch') AS utc_time,
       duration,
       type,
       CASE type WHEN 1 THEN 'INCOMING' WHEN 2 THEN 'OUTGOING'
                 WHEN 3 THEN 'MISSED' WHEN 4 THEN 'VOICEMAIL' END AS direction,
       name, geocoded_location, is_read
FROM calls
ORDER BY date;

-- Purpose: call count by type
SELECT type, COUNT(*) AS count
FROM calls
GROUP BY type;


-- =====================================================================
-- TASK 4.4 — Calendar Provider
-- Target DB: data/data/com.android.providers.calendar/databases/calendar.db
-- =====================================================================

-- Purpose: row counts for every user-content table (documents absence of events)
SELECT 'Calendars', COUNT(*) FROM Calendars
UNION ALL SELECT 'Events', COUNT(*) FROM Events
UNION ALL SELECT 'Attendees', COUNT(*) FROM Attendees
UNION ALL SELECT 'Reminders', COUNT(*) FROM Reminders
UNION ALL SELECT 'CalendarAlerts', COUNT(*) FROM CalendarAlerts
UNION ALL SELECT 'Colors', COUNT(*) FROM Colors
UNION ALL SELECT 'ExtendedProperties', COUNT(*) FROM ExtendedProperties
UNION ALL SELECT 'CalendarCache', COUNT(*) FROM CalendarCache
UNION ALL SELECT 'CalendarMetaData', COUNT(*) FROM CalendarMetaData
UNION ALL SELECT 'EventsRawTimes', COUNT(*) FROM EventsRawTimes
UNION ALL SELECT 'Instances', COUNT(*) FROM Instances;


-- =====================================================================
-- TASK 5.1 — Google Messages: bugle_db vs. AOSP mmssms.db
-- Target DB: data/data/com.google.android.apps.messaging/databases/bugle_db
-- =====================================================================

-- Purpose: total message count (SMS + RCS overlay)
SELECT COUNT(*) FROM messages;

-- Purpose: locate the first 10 rows linked back to AOSP via the sms_message_uri column
SELECT _id, conversation_id, sms_message_uri,
       datetime(received_timestamp/1000,'unixepoch') AS received_utc,
       message_protocol, message_status, seen, read
FROM messages
ORDER BY _id
LIMIT 10;

-- Purpose: confirm the three specific AOSP<->bugle links cited in the report
SELECT _id AS bugle_id, sms_message_uri,
       datetime(received_timestamp/1000,'unixepoch') AS received_utc
FROM messages
WHERE sms_message_uri IN ('content://sms/2','content://sms/3','content://sms/12');

-- Purpose: conversation list (used to confirm RCS-only conversation 15, "Josh Hickman")
SELECT _id, name, latest_message_id, snippet
FROM conversations
ORDER BY _id;


-- =====================================================================
-- TASK 5.2 — Google Dialer: annotated_call_log.db vs. AOSP calllog.db
-- Target DB: data/data/com.google.android.dialer/databases/annotated_call_log.db
-- =====================================================================

SELECT COUNT(*) FROM AnnotatedCallLog;

SELECT _id, number,
       datetime(timestamp/1000,'unixepoch') AS utc_time,
       duration, call_type, is_read, new, spam_status
FROM AnnotatedCallLog
ORDER BY timestamp;


-- =====================================================================
-- TASK 6a — WhatsApp: msgstore.db and wa.db
-- Target DB: data/data/com.whatsapp/databases/{msgstore,wa}.db
-- =====================================================================

-- Purpose: row counts for key tables
SELECT 'messages', COUNT(*) FROM messages
UNION ALL SELECT 'chat', COUNT(*) FROM chat
UNION ALL SELECT 'jid', COUNT(*) FROM jid
UNION ALL SELECT 'message_media', COUNT(*) FROM message_media
UNION ALL SELECT 'call_log', COUNT(*) FROM call_log;

-- Purpose: synced WhatsApp contacts (wa.db)
SELECT _id, jid, is_whatsapp_user, number, display_name, status
FROM wa_contacts
ORDER BY _id;

-- Purpose: full message export with UTC conversion, text, location and media columns
-- (schema probe via PRAGMA table_info(messages) first — legacy message_text join
--  table is empty in this app version; text lives directly in messages.data)
SELECT _id, key_remote_jid, key_from_me,
       datetime(timestamp/1000,'unixepoch') AS utc_time,
       data AS text, media_wa_type, media_caption, latitude, longitude,
       media_name, media_size
FROM messages
ORDER BY _id;

-- Purpose: chat/participant summary
SELECT _id, jid_row_id, created_timestamp, last_message_row_id, archived
FROM chat;

-- Purpose: media attachment inventory (file paths and hashes)
SELECT message_row_id, chat_row_id, file_path, file_size, mime_type,
       media_name, file_hash
FROM message_media
ORDER BY message_row_id;


-- =====================================================================
-- TASK 6b — TextNow: textnow_data.db
-- Target DB: data/data/com.enflick.android.TextNow/databases/textnow_data.db
-- =====================================================================

SELECT _id, global_id, contact_value, contact_name, contact_type,
       avatar_initials, avatar_color
FROM contacts
ORDER BY _id;

SELECT _id, contact_value, contact_name, message_direction, message_type,
       datetime(date/1000,'unixepoch') AS utc_time, text
FROM messages
ORDER BY date;


-- =====================================================================
-- TASK 7a — Google Maps: gmm_sync.db and gmm_storage.db
-- Target DB: data/data/com.google.android.apps.maps/databases/{gmm_sync,gmm_storage}.db
-- =====================================================================

SELECT corpus, client_id, server_id, timestamp, latitude_e6, longitude_e6
FROM sync_item_data
ORDER BY corpus, client_id;

SELECT _key_pri, _key_sec, length(data) AS data_size
FROM gmm_storage_table;


-- =====================================================================
-- TASK 7b — Google Photos: gphotos-1.db (media / local_media)
-- Target DB: data/data/com.google.android.apps.photos/databases/gphotos-1.db
-- =====================================================================

-- Purpose: 10 most recent photo/video records (cloud-synced media index)
SELECT _id, dedup_key,
       datetime(capture_timestamp/1000,'unixepoch') AS capture_utc,
       type, is_deleted, is_favorite, has_local
FROM media
ORDER BY capture_timestamp DESC
LIMIT 10;

-- Purpose: on-device local media index with EXIF-derived GPS and filesystem paths
-- (schema probe required — expected column `is_deleted` does not exist in
--  local_media; replaced with the app's real column set, see PRAGMA output)
SELECT _id, filename,
       datetime(capture_timestamp/1000,'unixepoch') AS capture_utc,
       latitude, longitude, filepath, camera_make, camera_model
FROM local_media
LIMIT 8;

-- Note: local_media returned only 8 rows in this examination (Download/,
-- Messenger/, Restored/ items). The two most recent DCIM/Camera/ files
-- (IMG_20200209_132353.jpg, IMG_20200213_195030.jpg) were present on disk
-- (file listing only) but had no corresponding local_media row retrieved,
-- so no DB-sourced capture_utc/GPS exists for them in this examination —
-- see Report Section 9, Issue I-05.
