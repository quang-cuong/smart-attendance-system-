-- Run ONCE only on the ORIGINAL schema (accounts.is_active; registration_requests.username).
-- Do not run on a database already containing accounts.status or registration_requests.account_id.
-- Back up and check PRAGMA table_info(accounts), PRAGMA table_info(registration_requests) first.
-- New installations use schema.sql instead. No attendance/user/face records are removed.
ALTER TABLE accounts ADD COLUMN status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE accounts ADD COLUMN must_change_password INTEGER NOT NULL DEFAULT 0;
ALTER TABLE accounts ADD COLUMN credential_version INTEGER NOT NULL DEFAULT 1;
UPDATE accounts SET status=CASE WHEN is_active=1 THEN 'active' ELSE 'disabled' END;

INSERT INTO accounts(username,email,password_hash,salt,role,status)
SELECT r.username,r.email,r.password_hash,r.salt,r.requested_role,
 CASE WHEN r.status='approved' THEN 'active' ELSE r.status END
FROM registration_requests r
WHERE NOT EXISTS(SELECT 1 FROM accounts a WHERE a.username=r.username OR a.email=r.email);

CREATE TABLE registration_requests_current (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 account_id INTEGER NOT NULL REFERENCES accounts(id),
 requested_role TEXT NOT NULL CHECK(requested_role IN ('teacher','parent')),
 status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 reviewed_by INTEGER REFERENCES accounts(id), reviewed_at TEXT,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO registration_requests_current(id,account_id,requested_role,status,reviewed_by,reviewed_at,created_at)
SELECT r.id,(SELECT a.id FROM accounts a WHERE a.username=r.username AND a.email=r.email),
 r.requested_role,r.status,r.reviewed_by,r.reviewed_at,r.created_at
FROM registration_requests r;
-- Preserve the original requests table as an archive, rather than deleting it.
ALTER TABLE registration_requests RENAME TO registration_requests_legacy_archive;
ALTER TABLE registration_requests_current RENAME TO registration_requests;
CREATE INDEX idx_registration_requests_current_status ON registration_requests(status);

CREATE TABLE IF NOT EXISTS student_accounts (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
 username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, salt TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'active', must_change_password INTEGER NOT NULL DEFAULT 1,
 credential_version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
