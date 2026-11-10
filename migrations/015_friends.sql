-- Friendships: one row per request. user_id = requester, friend_id = recipient.
-- status: 'pending' until the recipient accepts, then 'accepted'.
CREATE TABLE IF NOT EXISTS friendships (
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  friend_id  UUID REFERENCES users(id) ON DELETE CASCADE,
  status     VARCHAR(10) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id);
