// ─────────────────────────────────────────────
// Main Express application entry point.
// This is what gets built into the Docker image
// and ultimately runs on EC2.
// ─────────────────────────────────────────────

const express = require('express');
const app = express();

// Port comes from environment variable so we can
// override it at runtime without changing code.
// Default to 3000 for local development.
const PORT = process.env.PORT || 3000;

// Root health-check route.
// Jenkins pipeline will hit this after deploy
// to verify the container is actually running.
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    message: 'DevOps pipeline app is running',
    environment: process.env.NODE_ENV || 'development'
  });
});

// /health is a dedicated liveness probe endpoint.
// Useful later when we add Docker health checks
// and AWS load balancer target group checks.
app.get('/health', (req, res) => {
  res.status(200).json({ healthy: true });
});

// Only start listening when this file is run directly
// (not when imported by tests — this lets Jest import
// the app without binding a port and causing conflicts).
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server started on port ${PORT}`);
  });
}

// Export the app so tests can import it and
// make HTTP calls without starting the server.
module.exports = app;
