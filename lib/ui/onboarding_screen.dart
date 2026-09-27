import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "Bienvenue sur CheckGames !",
          body: "Le jeu de cartes stratégique qui met votre réflexion à l'épreuve",
          image: _buildImage('assets/icone/carte.png'),
          decoration: _getPageDecoration(),
        ),
        PageViewModel(
          title: "4 Modes de Jeu ",
          bodyWidget: Column(
            children: [
              _buildFeature(Icons.person, "Solo", "Affrontez des bots intelligents"),
              _buildFeature(Icons.timer, "Arcade", "Défi contre la montre"),
              _buildFeature(Icons.trending_up, "Survie", "Jusqu'où irez-vous ?"),
              _buildFeature(Icons.people, "Multi", "Jouez avec vos amis"),
            ],
          ),
          decoration: _getPageDecoration(),
        ),
        PageViewModel(
          title: "Règles simples ",
          body: "Défaussez-vous de toutes vos cartes avant vos adversaires. Attention aux cartes spéciales !",
          image: _buildImage('assets/tutorial/rules.png'),
          decoration: _getPageDecoration(),
        ),
        PageViewModel(
          title: "C'est parti ! ",
          body: "Commencez par le tutoriel ou lancez directement une partie",
          image: _buildImage('assets/tutorial/ready.png'),
          decoration: _getPageDecoration(),
        ),
      ],
      onDone: () => _completeOnboarding(context),
      onSkip: () => _completeOnboarding(context),
      showSkipButton: true,
      skip: const Text('Passer', style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Jouer !', style: TextStyle(fontWeight: FontWeight.w600)),
      dotsDecorator: DotsDecorator(
        size: const Size.square(10.0),
        activeSize: const Size(20.0, 10.0),
        activeColor: Theme.of(context).colorScheme.primary,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    return Center(
      child: Image.asset(path, width: 250, height: 250),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, size: 40, color: Colors.green),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }

  PageDecoration _getPageDecoration() {
    return PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      bodyTextStyle: TextStyle(fontSize: 16),
      bodyPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );
  }

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    Navigator.of(context).pushReplacementNamed('/main_menu');
  }
}
