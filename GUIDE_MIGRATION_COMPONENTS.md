# Guide Complet: Migration des Components Flutter → React Native

## Table des Matières

1. [Vue d'ensemble des Components](#vue-densemble-des-components)
2. [PlayingCard Component](#1-playingcard-component)
3. [CardBack Component](#2-cardback-component)
4. [HandFan Component](#3-handfan-component)
5. [DeckWidget Component](#4-deckwidget-component)
6. [DiscardPile Component](#5-discardpile-component)
7. [OpponentRow Component](#6-opponentrow-component)
8. [SuitPickerSheet Component](#7-suitpickersheet-component)
9. [GameOverSheet Component](#8-gameoversheet-component)
10. [ChecksOverlay Component](#9-checksoverlay-component)
11. [AnimatedCardOverlay Component](#10-animatedcardoverlay-component)
12. [ErrorMessageOverlay Component](#11-errormessageoverlay-component)
13. [PauseMenu Component](#12-pausemenu-component)
14. [Helpers et Utilitaires](#helpers-et-utilitaires)
15. [Checklist de Migration](#checklist-de-migration)

---

## Vue d'ensemble des Components

Votre application Flutter CheckGames contient **12 composants réutilisables** :

| Flutter Widget | React Native Component | Complexité | Animations |
|----------------|----------------------|------------|------------|
| `playing_card_widget.dart` | `PlayingCard.tsx` | ⭐ Simple | Non |
| `card_back_widget.dart` | `CardBack.tsx` | ⭐ Simple | Non |
| `hand_fan_widget.dart` | `HandFan.tsx` | ⭐⭐⭐⭐⭐ Très complexe | Oui (rotation, éventail) |
| `table_widgets.dart` (DeckWidget) | `DeckWidget.tsx` | ⭐⭐ Moyen | Non |
| `table_widgets.dart` (DiscardWidget) | `DiscardPile.tsx` | ⭐⭐ Moyen | Non |
| `table_widgets.dart` (OpponentsRow) | `OpponentRow.tsx` | ⭐⭐ Moyen | Non |
| `suit_picker_sheet.dart` | `SuitPickerSheet.tsx` | ⭐⭐ Moyen | Oui (modal) |
| `game_over_sheet.dart` | `GameOverSheet.tsx` | ⭐⭐ Moyen | Oui (modal) |
| `checks_overlay.dart` | `ChecksOverlay.tsx` | ⭐⭐⭐⭐ Complexe | Oui (scale, fade, rotate) |
| `animated_card_overlay.dart` | `AnimatedCardOverlay.tsx` | ⭐⭐⭐⭐⭐ Très complexe | Oui (position, scale, rotate) |
| `error_message_overlay.dart` | `ErrorMessageOverlay.tsx` | ⭐⭐⭐ Complexe | Oui (slide, fade) |
| `pause_menu.dart` | `PauseMenu.tsx` | ⭐⭐⭐ Complexe | Oui (modal) |

---

## 1. PlayingCard Component

### Flutter (Avant)

```dart
// lib/view/widgets/playing_card_widget.dart
class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final VoidCallback? onTap;
  final bool selectedFlag;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.45;
    final isRed = card.suit == CardSuit.hearts ||
                  card.suit == CardSuit.diamonds ||
                  card.suit == CardSuit.jokerRed;
    final color = isRed ? Colors.red.shade700 : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedFlag ? Color(0xFF0E766E) : Colors.black12,
            width: selectedFlag ? 3.0 : 1.0,
          ),
          boxShadow: [BoxShadow(...)],
        ),
        child: Stack(
          children: [
            // Coin supérieur gauche
            Positioned(left: 8, top: 6, child: Text(valueLabel(card.value))),
            // Centre
            Center(child: Text(suitSymbol(card.suit))),
            // Coin inférieur droit
            Positioned(right: 8, bottom: 6, child: Text(valueLabel(card.value))),
          ],
        ),
      ),
    );
  }
}
```

### React Native (Après)

```tsx
// src/components/PlayingCard.tsx
import React from 'react';
import { TouchableOpacity, View, Text, StyleSheet } from 'react-native';
import { PlayingCard, CardSuit, CardValue } from '../types/card.types';

interface PlayingCardProps {
  card: PlayingCard;
  width?: number;
  selected?: boolean;
  disabled?: boolean;
  onPress?: () => void;
}

export default function PlayingCardComponent({
  card,
  width = 84,
  selected = false,
  disabled = false,
  onPress,
}: PlayingCardProps) {
  const height = width * 1.45;

  // Déterminer la couleur de la carte
  const isRed =
    card.suit === CardSuit.Hearts ||
    card.suit === CardSuit.Diamonds ||
    card.suit === CardSuit.JokerRed;
  const cardColor = isRed ? '#C0392B' : '#2C3E50';

  // Fond spécial pour les jokers
  const isJoker = card.suit === CardSuit.JokerRed || card.suit === CardSuit.JokerBlack;
  const backgroundColor = isJoker
    ? card.suit === CardSuit.JokerRed
      ? '#FFEBEE'
      : '#EEEEEE'
    : '#FFFFFF';

  // Bordure
  const borderColor = selected
    ? '#0E766E'
    : isJoker
    ? card.suit === CardSuit.JokerRed
      ? '#EF5350'
      : '#9E9E9E'
    : '#E0E0E0';
  const borderWidth = selected ? 3 : isJoker ? 2 : 1;

  const cardContent = (
    <View
      style={[
        styles.card,
        {
          width,
          height,
          backgroundColor,
          borderColor,
          borderWidth,
        },
        selected && styles.cardSelected,
      ]}
    >
      {/* Coin supérieur gauche */}
      <View style={styles.topLeft}>
        <Text style={[styles.valueText, { color: cardColor }]}>
          {getValueLabel(card.value)}
        </Text>
        <Text style={[styles.suitTextSmall, { color: cardColor }]}>
          {getSuitSymbol(card.suit)}
        </Text>
      </View>

      {/* Centre */}
      <View style={styles.center}>
        <Text style={[styles.suitTextLarge, { color: cardColor }]}>
          {getValueLabel(card.value) === 'JOKER' ? '🃏' : getSuitSymbol(card.suit)}
        </Text>
      </View>

      {/* Coin inférieur droit */}
      <View style={styles.bottomRight}>
        <Text style={[styles.valueText, { color: cardColor }]}>
          {getValueLabel(card.value)}
        </Text>
      </View>
    </View>
  );

  if (!onPress || disabled) {
    return cardContent;
  }

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.8} disabled={disabled}>
      {cardContent}
    </TouchableOpacity>
  );
}

// Fonctions helper
function getSuitSymbol(suit: CardSuit): string {
  const symbols: Record<CardSuit, string> = {
    [CardSuit.Hearts]: '♥',
    [CardSuit.Diamonds]: '♦',
    [CardSuit.Clubs]: '♣',
    [CardSuit.Spades]: '♠',
    [CardSuit.JokerRed]: '🃏',
    [CardSuit.JokerBlack]: '🃏',
  };
  return symbols[suit];
}

function getValueLabel(value: CardValue): string {
  const labels: Record<CardValue, string> = {
    [CardValue.Ace]: 'A',
    [CardValue.Two]: '2',
    [CardValue.Three]: '3',
    [CardValue.Four]: '4',
    [CardValue.Five]: '5',
    [CardValue.Six]: '6',
    [CardValue.Seven]: '7',
    [CardValue.Eight]: '8',
    [CardValue.Nine]: '9',
    [CardValue.Ten]: '10',
    [CardValue.Jack]: 'J',
    [CardValue.Queen]: 'Q',
    [CardValue.King]: 'K',
    [CardValue.Joker]: 'JOKER',
  };
  return labels[value];
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.25,
    shadowRadius: 8,
    elevation: 5,
  },
  cardSelected: {
    shadowOpacity: 0.4,
    shadowRadius: 14,
    elevation: 8,
  },
  topLeft: {
    position: 'absolute',
    top: 6,
    left: 8,
    alignItems: 'center',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  bottomRight: {
    position: 'absolute',
    bottom: 6,
    right: 8,
  },
  valueText: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  suitTextSmall: {
    fontSize: 16,
    marginTop: 2,
  },
  suitTextLarge: {
    fontSize: 36,
  },
});
```

### Différences clés

| Flutter | React Native |
|---------|--------------|
| `Container` + `BoxDecoration` | `View` + `StyleSheet` |
| `Stack` | `position: 'absolute'` |
| `GestureDetector` | `TouchableOpacity` |
| `Colors.red.shade700` | `'#C0392B'` (hex) |
| `BorderRadius.circular(12)` | `borderRadius: 12` |

---

## 2. CardBack Component

### React Native

```tsx
// src/components/CardBack.tsx
import React from 'react';
import { View, StyleSheet } from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Icon from 'react-native-vector-icons/MaterialIcons';

interface CardBackProps {
  width?: number;
  showShadow?: boolean;
}

export default function CardBack({ width = 60, showShadow = true }: CardBackProps) {
  const height = width * 1.45;

  return (
    <LinearGradient
      colors={['#6B2C91', '#4A1A6B']}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={[
        styles.card,
        {
          width,
          height,
        },
        showShadow && styles.cardShadow,
      ]}
    >
      {/* Bordure extérieure */}
      <View style={[styles.outerBorder, { width: width * 0.7, height: height * 0.8 }]}>
        {/* Bordure intérieure */}
        <View style={[styles.innerBorder, { width: width * 0.5, height: height * 0.6 }]} />
      </View>

      {/* Points décoratifs aux coins */}
      <View style={[styles.dot, styles.dotTopLeft]} />
      <View style={[styles.dot, styles.dotTopRight]} />
      <View style={[styles.dot, styles.dotBottomLeft]} />
      <View style={[styles.dot, styles.dotBottomRight]} />
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#FFFFFF',
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardShadow: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 4,
  },
  outerBorder: {
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.3)',
    borderRadius: 4,
    justifyContent: 'center',
    alignItems: 'center',
  },
  innerBorder: {
    borderWidth: 1.5,
    borderColor: 'rgba(255, 255, 255, 0.3)',
    borderRadius: 4,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: 'rgba(255, 255, 255, 0.4)',
    position: 'absolute',
  },
  dotTopLeft: {
    top: 8,
    left: 8,
  },
  dotTopRight: {
    top: 8,
    right: 8,
  },
  dotBottomLeft: {
    bottom: 8,
    left: 8,
  },
  dotBottomRight: {
    bottom: 8,
    right: 8,
  },
});
```

---

## 3. HandFan Component

**⚠️ COMPOSANT LE PLUS COMPLEXE** - Arrangement des cartes en éventail avec rotation.

### Flutter (Avant)

```dart
class HandFanWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final Set<PlayingCard> selectedCards;
  final Function(PlayingCard) onCardTap;
  final bool enabled;
  final Map<PlayingCard, GlobalKey> cardKeys;

  @override
  Widget build(BuildContext context) {
    final totalCards = cards.length;
    const maxAngle = 40.0;
    final fanRadius = sizing.fanRadius;
    final angleStep = totalCards > 1 ? maxAngle / (totalCards - 1) : 0.0;
    final startAngle = -maxAngle / 2;

    return Stack(
      children: [
        for (int i = 0; i < cards.length; i++)
          _buildCard(
            card: cards[i],
            index: i,
            angle: startAngle + (i * angleStep),
          ),
      ],
    );
  }

  Widget _buildCard({required PlayingCard card, required int index, required double angle}) {
    final x = index * cardSpacing;
    final normalizedPos = (index - (totalCards - 1) / 2) / (totalCards / 2);
    final y = (normalizedPos * normalizedPos) * 30; // Courbe parabolique

    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: PlayingCardWidget(...),
      ),
    );
  }
}
```

### React Native (Après)

```tsx
// src/components/HandFan.tsx
import React, { forwardRef } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { PlayingCard as PlayingCardType } from '../types/card.types';
import PlayingCard from './PlayingCard';

interface HandFanProps {
  cards: PlayingCardType[];
  selectedCards: PlayingCardType[];
  onCardPress?: (card: PlayingCardType, index: number) => void;
  enabled?: boolean;
  cardWidth?: number;
}

const HandFan = forwardRef<View, HandFanProps>(
  ({ cards, selectedCards, onCardPress, enabled = true, cardWidth = 84 }, ref) => {
    const screenWidth = Dimensions.get('window').width;
    const cardHeight = cardWidth * 1.45;

    if (cards.length === 0) return null;

    // Paramètres de l'éventail
    const totalCards = cards.length;
    const maxAngle = 40; // Angle max en degrés
    const angleStep = totalCards > 1 ? maxAngle / (totalCards - 1) : 0;
    const startAngle = -maxAngle / 2;

    // Espacement dynamique pour éviter le débordement
    const maxTotalWidth = screenWidth * 0.95;
    const cardSpacing =
      totalCards > 1
        ? Math.min((maxTotalWidth - cardWidth) / (totalCards - 1), 50)
        : 0;

    // Dimensions du conteneur
    const totalWidth = (totalCards - 1) * cardSpacing + cardWidth;
    const maxHeight = cardHeight + 60;

    const isCardSelected = (card: PlayingCardType) => {
      return selectedCards.some(
        (c) => c.suit === card.suit && c.value === card.value
      );
    };

    const getCardTransform = (index: number) => {
      const angle = startAngle + index * angleStep;
      const angleRad = (angle * Math.PI) / 180;

      // Position horizontale (linéaire)
      const x = index * cardSpacing;

      // Position verticale (arc parabolique)
      const normalizedPos = (index - (totalCards - 1) / 2) / (totalCards / 2);
      const y = normalizedPos * normalizedPos * 30;

      return { x, y, angle: angleRad };
    };

    return (
      <View ref={ref} style={[styles.container, { width: totalWidth, height: maxHeight }]}>
        {cards.map((card, index) => {
          const transform = getCardTransform(index);
          const selected = isCardSelected(card);
          const selectedOffset = selected ? -20 : 0;

          return (
            <View
              key={`${card.suit}-${card.value}-${index}`}
              style={[
                styles.cardWrapper,
                {
                  left: transform.x,
                  top: transform.y + selectedOffset,
                  transform: [{ rotate: `${transform.angle}rad` }],
                  zIndex: selected ? 1000 : index,
                },
              ]}
            >
              <PlayingCard
                card={card}
                width={cardWidth}
                selected={selected}
                disabled={!enabled}
                onPress={() => enabled && onCardPress?.(card, index)}
              />
            </View>
          );
        })}
      </View>
    );
  }
);

HandFan.displayName = 'HandFan';

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  cardWrapper: {
    position: 'absolute',
  },
});

export default HandFan;
```

### Notes importantes

1. **Calcul de l'angle**: Même formule qu'en Flutter (angle linéaire)
2. **Courbe parabolique**: `y = normalizedPos² * 30` pour l'effet arc
3. **zIndex**: Les cartes sélectionnées ont un zIndex élevé pour apparaître au-dessus
4. **forwardRef**: Permet d'obtenir la référence du conteneur depuis le parent

---

## 4. DeckWidget Component

```tsx
// src/components/DeckWidget.tsx
import React from 'react';
import { TouchableOpacity, View, Text, StyleSheet } from 'react-native';
import CardBack from './CardBack';

interface DeckWidgetProps {
  count: number;
  enabled?: boolean;
  onPress?: () => void;
  cardWidth?: number;
}

export default function DeckWidget({
  count,
  enabled = true,
  onPress,
  cardWidth = 68,
}: DeckWidgetProps) {
  const cardHeight = cardWidth * 1.45;
  const containerWidth = cardWidth * 1.43;
  const containerHeight = cardHeight + 16;

  return (
    <TouchableOpacity
      onPress={enabled ? onPress : undefined}
      disabled={!enabled}
      activeOpacity={0.8}
      style={[styles.container, { width: containerWidth, height: containerHeight }]}
    >
      {/* Cartes empilées pour effet 3D */}
      <View style={[styles.cardLayer, { left: 6, top: 6 }]}>
        <CardBack width={cardWidth} showShadow={false} />
      </View>
      <View style={[styles.cardLayer, { left: 12, top: 12 }]}>
        <CardBack width={cardWidth} showShadow={false} />
      </View>
      <View style={styles.cardLayer}>
        <CardBack width={cardWidth} />
      </View>

      {/* Badge compteur */}
      <View
        style={[
          styles.badge,
          { backgroundColor: enabled ? '#00796B' : '#666' },
        ]}
      >
        <Text style={styles.badgeText}>{count}</Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  cardLayer: {
    position: 'absolute',
  },
  badge: {
    position: 'absolute',
    right: -6,
    bottom: -6,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.3)',
  },
  badgeText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 14,
  },
});
```

---

## 5. DiscardPile Component

```tsx
// src/components/DiscardPile.tsx
import React, { forwardRef } from 'react';
import { View, StyleSheet } from 'react-native';
import { PlayingCard as PlayingCardType } from '../types/card.types';
import PlayingCard from './PlayingCard';

interface DiscardPileProps {
  topCard: PlayingCardType;
  previousCards?: PlayingCardType[];
  cardWidth?: number;
}

const DiscardPile = forwardRef<View, DiscardPileProps>(
  ({ topCard, previousCards, cardWidth = 68 }, ref) => {
    const cardHeight = cardWidth * 1.45;
    const cardSpacing = 20;

    // Afficher jusqu'à 4 cartes
    const cardsToShow: PlayingCardType[] = [];

    if (previousCards && previousCards.length > 0) {
      const startIndex = Math.max(0, previousCards.length - 3);
      cardsToShow.push(...previousCards.slice(startIndex));
    }

    cardsToShow.push(topCard);

    const totalWidth = cardWidth + (cardsToShow.length - 1) * cardSpacing;

    return (
      <View
        ref={ref}
        style={[styles.container, { width: totalWidth, height: cardHeight }]}
      >
        {cardsToShow.map((card, index) => (
          <View
            key={`discard-${index}`}
            style={[styles.cardWrapper, { left: index * cardSpacing, zIndex: index }]}
          >
            <PlayingCard card={card} width={cardWidth} />
          </View>
        ))}
      </View>
    );
  }
);

DiscardPile.displayName = 'DiscardPile';

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  cardWrapper: {
    position: 'absolute',
    top: 0,
  },
});

export default DiscardPile;
```

---

## 6. OpponentRow Component

```tsx
// src/components/OpponentRow.tsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { Player } from '../types/game.types';
import CardBack from './CardBack';

interface OpponentRowProps {
  players: Player[];
  currentPlayerIndex: number;
  myIndex: number;
  cardWidth?: number;
}

export default function OpponentRow({
  players,
  currentPlayerIndex,
  myIndex,
  cardWidth = 48,
}: OpponentRowProps) {
  // Filtrer les adversaires (tous sauf moi)
  const opponents = players.filter((_, index) => index !== myIndex);

  if (opponents.length === 0) return null;

  const cardSpacing = 3;

  const renderOpponent = (player: Player, index: number) => {
    const isCurrentTurn = players[currentPlayerIndex].id === player.id;
    const cardCount = player.hand.length;
    const cardsToShow = Math.min(cardCount, 5);

    return (
      <View key={player.id} style={styles.opponentContainer}>
        {/* Nom du joueur avec indicateur de tour */}
        <View
          style={[
            styles.nameContainer,
            isCurrentTurn && styles.nameContainerActive,
          ]}
        >
          {isCurrentTurn && (
            <View style={styles.turnIndicator} />
          )}
          <Text
            style={[
              styles.playerName,
              isCurrentTurn && styles.playerNameActive,
            ]}
          >
            {player.name}
          </Text>
        </View>

        {/* Cartes */}
        <View style={styles.cardsRow}>
          {Array.from({ length: cardsToShow }).map((_, i) => (
            <View
              key={i}
              style={[
                styles.cardWrapper,
                i > 0 && { marginLeft: cardSpacing },
              ]}
            >
              <CardBack width={cardWidth} />
            </View>
          ))}
        </View>

        {/* Badge nombre de cartes */}
        <LinearGradient
          colors={['#E67E22', '#CA6F1E']}
          style={styles.badge}
        >
          <Text style={styles.badgeText}>+{cardCount}</Text>
        </LinearGradient>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {opponents.map((opponent, index) => renderOpponent(opponent, index))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    flexWrap: 'wrap',
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  opponentContainer: {
    alignItems: 'center',
    marginHorizontal: 8,
    marginVertical: 4,
  },
  nameContainer: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    borderRadius: 12,
    marginBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
  },
  nameContainerActive: {
    backgroundColor: '#E67E22',
    shadowColor: '#E67E22',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 12,
    elevation: 8,
  },
  turnIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#FFF',
    marginRight: 6,
  },
  playerName: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 13,
  },
  playerNameActive: {
    fontWeight: '900',
  },
  cardsRow: {
    flexDirection: 'row',
    marginBottom: 8,
  },
  cardWrapper: {
    // Pas de style supplémentaire nécessaire
  },
  badge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    borderWidth: 2,
    borderColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 4,
  },
  badgeText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 16,
  },
});
```

---

## 7. SuitPickerSheet Component

```tsx
// src/components/SuitPickerSheet.tsx
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Modal } from 'react-native';
import { CardSuit } from '../types/card.types';

interface SuitPickerSheetProps {
  visible: boolean;
  onSuitSelect: (suit: CardSuit) => void;
  onDismiss: () => void;
}

export default function SuitPickerSheet({
  visible,
  onSuitSelect,
  onDismiss,
}: SuitPickerSheetProps) {
  const suits = [
    { suit: CardSuit.Hearts, label: '♥ Cœur', color: '#E74C3C' },
    { suit: CardSuit.Diamonds, label: '♦ Carreau', color: '#E74C3C' },
    { suit: CardSuit.Clubs, label: '♣ Trèfle', color: '#2C3E50' },
    { suit: CardSuit.Spades, label: '♠ Pique', color: '#2C3E50' },
  ];

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onDismiss}
    >
      <TouchableOpacity
        style={styles.overlay}
        activeOpacity={1}
        onPress={onDismiss}
      >
        <View style={styles.content}>
          <Text style={styles.title}>Choisir une couleur</Text>

          <View style={styles.suitContainer}>
            {suits.map(({ suit, label, color }) => (
              <TouchableOpacity
                key={suit}
                style={[styles.suitButton, { borderColor: color }]}
                onPress={() => {
                  onSuitSelect(suit);
                  onDismiss();
                }}
              >
                <Text style={[styles.suitLabel, { color }]}>{label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </TouchableOpacity>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  content: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    paddingBottom: 40,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
  },
  suitContainer: {
    gap: 15,
  },
  suitButton: {
    padding: 20,
    borderRadius: 10,
    borderWidth: 2,
    alignItems: 'center',
  },
  suitLabel: {
    fontSize: 24,
    fontWeight: 'bold',
  },
});
```

---

## 8. GameOverSheet Component

```tsx
// src/components/GameOverSheet.tsx
import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  FlatList,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { Player } from '../types/game.types';

interface GameOverSheetProps {
  visible: boolean;
  finishingOrder: string[];
  players: Player[];
  onRestart: () => void;
  onDismiss?: () => void;
  isMultiplayer?: boolean;
  isHost?: boolean;
}

export default function GameOverSheet({
  visible,
  finishingOrder,
  players,
  onRestart,
  onDismiss,
  isMultiplayer = false,
  isHost = false,
}: GameOverSheetProps) {
  // Calculer le classement
  const ranking = finishingOrder.map((id) => players.find((p) => p.id === id)!);

  const getMedalForPosition = (position: number): string => {
    const medals: Record<number, string> = {
      1: '🥇',
      2: '🥈',
      3: '🥉',
      4: '4️⃣',
      5: '5️⃣',
      6: '6️⃣',
      7: '7️⃣',
      8: '8️⃣',
      9: '9️⃣',
    };
    return medals[position] || '🔟';
  };

  const renderPlayer = ({ item, index }: { item: Player; index: number }) => {
    const position = index + 1;
    const medal = getMedalForPosition(position);

    return (
      <View style={styles.playerRow}>
        <Text style={styles.medal}>{medal}</Text>
        <Text style={styles.playerName}>
          {position}. {item.name}
        </Text>
        {position === 1 && (
          <Icon name="emoji-events" size={24} color="#FFD700" />
        )}
      </View>
    );
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onDismiss}
    >
      <View style={styles.overlay}>
        <View style={styles.content}>
          <Text style={styles.title}>Partie terminée !</Text>

          <FlatList
            data={ranking}
            renderItem={renderPlayer}
            keyExtractor={(item) => item.id}
            style={styles.list}
          />

          {/* Boutons */}
          {isMultiplayer && !isHost ? (
            <View style={styles.waitingContainer}>
              <Text style={styles.waitingText}>⏳ En attente de l'hôte...</Text>
              <Text style={styles.waitingSubtext}>
                Seul le créateur de la partie peut la relancer
              </Text>
              <TouchableOpacity style={styles.backButton} onPress={onRestart}>
                <Icon name="home" size={20} color="#666" />
                <Text style={styles.backButtonText}>Retour au menu</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <View style={styles.buttonContainer}>
              <TouchableOpacity style={styles.restartButton} onPress={onRestart}>
                <Icon name="refresh" size={20} color="#FFFFFF" />
                <Text style={styles.restartButtonText}>
                  {isMultiplayer ? 'Relancer la partie' : 'Rejouer'}
                </Text>
              </TouchableOpacity>

              {onDismiss && (
                <TouchableOpacity style={styles.closeButton} onPress={onDismiss}>
                  <Text style={styles.closeButtonText}>Fermer</Text>
                </TouchableOpacity>
              )}
            </View>
          )}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  content: {
    backgroundColor: '#FFFFFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    paddingBottom: 40,
    maxHeight: '80%',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
  },
  list: {
    maxHeight: 300,
    marginBottom: 20,
  },
  playerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    gap: 12,
  },
  medal: {
    fontSize: 24,
  },
  playerName: {
    flex: 1,
    fontSize: 16,
  },
  waitingContainer: {
    alignItems: 'center',
    gap: 12,
  },
  waitingText: {
    fontSize: 14,
    color: '#E67E22',
    fontStyle: 'italic',
  },
  waitingSubtext: {
    fontSize: 12,
    color: '#999',
  },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 12,
    paddingHorizontal: 24,
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 8,
  },
  backButtonText: {
    fontSize: 16,
    color: '#666',
  },
  buttonContainer: {
    flexDirection: 'row',
    gap: 12,
  },
  restartButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: '#27AE60',
    paddingVertical: 16,
    borderRadius: 12,
  },
  restartButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  closeButton: {
    paddingVertical: 16,
    paddingHorizontal: 24,
    borderWidth: 2,
    borderColor: '#DDD',
    borderRadius: 12,
  },
  closeButtonText: {
    fontSize: 16,
    color: '#666',
  },
});
```

---

## 9. ChecksOverlay Component

**Animations complexes**: scale, fade, rotate avec `react-native-reanimated`.

```tsx
// src/components/ChecksOverlay.tsx
import React, { useEffect } from 'react';
import { View, Text, StyleSheet, Modal } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSequence,
  withTiming,
  Easing,
  runOnJS,
} from 'react-native-reanimated';
import LinearGradient from 'react-native-linear-gradient';

interface ChecksOverlayProps {
  visible: boolean;
  playerName: string;
  onComplete: () => void;
}

export default function ChecksOverlay({
  visible,
  playerName,
  onComplete,
}: ChecksOverlayProps) {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);
  const rotate = useSharedValue(-0.1);

  useEffect(() => {
    if (visible) {
      // Animation d'entrée
      scale.value = withSequence(
        withTiming(1.3, { duration: 400, easing: Easing.elastic(1.5) }),
        withTiming(1.0, { duration: 300, easing: Easing.inOut(Easing.ease) }),
        withTiming(1.0, { duration: 1000 }),
        withTiming(0, { duration: 300, easing: Easing.in(Easing.ease) }, () => {
          runOnJS(onComplete)();
        })
      );

      opacity.value = withSequence(
        withTiming(1.0, { duration: 200 }),
        withTiming(1.0, { duration: 1400 }),
        withTiming(0, { duration: 200 })
      );

      rotate.value = withTiming(0.1, {
        duration: 2000,
        easing: Easing.inOut(Easing.ease),
      });
    }
  }, [visible]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: scale.value },
      { rotate: `${rotate.value}rad` },
    ],
    opacity: opacity.value,
  }));

  if (!visible) return null;

  return (
    <Modal transparent visible={visible}>
      <View style={styles.overlay}>
        <Animated.View style={[styles.container, animatedStyle]}>
          <LinearGradient
            colors={['#E67E22', '#C0392B']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.gradient}
          >
            <Text style={styles.checksText}>CHECKS!</Text>
            <Text style={styles.playerName}>{playerName}</Text>
            <Text style={styles.subtitle}>Plus qu'une carte!</Text>
          </LinearGradient>
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  container: {
    margin: 40,
  },
  gradient: {
    paddingHorizontal: 40,
    paddingVertical: 30,
    borderRadius: 20,
    borderWidth: 4,
    borderColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.5,
    shadowRadius: 30,
    elevation: 20,
    alignItems: 'center',
  },
  checksText: {
    fontSize: 48,
    fontWeight: '900',
    color: '#FFFFFF',
    letterSpacing: 4,
    textShadowColor: 'rgba(0, 0, 0, 0.7)',
    textShadowOffset: { width: 3, height: 3 },
    textShadowRadius: 8,
  },
  playerName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginTop: 12,
  },
  subtitle: {
    fontSize: 16,
    color: 'rgba(255, 255, 255, 0.8)',
    marginTop: 8,
  },
});
```

### Dépendances requises

```bash
npm install react-native-reanimated
```

**Configuration** (dans `babel.config.js`):

```js
module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: ['react-native-reanimated/plugin'], // Doit être en dernier
};
```

---

## 10. AnimatedCardOverlay Component

**Animations de cartes volantes** - Position, scale, rotation, opacity.

```tsx
// src/components/AnimatedCardOverlay.tsx
import React, { useEffect } from 'react';
import { View, StyleSheet, Modal } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  Easing,
  runOnJS,
} from 'react-native-reanimated';
import { PlayingCard as PlayingCardType } from '../types/card.types';
import PlayingCard from './PlayingCard';

interface AnimatedCardOverlayProps {
  visible: boolean;
  cards: PlayingCardType[];
  startPositions: { x: number; y: number }[];
  endPosition: { x: number; y: number };
  duration?: number;
  onComplete: () => void;
}

export default function AnimatedCardOverlay({
  visible,
  cards,
  startPositions,
  endPosition,
  duration = 600,
  onComplete,
}: AnimatedCardOverlayProps) {
  if (!visible || cards.length === 0) return null;

  return (
    <Modal transparent visible={visible} pointerEvents="none">
      <View style={styles.container}>
        {cards.map((card, index) => (
          <AnimatedCard
            key={index}
            card={card}
            startPosition={startPositions[index]}
            endPosition={endPosition}
            duration={duration}
            delay={index * 50}
            onComplete={index === cards.length - 1 ? onComplete : undefined}
          />
        ))}
      </View>
    </Modal>
  );
}

interface AnimatedCardProps {
  card: PlayingCardType;
  startPosition: { x: number; y: number };
  endPosition: { x: number; y: number };
  duration: number;
  delay: number;
  onComplete?: () => void;
}

function AnimatedCard({
  card,
  startPosition,
  endPosition,
  duration,
  delay,
  onComplete,
}: AnimatedCardProps) {
  const translateX = useSharedValue(startPosition.x);
  const translateY = useSharedValue(startPosition.y);
  const scale = useSharedValue(1);
  const rotate = useSharedValue(0);
  const opacity = useSharedValue(1);

  useEffect(() => {
    // Délai avant l'animation
    setTimeout(() => {
      // Animation de position
      translateX.value = withSpring(endPosition.x, {
        damping: 15,
        stiffness: 100,
      });
      translateY.value = withSpring(endPosition.y, {
        damping: 15,
        stiffness: 100,
      });

      // Animation de scale (agrandir puis réduire)
      scale.value = withSequence(
        withTiming(1.1, { duration: duration * 0.4, easing: Easing.out(Easing.back(1.5)) }),
        withTiming(1.0, { duration: duration * 0.6, easing: Easing.inOut(Easing.ease) }, () => {
          if (onComplete) {
            runOnJS(onComplete)();
          }
        })
      );

      // Animation de rotation légère
      rotate.value = withTiming(0.2, {
        duration,
        easing: Easing.inOut(Easing.ease),
      });

      // Animation d'opacité
      opacity.value = withTiming(0.95, {
        duration: duration * 0.3,
        easing: Easing.in(Easing.ease),
      });
    }, delay);
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
      { rotate: `${rotate.value}rad` },
    ],
    opacity: opacity.value,
  }));

  return (
    <Animated.View style={[styles.card, animatedStyle]}>
      <PlayingCard card={card} width={84} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  card: {
    position: 'absolute',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.4,
    shadowRadius: 20,
    elevation: 10,
  },
});
```

---

## 11. ErrorMessageOverlay Component

```tsx
// src/components/ErrorMessageOverlay.tsx
import React, { useEffect } from 'react';
import { View, Text, StyleSheet, Modal } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSequence,
  withTiming,
  Easing,
  runOnJS,
} from 'react-native-reanimated';
import Icon from 'react-native-vector-icons/MaterialIcons';

interface ErrorMessageOverlayProps {
  visible: boolean;
  message: string;
  onComplete: () => void;
}

export default function ErrorMessageOverlay({
  visible,
  message,
  onComplete,
}: ErrorMessageOverlayProps) {
  const translateY = useSharedValue(-100);
  const opacity = useSharedValue(0);

  useEffect(() => {
    if (visible) {
      // Animation de slide depuis le haut
      translateY.value = withSequence(
        withTiming(0, { duration: 300, easing: Easing.out(Easing.ease) }),
        withTiming(0, { duration: 2000 }),
        withTiming(-100, { duration: 300, easing: Easing.in(Easing.ease) }, () => {
          runOnJS(onComplete)();
        })
      );

      opacity.value = withSequence(
        withTiming(1, { duration: 300 }),
        withTiming(1, { duration: 2000 }),
        withTiming(0, { duration: 300 })
      );
    }
  }, [visible]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
    opacity: opacity.value,
  }));

  if (!visible) return null;

  return (
    <Modal transparent visible={visible} pointerEvents="none">
      <Animated.View style={[styles.container, animatedStyle]}>
        <View style={styles.content}>
          <Icon name="error-outline" size={24} color="#FFFFFF" />
          <Text style={styles.message}>{message}</Text>
        </View>
      </Animated.View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#C0392B',
    paddingHorizontal: 20,
    paddingVertical: 15,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.3,
    shadowRadius: 15,
    elevation: 10,
    gap: 12,
  },
  message: {
    flex: 1,
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
});
```

---

## 12. PauseMenu Component

```tsx
// src/components/PauseMenu.tsx
import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  Switch,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import Icon from 'react-native-vector-icons/MaterialIcons';
import audioService from '../services/audio.service';

interface PauseMenuProps {
  visible: boolean;
  onResume: () => void;
  onQuit: () => void;
  onRestart?: () => void;
  onLeaveGame?: () => void;
  isMultiplayer?: boolean;
  isHost?: boolean;
}

export default function PauseMenu({
  visible,
  onResume,
  onQuit,
  onRestart,
  onLeaveGame,
  isMultiplayer = false,
  isHost = false,
}: PauseMenuProps) {
  const [soundEnabled, setSoundEnabled] = useState(audioService.isSoundEnabled());
  const [musicEnabled, setMusicEnabled] = useState(audioService.isMusicEnabled());

  const handleSoundToggle = (value: boolean) => {
    setSoundEnabled(value);
    if (value) {
      audioService.enableSound();
    } else {
      audioService.disableSound();
    }
  };

  const handleMusicToggle = (value: boolean) => {
    setMusicEnabled(value);
    if (value) {
      audioService.playMusic();
    } else {
      audioService.pauseMusic();
    }
  };

  return (
    <Modal visible={visible} transparent animationType="fade">
      <View style={styles.overlay}>
        <LinearGradient
          colors={['#145A32', '#0B3D2E']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.content}
        >
          <Text style={styles.title}>PAUSE</Text>

          {/* Options Audio */}
          <View style={styles.optionsContainer}>
            {/* Effets sonores */}
            <View style={styles.optionRow}>
              <View style={styles.optionLeft}>
                <Icon
                  name={soundEnabled ? 'volume-up' : 'volume-off'}
                  size={24}
                  color="#FFFFFF"
                />
                <Text style={styles.optionLabel}>Effets sonores</Text>
              </View>
              <Switch
                value={soundEnabled}
                onValueChange={handleSoundToggle}
                trackColor={{ false: '#666', true: '#0E766E' }}
                thumbColor="#FFFFFF"
              />
            </View>

            {/* Musique */}
            <View style={styles.optionRow}>
              <View style={styles.optionLeft}>
                <Icon
                  name={musicEnabled ? 'music-note' : 'music-off'}
                  size={24}
                  color="#FFFFFF"
                />
                <Text style={styles.optionLabel}>Musique</Text>
              </View>
              <Switch
                value={musicEnabled}
                onValueChange={handleMusicToggle}
                trackColor={{ false: '#666', true: '#0E766E' }}
                thumbColor="#FFFFFF"
              />
            </View>
          </View>

          {/* Boutons */}
          <View style={styles.buttonsContainer}>
            {/* Reprendre */}
            <TouchableOpacity style={styles.resumeButton} onPress={onResume}>
              <Icon name="play-arrow" size={20} color="#FFFFFF" />
              <Text style={styles.resumeButtonText}>Reprendre</Text>
            </TouchableOpacity>

            {/* Relancer (hôte uniquement) */}
            {isMultiplayer && isHost && onRestart && (
              <TouchableOpacity style={styles.restartButton} onPress={onRestart}>
                <Icon name="refresh" size={20} color="#FFFFFF" />
                <Text style={styles.restartButtonText}>Relancer la partie</Text>
              </TouchableOpacity>
            )}

            {/* Message pour non-hôtes */}
            {isMultiplayer && !isHost && (
              <View style={styles.infoBox}>
                <Icon name="info-outline" size={20} color="#FFFFFF80" />
                <Text style={styles.infoText}>
                  Seul l'hôte peut relancer la partie
                </Text>
              </View>
            )}

            {/* Quitter */}
            <TouchableOpacity
              style={styles.quitButton}
              onPress={isMultiplayer && onLeaveGame ? onLeaveGame : onQuit}
            >
              <Icon
                name={isMultiplayer ? 'exit-to-app' : 'home'}
                size={20}
                color={isMultiplayer ? '#E74C3C' : '#FFFFFF80'}
              />
              <Text
                style={[
                  styles.quitButtonText,
                  isMultiplayer && styles.quitButtonTextDanger,
                ]}
              >
                {isMultiplayer ? 'Quitter la partie' : 'Nouvelle Partie'}
              </Text>
            </TouchableOpacity>
          </View>
        </LinearGradient>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    width: '85%',
    maxWidth: 400,
    padding: 30,
    borderRadius: 20,
    borderWidth: 3,
    borderColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.5,
    shadowRadius: 30,
    elevation: 20,
  },
  title: {
    fontSize: 36,
    fontWeight: '900',
    color: '#FFFFFF',
    letterSpacing: 3,
    textAlign: 'center',
    marginBottom: 30,
  },
  optionsContainer: {
    gap: 12,
    marginBottom: 30,
  },
  optionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 12,
  },
  optionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  optionLabel: {
    fontSize: 16,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  buttonsContainer: {
    gap: 12,
  },
  resumeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: '#0E766E',
    paddingVertical: 16,
    borderRadius: 12,
  },
  resumeButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  restartButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: '#E67E22',
    paddingVertical: 16,
    borderRadius: 12,
  },
  restartButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  infoBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.2)',
  },
  infoText: {
    flex: 1,
    fontSize: 14,
    color: '#FFFFFF80',
    fontStyle: 'italic',
  },
  quitButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 16,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#FFFFFF80',
  },
  quitButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFFFFF80',
  },
  quitButtonTextDanger: {
    color: '#E74C3C',
  },
});
```

---

## Helpers et Utilitaires

### Card Utilities

```tsx
// src/utils/cardHelpers.ts
import { CardSuit, CardValue } from '../types/card.types';

export function getSuitSymbol(suit: CardSuit): string {
  const symbols: Record<CardSuit, string> = {
    [CardSuit.Hearts]: '♥',
    [CardSuit.Diamonds]: '♦',
    [CardSuit.Clubs]: '♣',
    [CardSuit.Spades]: '♠',
    [CardSuit.JokerRed]: '🃏',
    [CardSuit.JokerBlack]: '🃏',
  };
  return symbols[suit];
}

export function getValueLabel(value: CardValue): string {
  const labels: Record<CardValue, string> = {
    [CardValue.Ace]: 'A',
    [CardValue.Two]: '2',
    [CardValue.Three]: '3',
    [CardValue.Four]: '4',
    [CardValue.Five]: '5',
    [CardValue.Six]: '6',
    [CardValue.Seven]: '7',
    [CardValue.Eight]: '8',
    [CardValue.Nine]: '9',
    [CardValue.Ten]: '10',
    [CardValue.Jack]: 'J',
    [CardValue.Queen]: 'Q',
    [CardValue.King]: 'K',
    [CardValue.Joker]: 'JOKER',
  };
  return labels[value];
}

export function isRedCard(suit: CardSuit): boolean {
  return (
    suit === CardSuit.Hearts ||
    suit === CardSuit.Diamonds ||
    suit === CardSuit.JokerRed
  );
}

export function getCardColor(suit: CardSuit): string {
  return isRedCard(suit) ? '#C0392B' : '#2C3E50';
}
```

### Responsive Hook

```tsx
// src/hooks/useResponsive.ts
import { useWindowDimensions } from 'react-native';

export function useResponsive() {
  const { width, height } = useWindowDimensions();
  const isPortrait = height > width;
  const isSmallScreen = width < 375;
  const isMediumScreen = width >= 375 && width < 768;
  const isLargeScreen = width >= 768;

  const scaleFactor = width / 375; // Base sur iPhone X

  return {
    width,
    height,
    isPortrait,
    isSmallScreen,
    isMediumScreen,
    isLargeScreen,
    scaleFactor,
    // Tailles de cartes responsives
    cardWidth: isSmallScreen ? 70 : isMediumScreen ? 84 : 100,
    tableCardWidth: isSmallScreen ? 60 : isMediumScreen ? 68 : 80,
    opponentCardWidth: isSmallScreen ? 40 : isMediumScreen ? 48 : 56,
  };
}
```

---

## Checklist de Migration

### Components de base
- [ ] PlayingCard component
- [ ] CardBack component
- [ ] Installer `react-native-linear-gradient`
- [ ] Créer helpers `cardHelpers.ts`
- [ ] Tester rendu des cartes (toutes les couleurs/valeurs)

### Components de table
- [ ] DeckWidget component
- [ ] DiscardPile component
- [ ] OpponentRow component
- [ ] Tester rendu responsive

### HandFan (⭐⭐⭐⭐⭐ COMPLEXE)
- [ ] Créer HandFan component
- [ ] Implémenter calcul d'angle
- [ ] Implémenter courbe parabolique
- [ ] Gérer sélection de cartes
- [ ] Tester avec 2-10 cartes
- [ ] Tester rotation
- [ ] Optimiser performances (useMemo, React.memo)

### Bottom Sheets & Modals
- [ ] SuitPickerSheet component
- [ ] GameOverSheet component
- [ ] Tester affichage classement
- [ ] Tester boutons (restart, close)

### Overlays animés
- [ ] Installer `react-native-reanimated`
- [ ] Configurer babel pour reanimated
- [ ] ChecksOverlay component
- [ ] AnimatedCardOverlay component
- [ ] ErrorMessageOverlay component
- [ ] PauseMenu component
- [ ] Tester toutes les animations
- [ ] Optimiser performances

### Tests
- [ ] Tests unitaires pour helpers
- [ ] Tests snapshot pour composants
- [ ] Tests d'intégration HandFan
- [ ] Tests animations (si possible)

---

## Conseils de Migration

### 1. Ordre recommandé

Migrez dans cet ordre de difficulté croissante:
1. **CardBack** (le plus simple)
2. **PlayingCard**
3. **DeckWidget, DiscardPile, OpponentRow**
4. **SuitPickerSheet, GameOverSheet**
5. **ErrorMessageOverlay, PauseMenu**
6. **ChecksOverlay** (animations moyennes)
7. **AnimatedCardOverlay** (animations complexes)
8. **HandFan** (LE PLUS COMPLEXE - gardez pour la fin)

### 2. Animations avec Reanimated

- Utilisez `react-native-reanimated` v3 pour toutes les animations
- Préférez `useSharedValue` + `useAnimatedStyle` plutôt que `Animated` API
- Utilisez `withSequence` pour enchaîner les animations
- Utilisez `runOnJS` pour appeler des callbacks après animation

### 3. Performance

- Utilisez `React.memo` pour les composants qui re-render souvent (PlayingCard, CardBack)
- Utilisez `useMemo` pour les calculs coûteux (HandFan transforms)
- Évitez les inline styles dans les boucles
- Utilisez `FlatList` pour les listes longues

### 4. Responsive

- Utilisez `useWindowDimensions` pour obtenir la taille d'écran
- Créez un hook `useResponsive` pour centraliser la logique
- Testez sur différentes tailles d'écran (iPhone SE, iPhone 14 Pro Max, iPad)

### 5. Testing

Pour chaque composant:
1. Test snapshot (rendu)
2. Test props (toutes les variantes)
3. Test callbacks (onPress, onComplete)
4. Test responsive (différentes tailles)

### 6. Debugging Animations

Si les animations ne fonctionnent pas:
1. Vérifiez que `react-native-reanimated/plugin` est dans `babel.config.js` (en dernier)
2. Clear cache: `npx react-native start --reset-cache`
3. Rebuild: `npx react-native run-android` ou `run-ios`
4. Utilisez `console.log` dans `runOnJS` pour debug

---

## Ressources

- [React Native Reanimated Docs](https://docs.swmansion.com/react-native-reanimated/)
- [React Native Linear Gradient](https://github.com/react-native-linear-gradient/react-native-linear-gradient)
- [React Native Vector Icons](https://github.com/oblador/react-native-vector-icons)

Bon courage pour la migration des composants ! Le **HandFan** et **AnimatedCardOverlay** sont les plus complexes, prenez votre temps pour bien les tester. 🎴✨
