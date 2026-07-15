const mongoose = require('mongoose');
const SubscriptionPlan = require('./src/models/SubscriptionPlan');
const dotenv = require('dotenv');

dotenv.config({ path: './src/config/.env' });

const seedPlans = async () => {
  try {
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/namba';
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB for seeding...');

    // Clear existing plans
    await SubscriptionPlan.deleteMany();

    const plans = [
      {
        name: 'Starter',
        price: 499,
        period: 'month',
        icon: 'flash_circle',
        color: '#00BFA5',
        features: ['Hyperlocal visibility', 'Up to 100 orders/mo', 'Email support'],
        isPopular: false
      },
      {
        name: 'Professional',
        price: 999,
        period: 'month',
        icon: 'crown',
        color: '#F59E0B',
        features: ['Priority support', 'Unlimited orders', 'Analytics dashboard', 'Featured store status'],
        isPopular: true
      },
      {
        name: 'Ultimate',
        price: 1999,
        period: 'month',
        icon: 'award',
        color: '#3B82F6',
        features: ['Dedicated Account Manager', 'Customized promotions', '0% commission on orders', 'AI Insights'],
        isPopular: false
      }
    ];

    await SubscriptionPlan.insertMany(plans);
    console.log('✅ Subscription plans seeded successfully!');
    process.exit();
  } catch (err) {
    console.error('❌ Seeding failed:', err);
    process.exit(1);
  }
};

seedPlans();

