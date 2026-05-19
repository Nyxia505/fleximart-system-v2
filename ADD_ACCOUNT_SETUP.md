# Add Account – Make It Work (3 Steps)

Follow these **once** so Admin and Staff can create accounts from their dashboards.

---

## 1. Enable Email/Password in Firebase

1. Open [Firebase Console](https://console.firebase.google.com) → your project (**fleximart system**).
2. Go to **Authentication** → **Sign-in method**.
3. Click **Email/Password**.
4. Turn **Enable** ON → **Save**.

Without this, account creation will fail with an error.

---

## 2. Deploy the Cloud Function

From your project folder in a terminal:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Wait until you see “Deploy complete.” Then the `adminCreateUser` function is live.

---

## 3. Your Admin/Staff User Must Have a Role

The person who taps **Add Account** (Admin or Staff) must have their role set in Firestore:

1. Firebase Console → **Firestore Database** → **users** collection.
2. Find the document whose ID = the user’s **UID** (from **Authentication** → **Users** → copy **User UID**).
3. In that document, set (or edit) the field **`role`** to **`admin`** or **`staff`** (lowercase).
4. Save.

After this, that user can open the dashboard and use **Add Account** successfully.

---

## Quick Test

1. Log in as a user who has **admin** or **staff** in Firestore.
2. In the dashboard, click **Add Account** (or **Add Staff** on Admin).
3. Fill the form:
   - **Full Name:** e.g. Test User  
   - **Email:** e.g. test@example.com  
   - **Password:** at least 6 characters (e.g. **test12**)  
   - **Confirm Password:** same as password  
4. Tap **Create Account**.

You should see “Account created successfully” and the new user can sign in with that email and password.

---

If it still fails, check **Firebase Console** → **Functions** → **Logs** for the exact error when you tap Create Account.
