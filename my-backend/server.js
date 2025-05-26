const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcrypt'); // Untuk enkripsi password
const app = express();

// Middleware
app.use(express.json());
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'DELETE'],
  allowedHeaders: ['Content-Type']
}));

// Connect to MongoDB Atlas
mongoose.connect(
  'mongodb+srv://hanakokunyashirosan:Aman3Yug1@mymoney.m0l1lpt.mongodb.net/mymoney?retryWrites=true&w=majority',
  {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  }
)
.then(() => {
  console.log('Connected to MongoDB Atlas');
})
.catch((err) => {
  console.error('MongoDB connection error:', err);
});

mongoose.set("strictQuery", false);

// Schemas
const UserSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true },
  password: String
});

const IncomeSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  amount: Number,
  category: String,
  date: { type: Date, default: Date.now }
});

const ExpenseSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  amount: Number,
  category: String,
  date: { type: Date, default: Date.now }
});

// Target Schema
const TargetSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  type: {
    // income / expense
    type: String,
    enum: ['income', 'expense'],
    required: true,
  },
  nominal: {
    type: Number,
    required: true,
  },
  periodType: {
    // A day / A week / A month / A year
    type: String,
    required: true,
  },
  info: {
    // Detail seperti "Day: Apr 5, 2025" atau "Month: April 2025"
    type: String,
    required: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

const Target = mongoose.model('Target', TargetSchema);

// Save Income or Expense Target
app.post('/save-target', async (req, res) => {
  const { userId, type, nominal, periodType, info } = req.body;

  if (!userId || !type || !nominal || !periodType || !info) {
    return res.status(400).json({ message: 'All fields are required' });
  }

  if (!['income', 'expense'].includes(type)) {
    return res.status(400).json({ message: 'Invalid target type' });
  }

  if (!isValidObjectId(userId)) {
    return res.status(400).json({ message: 'Invalid userId format' });
  }

  try {
    // Hapus target lama untuk jenis ini
    await Target.deleteMany({
      userId: new mongoose.Types.ObjectId(userId),
      type,
    });

    // Simpan target baru
    const newTarget = new Target({
      userId: new mongoose.Types.ObjectId(userId),
      type,
      nominal,
      periodType,
      info,
    });

    await newTarget.save();

    res.status(201).json({
      message: `${type.toUpperCase()} target saved successfully`,
      target: newTarget,
    });
  } catch (error) {
    console.error(`Error saving ${type} target:`, error);
    res.status(500).json({
      message: `Error saving ${type} target`,
      error: error.message,
    });
  }
});

// Get User's Income and Expense Targets
app.get('/get-target', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    const objectId = new mongoose.Types.ObjectId(userId);

    const targets = await Target.find({ userId: objectId });

    const result = {
      income_target_nominal: null,
      income_target_info: null,
      expense_target_nominal: null,
      expense_target_info: null,
    };

    targets.forEach(target => {
      if (target.type === 'income') {
        result.income_target_nominal = target.nominal;
        result.income_target_info = target.info;
      } else if (target.type === 'expense') {
        result.expense_target_nominal = target.nominal;
        result.expense_target_info = target.info;
      }
    });

    res.json(result);
  } catch (error) {
    console.error('Error fetching targets:', error);
    res.status(500).json({
      message: 'Error fetching targets',
      error: error.message,
    });
  }
});

