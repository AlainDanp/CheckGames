"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPlayerDisconnect = void 0;
const admin = __importStar(require("firebase-admin"));
const database_1 = require("firebase-functions/v2/database");
const v2_1 = require("firebase-functions/v2");
admin.initializeApp();
const db = admin.firestore();
/**
 * Déclenchée quand un nœud RTDB /presence/{roomId}/{playerId}
 * passe à { online: false }.
 *
 * Politique : déconnexion = élimination. Pas de reprise possible.
 */
exports.onPlayerDisconnect = (0, database_1.onValueUpdated)("/presence/{roomId}/{playerId}", async (event) => {
    const after = event.data.after.val();
    // Agir uniquement quand online passe à false
    if (!after || after.online !== false)
        return;
    const roomId = event.params["roomId"];
    const playerId = event.params["playerId"];
    v2_1.logger.info(`Déconnexion détectée: joueur=${playerId} room=${roomId}`);
    // Vérifier que la partie est toujours en cours
    const roomRef = db.collection("game_rooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists)
        return;
    const roomData = roomSnap.data();
    // Pas encore commencée ou déjà finie
    if (roomData["status"] !== "playing")
        return;
    // Vérifier que le joueur est encore actif (pas déjà sorti volontairement)
    const playerSnap = await roomRef.collection("players").doc(playerId).get();
    if (!playerSnap.exists) {
        v2_1.logger.info("Joueur déjà absent — ignoré");
        return;
    }
    // ─── Même logique que leaveActiveGame() côté Dart ───────────────────────
    await db.runTransaction(async (tx) => {
        var _a, _b, _c;
        const gameStateRef = roomRef.collection("game_state").doc("current");
        const gameStateSnap = await tx.get(gameStateRef);
        // Retirer le joueur
        tx.delete(roomRef.collection("players").doc(playerId));
        tx.delete(roomRef.collection("player_hands").doc(playerId));
        if (gameStateSnap.exists) {
            const gs = gameStateSnap.data();
            const playerOrder = [...((_a = gs["playerOrder"]) !== null && _a !== void 0 ? _a : [])];
            const finishingOrder = [...((_b = gs["finishingOrder"]) !== null && _b !== void 0 ? _b : [])];
            const idx = playerOrder.indexOf(playerId);
            if (idx !== -1)
                playerOrder.splice(idx, 1);
            if (!finishingOrder.includes(playerId)) {
                finishingOrder.push(playerId); // marquer comme abandon
            }
            const active = playerOrder.filter((id) => !finishingOrder.includes(id));
            if (active.length <= 1) {
                // Dernier joueur en lice → victoire par forfait
                if (active.length === 1)
                    finishingOrder.push(active[0]);
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
            }
            else {
                tx.update(roomRef, {
                    hostId: playersSnap.docs[0].id,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
        const currentPlayers = (_c = roomData["currentPlayers"]) !== null && _c !== void 0 ? _c : 1;
        if (currentPlayers > 0) {
            tx.update(roomRef, {
                currentPlayers: currentPlayers - 1,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        v2_1.logger.info(`Joueur ${playerId} retiré de la partie (déconnexion)`);
    });
});
//# sourceMappingURL=index.js.map