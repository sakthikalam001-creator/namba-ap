const express = require('express');
const router = express.Router();
const {
  getEmployees,
  getEmployeeProfile,
  upsertEmployeeProfile,
  relieveEmployee,
  reinstateEmployee,
} = require('../controllers/employeeController');
const { protect, authorize } = require('../middlewares/auth');

router.use(protect);
router.use(authorize('admin', 'superadmin'));

router.get('/', getEmployees);
router.get('/:id', getEmployeeProfile);
router.put('/:id', upsertEmployeeProfile);
router.put('/:id/relieve', relieveEmployee);
router.put('/:id/reinstate', reinstateEmployee);

module.exports = router;
