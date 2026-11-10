const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/db');
const logger = require('../config/logger');

let io;

function initSocket(server) {
  io = new Server(server, {
    cors: {
      origin: process.env.CORS_ORIGIN || '*',
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 60000,
  });

  // JWT authentication middleware for socket connections
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.split(' ')[1];
    if (!token) return next(new Error('Authentication required'));

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.userId;
      socket.data.userId = decoded.userId; // readable via fetchSockets()
      socket.data.leagues = new Set();     // league rooms this socket is in
      next();
    } catch (err) {
      next(new Error('Invalid token'));
    }
  });

  // Broadcast the distinct online user ids in a league room.
  async function emitPresence(leagueId) {
    try {
      const sockets = await io.in(`league:${leagueId}`).fetchSockets();
      const online = [...new Set(sockets.map((s) => s.data.userId).filter(Boolean))];
      io.to(`league:${leagueId}`).emit('league:presence', { leagueId, online });
    } catch (_) { /* room may be empty */ }
  }

  io.on('connection', (socket) => {
    logger.debug(`Socket connected: ${socket.id} (user: ${socket.userId})`);

    // Join user's personal room
    socket.join(`user:${socket.userId}`);

    // Join a league room — vérifie que l'utilisateur est bien membre
    socket.on('league:join', async (leagueId) => {
      try {
        const result = await pool.query(
          'SELECT 1 FROM league_members WHERE league_id = $1 AND user_id = $2',
          [leagueId, socket.userId]
        );
        if (result.rows.length === 0) {
          socket.emit('error', { message: 'Not a member of this league' });
          return;
        }
        socket.join(`league:${leagueId}`);
        socket.data.leagues.add(leagueId);
        socket.to(`league:${leagueId}`).emit('league:user_joined', { userId: socket.userId });
        emitPresence(leagueId);
        logger.debug(`User ${socket.userId} joined league room: ${leagueId}`);
      } catch (err) {
        logger.error('Socket league:join error', { error: err.message });
        socket.emit('error', { message: 'Failed to join league room' });
      }
    });

    // Leave a league room
    socket.on('league:leave', (leagueId) => {
      socket.leave(`league:${leagueId}`);
      socket.data.leagues?.delete(leagueId);
      socket.to(`league:${leagueId}`).emit('league:user_left', { userId: socket.userId });
      emitPresence(leagueId);
    });

    // Typing indicator relay
    socket.on('chat:typing', (data) => {
      if (data?.leagueId) {
        socket.to(`league:${data.leagueId}`).emit('chat:typing', { userId: socket.userId });
      }
    });

    // Join a battle room for live updates
    socket.on('battle:watch', (battleId) => {
      socket.join(`battle:${battleId}`);
      logger.debug(`User ${socket.userId} watching battle: ${battleId}`);
    });

    socket.on('battle:unwatch', (battleId) => {
      socket.leave(`battle:${battleId}`);
    });

    // Draft events
    socket.on('draft:pick', (data) => {
      socket.to(`league:${data.leagueId}`).emit('draft:player_picked', {
        userId: socket.userId,
        playerId: data.playerId,
        playerName: data.playerName,
      });
    });

    // Chat message in league
    socket.on('chat:message', (data) => {
      io.to(`league:${data.leagueId}`).emit('chat:new_message', {
        userId: socket.userId,
        message: data.message,
        timestamp: new Date().toISOString(),
      });
    });

    socket.on('disconnect', (reason) => {
      // Refresh presence for every league this socket was in (it has already left rooms).
      for (const leagueId of socket.data.leagues || []) emitPresence(leagueId);
      logger.debug(`Socket disconnected: ${socket.id} (reason: ${reason})`);
    });

    socket.on('error', (err) => {
      logger.warn(`Socket error for ${socket.id}`, { error: err.message });
    });
  });

  return io;
}

function getIO() {
  if (!io) throw new Error('Socket.io not initialized');
  return io;
}

module.exports = { initSocket, getIO };
