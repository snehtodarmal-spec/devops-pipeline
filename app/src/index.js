const express = require('express');
const app = express();

// Middleware to parse JSON bodies from incoming requests
app.use(express.json());

const PORT = process.env.PORT || 3000;

// Mock Database
let items = [
  { id: 1, name: 'Docker Image' },
  { id: 2, name: 'EC2 Instance' }
];

// --- Existing Health Checks ---

app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'DevOps pipeline app is running' });
});

app.get('/health', (req, res) => {
  res.status(200).json({ healthy: true });
});

// --- CRUD Operations ---

// 1. CREATE: Add a new item
app.post('/items', (req, res) => {
  const newItem = {
    id: items.length + 1,
    name: req.body.name
  };
  items.push(newItem);
  res.status(201).json(newItem);
});

// 2. READ: Get all items
app.get('/items', (req, res) => {
  res.json(items);
});

// 3. READ: Get a single item by ID
app.get('/items/:id', (req, res) => {
  const item = items.find(i => i.id === parseInt(req.params.id));
  if (!item) return res.status(404).send('Item not found');
  res.json(item);
});

// 4. UPDATE: Modify an existing item
app.put('/items/:id', (req, res) => {
  const item = items.find(i => i.id === parseInt(req.params.id));
  if (!item) return res.status(404).send('Item not found');

  item.name = req.body.name;
  res.json(item);
});

// 5. DELETE: Remove an item
app.delete('/items/:id', (req, res) => {
  const itemIndex = items.findIndex(i => i.id === parseInt(req.params.id));
  if (itemIndex === -1) return res.status(404).send('Item not found');

  const deletedItem = items.splice(itemIndex, 1);
  res.json(deletedItem);
});

// --- Server Startup ---

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server started on port ${PORT}`);
  });
}

module.exports = app;
