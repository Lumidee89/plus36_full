import 'package:flutter/material.dart';

import '../../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      eyebrow: 'EVERY SCHOOL DAY, TOGETHER',
      title: "Your child's school life, all in one place",
      description: 'See attendance, school updates and everything that matters for each linked child.',
      accent: AppColors.mint,
      icon: Icons.school_rounded,
      cards: [
        _MiniCard('Present today', 'Checked in · 8:04 AM', Icons.check_rounded),
        _MiniCard(
          'New update',
          'Mathematics class note',
          Icons.campaign_rounded,
        ),
      ],
    ),
    _OnboardingPageData(
      eyebrow: 'PROGRESS MADE CLEAR',
      title: 'Celebrate every step of their learning journey',
      description: 'Follow assessments, CBT scores and academic progress with simple, useful insights.',
      accent: AppColors.amber,
      icon: Icons.auto_graph_rounded,
      cards: [
        _MiniCard('Mathematics', '92% · Excellent', Icons.trending_up_rounded),
        _MiniCard('CBT result', '18 of 20 correct', Icons.task_alt_rounded),
      ],
    ),
    _OnboardingPageData(
      eyebrow: 'CONNECTED & IN CONTROL',
      title: 'Stay close to the school, wherever you are',
      description: 'Message the school, receive important notices and manage fees securely from your phone.',
      accent: AppColors.orange,
      icon: Icons.forum_rounded,
      cards: [
        _MiniCard(
          'School message',
          'Your reply has arrived',
          Icons.chat_bubble_rounded,
        ),
        _MiniCard('School fees', 'Payment confirmed', Icons.verified_rounded),
      ],
    ),
  ];

  bool get _isLastPage => _page == _pages.length - 1;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _next() async {
    if (_isLastPage) return _finish();
    await _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 18, 4),
              child: Row(
                children: [
                  Image.asset(
                    'logo.png',
                    height: 42,
                    semanticLabel: 'Plus36 SchoolOS',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        key: ValueKey('onboarding-dot-$index'),
                        duration: const Duration(milliseconds: 220),
                        width: index == _page ? 28 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? AppColors.forest
                              : AppColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    key: const ValueKey('onboarding-primary-action'),
                    onPressed: _finishing ? null : _next,
                    child: _finishing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isLastPage ? 'Get started' : 'Continue'),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationHeight = (constraints.maxHeight * .52).clamp(
          250.0,
          370.0,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: illustrationHeight,
                child: _FeatureIllustration(data: data),
              ),
              const SizedBox(height: 22),
              Text(
                data.eyebrow,
                style: const TextStyle(
                  color: AppColors.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 31, height: 1.08),
              ),
              const SizedBox(height: 12),
              Text(
                data.description,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureIllustration extends StatelessWidget {
  const _FeatureIllustration({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A06322C),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.accent.withValues(alpha: .16),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: data.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(data.icon, color: AppColors.forest, size: 31),
              ),
              const Spacer(),
              for (final card in data.cards) ...[
                _IllustrationCard(card: card, accent: data.accent),
                if (card != data.cards.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.card, required this.accent});

  final _MiniCard card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(card.icon, color: AppColors.forest, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  card.subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_outward_rounded,
            color: AppColors.teal,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.accent,
    required this.icon,
    required this.cards,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Color accent;
  final IconData icon;
  final List<_MiniCard> cards;
}

class _MiniCard {
  const _MiniCard(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}
