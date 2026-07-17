sudo docker exec mongodb mongosh namba --quiet --eval 'db.users.find({role: "vendor"}, {name: 1, phone: 1, email: 1}).toArray()'
