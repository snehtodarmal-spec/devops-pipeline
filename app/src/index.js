const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ status: 'Success', 
    message: 'CI/CD Pipeline is Fully Operational!',
    version: '2.1.0',
    environment: 'Production',
    last_updated: new Date().toLocaleString()
  });
});

app.get('/health', (req, res) => {
  res.json({ healthy: true });
});

// ONLY start the server if this file is run directly
// This prevents port conflicts during testing
if (require.main === module) {
  app.listen(port, '0.0.0.0', () => {
    console.log(`Server running at port ${port}`);
  });
}

// CRITICAL: This allows the test suite to see the app
module.exports = app;
