class AppStrings {
  // Notification Channels
  static const String updatesChannelId = 'updates_channel';
  static const String updatesChannelName = 'App Updates';
  static const String updatesChannelDesc = 'Notifications for new app updates';
  
  static const String reminderChannelId = 'reminder_channel';
  static const String reminderChannelName = 'Daily Reminders';
  static const String reminderChannelDesc = 'Daily reminders to record expenses';

  // Notification Content
  static const String updateTitle = 'Update Available: ';
  static const String updateBody = 'A new version is available. Tap to update.';

  static const String dailyReminderTitle = 'Daily Reminder 📝';
  static const String dailyReminderBody = "Don't forget to record your expenses for today!";
  
  // Payloads
  static const String payloadUpdateCheck = 'update_check';

  // Login Screen
  static const String appTitle = 'Expense Tracker';
  static const String loginSubtitle = 'Manage your finances with ease';
  static const String signupSubtitle = 'Create your account';
  static const String loginBtn = 'Sign In';
  static const String signupBtn = 'Create Account'; // Used for button text
  static const String signupTitle = 'Sign Up'; // Used for header
  static const String loginTitle = 'Login';
  static const String emailHint = 'Email Address';
  static const String passwordHint = 'Password';
  static const String confirmPasswordHint = 'Confirm Password';
  static const String guestLogin = 'Continue as Guest';
  static const String guestLoginFailed = 'Guest login failed.';
  static const String passwordMismatch = 'Passwords do not match';
  static const String passwordLength = 'Password must be at least 6 characters';
  static const String toSignupText = "Don't have an account? Sign Up";
  static const String toLoginText = "Already have an account? Login";
  static const String orText = "OR";

  // Dashboard & Common
  static const String welcomeBack = 'Welcome back';
  static const String totalRemaining = 'Total Remaining';
  static const String income = 'Income';
  static const String spent = 'Spent';
  static const String topSpending = 'Top Spending';
  static const String noDataMonth = 'No data for this month';
  static const String recentActivity = 'Recent Activity';
  static const String viewAll = 'View All';
  
  // Transaction Actions
  static const String editTransaction = 'Edit Transaction';
  static const String recordRepayment = 'Record Repayment';
  static const String deleteTransaction = 'Delete Transaction';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  
  // Repayment Dialog
  static const String totalLoan = 'Total Lent: ';
  static const String remaining = 'Remaining: ';
  static const String amountReturned = 'Amount Returned';
  static const String enterAmount = 'Enter amount';
  static const String errorAmountExceeds = 'Amount cannot exceed remaining balance';
  static const String repaidPrefix = 'Repaid ';

  // Transactions Screen
  static const String historyTitle = 'History';
  static const String noTransactions = 'No transactions found';
  static const String filterAll = 'All';
  static const String filterExpenses = 'Expenses';
  static const String filterLoans = 'Lending';
  static const String filterIncome = 'Income';
  
  // Lending Actions
  static const String markAsPending = 'Mark as Pending';
  
  // Borrowing
  static const String borrow = 'Borrow';
  static const String loansManager = 'Loans Manager';
  static const String repay = 'Repay';
  static const String totalBorrowed = 'Total Borrowed: ';
  static const String descHintBorrow = 'Who are you borrowing from?';
  // Add/Edit Expense Screen
  static const String addTransaction = 'Add Transaction';
  static const String saveTransaction = 'Save Transaction';
  static const String transactionSaved = 'Transaction saved!';
  static const String transactionUpdated = 'Transaction updated!';
  static const String invalidAmount = 'Please enter a valid amount';
  static const String errorPrefix = 'Error: ';
  static const String amountLabel = 'Amount';
  static const String amountHint = '0.00';
  static const String descLabel = 'Description (Optional)';
  static const String descLabelLoan = 'Person Name';
  static const String descHint = 'What is this for?';
  static const String descHintLoan = 'Who are you lending to?';
  static const String categoryLabel = 'Category';
  static const String dateLabel = 'Date';
  static const String userNotLoggedIn = 'User not logged in';

  // Settings Screen
  static const String settingsTitle = 'Settings';
  static const String salaryCycleOption = 'Salary & Cycle';
  static const String categoriesOption = 'Categories';
  static const String categoriesSubtitle = 'Manage your categories';
  static const String changePasswordOption = 'Change Password';
  static const String checkUpdatesOption = 'Check for Updates';
  static const String resetDataOption = 'Reset All Data';
  static const String logoutOption = 'Log Out';
  static const String guestUser = 'Guest User';
  
  // Salary Dialog
  static const String customizeCycle = "Customize the salary and start date for this specific month.";
  static const String salaryAmount = "Salary Amount";
  static const String cycleStartsIn = "Cycle Starts In:";
  static const String cycleStartDay = "Day ";
  static const String cycleHelperText = "This cycle will start on ";
  static const String save = 'Save';
  
  // Change Password Dialog
  static const String currentPassword = "Current Password";
  static const String newPassword = "New Password";
  static const String confirmNewPassword = "Confirm New Password";
  static const String passwordUpdateSuccess = "Password updated successfully";
  static const String newPasswordMismatch = "New passwords do not match";
  
  // Reset Dialog
  static const String resetDataTitle = "Reset Data";
  static const String resetDataConfirm = "Are you sure you want to delete ALL expenses and reset your salary? This cannot be undone.";
  static const String deleteAll = "Delete All";
  
  // Updates
  static const String updateAvailableTitle = "Update Available 🚀";
  static const String changelog = "Changelog:";
  static const String later = "Later";
  static const String updateNow = "Update Now";
  static const String upToDate = "Up to date!";
  static const String checkFailed = "Check failed";
  static const String startDownload = "Starting download...";
  static const String downloading = "Downloading: ";
  static const String launchingInstaller = "Launching Installer...";
  static const String installFailed = "Install failed: ";
  static const String downloadFailed = "Download failed";
  
  // Category Screen
  static const String manageCategories = "Manage Categories";
  static const String addNewCategory = "Add New Category";
  static const String categoryNameHint = "Category Name";
  static const String selectColor = "Select Color";
  static const String selectIcon = "Select Icon";
  static const String createCategory = "Create Category";
  static const String myCategories = "My Categories";
  static const String noCustomCategories = "No custom categories yet.";
  static const String pleaseLogin = "Please login";
  
  // Expense Card
  static const String deleteConfirmationTitle = "Delete Transaction?";
  static const String deleteConfirmationBody = "This action cannot be undone.";
  static const String deleteAction = "Delete";
  static const String loanReturned = "Repaid";
  static const String returnedLabel = "Returned: ";
}
