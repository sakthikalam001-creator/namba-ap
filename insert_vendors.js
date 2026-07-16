db.vendors.insertMany([
  {
    name: 'Venkateshwara Store',
    phone: '9876543210',
    email: 'venkat@store.com',
    category: 'Bakery',
    address: '12, Anna Salai, Chennai',
    location: { type: 'Point', coordinates: [80.2707, 13.0827] },
    isOpen: true,
    isApproved: true,
    rating: 4.5,
    totalRatings: 20,
    deliveryTime: '30-40 min',
    minOrder: 100,
    deliveryCharge: 30,
    image: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400'
  },
  {
    name: 'Nelai Store',
    phone: '9876543211',
    email: 'nelai@store.com',
    category: 'Grocery',
    address: '45, Mount Road, Chennai',
    location: { type: 'Point', coordinates: [80.2500, 13.0600] },
    isOpen: true,
    isApproved: true,
    rating: 4.2,
    totalRatings: 15,
    deliveryTime: '20-30 min',
    minOrder: 200,
    deliveryCharge: 20,
    image: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400'
  },
  {
    name: 'OM Muruga Mess',
    phone: '9876543212',
    email: 'om@mess.com',
    category: 'Food',
    address: '78, T Nagar, Chennai',
    location: { type: 'Point', coordinates: [80.2300, 13.0400] },
    isOpen: true,
    isApproved: true,
    rating: 4.8,
    totalRatings: 50,
    deliveryTime: '25-35 min',
    minOrder: 150,
    deliveryCharge: 25,
    image: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400'
  }
]);
print('Done! Vendors inserted.');
