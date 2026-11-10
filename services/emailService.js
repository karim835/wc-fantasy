/**
 * Email Service — Nodemailer + Brevo SMTP (100% FREE)
 *
 * Setup (one-time, FREE):
 *  1. Register at: https://www.brevo.com (formerly Sendinblue)
 *  2. Free tier: 300 emails/day, unlimited contacts
 *  3. Get your API key → Settings → API keys (SMTP & API section)
 *  4. Set in .env:
 *       BREVO_API_KEY=xkeysib-xxxxxxxxxxxxxx...
 *       EMAIL_FROM="Fantasy WC 2026 <noreply@yourdomain.com>" (or Brevo sender)
 *
 * Brevo SMTP details:
 *   - Host: smtp-relay.brevo.com
 *   - Port: 587
 *   - TLS: yes
 *   - Username: your email (or 'apikey')
 *   - Password: your Brevo API key
 */

const nodemailer = require('nodemailer');

let _transporter = null;

function getTransporter() {
  if (_transporter) return _transporter;

  _transporter = nodemailer.createTransport({
    host: 'smtp-relay.brevo.com',
    port: 587,
    secure: false, // TLS, not SSL
    auth: {
      user: 'apikey', // Brevo uses 'apikey' as username
      pass: process.env.BREVO_API_KEY || process.env.EMAIL_PASS,
    },
  });

  return _transporter;
}

/**
 * Send a password-reset email.
 * @param {string} to         — recipient email address
 * @param {string} resetToken — the raw reset token to embed in the link
 * @param {string} username   — recipient's display name
 */
async function sendPasswordResetEmail(to, resetToken, username) {
  const appName   = process.env.APP_NAME   || 'Fantasy WC 2026';
  const clientUrl = process.env.CLIENT_URL  || 'http://localhost:3000';
  const resetLink = `${clientUrl}/reset-password?token=${resetToken}`;
  const expiresIn = '1 hour';

  const html = `
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background: #0a0e1a; color: #e0e0e0; margin: 0; padding: 0; }
    .container { max-width: 560px; margin: 40px auto; background: #141824; border-radius: 12px; overflow: hidden; }
    .header { background: linear-gradient(135deg, #f59e0b, #ef4444); padding: 32px; text-align: center; }
    .header h1 { margin: 0; color: #fff; font-size: 24px; }
    .body { padding: 32px; }
    .body p { line-height: 1.6; color: #b0b0b0; }
    .btn { display: inline-block; margin: 24px 0; padding: 14px 32px; background: linear-gradient(135deg, #f59e0b, #ef4444); color: #fff; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; }
    .footer { padding: 16px 32px; text-align: center; font-size: 12px; color: #555; border-top: 1px solid #222; }
    .warning { background: #1e1a0e; border-left: 4px solid #f59e0b; padding: 12px 16px; border-radius: 4px; margin-top: 16px; font-size: 13px; color: #aaa; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚽ ${appName}</h1>
    </div>
    <div class="body">
      <p>Bonjour <strong>${username}</strong>,</p>
      <p>Vous avez demandé à réinitialiser votre mot de passe. Cliquez sur le bouton ci-dessous pour choisir un nouveau mot de passe :</p>
      <a href="${resetLink}" class="btn">Réinitialiser mon mot de passe</a>
      <div class="warning">
        ⚠️ Ce lien expire dans <strong>${expiresIn}</strong>.<br>
        Si vous n'avez pas fait cette demande, ignorez cet e-mail — votre compte reste sécurisé.
      </div>
      <p style="margin-top:24px; font-size:13px; color:#666;">
        Si le bouton ne fonctionne pas, copiez ce lien dans votre navigateur :<br>
        <span style="color:#f59e0b; word-break:break-all;">${resetLink}</span>
      </p>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} ${appName} · Cet email est automatique, ne pas répondre.
    </div>
  </div>
</body>
</html>`;

  const text = `Bonjour ${username},\n\nRéinitialisez votre mot de passe ici (valide ${expiresIn}) :\n${resetLink}\n\nSi vous n'avez pas fait cette demande, ignorez cet email.\n\n— ${appName}`;

  await getTransporter().sendMail({
    from:    process.env.EMAIL_FROM || `"${appName}" <${process.env.EMAIL_USER}>`,
    to,
    subject: `[${appName}] Réinitialisation de votre mot de passe`,
    text,
    html,
  });
}

/**
 * Send a welcome email after registration.
 * @param {string} to       — recipient email
 * @param {string} username — display name
 */
async function sendWelcomeEmail(to, username) {
  const appName = process.env.APP_NAME || 'Fantasy WC 2026';

  const html = `
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background: #0a0e1a; margin: 0; padding: 0; }
    .container { max-width: 560px; margin: 40px auto; background: #141824; border-radius: 12px; overflow: hidden; }
    .header { background: linear-gradient(135deg, #f59e0b, #ef4444); padding: 32px; text-align: center; }
    .header h1 { margin: 0; color: #fff; font-size: 24px; }
    .body { padding: 32px; color: #b0b0b0; line-height: 1.6; }
    .footer { padding: 16px 32px; text-align: center; font-size: 12px; color: #555; border-top: 1px solid #222; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header"><h1>⚽ Bienvenue sur ${appName} !</h1></div>
    <div class="body">
      <p>Bonjour <strong>${username}</strong> 🎉</p>
      <p>Votre compte a bien été créé. Composez votre équipe, rejoignez une ligue et affrontez vos amis pendant la Coupe du Monde 2026 !</p>
      <p>Bon courage et que le meilleur gagne 🏆</p>
    </div>
    <div class="footer">© ${new Date().getFullYear()} ${appName}</div>
  </div>
</body>
</html>`;

  await getTransporter().sendMail({
    from:    process.env.EMAIL_FROM || `"${appName}" <${process.env.EMAIL_USER}>`,
    to,
    subject: `Bienvenue sur ${appName} !`,
    html,
    text: `Bonjour ${username}, bienvenue sur ${appName} ! Composez votre équipe et affrontez vos amis. — ${appName}`,
  });
}

/**
 * Verify SMTP connection (call on server start to detect mis-config early).
 */
async function verifyEmailConfig() {
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    console.warn('⚠️  Email not configured (EMAIL_USER / EMAIL_PASS missing). Password reset will not work.');
    return false;
  }
  try {
    await getTransporter().verify();
    console.log('✅ Email (SMTP) configured successfully');
    return true;
  } catch (err) {
    console.warn('⚠️  Email SMTP verification failed:', err.message);
    return false;
  }
}

module.exports = { sendPasswordResetEmail, sendWelcomeEmail, verifyEmailConfig };
