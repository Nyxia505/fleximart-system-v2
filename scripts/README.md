# Firestore Cleanup Scripts

## Cleanup Products Without Images

This script finds and deletes all product documents in the Firestore "products" collection where the `imageUrl` field is null, empty, or missing.

### Usage

```bash
# From the project root directory
dart run scripts/cleanup_products_without_images.dart
```

### What it does

1. **Connects to Firestore** - Initializes Firebase using your project's configuration
2. **Fetches all products** - Retrieves all documents from the "products" collection
3. **Analyzes products** - Checks each product for invalid `imageUrl` or `image` fields
4. **Shows preview** - Displays up to 10 products that will be deleted
5. **Asks for confirmation** - Requires you to type "yes" to proceed
6. **Deletes products** - Removes invalid products in batches (up to 500 per batch)
7. **Shows summary** - Reports how many products were deleted

### Safety Features

- ✅ **Preview before deletion** - See what will be deleted before confirming
- ✅ **Confirmation required** - Must type "yes" to proceed
- ✅ **Batch operations** - Efficient deletion using Firestore batches
- ✅ **Error handling** - Continues even if some deletions fail
- ✅ **Detailed logging** - Shows progress and results

### Example Output

```
============================================================
Firestore Product Cleanup Script
============================================================

🔧 Initializing Firebase...
✅ Firebase initialized successfully

📦 Fetching all products from Firestore...
✅ Found 150 total products

🔍 Analyzing products for invalid imageUrl...
📊 Analysis complete:
   - Total products: 150
   - Products with invalid/missing imageUrl: 12
   - Products to keep: 138

⚠️  Products that will be DELETED:
------------------------------------------------------------
   1. Sample Product 1 (ID: abc123)
   2. Sample Product 2 (ID: def456)
   ... and 10 more products
------------------------------------------------------------

⚠️  WARNING: This will permanently delete 12 product(s)!
   This action cannot be undone.

Do you want to proceed? (yes/no): yes

🗑️  Deleting products...
   ✅ Deleted batch 1: 12 products

============================================================
Cleanup Summary
============================================================
✅ Successfully deleted: 12 product(s)
📦 Remaining products: 138
============================================================

✅ Cleanup complete!
```

### Notes

- The script checks both `imageUrl` and `image` fields (for base64 images)
- Products are deleted in batches of 500 (Firestore limit)
- Failed deletions are reported in the summary
- The script requires Firebase to be properly configured in your project

### Troubleshooting

If you encounter errors:

1. **Firebase not initialized**: Make sure `firebase_options.dart` is properly configured
2. **Permission denied**: Check your Firestore security rules allow deletions
3. **Network errors**: Ensure you have internet connectivity
4. **Batch limit exceeded**: The script handles this automatically by batching
