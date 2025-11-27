/**
 * Firebase Admin SDK Script - Set Custom Claims for Admin and Staff
 * 
 * This script sets custom claims (roles) for admin and staff users in Firebase Authentication.
 * Custom claims are used to control access to admin and staff dashboards.
 * 
 * INSTRUCTIONS:
 * 1. Install dependencies:
 *    npm install firebase-admin
 * 
 * 2. Get your Firebase service account key:
 *    - Go to Firebase Console > Project Settings > Service Accounts
 *    - Click "Generate New Private Key"
 *    - Save the JSON file as "serviceAccountKey.json" in this directory
 * 
 * 3. Update the serviceAccountKey.json path below if needed
 * 
 * 4. Run the script:
 *    node scripts/set_custom_claims.js
 * 
 * 5. After running, users need to refresh their tokens:
 *    In Flutter: await user.getIdTokenResult(true)
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
// Option 1: Use service account key file (recommended for local scripts)
try {
  const serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  
  console.log('✅ Firebase Admin SDK initialized with service account key\n');
} catch (error) {
  // Option 2: Use environment variable (for production/CI)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin SDK initialized with environment variable\n');
  } else {
    console.error('❌ Error: Could not initialize Firebase Admin SDK');
    console.error('Please provide serviceAccountKey.json or set FIREBASE_SERVICE_ACCOUNT environment variable');
    console.error('\nTo get service account key:');
    console.error('1. Go to Firebase Console > Project Settings > Service Accounts');
    console.error('2. Click "Generate New Private Key"');
    console.error('3. Save as "serviceAccountKey.json" in the scripts directory');
    process.exit(1);
  }
}

// User UIDs
const ADMIN_UID = '902rmTO6DCY0OCuBoOJ6BrtXiaL2';
const STAFF_UID = 'tFQOi3Di1uZnds4cGfiBL7Nq9ys1';

/**
 * Set custom claims for a user
 * @param {string} uid - User UID
 * @param {string} role - Role to assign ('admin' or 'staff')
 */
async function setCustomClaims(uid, role) {
  try {
    // Verify user exists
    const user = await admin.auth().getUser(uid);
    console.log(`📋 User found: ${user.email || user.uid}`);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, { role: role });
    
    // Verify the claims were set
    const updatedUser = await admin.auth().getUser(uid);
    const claims = updatedUser.customClaims || {};
    
    if (claims.role === role) {
      console.log(`✅ ${role.toUpperCase()} role applied successfully`);
      console.log(`   Custom claims: ${JSON.stringify(claims)}\n`);
      return true;
    } else {
      console.error(`❌ Failed to verify ${role} role assignment`);
      return false;
    }
  } catch (error) {
    console.error(`❌ Error setting ${role} role for UID ${uid}:`);
    console.error(`   ${error.message}\n`);
    return false;
  }
}

/**
 * Main function to set roles for all users
 */
async function main() {
  console.log('🚀 Starting custom claims assignment...\n');
  console.log('=' .repeat(50));
  
  let successCount = 0;
  let failCount = 0;
  
  // Set admin role
  console.log(`\n1️⃣ Setting ADMIN role for UID: ${ADMIN_UID}`);
  const adminSuccess = await setCustomClaims(ADMIN_UID, 'admin');
  if (adminSuccess) {
    successCount++;
  } else {
    failCount++;
  }
  
  // Set staff role
  console.log(`\n2️⃣ Setting STAFF role for UID: ${STAFF_UID}`);
  const staffSuccess = await setCustomClaims(STAFF_UID, 'staff');
  if (staffSuccess) {
    successCount++;
  } else {
    failCount++;
  }
  
  // Summary
  console.log('=' .repeat(50));
  console.log('\n📊 Summary:');
  console.log(`   ✅ Success: ${successCount}`);
  console.log(`   ❌ Failed: ${failCount}`);
  
  if (successCount === 2) {
    console.log('\n🎉 All roles assigned successfully!');
    console.log('\n⚠️  IMPORTANT: Users must refresh their tokens to see the new role.');
    console.log('   In Flutter app, call: await user.getIdTokenResult(true)');
    console.log('   Or users can sign out and sign in again.\n');
  } else {
    console.log('\n⚠️  Some roles failed to assign. Please check the errors above.\n');
    process.exit(1);
  }
}

// Run the script
main()
  .then(() => {
    console.log('✨ Script completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });

