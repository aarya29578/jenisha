# 🧪 Testing Razorpay Payment Integration

## Quick Test Guide

### 1️⃣ Run the App
```bash
cd d:\jenisha\jenisha_flutter
flutter run
```

### 2️⃣ Navigate to Payment Screen
1. Open app on device/emulator
2. Go to Agent Registration
3. Fill Personal Details → Continue
4. Fill Address Details → Continue
5. You're now on **Payment Screen**

### 3️⃣ Click "Pay Now"

**What You Should See:**
- Razorpay payment modal opens
- Shows amount: ₹1000 (or configured fee)
- Payment options visible:
  - UPI
  - Cards
  - NetBanking
  - Wallets

### 4️⃣ Test Payment Success

**Option A: UPI (Easiest)**
1. Select UPI
2. Enter: `success@razorpay`
3. Click Pay
4. **Expected:** Success dialog appears with Payment ID

**Option B: Card**
1. Select Card Payment
2. Use test card: `4111 1111 1111 1111`
3. Expiry: Any future date (e.g., 12/25)
4. CVV: `123` (for success)
5. **Expected:** Success dialog appears

### 5️⃣ Test Payment Failure

**Option A: UPI**
1. Select UPI
2. Enter: `failure@razorpay`
3. **Expected:** Red error snackbar with retry option

**Option B: Card**
1. Use test card: `4111 1111 1111 1111`
2. CVV: `000` (for failure)
3. **Expected:** Error message displayed

### 6️⃣ Verify Firestore

**After successful payment, check Firebase Console:**

1. **Collection: agent_payments**
   - Should have new document
   - Check fields: paymentId, orderId, signature
   - paymentStatus should be: `success`

2. **Document: users/{userId}**
   - paymentCompleted: `true`
   - paymentId: `pay_xxxxxxxx`
   - registrationStatus: `paid`

3. **Collection: walletTransactions**
   - New transaction recorded
   - type: `credit`
   - paymentMethod: `razorpay`

### 7️⃣ Check Console Logs

**Success Flow Logs:**
```
✅ [PAYMENT SERVICE] Razorpay initialized
🚀 [PAYMENT] Opening Razorpay checkout
✅ [PAYMENT] Razorpay modal opened
✅ [PAYMENT] Payment successful!
   Payment ID: pay_xxxxxxxxxxxxx
💾 [FIRESTORE] Saving payment data
✅ [FIRESTORE] Payment saved to agent_payments/xxxxx
✅ [FIRESTORE] User document updated
```

**Failure Flow Logs:**
```
❌ [PAYMENT] Payment failed
   Message: Payment cancelled by user
```

---

## 📋 Test Checklist

- [ ] Payment button visible on Payment screen
- [ ] Clicking button opens Razorpay modal
- [ ] All payment methods shown (UPI, Cards, etc.)
- [ ] Test UPI success (`success@razorpay`) works
- [ ] Test card success (CVV `123`) works
- [ ] Success dialog shows Payment ID
- [ ] Navigates to Documents step after success
- [ ] Test UPI failure (`failure@razorpay`) shows error
- [ ] Test card failure (CVV `000`) shows error
- [ ] Retry button works after failure
- [ ] Firestore `agent_payments` collection created
- [ ] User document updated with payment data
- [ ] Console logs appear correctly
- [ ] No crashes or exceptions

---

## 🐛 Common Issues & Fixes

### Issue: "Payment gateway failed to open"
**Fix:** Check internet connection, Razorpay key is correct

### Issue: "User not authenticated"
**Fix:** Ensure user is logged in with Firebase Auth

### Issue: "Failed to save payment"
**Fix:** Check Firestore security rules allow writes to agent_payments

### Issue: Payment succeeds but doesn't navigate
**Fix:** Check `onPaymentSuccess` callback is defined

### Issue: User details missing in Razorpay
**Fix:** Ensure user document has fullName, email, phone fields

---

## 🎯 Success Criteria

✅ Payment opens Razorpay gateway
✅ Test payment succeeds
✅ Success dialog appears
✅ Data saved to Firestore
✅ User document updated
✅ Navigation to next step works
✅ Error handling works for failures
✅ Console logs show proper flow

---

## 📞 Need Help?

1. Check console for error logs
2. Verify Razorpay test key in `payment_service.dart`
3. Check Firebase Console for errors
4. Ensure all dependencies installed (`flutter pub get`)
5. Try hot reload/restart if UI not updating

---

*Happy Testing! 🚀*
