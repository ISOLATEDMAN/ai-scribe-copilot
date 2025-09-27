import 'package:assapp/blocs/AuthBloc/bloc/auths_bloc.dart';
import 'package:assapp/pages/home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The LoginScreen now simply displays the LoginView.
/// It doesn't need to provide the BLoC because it's already
/// provided higher up in the widget tree in main.dart.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The BlocProvider was removed from here.
    return const LoginView();
  }
}

/// The UI for the Login screen. It listens to state changes from AuthsBloc.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isEmailValid = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
    
    // Listen to email changes
    emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    emailController.dispose();
    super.dispose();
  }
  
  void _validateEmail() {
    final email = emailController.text;
    final isValid = email.isNotEmpty && 
                   email.contains('@') && 
                   email.contains('.') &&
                   RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    
    if (_isEmailValid != isValid) {
      setState(() {
        _isEmailValid = isValid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: BlocConsumer<AuthsBloc, AuthsState>(
          listener: (context, state) {
            if (state is AuthsFailure) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.error)),
                      ],
                    ),
                    backgroundColor: Colors.red.shade500,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
            }
            if (state is AuthsSuccess) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text("Login Successful!"),
                      ],
                    ),
                    backgroundColor: Colors.green.shade500,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              
              Navigator.pushReplacement(
                context, 
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const Home(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            }
          },
          builder: (context, state) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Header Section
                      Expanded(
                        flex: 2,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo/Icon
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF1D4ED8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                                      offset: const Offset(0, 8),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.medical_services_rounded,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Welcome Text
                              const Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Text(
                                'Sign in to access your medical records',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Form Section
                      Expanded(
                        flex: 3,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Login Form Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade200,
                                        offset: const Offset(0, 8),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Form Title
                                        const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 24),
                                        
                                        // Email Field
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Email Address',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: emailController,
                                              keyboardType: TextInputType.emailAddress,
                                              autovalidateMode: AutovalidateMode.onUserInteraction,
                                              decoration: InputDecoration(
                                                hintText: 'Enter your email address',
                                                prefixIcon: Icon(
                                                  Icons.email_outlined,
                                                  color: _isEmailValid 
                                                    ? const Color(0xFF10B981)
                                                    : Colors.grey.shade500,
                                                ),
                                                suffixIcon: _isEmailValid
                                                  ? const Icon(
                                                      Icons.check_circle,
                                                      color: Color(0xFF10B981),
                                                    )
                                                  : null,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: _isEmailValid 
                                                      ? const Color(0xFF10B981)
                                                      : Colors.grey.shade300,
                                                  ),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFF3B82F6), 
                                                    width: 2,
                                                  ),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: Colors.red.shade400),
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey.shade50,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 16,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter your email';
                                                }
                                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                                  return 'Please enter a valid email address';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 32),
                                        
                                        // Login Button
                                        SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            child: state is AuthsLoading
                                              ? Container(
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : ElevatedButton(
                                                  onPressed: _isEmailValid 
                                                    ? () {
                                                        if (formKey.currentState?.validate() ?? false) {
                                                          context.read<AuthsBloc>().add(
                                                            LoginReq(email: emailController.text.trim()),
                                                          );
                                                        }
                                                      }
                                                    : null,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.transparent,
                                                    disabledBackgroundColor: Colors.grey.shade300,
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                  ).copyWith(
                                                    backgroundColor: MaterialStateProperty.resolveWith((states) {
                                                      if (states.contains(MaterialState.disabled)) {
                                                        return Colors.grey.shade300;
                                                      }
                                                      return null;
                                                    }),
                                                  ),
                                                  child: Container(
                                                    decoration: _isEmailValid ? BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ) : null,
                                                    child: const Center(
                                                      child: Text(
                                                        'Sign In',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Help Text
                                Text(
                                  'Having trouble signing in? Contact support',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Footer
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            '© 2024 Medical Assistant App',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}