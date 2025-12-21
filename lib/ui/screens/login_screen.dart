import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../core/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../data/services/firestore_service.dart';
import '../../core/theme.dart';
import '../widgets/glass_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (!_isLogin) {
        if (password != _confirmPasswordController.text) {
          throw Exception(AppStrings.passwordMismatch);
        }
        if (password.length < 6) {
           throw Exception(AppStrings.passwordLength);
        }
        await auth.signUp(email, password);
      } else {
        await auth.signIn(email, password);
      }

      // Persist Selected Language
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
         // Using a new instance since we don't have direct access to provider's service here easily
         // and creating one is cheap.
         await FirestoreService().updateSettings(user.uid, {'language': AppStrings.language});
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll("Exception: ", ""); 
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).signInAnonymously();
    } catch (e) {
      if (mounted) setState(() => _error = AppStrings.guestLoginFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
       _isLoading = true;
       _error = null;
    });
    try {
      await Provider.of<AuthProvider>(context, listen: false).signInWithGoogle();
      // Auth wrapper handles navigation
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PopupMenuItem<String> _buildLangItem(String code, String label) {
    final isSelected = AppStrings.language == code;
    return PopupMenuItem(
      value: code,
      child: Row(
        children: [
          Text(label, style: GoogleFonts.outfit(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          if (isSelected) ...[
             const Spacer(),
             const Icon(LucideIcons.check, size: 16, color: AppTheme.primary),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)] 
                : [const Color(0xFFF0F9FF), const Color(0xFFE0E7FF)], 
          ),
        ),
        child: Stack(
          children: [
            // Language Switcher (Top Right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: PopupMenuButton<String>(
                onSelected: (lang) {
                   setState(() {
                      AppStrings.setLanguage(lang);
                   });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.globe, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                         AppStrings.language.toUpperCase(),
                         style: GoogleFonts.outfit(
                           color: isDark ? Colors.white : const Color(0xFF1E293B),
                           fontWeight: FontWeight.w600,
                         ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  _buildLangItem('en', "English"),
                  _buildLangItem('fr', "Français"),
                  _buildLangItem('ar', "العربية"),
                ],
              ),
            ),

            SafeArea(
              child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8b5cf6), Color(0xFF6366f1)], // Violet to Indigo
                        ),
                        borderRadius: BorderRadius.circular(24), // Rounded square like screenshot
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366f1).withOpacity(0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          )
                        ]
                      ),
                      child: const Icon(LucideIcons.wallet, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      AppStrings.appTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? AppStrings.loginSubtitle : AppStrings.signupSubtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Login/Signup Form Card
                    GlassContainer(
                       padding: const EdgeInsets.all(32),
                       borderRadius: BorderRadius.circular(24),
                       color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.white.withOpacity(0.8),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             _isLogin ? AppStrings.loginTitle : AppStrings.signupTitle, 
                             style: GoogleFonts.outfit(
                               fontSize: 24,
                               fontWeight: FontWeight.bold,
                               color: isDark ? Colors.white : Colors.black87
                             )
                           ),
                           const SizedBox(height: 24),
                           
                           // Email
                           TextField(
                             controller: _emailController,
                             style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                             decoration: InputDecoration(
                               hintText: AppStrings.emailHint,
                               hintStyle: GoogleFonts.outfit(color: Colors.grey),
                               prefixIcon: const Icon(LucideIcons.mail, size: 20, color: AppTheme.primary),
                               filled: true,
                               fillColor: isDark ? Colors.black26 : Colors.grey[100],
                               contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                               focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                             ),
                           ),
                           const SizedBox(height: 16),
                           
                           // Password
                           TextField(
                             controller: _passwordController,
                             obscureText: true,
                             style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                             decoration: InputDecoration(
                               hintText: AppStrings.passwordHint,
                               hintStyle: GoogleFonts.outfit(color: Colors.grey),
                               prefixIcon: const Icon(LucideIcons.lock, size: 20, color: AppTheme.primary),
                               filled: true,
                               fillColor: isDark ? Colors.black26 : Colors.grey[100],
                               contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                               focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                             ),
                           ),

                           // Confirm Password (Only for Sign Up)
                           if (!_isLogin) ...[
                             const SizedBox(height: 16),
                             TextField(
                               controller: _confirmPasswordController,
                               obscureText: true,
                               style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                               decoration: InputDecoration(
                                 hintText: AppStrings.confirmPasswordHint,
                                 hintStyle: GoogleFonts.outfit(color: Colors.grey),
                                 prefixIcon: const Icon(LucideIcons.lock, size: 20, color: AppTheme.primary),
                                 filled: true,
                                 fillColor: isDark ? Colors.black26 : Colors.grey[100],
                                 contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                               ),
                             ),
                           ],
                           
                           if (_error != null)
                             Padding(
                               padding: const EdgeInsets.only(top: 16),
                               child: Row(
                                 children: [
                                   const Icon(LucideIcons.alertCircle, color: Colors.red, size: 16),
                                   const SizedBox(width: 8),
                                   Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                                 ],
                               ),
                             ),

                           const SizedBox(height: 32),
                           
                           // Action Button
                           Container(
                             width: double.infinity,
                             height: 56,
                             decoration: BoxDecoration(
                               gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                               borderRadius: BorderRadius.circular(16),
                               boxShadow: [
                                 BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))
                               ]
                             ),
                             child: ElevatedButton(
                               onPressed: _isLoading ? null : _handleAuth,
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.transparent,
                                 shadowColor: Colors.transparent,
                                 foregroundColor: Colors.white,
                                 padding: EdgeInsets.zero,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                               ),
                               child: _isLoading 
                                 ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                 : Text(
                                     _isLogin ? AppStrings.loginBtn : AppStrings.signupBtn, 
                                     style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)
                                   ),
                             ),
                           ),
                           
                           const SizedBox(height: 16),
                           
                           SizedBox(
                             width: double.infinity,
                             height: 56,
                             child: ElevatedButton.icon(
                               onPressed: _isLoading ? null : _handleGoogleLogin,
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.white,
                                 foregroundColor: Colors.black54,
                                 elevation: 2,
                                 side: const BorderSide(color: Color(0xFFDADCE0)), // Standard Google Grey Border
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // Standard Capsule shape
                                 padding: EdgeInsets.zero,
                               ),
                               icon: const Icon(LucideIcons.chrome, size: 20, color: Colors.black87),
                               label: Text(
                                 "Sign in with Google",
                                 style: GoogleFonts.roboto( // Standard Google Font
                                   fontSize: 16,
                                   color: Colors.black87,
                                   fontWeight: FontWeight.w600,
                                 ),
                               ),
                             ),
                           ),

                           const SizedBox(height: 20),
                           
                           // Toggle Login/Signup
                           Center(
                             child: TextButton(
                               onPressed: () => setState(() { 
                                 _isLogin = !_isLogin; 
                                 _error = null;
                               }),
                               child: Text(
                                 _isLogin ? AppStrings.toSignupText : AppStrings.toLoginText,
                                 style: GoogleFonts.outfit(color: isDark ? Colors.grey[300] : Colors.grey[700])
                               ),
                             ),
                           ),
                         ],
                       ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Guest Option
                    if (_isLogin) ...[ 
                      Row(
                        children: [
                          Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(AppStrings.orText, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12))),
                          Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      TextButton(
                        onPressed: _isLoading ? null : _handleGuestLogin,
                        child: Text(
                          AppStrings.guestLogin, 
                          style: GoogleFonts.outfit(color: isDark ? Colors.grey[400] : Colors.grey[600])
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
      ),
    );
  }
}
