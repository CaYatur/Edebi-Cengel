import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';

// Floating Particle
class _Particle {
  double x, y, radius, speed, opacity;
  _Particle({required this.x, required this.y, required this.radius, required this.speed, required this.opacity});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animValue;
  _ParticlePainter({required this.particles, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = (p.y - p.speed * animValue * 300) % size.height;
      final dx = p.x + sin(animValue * 2 * pi + p.y) * 18;
      final paint = Paint()
        ..color = Colors.white.withOpacity(p.opacity * (0.4 + 0.6 * sin(animValue * pi + p.y).abs()))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 0.6);
      canvas.drawCircle(Offset(dx % size.width, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// Shimmer Text
class _ShimmerText extends StatelessWidget {
  final String text;
  final double animValue;
  final TextStyle baseStyle;
  const _ShimmerText({required this.text, required this.animValue, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: const [Colors.white, Color(0xFFFFD700), Colors.white],
          stops: [(animValue - 0.3).clamp(0.0, 1.0), animValue.clamp(0.0, 1.0), (animValue + 0.3).clamp(0.0, 1.0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(text, style: baseStyle),
    );
  }
}

// Floating icon model
class _FloatingIcon {
  final IconData icon;
  final double x, y, size, speed, phase;
  const _FloatingIcon({required this.icon, required this.x, required this.y, required this.size, required this.speed, required this.phase});
}

// Auth Screen
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerDisplayNameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerPasswordConfirmController = TextEditingController();

  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _logoController;
  late AnimationController _formSlideController;
  late AnimationController _floatingIconCtrl;
  late Animation<double> _logoScale;
  late Animation<Offset> _formSlide;

  final List<_Particle> _particles = [];
  final _rng = Random();
  final List<_FloatingIcon> _floatingIcons = [];
  final _sound = SoundService.instance;

  @override
  void initState() {
    super.initState();
    final _animEnabled = SettingsService.instance.animationsEnabled;
    final _particlesEnabled = SettingsService.instance.particlesEnabled;
    
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() => _errorMessage = null);
        _sound.playTabSwitch();
      }
    });

    _bgController = AnimationController(duration: const Duration(seconds: 8), vsync: this);
    _shimmerController = AnimationController(duration: const Duration(seconds: 3), vsync: this);
    _logoController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);

    _formSlideController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formSlideController, curve: Curves.easeOutCubic));

    _floatingIconCtrl = AnimationController(duration: const Duration(seconds: 12), vsync: this);

    if (_animEnabled) {
      _bgController.repeat(reverse: true);
      _shimmerController.repeat();
      _logoController.forward();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _formSlideController.forward();
      });
      _floatingIconCtrl.repeat();
    } else {
      // Animasyonlar kapalıysa controllers'i direkt son haline getir
      _bgController.value = 0.5;
      _shimmerController.value = 0.5;
      _logoController.value = 1.0;
      _formSlideController.value = 1.0;
      _floatingIconCtrl.value = 0.0;
    }

    if (_particlesEnabled) {
      _initParticles();
      _initFloatingIcons();
    }
    Future.delayed(const Duration(milliseconds: 600), () => _sound.playWelcome());
  }

  void _initParticles() {
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble() * 500,
        y: _rng.nextDouble() * 900,
        radius: _rng.nextDouble() * 3 + 1,
        speed: _rng.nextDouble() * 0.3 + 0.1,
        opacity: _rng.nextDouble() * 0.5 + 0.1,
      ));
    }
  }

  void _initFloatingIcons() {
    final icons = [Icons.menu_book_rounded, Icons.auto_stories, Icons.edit_note, Icons.school_rounded,
                   Icons.emoji_events, Icons.star_rounded, Icons.lightbulb_outline, Icons.extension_rounded];
    for (int i = 0; i < icons.length; i++) {
      _floatingIcons.add(_FloatingIcon(
        icon: icons[i], x: _rng.nextDouble(), y: _rng.nextDouble(),
        size: _rng.nextDouble() * 14 + 18, speed: _rng.nextDouble() * 0.4 + 0.15,
        phase: _rng.nextDouble() * 2 * pi,
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgController.dispose();
    _shimmerController.dispose();
    _logoController.dispose();
    _formSlideController.dispose();
    _floatingIconCtrl.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerDisplayNameController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgController, _shimmerController, _floatingIconCtrl]),
      builder: (context, _) {
        final t = _bgController.value;
        final topColor = Color.lerp(const Color(0xFF0A1929), const Color(0xFF0D3D3D), t)!;
        final midColor = Color.lerp(const Color(0xFF0E6E6E), const Color(0xFF19857B), t)!;
        final botColor = Color.lerp(const Color(0xFF26A69A), const Color(0xFF4DB6AC), t)!;

        return Scaffold(
          backgroundColor: topColor,
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [topColor, midColor, botColor],
                    stops: [0.0, 0.5 + sin(t * pi) * 0.15, 1.0],
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _ParticlePainter(particles: _particles, animValue: SettingsService.instance.particlesEnabled ? t : 0)),
              ),
              if (SettingsService.instance.particlesEnabled) ..._buildFloatingIcons(t),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    ScaleTransition(scale: _logoScale, child: _buildGlowingLogo(t)),
                    const SizedBox(height: 10),
                    _ShimmerText(
                      text: 'Edebi Çengel',
                      animValue: _shimmerController.value,
                      baseStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Opacity(
                      opacity: 0.6 + 0.4 * sin(t * pi),
                      child: const Text('Türk Edebiyatı Çengel Bulmacası',
                          style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SlideTransition(
                        position: _formSlide,
                        child: FadeTransition(opacity: _formSlideController, child: _buildFormCard(t)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFloatingIcons(double t) {
    final size = MediaQuery.of(context).size;
    return _floatingIcons.map((fi) {
      final progress = (_floatingIconCtrl.value + fi.phase / (2 * pi)) % 1.0;
      final x = fi.x * size.width + sin(progress * 2 * pi) * 30;
      final y = (fi.y * size.height - progress * fi.speed * size.height) % size.height;
      final opacity = (0.08 + 0.12 * sin(progress * 2 * pi + fi.phase)).clamp(0.0, 1.0);
      final rotation = progress * 2 * pi * 0.3;
      return Positioned(
        left: x, top: y,
        child: Transform.rotate(angle: rotation, child: Opacity(opacity: opacity, child: Icon(fi.icon, size: fi.size, color: Colors.white))),
      );
    }).toList();
  }

  Widget _buildGlowingLogo(double t) {
    final glowOpacity = 0.3 + 0.4 * sin(t * pi);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFD700).withOpacity(glowOpacity), blurRadius: 30, spreadRadius: 8),
          BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(glowOpacity * 0.5), blurRadius: 50, spreadRadius: 15),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset('assets/media/logo.png', height: 80, width: 80,
            errorBuilder: (_, __, ___) => const Icon(Icons.grid_on, size: 80, color: Colors.white)),
      ),
    );
  }

  Widget _buildFormCard(double t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.15 + 0.1 * sin(t * pi)), blurRadius: 30, offset: const Offset(0, -6)),
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, -2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            _buildAnimatedTopBar(t),
            _buildTabBar(),
            const SizedBox(height: 6),
            if (_errorMessage != null) _buildErrorBanner(),
            Expanded(
              child: TabBarView(controller: _tabController, children: [_buildLoginForm(t), _buildRegisterForm(t)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: TextButton.icon(
                onPressed: _isLoading ? null : () { _sound.playButtonClick(); Navigator.of(context).pop(); },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Giriş yapmadan devam et', style: TextStyle(fontSize: 13.5, decoration: TextDecoration.underline)),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTopBar(double t) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF26A69A), const Color(0xFFFFD700), const Color(0xFF00695C)],
          stops: [(t - 0.2).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.2).clamp(0.0, 1.0)],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF6E8C3), borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 54,
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.symmetric(vertical: 10),
          indicator: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE1C78F), Color(0xFFD4A843)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: const Color(0xFFD4A843).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          labelColor: const Color(0xFF004D40),
          unselectedLabelColor: const Color(0xFF6F5B3E),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          dividerHeight: 0,
          tabs: const [Tab(text: 'Giriş Yap'), Tab(text: 'Kayıt Ol')],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ]),
      ),
    );
  }

  Widget _buildLoginForm(double t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAnimatedField(delay: 0, child: TextFormField(
              controller: _loginUsernameController,
              decoration: _inputDeco('Kullanıcı Adı', Icons.person),
              validator: (v) => (v == null || v.isEmpty) ? 'Kullanıcı adı gerekli' : null,
              textInputAction: TextInputAction.next,
            )),
            const SizedBox(height: 14),
            _buildAnimatedField(delay: 100, child: TextFormField(
              controller: _loginPasswordController,
              obscureText: !_loginPasswordVisible,
              decoration: _inputDeco('Şifre', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_loginPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _loginPasswordVisible = !_loginPasswordVisible),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Şifre gerekli' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
            )),
            const SizedBox(height: 22),
            _buildAnimatedField(delay: 200, child: _buildActionButton(
              label: 'Giriş Yap', icon: Icons.login_rounded, color: Theme.of(context).colorScheme.primary,
              isLoading: _isLoading && _tabController.index == 0, onPressed: _handleLogin, animValue: t,
            )),
            const SizedBox(height: 14),
            _buildAnimatedField(delay: 260, child: _buildOAuthDivider()),
            const SizedBox(height: 12),
            _buildAnimatedField(delay: 320, child: _buildCayadevButton(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm(double t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAnimatedField(delay: 0, child: TextFormField(
              controller: _registerUsernameController,
              decoration: _inputDeco('Kullanıcı Adı', Icons.person).copyWith(helperText: '3-20 karakter'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kullanıcı adı gerekli';
                if (v.length < 3) return 'En az 3 karakter olmalı';
                if (v.length > 20) return 'En fazla 20 karakter olabilir';
                return null;
              },
              textInputAction: TextInputAction.next,
            )),
            const SizedBox(height: 14),
            _buildAnimatedField(delay: 80, child: TextFormField(
              controller: _registerDisplayNameController,
              decoration: _inputDeco('Görünen İsim (opsiyonel)', Icons.badge).copyWith(helperText: 'Sıralamada görünecek isim'),
              textInputAction: TextInputAction.next,
            )),
            const SizedBox(height: 14),
            _buildAnimatedField(delay: 160, child: TextFormField(
              controller: _registerPasswordController,
              obscureText: !_registerPasswordVisible,
              decoration: _inputDeco('Şifre', Icons.lock).copyWith(
                helperText: 'En az 6 karakter',
                suffixIcon: IconButton(
                  icon: Icon(_registerPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _registerPasswordVisible = !_registerPasswordVisible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Şifre gerekli';
                if (v.length < 6) return 'En az 6 karakter olmalı';
                return null;
              },
              textInputAction: TextInputAction.next,
            )),
            const SizedBox(height: 14),
            _buildAnimatedField(delay: 240, child: TextFormField(
              controller: _registerPasswordConfirmController,
              obscureText: !_registerPasswordVisible,
              decoration: _inputDeco('Şifre Tekrar', Icons.lock_outline),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Şifre tekrarı gerekli';
                if (v != _registerPasswordController.text) return 'Şifreler eşleşmiyor';
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleRegister(),
            )),
            const SizedBox(height: 22),
            _buildAnimatedField(delay: 320, child: _buildActionButton(
              label: 'Kayıt Ol', icon: Icons.person_add_rounded, color: Colors.green.shade700,
              isLoading: _isLoading && _tabController.index == 1, onPressed: _handleRegister, animValue: t,
            )),
            const SizedBox(height: 14),
            _buildAnimatedField(delay: 380, child: _buildOAuthDivider()),
            const SizedBox(height: 12),
            _buildAnimatedField(delay: 440, child: _buildCayadevButton(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'veya',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }

  Widget _buildCayadevButton(double animValue) {
    final pulse = 1.0 + sin(animValue * 2 * pi) * 0.018;
    // CaYaDev marka rengi (logo arka planı ile aynı, ki logo butona seamless oturur)
    const cayaColor = Color(0xFF111827);
    return AnimatedScale(
      scale: pulse,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cayaColor.withOpacity(0.35 + 0.15 * sin(animValue * 2 * pi)),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : () { _sound.playButtonClick(); _handleCayadevLogin(); },
          style: ElevatedButton.styleFrom(
            backgroundColor: cayaColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  height: 22, width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                SvgPicture.asset(
                  'assets/media/cayadev_logo.svg',
                  height: 28,
                  width: 28,
                ),
              const SizedBox(width: 12),
              const Text(
                'CaYaDev ile Giriş Yap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
    );
  }

  Widget _buildAnimatedField({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: ch)),
      child: child,
    );
  }

  Widget _buildActionButton({
    required String label, required IconData icon, required Color color,
    required bool isLoading, required VoidCallback onPressed, required double animValue,
  }) {
    final pulse = 1.0 + sin(animValue * 2 * pi) * 0.025;
    final glowStrength = 0.3 + 0.25 * sin(animValue * 2 * pi);
    return AnimatedScale(
      scale: pulse, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(glowStrength), blurRadius: 18, spreadRadius: 1, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : () { _sound.playButtonClick(); onPressed(); },
          icon: isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Icon(icon, size: 20),
          label: Text(isLoading ? 'Lütfen bekleyin...' : label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) { _sound.playError(); return; }
    setState(() { _isLoading = true; _errorMessage = null; });
    final auth = AuthService.instance;
    final success = await auth.login(username: _loginUsernameController.text.trim(), password: _loginPasswordController.text);
    if (!mounted) return;
    setState(() { _isLoading = false; if (!success) { _errorMessage = auth.errorMessage ?? 'Giriş başarısız'; _sound.playError(); } });
    if (success) { _sound.playSuccess(); if (mounted) Navigator.of(context).pop(true); }
  }

  Future<void> _handleCayadevLogin() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final auth = AuthService.instance;

    bool waitingDialogOpen = false;

    final success = await auth.loginWithCayadev(
      onWaitingForBrowser: () {
        if (!mounted) return;
        waitingDialogOpen = true;
        // Tam ekran modal: kullanıcı tarayıcıdan dönerken görsel feedback + iptal
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.85),
          builder: (ctx) => PopScope(
            canPop: false,
            child: _buildCayadevWaitingDialog(ctx),
          ),
        ).then((_) => waitingDialogOpen = false);
      },
    );

    // Bekleme diyaloğu hâlâ açıksa kapat
    if (waitingDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!success && auth.errorMessage != null) {
        _errorMessage = auth.errorMessage;
        _sound.playError();
      }
    });
    if (success) {
      _sound.playSuccess();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Widget _buildCayadevWaitingDialog(BuildContext dialogCtx) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1929), Color(0xFF111827), Color(0xFF0D3D3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: SvgPicture.asset(
                      'assets/media/cayadev_logo.svg',
                      height: 80,
                      width: 80,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    height: 36, width: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tarayıcıda Giriş Yapın',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CaYaDev hesabınızla giriş yapmak için açılan sekmeyi kullanın. '
                    'İzin verdikten sonra otomatik olarak buraya geri döneceksiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tarayıcı açılmadıysa, bu pencereyi iptal edip tekrar deneyin.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        AuthService.instance.cancelCayadevLogin();
                        Navigator.of(dialogCtx).pop();
                      },
                      icon: const Icon(Icons.close_rounded, size: 20),
                      label: const Text(
                        'İptal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) { _sound.playError(); return; }
    setState(() { _isLoading = true; _errorMessage = null; });
    final auth = AuthService.instance;
    final success = await auth.register(
      username: _registerUsernameController.text.trim(),
      password: _registerPasswordController.text,
      displayName: _registerDisplayNameController.text.trim().isNotEmpty ? _registerDisplayNameController.text.trim() : null,
    );
    if (!mounted) return;
    setState(() { _isLoading = false; if (!success) { _errorMessage = auth.errorMessage ?? 'Kayıt başarısız'; _sound.playError(); } });
    if (success) { _sound.playSuccess(); if (mounted) Navigator.of(context).pop(true); }
  }
}
