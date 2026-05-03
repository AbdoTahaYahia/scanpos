# ScanPos — Implementation Plan

Build a Flutter-based supermarket POS & inventory management app with Firebase backend and an organic minimalist black-and-white design system.

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.41.1 (Dart 3.11) |
| **Auth** | Firebase Auth (Google Sign-In) |
| **Database** | Cloud Firestore |
| **Storage** | Firebase Storage (product images) |
| **Barcode** | `mobile_scanner` package |
| **State** | `provider` (simple, fits the scope) |
| **Font** | Space Grotesk (Google Fonts) |

---

## Phase 1: Project Setup & Design System

### Dependencies & Config

#### [MODIFY] [pubspec.yaml](file:///c:/Users/abdot/Downloads/scanpos/pubspec.yaml)
Add all required dependencies:
```yaml
dependencies:
  firebase_core, firebase_auth, cloud_firestore, firebase_storage
  google_sign_in
  mobile_scanner          # barcode/QR scanning
  provider                # state management
  google_fonts            # Space Grotesk
  image_picker            # product image capture
  uuid                    # unique IDs for transactions
  cached_network_image    # product image caching
```
Add Space Grotesk font assets.

#### Firebase Configuration
- Run `flutterfire configure` to generate `firebase_options.dart`
- Initialize Firebase in `main.dart`

### Design System

#### [NEW] `lib/theme/app_theme.dart`
The core design system implementing the DESIGN.md spec:
- **Colors**: Pure black `#000000` & white `#FFFFFF` — no grays for primary UI
- **Typography**: Space Grotesk with all variants (display, headline-lg/md, body-lg/sm, label-bold, price-display)
- **Shapes**: Pill-shaped (`StadiumBorder`) for buttons/inputs, `BorderRadius.circular(24+)` for containers
- **Borders**: 2px black borders for Level 1, solid black fill for Level 2
- Custom `ThemeData` with the organic minimalist system

#### [NEW] `lib/theme/app_styles.dart`
Reusable style constants: spacing (8px grid), border styles, elevation levels, touch target minimums (48px).

### Custom Widgets (Design System Components)

#### [NEW] `lib/widgets/pill_button.dart`
Primary (solid black + white text) and secondary (2px border + white fill) pill buttons. Min height 48px.

#### [NEW] `lib/widgets/pill_input.dart`
Pill-shaped text fields: 2px border → 4px on focus. Placeholder text support.

#### [NEW] `lib/widgets/product_chip.dart`
Large pill-shaped category chips (min 64px height, 18px bold text).

#### [NEW] `lib/widgets/rounded_card.dart`
Rounded-rectangle container card with 2px black border and 24px+ corner radius.

#### [NEW] `lib/widgets/circle_button.dart`
Perfect circle button for +/- quantity controls and keypad digits.

#### [NEW] `lib/widgets/scan_feedback_overlay.dart`
Large circular popup with checkmark animation — shows 500ms on successful scan.

---

## Phase 2: Authentication & Onboarding

### Data Models

#### [NEW] `lib/models/app_user.dart`
```dart
class AppUser {
  String uid;
  String email;
  String displayName;
  String? photoUrl;
  String role;          // 'manager', 'warehouse', 'cashier'
  String storeId;
  DateTime createdAt;
}
```

#### [NEW] `lib/models/store.dart`
```dart
class Store {
  String id;
  String name;
  String managerId;
  String inviteCode;    // 6-char alphanumeric
  DateTime createdAt;
}
```

### Services

#### [NEW] `lib/services/auth_service.dart`
- `signInWithGoogle()` — Firebase Auth + Google Sign-In
- `signOut()`
- `getCurrentUser()` stream
- Auto-detect returning users (skip role selection)

#### [NEW] `lib/services/store_service.dart`
- `createStore(managerId)` — creates store doc + generates invite code
- `joinStore(inviteCode, userId)` — validates code, adds user to store
- `regenerateInviteCode(storeId)`
- `getStoreEmployees(storeId)`
- `updateEmployeeRole(userId, newRole)`
- `removeEmployee(userId)`

### Screens

#### [NEW] `lib/screens/auth/sign_in_screen.dart`
Full-screen sign-in with Google button. Organic minimalist style — large centered logo, pill-shaped Google sign-in button.

#### [NEW] `lib/screens/auth/role_selection_screen.dart`
Two large pill options: "I'm a Manager" / "I'm an Employee". Manager path → create store. Employee path → enter invite code screen.

#### [NEW] `lib/screens/auth/enter_invite_code_screen.dart`
Pill input for 6-char invite code. Validates against Firestore. On success → wait for manager to assign role.

