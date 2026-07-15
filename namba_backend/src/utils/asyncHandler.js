/**
 * asyncHandler utility
 * Wraps asynchronous controller functions to automatically catch errors 
 * and forward them to the global error handling middleware.
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;
