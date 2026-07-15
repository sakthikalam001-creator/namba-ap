const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

const app = express();

// Middlewares
app.use(express.json()); // Parse JSON bodies
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies
app.use(cors()); // Allow cross-origin requests

// Static Folders
app.use('/public', express.static(path.join(__dirname, '../public')));

// Logging in development
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// Basic Health Check Route
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'success',
    message: 'Namba Backend API is running smoothly.',
  });
});

// Import Routes
const authRoutes = require('./routes/authRoutes');
const vendorRoutes = require('./routes/vendorRoutes');
const orderRoutes = require('./routes/orderRoutes');
const adminRoutes = require('./routes/adminRoutes');
const productRoutes = require('./routes/productRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const offerRoutes = require('./routes/offerRoutes');
const employeeRoutes = require('./routes/employeeRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/vendors', vendorRoutes);
app.use('/api/v1/orders', orderRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/products', productRoutes);
app.use('/api/v1/subscriptions', subscriptionRoutes);
app.use('/api/v1/offers', offerRoutes);
app.use('/api/v1/admin/employees', employeeRoutes);
app.use('/api/v1/attendance', attendanceRoutes);

// Handle 404 (Not Found)
app.use((req, res, next) => {
  const error = new Error(`Route not found: ${req.originalUrl}`);
  error.statusCode = 404;
  next(error);
});

// Centralized Error Handling Middleware
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  
  // Log critical errors (500s)
  if (statusCode === 500) {
    console.error(' [CRITICAL ERROR] ', err);
    console.error(err.stack);
  } else {
    console.warn(`[API Alert] ${statusCode} - ${err.message}`);
  }

  res.status(statusCode).json({
    success: false,
    error: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// Stability Test Routes
app.get('/test/error', (req, res) => {
  throw new Error('Simulated Synchronous Error (Crash Prevention Test)');
});

app.get('/test/rejection', (req, res) => {
  Promise.reject(new Error('Simulated Unhandled Promise Rejection (Crash Prevention Test)'));
  res.status(200).json({ success: true, message: 'Rejection triggered; check server logs.' });
});

module.exports = app;
