import 'package:flutter/material.dart';
import '../services/game_settings_service.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = GameSettingsService.instance;

  late int _botCount;
  late BotDifficulty _difficulty;
  late bool _soundEnabled;
  late bool _musicEnabled;
  late GameMusic _selectedMusic;
  late bool _vibrationEnabled;
  late GameSpeed _gameSpeed;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _botCount = _settings.botCount;
    _difficulty = _settings.difficulty;
    _soundEnabled = _settings.soundEnabled;
    _musicEnabled = _settings.musicEnabled;
    _selectedMusic = _settings.selectedMusic;
    _vibrationEnabled = _settings.vibrationEnabled;
    _gameSpeed = _settings.gameSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF145A32), Color(0xFF0B3D2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        AudioService.instance.playButtonClick();
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Paramètres',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section Gameplay
                    _buildSectionHeader('Gameplay', Icons.sports_esports),
                    const SizedBox(height: 12),

                    // Nombre de bots
                    _buildSettingCard(
                      title: 'Nombre d\'adversaires',
                      subtitle: '$_botCount bot${_botCount > 1 ? 's' : ''}',
                      icon: Icons.smart_toy,
                      child: Row(
                        children: [1, 2, 3].map((count) {
                          final isSelected = _botCount == count;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$count'),
                              selected: isSelected,
                              onSelected: (selected) async {
                                if (selected) {
                                  AudioService.instance.playButtonClick();
                                  setState(() => _botCount = count);
                                  await _settings.setBotCount(count);
                                }
                              },
                              selectedColor: Colors.green.shade600,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Difficulté
                    _buildSettingCard(
                      title: 'Difficulté',
                      subtitle: _difficulty.description,
                      icon: Icons.psychology,
                      child: Column(
                        children: BotDifficulty.values.map((diff) {
                          final isSelected = _difficulty == diff;
                          return RadioListTile<BotDifficulty>(
                            title: Text(
                              diff.displayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              diff.description,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: diff,
                            groupValue: _difficulty,
                            activeColor: Colors.green.shade600,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (value) async {
                              if (value != null) {
                                AudioService.instance.playButtonClick();
                                setState(() => _difficulty = value);
                                await _settings.setDifficulty(value);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Vitesse du jeu
                    _buildSettingCard(
                      title: 'Vitesse du jeu',
                      subtitle: _gameSpeed.description,
                      icon: Icons.speed,
                      child: Column(
                        children: GameSpeed.values.map((speed) {
                          final isSelected = _gameSpeed == speed;
                          return RadioListTile<GameSpeed>(
                            title: Text(
                              speed.displayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              speed.description,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: speed,
                            groupValue: _gameSpeed,
                            activeColor: Colors.green.shade600,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (value) async {
                              if (value != null) {
                                AudioService.instance.playButtonClick();
                                setState(() => _gameSpeed = value);
                                await _settings.setGameSpeed(value);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Audio & Feedback
                    _buildSectionHeader('Audio & Feedback', Icons.volume_up),
                    const SizedBox(height: 12),

                    // Son
                    _buildSwitchCard(
                      title: 'Effets sonores',
                      subtitle: 'Sons des cartes et actions',
                      icon: Icons.audiotrack,
                      value: _soundEnabled,
                      onChanged: (value) async {
                        AudioService.instance.playButtonClick();
                        setState(() => _soundEnabled = value);
                        await _settings.setSoundEnabled(value);
                        AudioService.instance.setSoundEnabled(value);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Musique On/Off
                    _buildSwitchCard(
                      title: 'Musique',
                      subtitle: 'Musique de fond pendant le jeu',
                      icon: Icons.music_note,
                      value: _musicEnabled,
                      onChanged: (value) async {
                        AudioService.instance.playButtonClick();
                        setState(() => _musicEnabled = value);
                        await _settings.setMusicEnabled(value);
                        AudioService.instance.setMusicEnabled(value);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Sélection de la musique
                    if (_musicEnabled)
                      _buildMusicSelector(),

                    if (_musicEnabled)
                      const SizedBox(height: 12),

                    // Vibrations
                    _buildSwitchCard(
                      title: 'Vibrations',
                      subtitle: 'Retour haptique pour les actions',
                      icon: Icons.vibration,
                      value: _vibrationEnabled,
                      onChanged: (value) async {
                        AudioService.instance.playButtonClick();
                        setState(() => _vibrationEnabled = value);
                        await _settings.setVibrationEnabled(value);
                      },
                    ),

                    const SizedBox(height: 32),

                    // Bouton réinitialiser
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.restore, color: Colors.white70),
                        label: const Text(
                          'Réinitialiser les paramètres',
                          style: TextStyle(color: Colors.white70),
                        ),
                        onPressed: () async {
                          AudioService.instance.playButtonClick();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Réinitialiser'),
                              content: const Text(
                                'Voulez-vous réinitialiser tous les paramètres par défaut ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                  child: const Text('Réinitialiser'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await _settings.resetToDefaults();
                            setState(_loadSettings);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Paramètres réinitialisés'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Version
                    const Center(
                      child: Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade700.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (value ? Colors.green.shade700 : Colors.grey).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green.shade400,
            activeTrackColor: Colors.green.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildMusicSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade700.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.library_music, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choix de la musique',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _selectedMusic.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Liste des musiques
          ...GameMusic.values.map((music) {
            final isSelected = _selectedMusic == music;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  AudioService.instance.playButtonClick();
                  setState(() => _selectedMusic = music);
                  await AudioService.instance.setMusic(music);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purple.shade700.withOpacity(0.4)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.purple.shade400
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icône de lecture
                      Icon(
                        isSelected ? Icons.music_note : Icons.music_note_outlined,
                        color: isSelected ? Colors.purple.shade300 : Colors.white54,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      // Nom et description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              music.displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                            Text(
                              music.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Indicateur de sélection
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      // Bouton preview
                      if (!isSelected)
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, color: Colors.white54),
                          onPressed: () async {
                            await AudioService.instance.previewMusic(music);
                          },
                          tooltip: 'Écouter',
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
