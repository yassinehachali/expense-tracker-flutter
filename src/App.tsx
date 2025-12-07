import React, { useState, useEffect, useMemo } from 'react';
import { initializeApp } from 'firebase/app';
import { 
  getAuth, 
  signInWithEmailAndPassword,
  signInAnonymously, 
  signOut,
  onAuthStateChanged,
  type User 
} from 'firebase/auth';
import { 
  getFirestore, 
  collection, 
  doc, 
  addDoc, 
  deleteDoc, 
  onSnapshot, 
  setDoc,
  serverTimestamp,
  updateDoc,
  arrayUnion
} from 'firebase/firestore';
import { 
  PieChart, 
  Pie, 
  Cell, 
  ResponsiveContainer, 
  Tooltip as RechartsTooltip, 
  Legend,
  BarChart,
  Bar,
  XAxis,
} from 'recharts';
import { 
  Plus, 
  Trash2, 
  Wallet, 
  TrendingDown, 
  DollarSign, 
  Calendar, 
  PieChart as PieChartIcon,
  BarChart3,
  Loader2,
  X,
  Settings,
  Sun,
  Moon,
  Pencil,
  Check,
  LogOut,
  Lock,
  User as UserIcon, 
  Home,
  Utensils,
  Car,
  Zap,
  Film,
  ShoppingBag,
  HeartPulse,
  MoreHorizontal,
  Dumbbell,
  Smartphone,
  Wifi,
  Briefcase,
  Gift,
  Plane,
  GraduationCap,
  Coffee,
  Music,
  Gamepad2,
  PawPrint,
  Scissors,
  CreditCard,
  Landmark,
  Baby,
  Shirt
} from 'lucide-react';

// --- Firebase Configuration & Initialization ---

// ------------------------------------------------------------------
// 1. FOR LOCAL VITE PROJECT (Uncomment this block locally)
// ------------------------------------------------------------------

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID
};
// Use a fixed ID for local dev to keep path logic simple
const appId = 'expense-tracker'; 


// ------------------------------------------------------------------
// 2. FOR THIS PREVIEW ONLY (Keep this active here, Delete locally)
// ------------------------------------------------------------------
// ------------------------------------------------------------------

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// --- Icon System Configuration ---
const ICON_MAP: Record<string, any> = {
  Home, Utensils, Car, Zap, Film, ShoppingBag, HeartPulse, MoreHorizontal,
  Dumbbell, Smartphone, Wifi, Briefcase, Gift, Plane, GraduationCap, Coffee,
  Music, Gamepad2, PawPrint, Scissors, CreditCard, Landmark, Baby, Shirt
};

const ICON_OPTIONS = [
  { key: 'Home', keywords: ['house', 'rent', 'mortgage', 'apartment'], component: Home },
  { key: 'Utensils', keywords: ['food', 'restaurant', 'dinner', 'lunch', 'groceries', 'snack'], component: Utensils },
  { key: 'Car', keywords: ['transport', 'gas', 'uber', 'taxi', 'bus', 'fuel', 'parking'], component: Car },
  { key: 'Zap', keywords: ['utilities', 'electric', 'water', 'bill', 'power'], component: Zap },
  { key: 'Film', keywords: ['movie', 'netflix', 'cinema', 'theatre', 'show', 'entertainment'], component: Film },
  { key: 'ShoppingBag', keywords: ['shopping', 'clothes', 'mall', 'buy'], component: ShoppingBag },
  { key: 'HeartPulse', keywords: ['health', 'doctor', 'med', 'pharmacy', 'hospital'], component: HeartPulse },
  { key: 'Dumbbell', keywords: ['gym', 'fitness', 'sport', 'workout', 'yoga'], component: Dumbbell },
  { key: 'Smartphone', keywords: ['phone', 'mobile', 'cell'], component: Smartphone },
  { key: 'Wifi', keywords: ['internet', 'wifi', 'broadband', 'connection'], component: Wifi },
  { key: 'Briefcase', keywords: ['work', 'business', 'office', 'salary'], component: Briefcase },
  { key: 'Gift', keywords: ['gift', 'donation', 'present', 'charity'], component: Gift },
  { key: 'Plane', keywords: ['travel', 'flight', 'hotel', 'vacation', 'trip'], component: Plane },
  { key: 'GraduationCap', keywords: ['education', 'school', 'course', 'tuition', 'book'], component: GraduationCap },
  { key: 'Coffee', keywords: ['coffee', 'cafe', 'starbucks', 'drink'], component: Coffee },
  { key: 'Music', keywords: ['music', 'spotify', 'concert', 'song'], component: Music },
  { key: 'Gamepad2', keywords: ['game', 'steam', 'playstation', 'xbox', 'nintendo'], component: Gamepad2 },
  { key: 'PawPrint', keywords: ['pet', 'dog', 'cat', 'vet'], component: PawPrint },
  { key: 'Scissors', keywords: ['haircut', 'salon', 'barber', 'beauty'], component: Scissors },
  { key: 'CreditCard', keywords: ['subscription', 'fee', 'tax'], component: CreditCard },
  { key: 'Landmark', keywords: ['bank', 'save', 'invest'], component: Landmark },
  { key: 'Baby', keywords: ['baby', 'child', 'kids', 'diaper'], component: Baby },
  { key: 'Shirt', keywords: ['laundry', 'dry clean'], component: Shirt },
  { key: 'MoreHorizontal', keywords: ['other', 'misc', 'general'], component: MoreHorizontal },
];

