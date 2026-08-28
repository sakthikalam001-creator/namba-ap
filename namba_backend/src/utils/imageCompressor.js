const path = require('path');
const fs = require('fs');
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  console.warn('[ImageCompressor] sharp not available, fallback to passthrough');
}
const Settings = require('../models/Settings');

function formatFileSize(bytes) {
  if (!bytes || isNaN(bytes) || bytes <= 0) return '0 KB';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

function resolveUploadDiskPath(relativePathOrUrl) {
  if (!relativePathOrUrl || typeof relativePathOrUrl !== 'string') return null;
  const cleanPath = relativePathOrUrl.split('?')[0].replace(/^[a-zA-Z]+:\/\/[^/]+/, '');
  const filename = path.basename(cleanPath);
  const diskPath = path.join(__dirname, '../../public/uploads', filename);
  if (fs.existsSync(diskPath)) return diskPath;
  return null;
}

function getFileSizeInfo(relativePathOrUrl) {
  try {
    const diskPath = resolveUploadDiskPath(relativePathOrUrl);
    if (diskPath && fs.existsSync(diskPath)) {
      const stats = fs.statSync(diskPath);
      return {
        bytes: stats.size,
        formatted: formatFileSize(stats.size),
        exists: true
      };
    }
  } catch (e) {
    console.error('Error getting file size info:', e.message);
  }
  return { bytes: 0, formatted: '0 KB', exists: false };
}

/**
 * Automatically compress an uploaded image file on disk according to Settings
 * @param {string} filePath - Absolute path to the uploaded file
 * @param {object} customOptions - Optional override options
 * @returns {Promise<{ originalSize: number, compressedSize: number, formattedSize: string, savingsPct: number }>}
 */
async function compressImageFile(filePath, customOptions = {}) {
  try {
    if (!fs.existsSync(filePath)) {
      return { originalSize: 0, compressedSize: 0, formattedSize: '0 KB', savingsPct: 0 };
    }

    const originalStats = fs.statSync(filePath);
    const originalSize = originalStats.size;

    if (!sharp) {
      return {
        originalSize,
        compressedSize: originalSize,
        formattedSize: formatFileSize(originalSize),
        savingsPct: 0,
      };
    }

    // Fetch dynamic compression settings from DB
    let compressionEnabled = true;
    let quality = 75;
    let maxMp = 2.0; // Megapixels (e.g. 2MP = ~1920x1080)
    let maxTargetKb = 800;

    try {
      const settings = await Settings.findOne();
      if (settings) {
        if (typeof settings.imageCompressionEnabled === 'boolean') {
          compressionEnabled = settings.imageCompressionEnabled;
        }
        if (settings.imageQualityPct) quality = Number(settings.imageQualityPct);
        if (settings.imageMaxResolutionMp) maxMp = Number(settings.imageMaxResolutionMp);
        if (settings.imageMaxTargetKb) maxTargetKb = Number(settings.imageMaxTargetKb);
      }
    } catch (e) {}

    if (customOptions.quality) quality = customOptions.quality;
    if (customOptions.maxMp) maxMp = customOptions.maxMp;

    if (!compressionEnabled && !customOptions.force) {
      return {
        originalSize,
        compressedSize: originalSize,
        formattedSize: formatFileSize(originalSize),
        savingsPct: 0,
      };
    }

    // Determine max pixel dimension from Megapixels: sqrt(maxMp * 1,000,000 * (16/9))
    const maxDimension = Math.round(Math.sqrt(maxMp * 1000000 * (16 / 9)));

    const ext = path.extname(filePath).toLowerCase();
    const tempPath = filePath + '.tmp' + ext;

    let transformer = sharp(filePath, { failOnError: false })
      .rotate() // auto-rotate based on EXIF orientation
      .resize({
        width: maxDimension,
        height: maxDimension,
        fit: sharp.fit.inside,
        withoutEnlargement: true
      });

    if (ext === '.png') {
      transformer = transformer.png({ quality: Math.min(quality + 10, 100), compressionLevel: 8 });
    } else if (ext === '.webp') {
      transformer = transformer.webp({ quality });
    } else {
      transformer = transformer.jpeg({ quality, mozjpeg: true });
    }

    await transformer.toFile(tempPath);

    // Replace original file with compressed file if smaller
    const compressedStats = fs.statSync(tempPath);
    if (compressedStats.size < originalSize || originalSize > (maxTargetKb * 1024)) {
      fs.renameSync(tempPath, filePath);
      const finalStats = fs.statSync(filePath);
      const savings = Math.max(0, Math.round(((originalSize - finalStats.size) / originalSize) * 100));
      return {
        originalSize,
        compressedSize: finalStats.size,
        formattedSize: formatFileSize(finalStats.size),
        savingsPct: savings
      };
    } else {
      if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
      return {
        originalSize,
        compressedSize: originalSize,
        formattedSize: formatFileSize(originalSize),
        savingsPct: 0
      };
    }
  } catch (err) {
    console.error('[ImageCompressor] Error compressing image:', err.message);
    const stats = fs.existsSync(filePath) ? fs.statSync(filePath) : { size: 0 };
    return {
      originalSize: stats.size,
      compressedSize: stats.size,
      formattedSize: formatFileSize(stats.size),
      savingsPct: 0
    };
  }
}

module.exports = {
  formatFileSize,
  resolveUploadDiskPath,
  getFileSizeInfo,
  compressImageFile
};
