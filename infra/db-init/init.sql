CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL
);
-- bcrypt hash for "password" ($2b$10$...)
INSERT INTO users (username, password_hash)
VALUES ('testuser1', '$2b$10$N9qo8uLOickgx2ZMRZo5i.ez6WfQWf1iY4zYx2QVX8W2u0YQnXQW2')
ON CONFLICT (username) DO NOTHING;