#### [NEW] `lib/screens/auth/invite_code_display_screen.dart`
Shows the generated invite code to the manager — large display text with copy button.

### State

#### [NEW] `lib/providers/auth_provider.dart`
Wraps `AuthService`, exposes current user, role, and store context. Handles auth state changes.

---

## Phase 3: Navigation Shell

#### [MODIFY] `lib/main.dart`
- Initialize Firebase
- Set up `MultiProvider` with all providers
- Route based on auth state:
  - Not authenticated → `SignInScreen`
  - Authenticated, no role → `RoleSelectionScreen`
  - Authenticated + role → `AppShell`

#### [NEW] `lib/screens/app_shell.dart`
Bottom navigation with:
- **Scanner tab** (QR icon) — visible to all
- **Inventory tab** (box icon) — hidden for Cashiers
- Pill-shaped bottom bar with organic styling (rounded container, black/white icons)

---

## Phase 4: Scanner / POS Screen

### Data Models

#### [NEW] `lib/models/product.dart`
```dart
class Product {
  String id;
  String name;
  double price;
  int quantityInStock;
  String barcode;
  String category;
  String? imageUrl;
  String storeId;
}
```

#### [NEW] `lib/models/cart_item.dart`
```dart
class CartItem {
  Product product;
  int quantity;
  double get subtotal => product.price * quantity;
}
```

#### [NEW] `lib/models/transaction.dart`
```dart
class SaleTransaction {
  String id;
  String storeId;
  String cashierId;
  String cashierName;
  List<CartItem> items;
  double totalAmount;
  DateTime timestamp;
}
```

### Services

#### [NEW] `lib/services/product_service.dart`
- `getProductByBarcode(storeId, barcode)` — Firestore lookup
- `getAllProducts(storeId)` — stream
- `addProduct(product)` / `updateProduct(product)` / `deleteProduct(id)`
- `decrementStock(productId, quantity)` — atomic decrement via FieldValue

#### [NEW] `lib/services/transaction_service.dart`
- `createTransaction(transaction)` — saves to Firestore
- `getTransactions(storeId)` — stream, reverse chronological
- Stock decrement in a Firestore batch/transaction for atomicity

### State

#### [NEW] `lib/providers/cart_provider.dart`
- `items` list, `totalAmount` getter
- `addItem(product)` — if exists, increment qty
- `removeItem(productId)`
- `clearCart()`
- `checkout()` — creates transaction, decrements stock, clears cart

### Screen

#### [NEW] `lib/screens/scanner/scanner_screen.dart`
Layout (top to bottom):
1. **Camera viewfinder** — `MobileScanner` widget, takes ~40% of screen
2. **Cart list** — scrollable rounded cards for each item (name, price, qty, subtotal)
3. **Total bar + Pay button** — sticky bottom, large price-display font, oversized pill "Pay" button

Behavior:
- Camera auto-starts on tab focus
- On scan → lookup product → add to cart → show `ScanFeedbackOverlay` (✓)
- If not found → show error toast "Product not in inventory"
- Swipe-to-dismiss or remove button on cart items
- Pay → confirmation dialog → process sale → clear cart → ready for next customer

---

## Phase 5: Inventory Screen

### Screen

#### [NEW] `lib/screens/inventory/inventory_screen.dart`
Layout:
1. **Search bar** — pill-shaped input at top (search by name or barcode)
2. **Category filter** — horizontal scroll of `ProductChip` widgets
3. **Product grid/list** — `RoundedCard` for each product (image, name, category, price, stock qty)
4. **FAB** — circular black "+" button → opens add product form

#### [NEW] `lib/screens/inventory/add_edit_product_screen.dart`
Bottom sheet or full screen form:
- Product Name (pill input, required)
- Price (pill input, numeric, required)
- Quantity in Stock (pill input, numeric, required)
- Barcode (pill input + scan icon button, required)
- Category (pill input or dropdown, required)
- Product Image (optional — camera or gallery via `image_picker`, upload to Firebase Storage)
- Save/Update button (primary pill)
- Delete button (for edit mode, with confirmation dialog)

### State

#### [NEW] `lib/providers/inventory_provider.dart`
- Real-time stream of products from Firestore
- Search/filter state
- Selected category filter
- CRUD operations via `ProductService`

---

## Phase 6: Sales History & Team Management

### Screens

#### [NEW] `lib/screens/sales/sales_history_screen.dart`
- Accessible from Manager's profile/settings (not a bottom tab)
- List of transactions in reverse chronological order
- Each card shows: transaction ID, date/time, cashier name, items count, total
- Tap to expand → full item breakdown
- No edit/delete capabilities