// Delete a specific target
app.delete('/delete-target', async (req, res) => {
  const { userId, type } = req.body;

  if (!userId || !type) {
    return res.status(400).json({ message: 'UserId and type are required' });
  }

  if (!['income', 'expense'].includes(type)) {
    return res.status(400).json({ message: 'Invalid target type' });
  }

  if (!isValidObjectId(userId)) {
    return res.status(400).json({ message: 'Invalid userId format' });
  }

  try {
    const result = await Target.deleteOne({
      userId: new mongoose.Types.ObjectId(userId),
      type,
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({ message: `${type.toUpperCase()} target not found` });
    }

    res.json({ message: `${type.toUpperCase()} target deleted successfully` });
  } catch (error) {
    console.error(`Error deleting ${type} target:`, error);
    res.status(500).json({
      message: `Error deleting ${type} target`,
      error: error.message,
    });
  }
});

module.exports = { app, Target };

// Models
const User = mongoose.model('User', UserSchema);
const Income = mongoose.model('Income', IncomeSchema);
const Expense = mongoose.model('Expense', ExpenseSchema);

// Helper function
function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

// Routes

// Login Route
app.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required' });
  }

  try {
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    res.json({
      message: 'Login successful',
      name: user.name,
      userId: user._id,
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Register Route
app.post('/register', async (req, res) => {
  const { name, email, password } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({ message: 'Name, email, and password are required' });
  }

  try {
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    const hashedPassword = await bcrypt.hash(password, 10); // Enkripsi password

    const newUser = new User({
      name,
      email,
      password: hashedPassword,
    });

    await newUser.save();

    res.status(201).json({
      message: 'Registration successful',
      name: newUser.name,
      userId: newUser._id,
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error during registration' });
  }
});

// Add Income
app.post('/incomes', async (req, res) => {
  const { userId, amount, category, description } = req.body;
  if (!userId || !amount || !category) {
    return res.status(400).json({ message: 'UserId, amount, and category are required' });
  }

  if (!isValidObjectId(userId)) {
    return res.status(400).json({ message: 'Invalid userId format' });
  }

  try {
    const income = new Income({ userId, amount, category, description });
    await income.save();
    res.status(201).json(income);
  } catch (error) {
    res.status(500).json({ message: 'Error saving income', error: error.message });
  }
});

// Add Expense
app.post('/expenses', async (req, res) => {
  const { userId, amount, category, description } = req.body;
  if (!userId || !amount || !category) {
    return res.status(400).json({ message: 'UserId, amount, and category are required' });
  }

  if (!isValidObjectId(userId)) {
    return res.status(400).json({ message: 'Invalid userId format' });
  }

  try {
    const expense = new Expense({ userId, amount, category, description });
    await expense.save();
    res.status(201).json(expense);
  } catch (error) {
    res.status(500).json({ message: 'Error saving expense', error: error.message });
  }
});

// Get Incomes
app.get('/incomes', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    const incomes = await Income.find({ userId }).sort({ date: -1 });
    res.json(incomes);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching incomes', error: error.message });
  }
});

// Get Expenses
app.get('/expenses', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    const expenses = await Expense.find({ userId }).sort({ date: -1 });
    res.json(expenses);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching expenses', error: error.message });
  }
});

// Summary
app.get('/summary', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Pastikan konversi userId ke ObjectId dengan benar
    const objectId = new mongoose.Types.ObjectId(userId);

    // Total Income
    const totalIncomeResult = await Income.aggregate([
      { $match: { userId: objectId } },
      { $group: { _id: null, total: { $sum: "$amount" } } }
    ]);

    // Total Expense
    const totalExpenseResult = await Expense.aggregate([
      { $match: { userId: objectId } },
      { $group: { _id: null, total: { $sum: "$amount" } } }
    ]);

    // Today Income
    const todayIncomeResult = await Income.aggregate([
      { 
        $match: { 
          userId: objectId, 
          date: { $gte: today, $lt: tomorrow } 
        } 
      },
      { $group: { _id: null, total: { $sum: "$amount" } } }
    ]);

    // Today Expense
    const todayExpenseResult = await Expense.aggregate([
      { 
        $match: { 
          userId: objectId, 
          date: { $gte: today, $lt: tomorrow } 
        } 
      },
      { $group: { _id: null, total: { $sum: "$amount" } } }
    ]);

    const totalIncome = totalIncomeResult.length > 0 ? totalIncomeResult[0].total : 0;
    const totalExpense = totalExpenseResult.length > 0 ? totalExpenseResult[0].total : 0;
    const todayIncome = todayIncomeResult.length > 0 ? todayIncomeResult[0].total : 0;
    const todayExpense = todayExpenseResult.length > 0 ? todayExpenseResult[0].total : 0;

    res.json({
      totalIncome,
      totalExpense,
      todayIncome,
      todayExpense,
      balance: totalIncome - totalExpense
    });
  } catch (error) {
    console.error('Summary error:', error);
    res.status(500).json({ message: 'Error fetching summary', error: error.message });
  }
});