// --- Types ---
type Expense = {
  id: string;
  amount: number;
  category: string;
  description: string;
  date: string;
  createdAt: any;
};

type Category = {
  name: string;
  color: string;
  icon: string;
};

type UserSettings = {
  salary: number;
};

// --- Constants ---
const DEFAULT_CATEGORIES: Category[] = [
  { name: 'Housing', color: '#6366f1', icon: 'Home' },
  { name: 'Food', color: '#ec4899', icon: 'Utensils' },
  { name: 'Transport', color: '#f59e0b', icon: 'Car' },
  { name: 'Utilities', color: '#3b82f6', icon: 'Zap' },
  { name: 'Entertainment', color: '#8b5cf6', icon: 'Film' },
  { name: 'Shopping', color: '#10b981', icon: 'ShoppingBag' },
  { name: 'Health', color: '#ef4444', icon: 'HeartPulse' },
  { name: 'Others', color: '#64748b', icon: 'MoreHorizontal' },
];

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

const COLORS = [
  '#ef4444', '#f97316', '#f59e0b', '#84cc16', '#10b981', 
  '#06b6d4', '#3b82f6', '#6366f1', '#8b5cf6', '#d946ef', 
  '#f43f5e', '#64748b'
];

// --- Components ---

export default function App() {
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true); 
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [categories, setCategories] = useState<Category[]>(DEFAULT_CATEGORIES);
  const [salary, setSalary] = useState<number>(0);
  const [loading, setLoading] = useState(false);
  
  // Login State
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  
  // UI State
  const [selectedMonth, setSelectedMonth] = useState(new Date().getMonth());
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [chartType, setChartType] = useState<'pie' | 'bar'>('bar');
  
  // Modals
  const [showSalaryModal, setShowSalaryModal] = useState(false);
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [showAddExpenseModal, setShowAddExpenseModal] = useState(false);
  const [tempSalary, setTempSalary] = useState('');
  
  // New Category Form
  const [newCategoryName, setNewCategoryName] = useState('');
  const [newCategoryColor, setNewCategoryColor] = useState(COLORS[0]);
  const [newCategoryIcon, setNewCategoryIcon] = useState('MoreHorizontal');

  // Editing State
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState<{description: string, amount: string}>({ description: '', amount: '' });

  // Form State
  const [newExpense, setNewExpense] = useState({
    amount: '',
    category: '',
    description: '',
    date: new Date().toISOString().split('T')[0]
  });

  // --- Authentication ---
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setAuthLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError('');
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (error: any) {
      console.error("Login failed:", error);
      setLoginError('Invalid email or password.');
    } finally {
      setLoading(false);
    }
  };

  const handleGuestLogin = async () => {
    setLoading(true);
    try {
      await signInAnonymously(auth);
    } catch (error) {
      console.error("Guest login failed:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await signOut(auth);
      setExpenses([]); 
      setSalary(0);
    } catch (error) {
      console.error("Logout failed:", error);
    }
  };

  // --- Data Fetching ---
  useEffect(() => {
    if (!user) return;
    setLoading(true);

    const expensesRef = collection(db, 'artifacts', appId, 'users', user.uid, 'expenses');
    const unsubExpenses = onSnapshot(expensesRef, (snapshot) => {
      const data = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Expense[];
      
      data.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      setExpenses(data);
      setLoading(false);
    }, (error) => {
      console.error("Expenses fetch error:", error);
      setLoading(false);
    });

    const settingsRef = doc(db, 'artifacts', appId, 'users', user.uid, 'settings', 'general');
    const unsubSettings = onSnapshot(settingsRef, (docSnap) => {
      if (docSnap.exists()) {
        const data = docSnap.data() as UserSettings;
        setSalary(data.salary || 0);
        setTempSalary((data.salary || 0).toString());
      }
    });

    const categoriesRef = doc(db, 'artifacts', appId, 'users', user.uid, 'settings', 'categories');
    const unsubCategories = onSnapshot(categoriesRef, (docSnap) => {
      if (docSnap.exists()) {
        const data = docSnap.data();
        if (data.list && Array.isArray(data.list)) {
          const merged = data.list.map((c: any) => ({
            ...c,
            icon: c.icon || DEFAULT_CATEGORIES.find(d => d.name === c.name)?.icon || 'MoreHorizontal'
          }));
          setCategories(merged);
        }
      } else {
        setDoc(categoriesRef, { list: DEFAULT_CATEGORIES });
      }
    });

    return () => {
      unsubExpenses();
      unsubSettings();
      unsubCategories();
    };
  }, [user]);

  // --- Actions ---

  const handleAddExpense = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !newExpense.amount) return;

    try {
      const expensesRef = collection(db, 'artifacts', appId, 'users', user.uid, 'expenses');
      const descriptionToUse = newExpense.description || newExpense.category || categories[0].name;

      await addDoc(expensesRef, {
        amount: parseFloat(newExpense.amount),
        category: newExpense.category || categories[0].name,
        description: descriptionToUse,
        date: newExpense.date,
        createdAt: serverTimestamp()
      });
      
      setShowAddExpenseModal(false);
      setNewExpense({
        amount: '',
        category: '',
        description: '',
        date: new Date().toISOString().split('T')[0]
      });
    } catch (error) {
      console.error("Error adding expense:", error);
    }
  };

  const handleDeleteExpense = async (id: string) => {
    if (!user) return;
    try {
      const docRef = doc(db, 'artifacts', appId, 'users', user.uid, 'expenses', id);
      await deleteDoc(docRef);
    } catch (error) {
      console.error("Error deleting expense:", error);
    }
  };

  const handleUpdateSalary = async () => {
    if (!user) return;
    try {
      const settingsRef = doc(db, 'artifacts', appId, 'users', user.uid, 'settings', 'general');
      await setDoc(settingsRef, { salary: parseFloat(tempSalary) || 0 }, { merge: true });
      setShowSalaryModal(false);
    } catch (error) {
      console.error("Error updating salary:", error);
    }
  };

  const handleCategoryNameChange = (val: string) => {
    setNewCategoryName(val);
    if (val.length > 2) {
      const lower = val.toLowerCase();
      const match = ICON_OPTIONS.find(opt => 
        opt.keywords.some(k => lower.includes(k)) || opt.key.toLowerCase() === lower
      );
      if (match) {
        setNewCategoryIcon(match.key);
      }
    }
  };

  const handleAddCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !newCategoryName) return;

    try {
      const categoriesRef = doc(db, 'artifacts', appId, 'users', user.uid, 'settings', 'categories');
      const newCat = { 
        name: newCategoryName, 
        color: newCategoryColor,
        icon: newCategoryIcon 
      };
      
      await updateDoc(categoriesRef, {
        list: arrayUnion(newCat)
      });

      setNewCategoryName('');
      setNewCategoryIcon('MoreHorizontal');
      setShowCategoryModal(false);
    } catch (error) {
      console.error("Error adding category:", error);
    }
  };

  const startEditing = (expense: Expense) => {
    setEditingId(expense.id);
    setEditValues({
      description: expense.description,
      amount: expense.amount.toString()
    });
  };

  const cancelEditing = () => {
    setEditingId(null);
    setEditValues({ description: '', amount: '' });
  };

  const saveEdit = async () => {
    if (!user || !editingId) return;
    
    try {
      const docRef = doc(db, 'artifacts', appId, 'users', user.uid, 'expenses', editingId);
      await updateDoc(docRef, {
        description: editValues.description,
        amount: parseFloat(editValues.amount) || 0
      });
      setEditingId(null);
    } catch (error) {
      console.error("Error updating expense:", error);
    }
  };

  // --- Derived State ---
  const filteredExpenses = useMemo(() => {
    return expenses.filter(exp => {
      const d = new Date(exp.date);
      return d.getMonth() === selectedMonth && d.getFullYear() === selectedYear;
    });
  }, [expenses, selectedMonth, selectedYear]);

  const stats = useMemo(() => {
    const totalSpent = filteredExpenses.reduce((acc, curr) => acc + curr.amount, 0);
    const remaining = salary - totalSpent;
    
    const categoryMap = filteredExpenses.reduce((acc, curr) => {
      acc[curr.category] = (acc[curr.category] || 0) + curr.amount;
      return acc;
    }, {} as Record<string, number>);

    const chartData = Object.entries(categoryMap)
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value);

    return { totalSpent, remaining, chartData };
  }, [filteredExpenses, salary]);

  const formatCurrency = (amount: number) => {
    const formattedNumber = new Intl.NumberFormat('en-US', {
      style: 'decimal',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
    
    // Use Non-Breaking Space (\u00A0) to prevent wrapping
    return `${formattedNumber}\u00A0DH`;
  };

  // --- Theme Classes ---
  const theme = {
    bg: isDarkMode ? 'bg-slate-900' : 'bg-slate-50',
    cardBg: isDarkMode ? 'bg-slate-800' : 'bg-white',
    text: isDarkMode ? 'text-slate-100' : 'text-slate-900',
    textMuted: isDarkMode ? 'text-slate-400' : 'text-slate-500',
    border: isDarkMode ? 'border-slate-700' : 'border-slate-200',
    inputBg: isDarkMode ? 'bg-slate-700' : 'bg-white',
    hoverBg: isDarkMode ? 'hover:bg-slate-700' : 'hover:bg-slate-50',
    modalOverlay: isDarkMode ? 'rgba(15, 23, 42, 0.8)' : 'rgba(255, 255, 255, 0.8)',
  };

  const renderIcon = (iconKey: string, className = "w-5 h-5") => {
    const IconComponent = ICON_MAP[iconKey] || MoreHorizontal;
    return <IconComponent className={className} />;
  };

  // --- Render ---

  if (authLoading) {
    return (
      <div className={`flex items-center justify-center min-h-screen ${theme.bg} ${theme.textMuted}`}>
        <Loader2 className="w-8 h-8 animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className={`flex items-center justify-center min-h-screen ${theme.bg} transition-colors duration-300`}>
        <div className={`w-full max-w-md p-8 ${theme.cardBg} rounded-2xl shadow-xl border ${theme.border}`}>
          {/* ... existing login code ... */}
          <div className="flex justify-center mb-6">
            <div className="bg-indigo-600 p-3 rounded-xl shadow-lg shadow-indigo-500/30">
              <Wallet className="w-8 h-8 text-white" />
            </div>
          </div>
          <h2 className={`text-2xl font-bold text-center mb-2 ${theme.text}`}>Welcome Back</h2>
          <p className={`text-center ${theme.textMuted} mb-8`}>Please sign in to access your budget.</p>
          
          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Email Address</label>
              <input 
                type="email" 
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={`w-full px-4 py-3 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none transition-all`}
                placeholder="you@example.com"
              />
            </div>
            <div>
              <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Password</label>
              <input 
                type="password" 
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className={`w-full px-4 py-3 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none transition-all`}
                placeholder="••••••••"
              />
            </div>
            
            {loginError && (
              <p className="text-red-500 text-sm text-center bg-red-50 dark:bg-red-900/20 p-2 rounded-lg">{loginError}</p>
            )}

            <button 
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-indigo-600 text-white font-bold rounded-lg hover:bg-indigo-700 transition-colors shadow-lg shadow-indigo-500/20 flex items-center justify-center gap-2"
            >
              {loading ? <Loader2 className="w-5 h-5 animate-spin" /> : <><Lock className="w-4 h-4" /> Sign In</>}
            </button>
          </form>

          <div className="mt-4 flex items-center gap-4">
            <div className={`h-px flex-1 ${theme.border} bg-slate-200`}></div>
            <span className={`text-xs ${theme.textMuted}`}>OR</span>
            <div className={`h-px flex-1 ${theme.border} bg-slate-200`}></div>
          </div>

          <button 
            onClick={handleGuestLogin}
            className={`w-full mt-4 py-2 border ${theme.border} rounded-lg text-sm font-medium ${theme.textMuted} hover:${theme.text} hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors flex items-center justify-center gap-2`}
          >
            <UserIcon className="w-4 h-4" />
            Continue as Guest
          </button>
          
          <div className="mt-6 text-center">
             <button
              onClick={() => setIsDarkMode(!isDarkMode)}
              className={`p-2 rounded-lg ${isDarkMode ? 'bg-slate-700 text-yellow-400' : 'bg-slate-100 text-slate-600'} hover:opacity-80 transition-all inline-flex`}
            >
              {isDarkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (loading && expenses.length === 0) {
    return (
      <div className={`flex items-center justify-center min-h-screen ${theme.bg} ${theme.textMuted}`}>
        <Loader2 className="w-8 h-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className={`min-h-screen ${theme.bg} ${theme.text} font-sans transition-colors duration-300 pb-12`}>
      {/* Header */}
      <header className={`${theme.cardBg} border-b ${theme.border} sticky top-0 z-10 transition-colors duration-300`}>
        <div className="max-w-[1600px] mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="bg-indigo-600 p-2 rounded-lg shadow-lg shadow-indigo-500/30">
              <Wallet className="w-5 h-5 text-white" />
            </div>
            <h1 className="text-xl font-bold hidden sm:block">BudgetTracker</h1>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => setIsDarkMode(!isDarkMode)}
              className={`p-2 rounded-lg ${isDarkMode ? 'bg-slate-700 text-yellow-400' : 'bg-slate-100 text-slate-600'} hover:opacity-80 transition-all`}
            >
              {isDarkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            </button>

            <button
              onClick={handleLogout}
              className={`p-2 rounded-lg text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all`}
              title="Sign Out"
            >
              <LogOut className="w-5 h-5" />
            </button>

            <div className={`flex items-center gap-2 sm:gap-4 ${isDarkMode ? 'bg-slate-700' : 'bg-slate-100'} rounded-lg p-1`}>
              <select 
                value={selectedMonth} 
                onChange={(e) => setSelectedMonth(parseInt(e.target.value))}
                className={`bg-transparent border-none text-sm font-medium ${theme.text} focus:ring-0 cursor-pointer py-1 pl-3 outline-none`}
              >
                {MONTHS.map((m, i) => (
                  <option key={m} value={i} className={isDarkMode ? 'bg-slate-800' : ''}>{m}</option>
                ))}
              </select>
              <select 
                value={selectedYear} 
                onChange={(e) => setSelectedYear(parseInt(e.target.value))}
                className={`bg-transparent border-none text-sm font-medium ${theme.text} focus:ring-0 cursor-pointer py-1 pr-3 border-l ${theme.border} outline-none`}
              >
                {[2023, 2024, 2025, 2026].map(y => (
                  <option key={y} value={y} className={isDarkMode ? 'bg-slate-800' : ''}>{y}</option>
                ))}
              </select>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-[1600px] mx-auto px-4 sm:px-6 py-8 space-y-6">
        
        {/* Top Actions & Salary Button */}
        {/* FIXED: Changed to column layout on mobile to prevent squished buttons */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <h2 className="text-2xl font-bold">Dashboard</h2>
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <button 
                onClick={() => setShowAddExpenseModal(true)}
                className={`flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 py-2 ${isDarkMode ? 'bg-indigo-600 hover:bg-indigo-700' : 'bg-slate-900 hover:bg-slate-800'} text-white rounded-lg transition-colors shadow-sm font-medium`}
            >
                <Plus className="w-4 h-4" />
                Add Expense
            </button>
            <button 
                onClick={() => {
                  setTempSalary(salary === 0 ? '' : salary.toString());
                  setShowSalaryModal(true);
                }}
                className={`flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 py-2 ${theme.cardBg} border ${theme.border} rounded-lg hover:border-indigo-500 transition-all shadow-sm font-medium`}
            >
                <Settings className="w-4 h-4" />
                Set Monthly Salary
            </button>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* FIXED: Reduced padding on mobile from p-6 to p-4 */}
          <div className={`${theme.cardBg} p-4 sm:p-6 rounded-2xl shadow-sm border ${theme.border} transition-colors duration-300`}>
            <div className="flex justify-between items-start mb-4">
              <div className="p-2 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg text-emerald-600 dark:text-emerald-400">
                <DollarSign className="w-5 h-5" />
              </div>
            </div>
            <div>
              <p className={`text-sm font-medium ${theme.textMuted} mb-1`}>Monthly Income</p>
              <p className="text-2xl font-bold">{formatCurrency(salary)}</p>
            </div>
          </div>

          <div className={`${theme.cardBg} p-4 sm:p-6 rounded-2xl shadow-sm border ${theme.border} transition-colors duration-300`}>
            <div className="flex justify-between items-start mb-4">
              <div className="p-2 bg-rose-100 dark:bg-rose-900/30 rounded-lg text-rose-600 dark:text-rose-400">
                <TrendingDown className="w-5 h-5" />
              </div>
            </div>
            <div>
              <p className={`text-sm font-medium ${theme.textMuted} mb-1`}>Total Spent</p>
              <p className="text-2xl font-bold text-rose-600 dark:text-rose-400">{formatCurrency(stats.totalSpent)}</p>
            </div>
          </div>

          <div className={`${theme.cardBg} p-4 sm:p-6 rounded-2xl shadow-sm border ${theme.border} transition-colors duration-300`}>
            <div className="flex justify-between items-start mb-4">
              <div className="p-2 bg-indigo-100 dark:bg-indigo-900/30 rounded-lg text-indigo-600 dark:text-indigo-400">
                <Wallet className="w-5 h-5" />
              </div>
            </div>
            <div>
              <p className={`text-sm font-medium ${theme.textMuted} mb-1`}>Remaining Balance</p>
              <p className={`text-2xl font-bold ${stats.remaining < 0 ? 'text-red-500' : theme.text}`}>
                {formatCurrency(stats.remaining)}
              </p>
            </div>
          </div>
        </div>

        {/* SPENDING BREAKDOWN */}
        <div className={`${theme.cardBg} p-4 sm:p-6 rounded-2xl shadow-sm border ${theme.border} transition-colors duration-300`}>
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold">Spending Breakdown</h3>
            <div className={`flex p-1 rounded-lg border ${theme.border} ${isDarkMode ? 'bg-slate-800' : 'bg-slate-100'}`}>
                <button
                    onClick={() => setChartType('bar')}
                    className={`p-2 rounded-md transition-all ${chartType === 'bar' ? (isDarkMode ? 'bg-slate-700 text-white shadow-sm' : 'bg-white text-indigo-600 shadow-sm') : 'text-slate-400 hover:text-slate-600'}`}
                    title="Bar Chart"
                >
                    <BarChart3 className="w-4 h-4" />
                </button>
                <button
                    onClick={() => setChartType('pie')}
                    className={`p-2 rounded-md transition-all ${chartType === 'pie' ? (isDarkMode ? 'bg-slate-700 text-white shadow-sm' : 'bg-white text-indigo-600 shadow-sm') : 'text-slate-400 hover:text-slate-600'}`}
                      title="Pie Chart"
                >
                    <PieChartIcon className="w-4 h-4" />
                </button>
            </div>
          </div>

          <div className="h-[300px] w-full relative">
            {stats.chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                {chartType === 'pie' ? (
                  <PieChart>
                    <Pie
                      data={stats.chartData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={80}
                      paddingAngle={5}
                      dataKey="value"
                      stroke="none"
                    >
                      {stats.chartData.map((entry, index) => {
                        const cat = categories.find(c => c.name === entry.name);
                        return (
                          <Cell key={`cell-${index}`} fill={cat ? cat.color : '#ccc'} />
                        );
                      })}
                    </Pie>
                    <RechartsTooltip 
                      formatter={(value: number) => formatCurrency(value)}
                      contentStyle={{ 
                        backgroundColor: isDarkMode ? '#1e293b' : '#fff',
                        color: isDarkMode ? '#fff' : '#000',
                        borderRadius: '8px', 
                        border: 'none', 
                        boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' 
                      }}
                    />
                    <Legend 
                      formatter={(value) => <span style={{ color: isDarkMode ? '#cbd5e1' : '#475569' }}>{value}</span>} 
                    />
                  </PieChart>
                ) : (
                  <BarChart data={stats.chartData} margin={{ top: 10, right: 10, left: 0, bottom: 50 }}>
                    <XAxis 
                      dataKey="name" 
                      axisLine={false}
                      tickLine={false}
                      tick={{ fill: isDarkMode ? '#94a3b8' : '#64748b', fontSize: 11 }}
                      dy={10}
                      interval={0}
                    />
                    <RechartsTooltip
                      formatter={(value: number) => formatCurrency(value)}
                      cursor={{ fill: isDarkMode ? '#334155' : '#f1f5f9', opacity: 0.4 }}
                      contentStyle={{ 
                        backgroundColor: isDarkMode ? '#1e293b' : '#fff',
                        color: isDarkMode ? '#fff' : '#000',
                        borderRadius: '8px', 
                        border: 'none', 
                        boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' 
                      }}
                    />
                      <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                        {stats.chartData.map((entry, index) => {
                          const cat = categories.find(c => c.name === entry.name);
                          return <Cell key={`cell-${index}`} fill={cat ? cat.color : '#ccc'} />;
                        })}
                    </Bar>
                  </BarChart>
                )}
              </ResponsiveContainer>
            ) : (
              <div className={`absolute inset-0 flex items-center justify-center ${theme.textMuted} text-sm`}>
                No data to display
              </div>
            )}
          </div>
        </div>

        {/* TRANSACTION LIST */}
        <div className={`${theme.cardBg} rounded-2xl shadow-sm border ${theme.border} overflow-hidden transition-colors duration-300`}>
          <div className={`p-4 sm:p-6 border-b ${theme.border} flex items-center justify-between`}>
            <h2 className="text-lg font-bold">Transactions</h2>
          </div>

          <div className={`divide-y ${isDarkMode ? 'divide-slate-700' : 'divide-slate-100'}`}>
            {filteredExpenses.length === 0 ? (
              <div className={`p-12 text-center ${theme.textMuted}`}>
                <PieChartIcon className="w-12 h-12 mx-auto mb-3 opacity-20" />
                <p>No expenses found for {MONTHS[selectedMonth]}</p>
              </div>
            ) : (
              filteredExpenses.map((expense) => {
                const category = categories.find(c => c.name === expense.category);
                const categoryColor = category?.color || '#64748b';
                const isEditing = editingId === expense.id;

                return (
                  <div key={expense.id} className={`p-4 ${theme.hoverBg} flex items-center justify-between group transition-colors min-h-[88px]`}>
                    {isEditing ? (
                        <div className="flex items-center gap-2 w-full">
                          <div className="flex-1 space-y-2">
                            <input 
                              value={editValues.description}
                              onChange={(e) => setEditValues({...editValues, description: e.target.value})}
                              className={`w-full px-2 py-1 text-sm border ${theme.border} rounded ${theme.inputBg} ${theme.text} focus:outline-none focus:ring-1 focus:ring-indigo-500`}
                              placeholder="Description"
                              autoFocus
                            />
                            <input 
                              type="number"
                              step="0.01"
                              value={editValues.amount}
                              onChange={(e) => setEditValues({...editValues, amount: e.target.value})}
                              className={`w-full px-2 py-1 text-sm border ${theme.border} rounded ${theme.inputBg} ${theme.text} focus:outline-none focus:ring-1 focus:ring-indigo-500`}
                              placeholder="Amount"
                            />
                          </div>
                          <div className="flex gap-1">
                            <button 
                              onClick={saveEdit}
                              className="p-2 bg-indigo-100 text-indigo-600 rounded-lg hover:bg-indigo-200"
                            >
                              <Check className="w-4 h-4" />
                            </button>
                            <button 
                              onClick={cancelEditing}
                              className="p-2 bg-slate-100 text-slate-500 rounded-lg hover:bg-slate-200"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                    ) : (
                        <>
                        <div className="flex items-center gap-4 flex-1 min-w-0 overflow-hidden">
                          <div 
                            className="w-10 h-10 rounded-full flex items-center justify-center text-white shrink-0 shadow-sm"
                            style={{ backgroundColor: categoryColor }}
                          >
                            {renderIcon(category?.icon || 'MoreHorizontal', "w-5 h-5")}
                          </div>
                          <div className="overflow-hidden">
                            <p className={`font-medium ${theme.text} truncate`}>{expense.description}</p>
                            <div className={`flex items-center gap-2 text-xs ${theme.textMuted}`}>
                              <Calendar className="w-3 h-3" />
                              {new Date(expense.date).toLocaleDateString()}
                              <span className="w-1 h-1 bg-slate-300 rounded-full"></span>
                              <span>{expense.category}</span>
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-2 flex-shrink-0">
                          
                          <div className="hidden group-hover:flex gap-1 transition-opacity">
                            <button
                              onClick={() => startEditing(expense)}
                              className={`p-2 ${isDarkMode ? 'text-slate-400 hover:text-indigo-400 hover:bg-slate-700' : 'text-slate-300 hover:text-indigo-500 hover:bg-indigo-50'} rounded-lg transition-all`}
                              title="Edit"
                            >
                              <Pencil className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleDeleteExpense(expense.id)}
                              className={`p-2 ${isDarkMode ? 'text-slate-400 hover:text-red-400 hover:bg-slate-700' : 'text-slate-300 hover:text-red-500 hover:bg-red-50'} rounded-lg transition-all`}
                              title="Delete"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                          {/* MOVED: Amount is now the last element (furthest right), buttons are to its left */}
                          <span className={`font-bold ${theme.text} whitespace-nowrap text-right`}>
                            -{formatCurrency(expense.amount)}
                          </span>
                        </div>
                        </>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </div>
      </main>

      {/* --- MODALS --- */}

      {/* Add Expense Modal (POPUP) */}
      {showAddExpenseModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 backdrop-blur-sm bg-black/50">
          <div className={`${theme.cardBg} w-full max-w-lg rounded-2xl p-6 shadow-2xl border ${theme.border} animate-in zoom-in-95`}>
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-bold">Add New Expense</h3>
              <button onClick={() => setShowAddExpenseModal(false)} className={theme.textMuted}>
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <form onSubmit={handleAddExpense} className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Amount</label>
                <div className="relative">
                  <span className={`absolute left-3 top-1/2 -translate-y-1/2 ${theme.textMuted}`}>DH</span>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={newExpense.amount}
                    onChange={(e) => setNewExpense({ ...newExpense, amount: e.target.value })}
                    className={`w-full pl-10 pr-4 py-2 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none transition-all`}
                    placeholder="0.00"
                    autoFocus
                  />
                </div>
              </div>
              
              <div>
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Category</label>
                <div className="flex gap-2">
                  <select
                    value={newExpense.category}
                    onChange={(e) => setNewExpense({ ...newExpense, category: e.target.value })}
                    className={`w-full px-4 py-2 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none transition-all`}
                  >
                    <option value="" disabled>Select Category</option>
                    {categories.map(cat => (
                      <option key={cat.name} value={cat.name}>{cat.name}</option>
                    ))}
                  </select>
                  <button 
                    type="button"
                    onClick={() => setShowCategoryModal(true)}
                    className={`p-2 border ${theme.border} rounded-lg hover:border-indigo-500 text-indigo-500`}
                    title="Add Custom Category"
                  >
                    <Plus className="w-5 h-5" />
                  </button>
                </div>
              </div>

              <div className="md:col-span-2">
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Description</label>
                <input
                  type="text"
                  value={newExpense.description}
                  onChange={(e) => setNewExpense({ ...newExpense, description: e.target.value })}
                  className={`w-full px-4 py-2 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none transition-all`}
                  placeholder="What was it for?"
                />
              </div>
              
              <div className="md:col-span-2">
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Date</label>
                <input
                  type="date"
                  required
                  value={newExpense.date}
                  onChange={(e) => setNewExpense({ ...newExpense, date: e.target.value })}
                  className={`w-full px-4 py-2 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none transition-all`}
                  style={{ colorScheme: isDarkMode ? 'dark' : 'light' }}
                />
              </div>
              
              <div className="md:col-span-2 pt-2">
                <button
                  type="submit"
                  className="w-full py-2 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition-colors shadow-lg shadow-indigo-500/20"
                >
                  Save Transaction
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Salary Modal */}
      {showSalaryModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 backdrop-blur-sm bg-black/50">
          <div className={`${theme.cardBg} w-full max-w-sm rounded-2xl p-6 shadow-2xl border ${theme.border} animate-in zoom-in-95`}>
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-bold">Update Salary</h3>
              <button onClick={() => setShowSalaryModal(false)} className={theme.textMuted}>
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className={`text-sm ${theme.textMuted} mb-4`}>
              Set your expected monthly income to track your remaining balance accurately.
            </p>
            <input
              type="number"
              value={tempSalary}
              onChange={(e) => setTempSalary(e.target.value)}
              className={`w-full px-4 py-2 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} mb-4 focus:ring-2 focus:ring-indigo-500 outline-none`}
              placeholder="0.00"
              autoFocus
            />
            <button 
              onClick={handleUpdateSalary}
              className="w-full py-2 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700"
            >
              Save Salary
            </button>
          </div>
        </div>
      )}

      {/* Category Modal */}
      {showCategoryModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 backdrop-blur-sm bg-black/50">
          <div className={`${theme.cardBg} w-full max-w-md rounded-2xl p-6 shadow-2xl border ${theme.border} animate-in zoom-in-95 max-h-[90vh] overflow-y-auto`}>
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-bold">New Category</h3>
              <button onClick={() => setShowCategoryModal(false)} className={theme.textMuted}>
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <form onSubmit={handleAddCategory} className="space-y-6">
              <div>
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-1`}>Category Name</label>
                <input
                  type="text"
                  required
                  value={newCategoryName}
                  onChange={(e) => handleCategoryNameChange(e.target.value)}
                  className={`w-full px-4 py-2 rounded-lg border ${theme.border} ${theme.inputBg} ${theme.text} focus:ring-2 focus:ring-indigo-500 outline-none`}
                  placeholder="e.g. Gym, Subscriptions"
                />
              </div>
              
              <div>
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-2`}>Select Icon</label>
                <div className={`p-3 rounded-lg border ${theme.border} ${isDarkMode ? 'bg-slate-900/50' : 'bg-slate-50'}`}>
                  <div className="grid grid-cols-6 gap-2">
                    {ICON_OPTIONS.map(opt => {
                      const IconComp = opt.component;
                      const isSelected = newCategoryIcon === opt.key;
                      return (
                        <button
                          key={opt.key}
                          type="button"
                          onClick={() => setNewCategoryIcon(opt.key)}
                          className={`
                            p-2 rounded-lg flex items-center justify-center transition-all
                            ${isSelected 
                              ? 'bg-indigo-600 text-white shadow-md scale-110' 
                              : `text-slate-500 hover:bg-slate-200 dark:hover:bg-slate-700`}
                          `}
                          title={opt.key}
                        >
                          <IconComp className="w-5 h-5" />
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>

              <div>
                <label className={`block text-xs font-semibold ${theme.textMuted} uppercase mb-2`}>Color</label>
                <div className="grid grid-cols-6 gap-2">
                  {COLORS.map(color => (
                    <button
                      key={color}
                      type="button"
                      onClick={() => setNewCategoryColor(color)}
                      className={`w-8 h-8 rounded-full transition-transform hover:scale-110 ${newCategoryColor === color ? 'ring-2 ring-offset-2 ring-indigo-500' : ''}`}
                      style={{ backgroundColor: color }}
                    />
                  ))}
                </div>
              </div>

              <button 
                type="submit"
                className="w-full py-2 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 mt-2"
              >
                Create Category
              </button>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}