#### [NEW] `lib/screens/settings/settings_screen.dart`
Manager-only settings page:
- **Store Info** — store name, invite code (with copy & regenerate buttons)
- **Team section** — list of all employees
  - Each employee card: name, role badge, role change button, remove button
- **Sign Out** button

#### [NEW] `lib/screens/settings/employee_card.dart`
Employee card widget with role toggle (Cashier ↔ Warehouse Staff) and remove action.

---

## Project Structure (Final)

```
lib/
├── main.dart
├── firebase_options.dart          # generated by flutterfire
├── theme/
│   ├── app_theme.dart
│   └── app_styles.dart
├── models/
│   ├── app_user.dart
│   ├── store.dart
│   ├── product.dart
│   ├── cart_item.dart
│   └── transaction.dart
├── services/
│   ├── auth_service.dart
│   ├── store_service.dart
│   ├── product_service.dart
│   └── transaction_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── cart_provider.dart
│   └── inventory_provider.dart
├── screens/
│   ├── app_shell.dart
│   ├── auth/
│   │   ├── sign_in_screen.dart
│   │   ├── role_selection_screen.dart
│   │   ├── enter_invite_code_screen.dart
│   │   └── invite_code_display_screen.dart
│   ├── scanner/
│   │   └── scanner_screen.dart
│   ├── inventory/
│   │   ├── inventory_screen.dart
│   │   └── add_edit_product_screen.dart
│   ├── sales/
│   │   └── sales_history_screen.dart
│   └── settings/
│       ├── settings_screen.dart
│       └── employee_card.dart
└── widgets/
    ├── pill_button.dart
    ├── pill_input.dart
    ├── product_chip.dart
    ├── rounded_card.dart
    ├── circle_button.dart
    └── scan_feedback_overlay.dart
```

---

## Firestore Data Structure

```
stores/
  {storeId}/
    name: string
    managerId: string
    inviteCode: string
    createdAt: timestamp

    products/
      {productId}/
        name, price, quantityInStock, barcode, category, imageUrl, storeId

    transactions/
      {transactionId}/
        cashierId, cashierName, totalAmount, timestamp
        items: [{ productName, productId, price, quantity, subtotal }]

users/
  {uid}/
    email, displayName, photoUrl, role, storeId, createdAt
```

---

## Execution Order

| Step | Phase | Description |
|------|-------|-------------|
| 1 | Setup | Add dependencies to `pubspec.yaml`, run `flutter pub get` |
| 2 | Setup | Firebase configuration (`flutterfire configure` — **needs user's Firebase project**) |
| 3 | Design | Build `app_theme.dart` + `app_styles.dart` |
| 4 | Design | Build all reusable widgets (pill_button, pill_input, etc.) |
| 5 | Models | Create all data models |
| 6 | Services | Build auth_service + store_service |
| 7 | Auth | Build sign-in, role selection, invite code screens |
| 8 | Auth | Build auth_provider |
| 9 | Nav | Build app_shell + main.dart routing |
| 10 | Services | Build product_service + transaction_service |
| 11 | POS | Build cart_provider + scanner_screen |
| 12 | Inventory | Build inventory_provider + inventory screens |
| 13 | History | Build sales_history_screen |
| 14 | Settings | Build settings_screen + employee management |
| 15 | Polish | Test flows, fix issues, refine animations |

---

## Open Questions

> [!IMPORTANT]
> **Firebase Project**: Do you already have a Firebase project set up for ScanPos? I'll need to run `flutterfire configure` which requires a Firebase project. If not, I can write all the code assuming Firebase is configured and you can run the config step yourself.

> [!IMPORTANT]
> **Platform Target**: The PRD says iOS & Android. Should I focus on Android first (since you're on Windows and can test with an emulator), or do you want both platforms configured from the start?

> [!NOTE]
> **State Management**: I'm proposing `provider` as it's simple and sufficient for this app's complexity. The PRD suggested Zustand/Redux (for React Native), but `provider` is the Flutter equivalent. If you prefer `riverpod` or `bloc`, let me know.

> [!NOTE]
> **Currency**: The PRD doesn't specify a currency. I'll use a generic format — should I default to EGP (Egyptian Pound) or another currency?

## Verification Plan

### Automated
- `flutter analyze` — no errors or warnings
- `flutter build apk --debug` — successful Android build

### Manual
- Run on Android emulator/device to verify:
  - Design system renders correctly (B&W, rounded shapes, Space Grotesk)
  - Auth flow works end-to-end
  - Barcode scanning works with camera
  - Cart + Pay flow with stock deduction
  - Inventory CRUD operations
  - Role-based UI visibility
