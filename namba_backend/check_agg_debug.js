const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const Vendor = require('./src/models/Vendor');
const User = require('./src/models/User');
const Order = require('./src/models/Order');

dotenv.config({ path: path.join(__dirname, '.env') });

const checkAgg = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
    console.log('[Info] Connected to MongoDB');

    const vendors = await Vendor.aggregate([
      {
        $lookup: {
          from: 'users',
          localField: 'user',
          foreignField: '_id',
          as: 'userDetails',
        },
      },
      {
        $unwind: { path: '$userDetails', preserveNullAndEmptyArrays: true },
      },
      {
        $lookup: {
          from: 'orders',
          localField: '_id',
          foreignField: 'vendor',
          as: 'allOrders',
        },
      },
      {
        $addFields: {
          user: '$userDetails',
          orders: {
            $size: {
              $filter: {
                input: '$allOrders',
                as: 'o',
                cond: { $eq: ['$$o.status', 'Delivered'] },
              },
            },
          },
          revenue: {
            $sum: {
              $map: {
                input: {
                  $filter: {
                    input: '$allOrders',
                    as: 'o',
                    cond: { $eq: ['$$o.status', 'Delivered'] },
                  },
                },
                as: 'o',
                in: '$$o.totalAmount',
              },
            },
          },
        },
      },
      {
        $project: {
          allOrders: 0,
          userDetails: 0,
        },
      },
      { $sort: { createdAt: -1 } },
    ]);

    console.log(`[Info] Aggregation returned ${vendors.length} vendors:`);
    console.log(JSON.stringify(vendors, null, 2));
    
    process.exit(0);
  } catch (err) {
    console.error('[Error]', err);
    process.exit(1);
  }
};

checkAgg();
