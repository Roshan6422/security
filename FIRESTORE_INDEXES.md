# Firestore Required Composite Indexes

The following composite indexes are required for SafeShell to function correctly. Without these, queries like "Recent Items" or "Stats by Type" will fail.

## Composite Indexes

| Collection | Fields | Status | Use Case |
|------------|--------|--------|----------|
| `vault`    | `isDeleted` (ASC), `updatedAt` (ASC) | **Action Required** | Background cleanup of old recycle bin items |
| `vault`    | `userId` (ASC), `isDeleted` (ASC), `createdAt` (DESC) | OK | Recent items / Dashboard |

### Link to create:
[Firebase Console -> Firestore -> Indexes](https://console.firebase.google.com/project/_/firestore/indexes)

> [!NOTE]
> If a query fails in the console during development, Firebase usually provides a direct link in the error logs to create the missing index automatically.
