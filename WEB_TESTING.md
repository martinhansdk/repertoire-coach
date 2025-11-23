# Web Testing Guide

## Running the Web Version

Start the web server:
```bash
scripts/run-web.sh
```

The app will be available at: **http://localhost:8080**

## Testing IndexedDB (Local Storage)

The web version uses IndexedDB instead of SQLite for local data storage.

### Method 1: Browser DevTools

1. **Open the app** in your browser: http://localhost:8080
2. **Open DevTools** (F12 or Right-click → Inspect)
3. **Go to Application tab** → Storage → IndexedDB
4. You should see a database named `repertoire_coach_db`

### Method 2: Test Data in Browser Console

Open the browser console (F12 → Console tab) and run:

```javascript
// Open the database
const request = indexedDB.open('repertoire_coach_db');

request.onsuccess = (event) => {
  const db = event.target.result;
  console.log('Database opened:', db.name);
  console.log('Object stores:', Array.from(db.objectStoreNames));

  // Check if concerts table exists
  if (db.objectStoreNames.contains('concerts')) {
    console.log('✅ Concerts table exists');
  }
};

request.onerror = () => {
  console.error('❌ Failed to open database');
};
```

### Method 3: Visual Verification

1. Open http://localhost:8080 in your browser
2. You should see the app with "No Concerts" empty state
3. **Check IndexedDB** in DevTools → Application → IndexedDB → repertoire_coach_db
4. The database should be created automatically when the app loads

### Expected Behavior

- ✅ App loads without errors
- ✅ "Repertoire Coach" title appears in app bar
- ✅ "No Concerts" empty state is displayed
- ✅ IndexedDB database `repertoire_coach_db` is created
- ✅ Pull-to-refresh works (shows loading indicator)
- ✅ No console errors related to database

## Comparing Web vs Native Storage

| Platform | Storage | Location |
|----------|---------|----------|
| Web | IndexedDB | Browser storage (persists across sessions) |
| Android/iOS | SQLite | App documents directory |
| Desktop | SQLite | App documents directory |

Both use the **same Drift API**, so the app code is identical across platforms!

## Troubleshooting

### Database not created
- Check browser console for errors
- Try hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
- Clear IndexedDB and reload

### Clear IndexedDB
In DevTools → Application → IndexedDB → Right-click `repertoire_coach_db` → Delete database

## Testing with Sample Data

Since there's no UI to add concerts yet (Phase 1 is local-only), you can verify data persistence by:

1. Inspecting the IndexedDB structure in DevTools
2. Confirming the schema matches the Drift table definitions
3. Waiting for Phase 2 when we add UI to create concerts

## Notes

- Web storage is isolated per browser/profile
- Incognito mode will clear data on close
- IndexedDB has much larger storage limits than localStorage (~50MB minimum, often much more)
- Data persists across page reloads and browser restarts
