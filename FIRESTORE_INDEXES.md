# Firestore Required Composite Indexes

The following composite indexes are required for SafeShell to function correctly. Without these, queries like "Recent Items" or "Stats by Type" will fail.

## Vault Collection
| Fields | Order | Purpose |
| :--- | :--- | :--- |
| `userId` | ASC | Fetch user specific items |
| `isDeleted` | ASC | Filter out recycle bin items |
| `createdAt` | DESC | Order by date (Recent Items) |

### Link to create:
[Firebase Console -> Firestore -> Indexes](https://console.firebase.google.com/project/_/firestore/indexes)

> [!NOTE]
> If a query fails in the console during development, Firebase usually provides a direct link in the error logs to create the missing index automatically.
