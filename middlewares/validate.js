const { validationResult } = require('express-validator');

/**
 * Middleware à placer après les règles express-validator.
 * Si des erreurs de validation sont présentes, renvoie 422 avec le détail.
 * Sinon, passe au handler suivant.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({
      error: 'Validation failed',
      details: errors.array().map((e) => ({ field: e.path, message: e.msg })),
    });
  }
  next();
}

module.exports = validate;
