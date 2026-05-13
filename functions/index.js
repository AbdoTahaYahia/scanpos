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

/**
 * Edit or delete a transaction with atomic stock adjustment.
 * Only the original cashier can edit, and only within 24 hours.
 */
exports.editTransaction = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const {storeId, transactionId, updatedItems} = request.data;
  if (!storeId || !transactionId) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }
  if (!Array.isArray(updatedItems)) {
    throw new HttpsError("invalid-argument", "updatedItems must be an array.");
  }

  try {
    await db.runTransaction(async (tx) => {
      // 1. Read the existing transaction
      const txRef = db.collection("stores").doc(storeId)
        .collection("transactions").doc(transactionId);
      const txSnap = await tx.get(txRef);

      if (!txSnap.exists) {
        throw new HttpsError("not-found", "Transaction not found.");
      }

      const txData = txSnap.data();

      // 2. Verify ownership — only the original cashier can edit
      if (txData.cashierId !== auth.uid) {
        // Allow managers too
        const userRef = db.collection("users").doc(auth.uid);
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists || userSnap.data().role !== "manager") {
          throw new HttpsError("permission-denied",
            "Only the original cashier or a manager can edit this transaction.");
        }
      }

      // 3. Verify within 24 hours
      const txTimestamp = txData.timestamp?.toDate?.() || new Date(0);
      const hoursSince = (Date.now() - txTimestamp.getTime()) / (1000 * 60 * 60);
      if (hoursSince > 24) {
        throw new HttpsError("failed-precondition",
          "Transactions older than 24 hours cannot be edited.");
      }

      // 4. Build maps for old and new quantities
      const oldQtyMap = new Map();
      for (const item of txData.items) {
        oldQtyMap.set(item.productId,
          (oldQtyMap.get(item.productId) || 0) + item.quantity);
      }

      const newQtyMap = new Map();
      for (const item of updatedItems) {
        if (item.quantity > 0) {
          newQtyMap.set(item.productId,
            (newQtyMap.get(item.productId) || 0) + item.quantity);
        }
      }

      // 5. Calculate diffs and get all affected product refs
      const allProductIds = new Set([...oldQtyMap.keys(), ...newQtyMap.keys()]);
      const productRefs = [];
      const productIds = [];
      for (const pid of allProductIds) {
        productRefs.push(
          db.collection("stores").doc(storeId).collection("products").doc(pid)
        );
        productIds.push(pid);
      }

      // Read all products
      const productSnaps = await tx.getAll(...productRefs);

      // 6. Validate new quantities against available stock
      for (let i = 0; i < productIds.length; i++) {
        const pid = productIds[i];
        const snap = productSnaps[i];
        const oldQty = oldQtyMap.get(pid) || 0;
        const newQty = newQtyMap.get(pid) || 0;
        const diff = newQty - oldQty; // positive = need more stock

        if (diff > 0 && snap.exists) {
          const currentStock = snap.data().quantityInStock || 0;
          if (currentStock < diff) {
            const name = snap.data().name || pid;
            throw new HttpsError("failed-precondition",
              `Insufficient stock for ${name}. Available: ${currentStock}, needed: ${diff}`);
          }
        }
      }

      // 7. Apply stock adjustments
      for (let i = 0; i < productIds.length; i++) {
        const pid = productIds[i];
        const oldQty = oldQtyMap.get(pid) || 0;
        const newQty = newQtyMap.get(pid) || 0;
        const diff = newQty - oldQty;

        if (diff !== 0 && productSnaps[i].exists) {
          tx.update(productRefs[i], {
            quantityInStock: FieldValue.increment(-diff),
          });
        }
      }

      // 8. Update or delete the transaction
      if (updatedItems.length === 0) {
        // Delete transaction
        tx.delete(txRef);
      } else {
        // Recalculate total
        let newTotal = 0;
        for (const item of updatedItems) {
          newTotal += (item.price || 0) * (item.quantity || 0);
        }

        tx.update(txRef, {
          items: updatedItems,
          totalAmount: newTotal,
        });
      }
    });

    return {success: true};
  } catch (error) {
    console.error("Edit transaction failed:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", error.message);
  }
});
