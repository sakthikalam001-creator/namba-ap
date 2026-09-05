const multer = require('multer');
const path = require('path');
const fs = require('fs');
const Settings = require('../models/Settings');

// Ensure upload directory exists
const uploadDir = path.join(__dirname, '../../public/uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    // Ensure we have an extension, fallback to .png if missing but mimetype is image/png
    let ext = path.extname(file.originalname).toLowerCase();
    if (!ext) {
       if (file.mimetype === 'image/jpeg') ext = '.jpg';
       else if (file.mimetype === 'image/png') ext = '.png';
       else if (file.mimetype === 'image/webp') ext = '.webp';
       else ext = '.jpg'; // Fallback for extension-less files (common in Flutter)
    }
    cb(null, file.fieldname + '-' + uniqueSuffix + ext);
  }
});

const fileFilter = (req, file, cb) => {
  const filetypes = /jpeg|jpg|png|webp|octet-stream/;
  const mimetype = filetypes.test(file.mimetype);
  const extname = filetypes.test(path.extname(file.originalname).toLowerCase());

  // Robust check: allow if mimetype is valid, OR if extension is valid, OR if it's a bill upload
  if (mimetype || extname || file.fieldname === 'bill' || file.fieldname === 'qr') {
    return cb(null, true);
  }
  
  console.error(`[Upload Filter] ❌ Rejected file: ${file.originalname} (Mime: ${file.mimetype})`);
  cb(new Error('Only .png, .jpg, .jpeg and .webp format allowed!'));
};

/**
 * Fetch dynamic max upload limit from Settings in MB (default 5.0 MB)
 */
async function getMaxUploadLimitMb() {
  try {
    const settings = await Settings.findOne();
    if (settings && typeof settings.maxUploadSizeMb === 'number' && settings.maxUploadSizeMb > 0) {
      return Number(settings.maxUploadSizeMb);
    }
  } catch (e) {
    console.warn('[UploadLimit] Error fetching settings:', e.message);
  }
  return 5.0; // Default 5.0 MB
}

/**
 * Dynamic single file upload middleware
 */
function dynamicSingle(fieldName = 'photo') {
  return async (req, res, next) => {
    try {
      const maxMb = await getMaxUploadLimitMb();
      const maxBytes = Math.round(maxMb * 1024 * 1024);

      const multerInstance = multer({
        storage: storage,
        limits: { fileSize: maxBytes },
        fileFilter: fileFilter
      }).single(fieldName);

      multerInstance(req, res, (err) => {
        if (err) {
          if (err.code === 'LIMIT_FILE_SIZE') {
            console.warn(`[Upload Limit Exceeded] ⚠️ Rejected upload. File is larger than ${maxMb} MB.`);
            return res.status(400).json({
              success: false,
              error: `File size exceeds the allowed limit of ${maxMb} MB. Please upload a smaller photo or increase the limit in Admin Settings.`
            });
          }
          return res.status(400).json({
            success: false,
            error: err.message || 'File upload error'
          });
        }
        next();
      });
    } catch (err) {
      console.error('[Upload Middleware Error]', err);
      next(err);
    }
  };
}

/**
 * Dynamic array upload middleware
 */
function dynamicArray(fieldName = 'photos', maxCount = 5) {
  return async (req, res, next) => {
    try {
      const maxMb = await getMaxUploadLimitMb();
      const maxBytes = Math.round(maxMb * 1024 * 1024);

      const multerInstance = multer({
        storage: storage,
        limits: { fileSize: maxBytes },
        fileFilter: fileFilter
      }).array(fieldName, maxCount);

      multerInstance(req, res, (err) => {
        if (err) {
          if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
              success: false,
              error: `File size exceeds the allowed limit of ${maxMb} MB.`
            });
          }
          return res.status(400).json({
            success: false,
            error: err.message || 'File upload error'
          });
        }
        next();
      });
    } catch (err) {
      next(err);
    }
  };
}

const upload = {
  single: (fieldName) => dynamicSingle(fieldName),
  array: (fieldName, maxCount) => dynamicArray(fieldName, maxCount),
  getMaxUploadLimitMb,
  storage,
  fileFilter
};

module.exports = upload;

