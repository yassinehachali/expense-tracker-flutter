import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart'; 
import '../../providers/auth_provider.dart';
import '../widgets/glass_container.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = "Invalid email or password.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).signInAnonymously();
    } catch (e) {
      setState(() => _error = "Guest login failed.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFf3f4f6), // Match gradient end color
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1e1b4b), const Color(0xFF0f172a)] 
              : [const Color(0xFFe0e7ff), const Color(0xFFf3f4f6)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))
                    ]
                  ),
                  child: const Icon(LucideIcons.wallet, color: Colors.white, size: 48),
                ),


                const SizedBox(height: 32),
                
                // Title
                Text(
                  "Expense Tracker",
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  "Manage your finances with ease",
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 48),
                
                // Login Form Card
                GlassContainer(
                   padding: const EdgeInsets.all(32),
                   borderRadius: BorderRadius.circular(24),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text("Login", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 24),
                       
                       // Email
                       TextField(
                         controller: _emailController,
                         style: theme.textTheme.bodyMedium,
                         decoration: InputDecoration(
                           hintText: 'Email Address',
                           prefixIcon: const Icon(LucideIcons.mail, size: 18),
                           filled: true,
                           fillColor: theme.cardColor.withOpacity(0.5),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor)),
                         ),
                       ),
                       const SizedBox(height: 16),
                       
                       // Password
                       TextField(
                         controller: _passwordController,
                         obscureText: true,
                         style: theme.textTheme.bodyMedium,
                         decoration: InputDecoration(
                           hintText: 'Password',
                           prefixIcon: const Icon(LucideIcons.lock, size: 18),
                           filled: true,
                           fillColor: theme.cardColor.withOpacity(0.5),
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor)),
                         ),
                       ),
                       
                       if (_error != null)
                         Padding(
                           padding: const EdgeInsets.only(top: 12),
                           child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                         ),

                       const SizedBox(height: 32),
                       
                       // Sign In Button
                       Container(
                         width: double.infinity,
                         height: 56,
                         decoration: BoxDecoration(
                           gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: [
                             BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
                           ]
                         ),
                         child: ElevatedButton(
                           onPressed: _isLoading ? null : _handleLogin,
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.transparent,
                             shadowColor: Colors.transparent,
                             foregroundColor: Colors.white,
                             padding: EdgeInsets.zero,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                           child: _isLoading 
                             ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                             : const Text("Sign In", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         ),
                       ),
                     ],
                   ),
                ),
                
                const SizedBox(height: 24),
                
                // Guest Option
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.dividerColor)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: TextStyle(color: Colors.grey[500], fontSize: 12))),
                    Expanded(child: Divider(color: theme.dividerColor)),
                  ],
                ),
                const SizedBox(height: 24),
                
                TextButton(
                  onPressed: _isLoading ? null : _handleGuestLogin,
                  child: Text("Continue as Guest", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
