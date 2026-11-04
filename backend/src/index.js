require('dotenv').config();

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const healthRouter = require('./routes/health');
const checkinsRouter = require('./routes/checkins');

const app = express();
const PORT = process.env.PORT || 5000;
const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error('MONGODB_URI environment variable is required');
  process.exit(1);
}

app.use(cors());
app.use(express.json());

app.use('/api/health', healthRouter);
app.use('/api/checkins', checkinsRouter);
app.get("/", (req, res) => {
  res.send("hello")
})
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

async function start() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    app.listen(PORT, () => {
      console.log(`TeamPulse API listening on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error.message);
    process.exit(1);
  }
}

start();
