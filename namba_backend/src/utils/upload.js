const multer = require('multer');
const path = require('path');
const fs = require('fs');

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

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const filetypes = /jpeg|jpg|png|webp|octet-stream/;
    const mimetype = filetypes.test(file.mimetype);
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());

    // Robust check: allow if mimetype is valid, OR if extension is valid, OR if it's a bill upload
    if (mimetype || extname || file.fieldname === 'bill') {
      return cb(null, true);
    }
    
    console.error(`[Upload Filter] ❌ Rejected file: ${file.originalname} (Mime: ${file.mimetype})`);
    cb(new Error('Only .png, .jpg, .jpeg and .webp format allowed!'));
  }
});

module.exports = upload;
