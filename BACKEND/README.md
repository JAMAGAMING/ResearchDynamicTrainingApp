# Training App Backend

A minimal Node.js + Express + Prisma backend for the training app.
All training plan logic runs in the Flutter app — the server only stores JSON blobs.

## Stack
- **Node.js** + **Express** — HTTP server
- **Prisma** — ORM
- **SQLite** — file-based database (zero infra, single file)
- **bcryptjs** — password hashing
- **jsonwebtoken** — stateless auth

---

## Setup

### 1. Install dependencies
```bash
npm install
```

### 2. Configure environment
```bash
cp .env.example .env
```
Edit `.env`:
- Set `JWT_SECRET` to a long random string (run `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"`)
- `DATABASE_URL` defaults to `file:./dev.db` — leave as-is for SQLite

### 3. Initialize the database
```bash
npx prisma db push
```
This creates `dev.db` and all tables. Run this again any time you change `schema.prisma`.

### 4. Start the server
```bash
# Development (auto-restart on file changes)
npm run dev

# Production
npm start
```

The server runs on port `3000` by default (change via `PORT` in `.env`).

---

## API Reference

### Auth
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/auth/register` | — | Register a new account |
| POST | `/auth/login` | — | Login, returns JWT token |
| POST | `/auth/reset-password` | ✅ | Change password |
| GET | `/auth/me` | ✅ | Get current user info |

### Plans
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/plans` | ✅ | List all plan stubs (planId + updatedAt) |
| GET | `/plans/:planId` | ✅ | Get full plan JSON |
| PUT | `/plans/:planId` | ✅ | Upsert a plan |
| DELETE | `/plans/:planId` | ✅ | Delete a plan |
| POST | `/plans/batch` | ✅ | Upsert multiple plans at once |

### Health
| Method | Route | Description |
|--------|-------|-------------|
| GET | `/health` | Returns `{ ok: true }` — use this to check connectivity |

---

## Sync Rules (implemented in Flutter)

1. **On login / open SelectTrainingPlanScreen:**
   - Push all local plans to server (upsert) — local is always authoritative
   - Pull any server plans whose `planId` doesn't exist locally yet — add to local

2. **On any local modification** (create, save, complete day, adjust intensity, etc.):
   - Push the updated plan to `PUT /plans/:planId` in the background

3. **On local delete:**
   - Call `DELETE /plans/:planId` — fire and forget

4. **Offline:** all operations work locally; sync happens when connectivity returns.

---

## Hosting on a dedicated server

```bash
# Install Node.js (if not already)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Clone / copy project files
cd /your/server/path
npm install
npx prisma db push

# Run with PM2 for auto-restart
npm install -g pm2
pm2 start src/index.js --name training-app
pm2 save
pm2 startup
```

Point your Flutter app's `ApiService.baseUrl` at `http://YOUR_SERVER_IP:3000`.
For production, put Nginx in front and use HTTPS.
