const express = require('express');
const app = express();
app.use(express.json());

// This is the "Validation Logic" from your research
app.post('/api/verify-visit', (req, res) => {
    const { expertLocation, enterpriseLocation, verificationToken } = req.body;

    // 1. Calculate distance between Expert and Enterprise
    const distance = calculateDistance(expertLocation, enterpriseLocation);

    // 2. Rule: Must be within 50 meters to prevent false reporting
    if (distance > 50) {
        return res.status(400).json({ 
            success: false, 
            message: "Verification Failed: You are too far from the enterprise location." 
        });
    }

    // 3. Check if token is valid
    if (verificationToken === "VALID_CODE") { // This would check the DB in real life
        res.json({ success: true, message: "Visit Verified and Logged!" });
    } else {
        res.status(400).json({ success: false, message: "Invalid Verification Token." });
    }
});

function calculateDistance(loc1, loc2) {
    // Logic to calculate meters between two GPS coordinates
    return 0; // Placeholder for actual math
}

app.listen(3000, () => console.log('FOMIS Server running on port 3000'));