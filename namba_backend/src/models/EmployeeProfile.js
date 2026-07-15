const mongoose = require('mongoose');

const EmployeeProfileSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  dateOfBirth: {
    type: Date,
  },
  dateOfJoining: {
    type: Date,
    default: Date.now,
  },
  bloodGroup: {
    type: String,
    enum: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
  },
  emergencyContact: {
    name: String,
    phone: String,
    relation: String,
  },
  bankDetails: {
    accountName: String,
    accountNumber: String,
    ifscCode: String,
    bankName: String,
    branchName: String,
  },
  baseSalary: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('EmployeeProfile', EmployeeProfileSchema);