// Expenses by Category
app.get('/expenses-by-category', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    // Pastikan konversi userId ke ObjectId dengan benar
    const objectId = new mongoose.Types.ObjectId(userId);
    
    const result = await Expense.aggregate([
      { $match: { userId: objectId } },
      { 
        $group: { 
          _id: "$category", 
          total: { $sum: "$amount" },
          count: { $sum: 1 }
        } 
      },
      { $sort: { total: -1 } } // Sort by total descending
    ]);
    
    // Format hasil untuk response yang lebih baik
    const formattedResult = result.map(item => ({
      category: item._id,
      total: item.total,
      count: item.count
    }));
    
    res.json(formattedResult);
  } catch (error) {
    console.error('Expenses by category error:', error);
    res.status(500).json({ message: 'Error fetching expenses by category', error: error.message });
  }
});

app.get('/expenses-by-category-today', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    // Konversi userId ke ObjectId
    const objectId = new mongoose.Types.ObjectId(userId);

    // Mendapatkan awal hari ini (pukul 00:00:00)
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const result = await Expense.aggregate([
      {
        $match: {
          userId: objectId,
          date: { $gte: today } // Filter hanya hari ini
        }
      },
      {
        $group: {
          _id: "$category",
          total: { $sum: "$amount" },
          count: { $sum: 1 }
        }
      },
      { $sort: { total: -1 } } // Sort by total descending
    ]);

    // Format hasil
    const formattedResult = result.map(item => ({
      category: item._id,
      total: item.total,
      count: item.count
    }));

    res.json(formattedResult);
  } catch (error) {
    console.error('Error fetching today expenses by category:', error);
    res.status(500).json({
      message: 'Error fetching today expenses by category',
      error: error.message
    });
  }
});

// Delete Income
app.delete('/incomes/:id', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });
  if (!isValidObjectId(req.params.id))
    return res.status(400).json({ message: 'Invalid income ID format' });

  try {
    const result = await Income.findOneAndDelete({ _id: req.params.id, userId });
    if (!result) return res.status(404).json({ message: 'Income not found or unauthorized' });
    res.json({ message: 'Income deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting income', error: error.message });
  }
});

app.get('/incomes-by-category', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });

  try {
    // Pastikan konversi userId ke ObjectId dengan benar
    const objectId = new mongoose.Types.ObjectId(userId);
    
    const result = await Income.aggregate([
      { $match: { userId: objectId } },
      { 
        $group: { 
          _id: "$category", 
          total: { $sum: "$amount" },
          count: { $sum: 1 }
        } 
      },
      { $sort: { total: -1 } } // Sort by total descending
    ]);
    
    // Format hasil untuk response yang lebih baik
    const formattedResult = result.map(item => ({
      category: item._id,
      total: item.total,
      count: item.count
    }));
    
    res.json(formattedResult);
  } catch (error) {
    console.error('Incomes by category error:', error);
    res.status(500).json({ message: 'Error fetching incomes by category', error: error.message });
  }
});

// Delete Expense
app.delete('/expenses/:id', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ message: 'UserId is required' });
  if (!isValidObjectId(userId))
    return res.status(400).json({ message: 'Invalid userId format' });
  if (!isValidObjectId(req.params.id))
    return res.status(400).json({ message: 'Invalid expense ID format' });

  try {
    const result = await Expense.findOneAndDelete({ _id: req.params.id, userId });
    if (!result) return res.status(404).json({ message: 'Expense not found or unauthorized' });
    res.json({ message: 'Expense deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting expense', error: error.message });
  }
});

// Start Server

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST}:${PORT}`);
});
