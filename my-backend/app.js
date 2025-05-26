const express = require('express');
const app = express();
const port = 3000;

// Middleware to parse incoming JSON requests
app.use(express.json());

// Simple route for testing
app.get('/', (req, res) => {
  res.send('Server is running');
});

// Registration endpoint
app.post('/register', (req, res) => {
  const { email, password, name } = req.body;
  if (email && password && name) {
    // Di sini bisa menambahkan logika untuk menyimpan user ke database
    res.json({ message: 'Register successful' });
  } else {
    res.status(400).json({ message: 'Missing fields' });
  }
});

// Login endpoint
app.post('/login', (req, res) => {
  const { email, password } = req.body;
  
  // Dummy validation (harusnya melakukan pengecekan dengan database)
  if (email === 'user@example.com' && password === 'password123') {
    res.json({ message: 'Login successful' });
  } else {
    res.status(400).json({ message: 'Invalid email or password' });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
