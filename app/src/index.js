const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// A professional logging statement is fine
console.log("Starting application...");

app.get('/', (req, res) => {
  res.send('Hello! The Quality Gate is now PASSING. Deployment successful.');
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`App listening at http://0.0.0.0:${port}`);
});