const io = require('socket.io-client');
const socket = io('http://127.0.0.1:5000');

// CHANGE THIS to your Order ID (The full 24-character ID from your URL or database)
const orderId = process.argv[2];

if (!orderId) {
    console.error('❌ Please provide an Order ID. Usage: node test_tracking.js <ORDER_ID>');
    process.exit(1);
}

socket.on('connect', () => {
    console.log(`✅ Connected to server. Simulating tracking for Order: ${orderId}`);
    
    const startCoord = { lat: 11.0168, lng: 76.9558 };
    const endCoord = { lat: 11.0500, lng: 76.9800 };
    let steps = 0;
    const totalSteps = 20;

    const interval = setInterval(() => {
        steps++;
        const progress = steps / totalSteps;
        const currentLat = startCoord.lat + (endCoord.lat - startCoord.lat) * progress;
        const currentLng = startCoord.lng + (endCoord.lng - startCoord.lng) * progress;

        const data = {
            orderId: orderId,
            riderId: 'rider_123',
            lat: currentLat,
            lng: currentLng,
            status: progress < 0.3 ? 'Arriving at Shop' : (progress < 0.8 ? 'On the way to Customer' : 'Near Destination'),
            progress: progress
        };

        socket.emit('update_rider_location', data);
        console.log(`📍 Step ${steps}/${totalSteps}: ${currentLat.toFixed(4)}, ${currentLng.toFixed(4)} | Progress: ${(progress * 100).toFixed(0)}%`);

        if (steps >= totalSteps) {
            clearInterval(interval);
            console.log('🏁 Simulation Finished!');
            process.exit(0);
        }
    }, 1000);
});
