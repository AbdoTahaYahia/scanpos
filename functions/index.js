const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

exports.checkout = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {storeId, cartItems} = request.data;
  if (!storeId || !cartItems || !Array.isArray(cartItems) || cartItems.length === 0) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  try {
    const result = await db.runTransaction(async (tx) => {
      let totalAmount = 0;
      const transactionItems = [];
      const requestedQuantities = new Map();

      const userRef = db.collection("users").doc(auth.uid);
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("permission-denied", "User profile not found.");
      }

      const userData = userSnap.data();
      const roles = Array.isArray(userData.roles) ? userData.roles : [];
      const canCheckout = userData.storeId === storeId &&
        (userData.role === "manager" ||
          (userData.role === "employee" && roles.includes("cashier")));

      if (!canCheckout) {
        throw new HttpsError("permission-denied", "User cannot checkout for this store.");
      }

      for (const item of cartItems) {
        if (typeof item.productId !== "string" ||
            !Number.isInteger(item.quantity) ||
            item.quantity <= 0) {
          throw new HttpsError("invalid-argument", "Invalid cart item.");
        }

        requestedQuantities.set(
          item.productId,
          (requestedQuantities.get(item.productId) || 0) + item.quantity,
        );
      }

      const productRefs = Array.from(requestedQuantities.keys()).map((productId) => {
        return db.collection("stores").doc(storeId).collection("products").doc(productId);
      });

      const snapshots = await tx.getAll(...productRefs);

      // Validate stock and calculate true price from server-side product docs.
      for (let i = 0; i < productRefs.length; i++) {
        const snap = snapshots[i];
        const productId = productRefs[i].id;
        const quantity = requestedQuantities.get(productId);

        if (!snap.exists) {
          throw new HttpsError("not-found", `Product ${productId} not found.`);
        }

        const productData = snap.data();
        const stock = productData.quantityInStock || 0;
        const price = Number(productData.price || 0);
        if (stock < quantity) {
          throw new HttpsError("failed-precondition", `Insufficient stock for ${productData.name}`);
        }

        const subtotal = price * quantity;
        totalAmount += subtotal;

        transactionItems.push({
          productId: snap.id,
          productName: productData.name,
          price,
          quantity,
          subtotal,
        });
      }

      const transactionRef = db.collection("stores").doc(storeId)
        .collection("transactions").doc();
      const transactionData = {
        id: transactionRef.id,
        storeId,
        cashierId: auth.uid,
        cashierName: userData.displayName || "Unknown",
        items: transactionItems,
        totalAmount,
        timestamp: FieldValue.serverTimestamp(),
      };

      tx.set(transactionRef, transactionData);

      for (let i = 0; i < productRefs.length; i++) {
        const quantity = requestedQuantities.get(productRefs[i].id);
        tx.update(productRefs[i], {
          quantityInStock: FieldValue.increment(-quantity),
        });
      }

      return {
        transactionId: transactionRef.id,
        cashierName: transactionData.cashierName,
        items: transactionItems,
        totalAmount,
      };
    });

    return { success: true, ...result };
  } catch (error) {
    console.error("Checkout transaction failed:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Secure invite code lookup — allows new users to find a store
 * without granting broad read access to the stores collection.
 */
exports.lookupStoreByInviteCode = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {inviteCode} = request.data;
  if (!inviteCode || typeof inviteCode !== "string" || inviteCode.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Invite code is required.");
  }

  const code = inviteCode.trim().toUpperCase();
  const snapshot = await db.collection("stores")
    .where("inviteCode", "==", code)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return {found: false};
  }

  const storeData = snapshot.docs[0].data();
  return {
    found: true,
    store: {
      id: storeData.id,
      name: storeData.name,
    },
  };
});
