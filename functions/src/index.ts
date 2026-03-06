import * as admin from "firebase-admin";
import {onValueUpdated} from "firebase-functions/v2/database";
import {logger} from "firebase-functions/v2";

admin.initializeApp();
const db = admin.firestore();

/**
 * Déclenchée quand un nœud RTDB /presence/{roomId}/{playerId}
 * passe à { online: false }.
 *
 * Politique : déconnexion = élimination. Pas de reprise possible.
 */
export const onPlayerDisconnect = onValueUpdated(
  "/presence/{roomId}/{playerId}",
  async (event) => {
    const after = event.data.after.val() as { online: boolean } | null;

    // Agir uniquement quand online passe à false
    if (!after || after.online !== false) return;

    const roomId = event.params["roomId"];
    const playerId = event.params["playerId"];
    logger.info(`Déconnexion détectée: joueur=${playerId} room=${roomId}`);

    // Vérifier que la partie est toujours en cours
    const roomRef = db.collection("game_rooms").doc(roomId);
    const roomSnap = await roomRef.get();

    if (!roomSnap.exists) return;

    const roomData = roomSnap.data()!;
    // Pas encore commencée ou déjà finie
    if (roomData["status"] !== "playing") return;

    // Vérifier que le joueur est encore actif (pas déjà sorti volontairement)
    const playerSnap = await roomRef.collection("players").doc(playerId).get();
    if (!playerSnap.exists) {
      logger.info("Joueur déjà absent — ignoré");
      return;
    }

    // ─── Même logique que leaveActiveGame() côté Dart ───────────────────────
    await db.runTransaction(async (tx) => {
      const gameStateRef = roomRef.collection("game_state").doc("current");
      const gameStateSnap = await tx.get(gameStateRef);

      // Retirer le joueur
      tx.delete(roomRef.collection("players").doc(playerId));
      tx.delete(roomRef.collection("player_hands").doc(playerId));

      if (gameStateSnap.exists) {
        const gs = gameStateSnap.data()!;
        const playerOrder: string[] = [...(gs["playerOrder"] ?? [])];
        const finishingOrder: string[] = [...(gs["finishingOrder"] ?? [])];

        const idx = playerOrder.indexOf(playerId);
        if (idx !== -1) playerOrder.splice(idx, 1);

        if (!finishingOrder.includes(playerId)) {
          finishingOrder.push(playerId); // marquer comme abandon
        }

        const active = playerOrder.filter((id) => !finishingOrder.includes(id));

        if (active.length <= 1) {
          // Dernier joueur en lice → victoire par forfait
          if (active.length === 1) finishingOrder.push(active[0]);

          tx.update(roomRef, {
            status: "finished",
            isGameOver: true,
            phase: "finished",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        tx.update(gameStateRef, {
          playerOrder,
          finishingOrder,
          lastAction: {
            playerId,
            type: "player_disconnected", // distingue abandon vs quit volontaire
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
        });
      }

      // Transfert de l'hôte si nécessaire
      if (roomData["hostId"] === playerId) {
        const playersSnap = await roomRef.collection("players").get();
        if (playersSnap.empty) {
          tx.delete(roomRef);
        } else {
          tx.update(roomRef, {
            hostId: playersSnap.docs[0].id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      const currentPlayers = (roomData["currentPlayers"] as number) ?? 1;
      if (currentPlayers > 0) {
        tx.update(roomRef, {
          currentPlayers: currentPlayers - 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      logger.info(`Joueur ${playerId} retiré de la partie (déconnexion)`);
    });
  }
);
