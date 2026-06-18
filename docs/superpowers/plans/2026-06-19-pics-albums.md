# PICS Albums Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full album management (create/rename/delete, add/remove photos, set cover, browse) to the iOS PICS section, managing the same server-side albums that afilmory already renders on pics.andypandy.org.

**Architecture:** A thin personal-site bridge (`andypandy/site`) exposes `/api/admin/albums*` routes (Bearer `PUBLISH_SECRET` auth) that proxy to afilmory's existing album admin CRUD via the admin-cookie in `lib/afilmory.ts`, mapping the app's photo **keys** ↔ afilmory **photoIds** server-side. The iOS app gets an `Album` model + `SiteClient` methods + album views that reuse the existing masonry/SELECT/brutalist UI.

**Tech Stack:** Backend — Next.js (App Router) / TypeScript / vitest, deploys to Vercel. iOS — Swift 6 / SwiftUI / iOS 17, ships via the OTA pipeline.

## Global Constraints

- **Backend** is `andypandy/site` (separate repo from the iOS app) and **requires a Vercel deploy** — not the iOS OTA. Tests run with **vitest** (locally runnable).
- **iOS** is Swift 6 / iOS 17 target; verified by the `ios-tests` CI workflow (no local Xcode) + on-device after OTA.
- **Auth:** app↔site uses `Bearer PUBLISH_SECRET` (guard via `isAdminRequest` from `@/lib/admin-auth`, exactly as `app/api/admin/r2-photos/route.ts` does). site↔afilmory uses the admin-password cookie from `adminCookie()` in `lib/afilmory.ts`.
- **Key↔id boundary:** the app sends/receives photo **keys** only; ALL key↔photoId mapping stays in `lib/afilmory.ts` (`idFromKey` for key→id; the afilmory manifest's `id`→`s3Key` for id→key). The app never computes `idFromKey`.
- **Album model** mirrors afilmory's `AlbumInfo { id, name, description, photoIds[], coverPhotoId, createdAt }`; bridge responses add `photoKeys: string[]` (and `coverKey: string | null`) for the app.
- afilmory album pages are `force-dynamic` → edits appear with **no rebuild**.

---

## Phase 1 — Backend bridge (`andypandy/site`)

### Task 1: Album key↔id mapping helpers (pure, vitest)

**Files:**
- Modify: `lib/afilmory.ts` (add pure helpers near `idFromKey`)
- Test: `lib/afilmory.albums.test.ts` (new)

**Interfaces:**
- Consumes: `idFromKey(key: string): string` (existing).
- Produces:
  - `type AlbumWire = { id: string; name: string; description: string; photoIds: string[]; coverPhotoId: string | null; createdAt: string }`
  - `keysToIds(keys: string[]): string[]` — `keys.map(idFromKey)`
  - `enrichAlbum(album: AlbumWire, idToKey: Map<string, string>): AlbumWire & { photoKeys: string[]; coverKey: string | null }` — maps each photoId→key (drops ids with no key), and coverPhotoId→coverKey.

- [ ] **Step 1: Write the failing test**

```ts
// lib/afilmory.albums.test.ts
import { describe, it, expect } from 'vitest'
import { keysToIds, enrichAlbum } from './afilmory'

describe('album key<->id mapping', () => {
  it('maps keys to ids deterministically', () => {
    expect(keysToIds(['photos/a.jpg', 'photos/b.jpg'])).toHaveLength(2)
  })

  it('enriches an album with photoKeys + coverKey from the manifest map', () => {
    const idToKey = new Map([['id1', 'photos/a.jpg'], ['id2', 'photos/b.jpg']])
    const album = {
      id: 'al1', name: 'Trip', description: '', photoIds: ['id1', 'id2', 'idGone'],
      coverPhotoId: 'id2', createdAt: '2026-01-01',
    }
    const out = enrichAlbum(album, idToKey)
    expect(out.photoKeys).toEqual(['photos/a.jpg', 'photos/b.jpg']) // idGone dropped
    expect(out.coverKey).toBe('photos/b.jpg')
  })

  it('null coverKey when cover is missing from the map', () => {
    const out = enrichAlbum(
      { id: 'al1', name: 'X', description: '', photoIds: [], coverPhotoId: 'gone', createdAt: '' },
      new Map())
    expect(out.coverKey).toBeNull()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/andy/andypandy/site && npx vitest run lib/afilmory.albums.test.ts`
Expected: FAIL — `keysToIds`/`enrichAlbum` not exported.

- [ ] **Step 3: Add the helpers to `lib/afilmory.ts`**

```ts
export type AlbumWire = {
  id: string
  name: string
  description: string
  photoIds: string[]
  coverPhotoId: string | null
  createdAt: string
}

export function keysToIds(keys: string[]): string[] {
  return keys.map(idFromKey)
}

export function enrichAlbum(
  album: AlbumWire,
  idToKey: Map<string, string>,
): AlbumWire & { photoKeys: string[]; coverKey: string | null } {
  const photoKeys = album.photoIds
    .map((id) => idToKey.get(id))
    .filter((k): k is string => typeof k === 'string')
  const coverKey = (album.coverPhotoId && idToKey.get(album.coverPhotoId)) || null
  return { ...album, photoKeys, coverKey }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/andy/andypandy/site && npx vitest run lib/afilmory.albums.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit** (in the andypandy repo)

```bash
cd /home/andy/andypandy && git add site/lib/afilmory.ts site/lib/afilmory.albums.test.ts
git commit -m "feat(albums): pure key<->id mapping helpers for album bridge"
```

---

### Task 2: Album bridge functions (`lib/afilmory.ts`)

**Files:**
- Modify: `lib/afilmory.ts`

**Interfaces:**
- Consumes: `adminCookie()`, `SITE`, `idFromKey`, `fetchAfilmoryManifest()` (existing); `keysToIds`, `enrichAlbum`, `AlbumWire` (Task 1).
- Produces (all return the enriched album shape `AlbumWire & {photoKeys, coverKey}`, or throw on failure):
  - `listAlbums(): Promise<(AlbumWire & {photoKeys: string[]; coverKey: string|null})[]>`
  - `createAlbum(input: {name: string; description?: string; photoKeys?: string[]; coverKey?: string|null}): Promise<...>`
  - `updateAlbum(id: string, input: {name?: string; description?: string; coverKey?: string|null; addKeys?: string[]; removeKeys?: string[]}): Promise<...>`
  - `deleteAlbum(id: string): Promise<void>`

> No unit test (network to afilmory). Verify by build (`next build` typecheck, Task 3) + manual curl after deploy.

- [ ] **Step 1: Add the functions to `lib/afilmory.ts`**

```ts
async function idToKeyMap(): Promise<Map<string, string>> {
  const byId = await fetchAfilmoryManifest()   // Map<id, {s3Key,...}>
  const m = new Map<string, string>()
  for (const [id, p] of byId) if (p.s3Key) m.set(id, p.s3Key)
  return m
}

export async function listAlbums() {
  const cookie = adminCookie()
  if (!cookie) throw new Error('AFILMORY_ADMIN_PASSWORD not set')
  const res = await fetch(`${SITE}/api/admin/albums`, { headers: { Cookie: cookie }, cache: 'no-store' })
  if (!res.ok) throw new Error(`afilmory albums ${res.status}`)
  const albums = (await res.json()) as AlbumWire[]
  const idToKey = await idToKeyMap()
  return albums.map((a) => enrichAlbum(a, idToKey))
}

export async function createAlbum(input: { name: string; description?: string; photoKeys?: string[]; coverKey?: string | null }) {
  const cookie = adminCookie()
  if (!cookie) throw new Error('AFILMORY_ADMIN_PASSWORD not set')
  const body = {
    name: input.name,
    description: input.description ?? '',
    photoIds: input.photoKeys ? keysToIds(input.photoKeys) : [],
    coverPhotoId: input.coverKey ? idFromKey(input.coverKey) : null,
  }
  const res = await fetch(`${SITE}/api/admin/albums`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`afilmory create album ${res.status}`)
  const album = (await res.json()) as AlbumWire
  return enrichAlbum(album, await idToKeyMap())
}

export async function updateAlbum(id: string, input: { name?: string; description?: string; coverKey?: string | null; addKeys?: string[]; removeKeys?: string[] }) {
  const cookie = adminCookie()
  if (!cookie) throw new Error('AFILMORY_ADMIN_PASSWORD not set')
  const body: Record<string, unknown> = {}
  if (input.name !== undefined) body.name = input.name
  if (input.description !== undefined) body.description = input.description
  if (input.coverKey !== undefined) body.coverPhotoId = input.coverKey ? idFromKey(input.coverKey) : null
  if (input.addKeys) body.addPhotoIds = keysToIds(input.addKeys)
  if (input.removeKeys) body.removePhotoIds = keysToIds(input.removeKeys)
  const res = await fetch(`${SITE}/api/admin/albums/${encodeURIComponent(id)}`, {
    method: 'PATCH', headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`afilmory update album ${res.status}`)
  const album = (await res.json()) as AlbumWire
  return enrichAlbum(album, await idToKeyMap())
}

export async function deleteAlbum(id: string): Promise<void> {
  const cookie = adminCookie()
  if (!cookie) throw new Error('AFILMORY_ADMIN_PASSWORD not set')
  const res = await fetch(`${SITE}/api/admin/albums/${encodeURIComponent(id)}`, { method: 'DELETE', headers: { Cookie: cookie } })
  if (!res.ok) throw new Error(`afilmory delete album ${res.status}`)
}
```

- [ ] **Step 2: Typecheck**

Run: `cd /home/andy/andypandy/site && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd /home/andy/andypandy && git add site/lib/afilmory.ts
git commit -m "feat(albums): afilmory album bridge functions (list/create/update/delete)"
```

---

### Task 3: Album API routes (`/api/admin/albums`)

**Files:**
- Create: `app/api/admin/albums/route.ts`, `app/api/admin/albums/[id]/route.ts`

**Interfaces:**
- Consumes: `isAdminRequest` (`@/lib/admin-auth`); `listAlbums/createAlbum/updateAlbum/deleteAlbum` (Task 2).
- Produces HTTP: `GET/POST /api/admin/albums`, `PATCH/DELETE /api/admin/albums/[id]` — all gated by `isAdminRequest`.

> Guard exactly as `app/api/admin/r2-photos/route.ts` does. No unit test (integration); verify by typecheck + manual curl after deploy.

- [ ] **Step 1: Create `app/api/admin/albums/route.ts`**

```ts
import type { NextRequest } from 'next/server'
import { isAdminRequest } from '@/lib/admin-auth'
import { listAlbums, createAlbum } from '@/lib/afilmory'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  if (!isAdminRequest(req)) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  try {
    return Response.json({ albums: await listAlbums() })
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 502 })
  }
}

export async function POST(req: NextRequest) {
  if (!isAdminRequest(req)) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  const { name, description, photoKeys, coverKey } = await req.json()
  if (!name || typeof name !== 'string') return Response.json({ error: 'name required' }, { status: 400 })
  try {
    return Response.json(await createAlbum({ name, description, photoKeys, coverKey }), { status: 201 })
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 502 })
  }
}
```

> If `isAdminRequest` is async in this codebase, `await` it — match the exact usage in `app/api/admin/r2-photos/route.ts`.

- [ ] **Step 2: Create `app/api/admin/albums/[id]/route.ts`**

```ts
import type { NextRequest } from 'next/server'
import { isAdminRequest } from '@/lib/admin-auth'
import { updateAlbum, deleteAlbum } from '@/lib/afilmory'

export const dynamic = 'force-dynamic'

export async function PATCH(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  if (!isAdminRequest(req)) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  const { id } = await params
  const body = await req.json()
  try {
    return Response.json(await updateAlbum(id, body))
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 502 })
  }
}

export async function DELETE(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  if (!isAdminRequest(req)) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  const { id } = await params
  try {
    await deleteAlbum(id)
    return Response.json({ success: true })
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 502 })
  }
}
```

- [ ] **Step 3: Typecheck + build**

Run: `cd /home/andy/andypandy/site && npx tsc --noEmit && npx next build`
Expected: build succeeds; routes appear.

- [ ] **Step 4: Commit + deploy**

```bash
cd /home/andy/andypandy && git add site/app/api/admin/albums
git commit -m "feat(albums): site album API routes (bridge to afilmory)"
```
Then **deploy the personal-site to Vercel** (push to the deploy branch / `vercel --prod`, per the repo's deploy flow — coordinate with the user). Verify: `curl -H "Authorization: Bearer $PUBLISH_SECRET" https://www.andypandy.org/api/admin/albums` returns `{albums: [...]}`.

---

## Phase 2 — iOS (`Andy-Swiss-Knife`)

### Task 4: `Album` model + `SiteClient` methods

**Files:**
- Modify: `Sources/Services/SiteClient.swift`

**Interfaces:**
- Consumes: `SiteClient`'s existing authed-request helper (the one `listR2Photos`/`deleteR2Photos` use — match its Bearer pattern).
- Produces:
  - `struct Album: Codable, Identifiable, Hashable, Sendable { let id: String; let name: String; let description: String; let photoIds: [String]; let photoKeys: [String]; let coverPhotoId: String?; let coverKey: String?; let createdAt: String }`
  - `func listAlbums() async throws -> [Album]`
  - `func createAlbum(name: String, description: String, photoKeys: [String], coverKey: String?) async throws -> Album`
  - `func updateAlbum(id: String, name: String?, description: String?, coverKey: String??, addKeys: [String], removeKeys: [String]) async throws -> Album`
  - `func deleteAlbum(id: String) async throws`

- [ ] **Step 1: Add the model + methods**

Match the existing request helpers in `SiteClient.swift` (Bearer token from `SiteAuth`, base URL, JSON decode). Add:

```swift
struct Album: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let photoIds: [String]
    let photoKeys: [String]
    let coverPhotoId: String?
    let coverKey: String?
    let createdAt: String
}

private struct AlbumListResponse: Codable { let albums: [Album] }

extension SiteClient {
    func listAlbums() async throws -> [Album] {
        try await get("/api/admin/albums", as: AlbumListResponse.self).albums
    }
    func createAlbum(name: String, description: String = "", photoKeys: [String] = [], coverKey: String? = nil) async throws -> Album {
        try await post("/api/admin/albums",
                       body: ["name": name, "description": description, "photoKeys": photoKeys, "coverKey": coverKey as Any],
                       as: Album.self)
    }
    func updateAlbum(id: String, name: String? = nil, description: String? = nil,
                     coverKey: String?? = nil, addKeys: [String] = [], removeKeys: [String] = []) async throws -> Album {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let description { body["description"] = description }
        if case let .some(cover) = coverKey { body["coverKey"] = cover as Any }
        if !addKeys.isEmpty { body["addKeys"] = addKeys }
        if !removeKeys.isEmpty { body["removeKeys"] = removeKeys }
        return try await patch("/api/admin/albums/\(id)", body: body, as: Album.self)
    }
    func deleteAlbum(id: String) async throws {
        try await delete("/api/admin/albums/\(id)")
    }
}
```

> Use whatever generic `get/post/patch/delete` helpers `SiteClient` already has (mirror `listR2Photos`/`deleteR2Photos`). If it doesn't expose generic verbs, replicate their request-builder inline. Match the EXACT existing networking style — read `SiteClient.swift` first.

- [ ] **Step 2: Verify a clean build**

Run: `xcodegen generate && xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/SiteClient.swift
git commit -m "feat(albums): Album model + SiteClient list/create/update/delete"
```

---

### Task 5: Albums list view + PHOTOS/ALBUMS segment

**Files:**
- Create: `Sources/Views/Photos/AlbumsView.swift`
- Modify: `Sources/Views/Photos/PhotoGalleryView.swift` (add a `PHOTOS | ALBUMS` segment in the header that swaps the body)

**Interfaces:**
- Consumes: `SiteClient.listAlbums/createAlbum` (Task 4); `R2Photo`, `PhotoMasonry`, `AppColors`, brutalist chip style (existing).
- Produces: `struct AlbumsView: View` (list of albums + create); a `@State` mode in `PhotoGalleryView` toggling PHOTOS vs ALBUMS.

> Build-verified + on-device (UI). Reuse the existing brutalist header/chip styling and `AppColors`.

- [ ] **Step 1: Create `AlbumsView.swift`**

A list/grid of albums: each row shows the cover thumbnail (from `coverKey`/first `photoKeys`, via the same thumbnail URL the gallery uses), the `name`, and `photoKeys.count`. A `+ NEW ALBUM` button presents a name prompt (`alert` with a `TextField`) → `SiteClient.createAlbum(name:)` → refresh. Tapping an album `NavigationLink`s to `AlbumDetailView(album:)` (Task 6). Pull-to-refresh re-fetches. Loading/empty/error states mirror `PhotoGalleryView`. (Full SwiftUI per the existing PICS style; ~120 lines.)

- [ ] **Step 2: Add the PHOTOS/ALBUMS segment to `PhotoGalleryView`**

Add `@State private var showingAlbums = false`. In the header, add two brutalist chips `PHOTOS` / `ALBUMS` (reuse the existing `chip(...)` helper) that set `showingAlbums`. When `showingAlbums`, render `AlbumsView()` instead of the gallery `content`.

- [ ] **Step 3: Verify a clean build**

Run: `xcodegen generate && xcodebuild build ... CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/Photos/AlbumsView.swift Sources/Views/Photos/PhotoGalleryView.swift
git commit -m "feat(albums): albums list + PHOTOS/ALBUMS segment"
```

---

### Task 6: Album detail (browse + rename/cover/delete + remove photos)

**Files:**
- Create: `Sources/Views/Photos/AlbumDetailView.swift`

**Interfaces:**
- Consumes: `SiteClient.listR2Photos`, `updateAlbum`, `deleteAlbum` (Tasks 4); `PhotoMasonry`, `PhotoDetailView`, `R2Photo`.
- Produces: `struct AlbumDetailView: View { init(album: Album, onChanged: @escaping () -> Void) }`.

> Build-verified + on-device.

- [ ] **Step 1: Create `AlbumDetailView.swift`**

Fetch the full photo library (`listR2Photos(prefix: nil)`) once, then show the album's photos = `photos.filter { album.photoKeys.contains($0.key) }` in `PhotoMasonry` (reuse the gallery's `masonryCell` pattern). A toolbar menu: **Rename** (alert+TextField → `updateAlbum(id:name:)`), **Set cover** (enter SELECT, pick one → `updateAlbum(id:coverKey:.some(key))`), **Delete album** (confirm → `deleteAlbum(id:)` → pop + `onChanged()`). A SELECT mode → **REMOVE FROM ALBUM** → `updateAlbum(id:removeKeys:selectedKeys)` → refetch the album (re-list to get fresh `photoKeys`). Empty state with `+ ADD PHOTOS` (presents `AddToAlbumSheet` in add-to-this-album mode, Task 7). Hold the album in `@State` so edits update the view; after a mutating call, replace it with the returned `Album`.

- [ ] **Step 2: Verify a clean build**

Run: `xcodegen generate && xcodebuild build ... CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Photos/AlbumDetailView.swift
git commit -m "feat(albums): album detail — browse, rename, cover, delete, remove photos"
```

---

### Task 7: Add-to-album from the gallery

**Files:**
- Create: `Sources/Views/Photos/AddToAlbumSheet.swift`
- Modify: `Sources/Views/Photos/PhotoGalleryView.swift` (SELECT mode → ADD TO ALBUM)

**Interfaces:**
- Consumes: `SiteClient.listAlbums/createAlbum/updateAlbum` (Task 4).
- Produces: `struct AddToAlbumSheet: View { init(keys: [String], onDone: @escaping () -> Void) }`.

> Build-verified + on-device.

- [ ] **Step 1: Create `AddToAlbumSheet.swift`**

A sheet listing existing albums (tap one → `updateAlbum(id:addKeys:keys)` → `onDone()` + dismiss) plus a `+ NEW ALBUM` row (name prompt → `createAlbum(name:photoKeys:keys)` → dismiss). Loading/error states.

- [ ] **Step 2: Wire into the gallery SELECT mode**

In `PhotoGalleryView`'s toolbar, when `selectionMode && !selected.isEmpty`, add an **ADD TO ALBUM** button (alongside DELETE) that presents `AddToAlbumSheet(keys: Array(selected))`; on done, clear selection.

- [ ] **Step 3: Verify a clean build**

Run: `xcodegen generate && xcodebuild build ... CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/Photos/AddToAlbumSheet.swift Sources/Views/Photos/PhotoGalleryView.swift
git commit -m "feat(albums): add-to-album from gallery selection"
```

---

## Self-review against the spec

- **Spec coverage:** create/rename/delete (Tasks 3, 5, 6) · add/remove photos (Tasks 6, 7) · set cover (Task 6) · browse albums + album photos (Tasks 5, 6) · server-synced via the afilmory bridge (Tasks 1–3) · key↔id stays server-side (Tasks 1–2) · `photoKeys`/`coverKey` enrichment (Task 1) · Bearer/admin-cookie auth (Tasks 2–4) · brutalist UI reuse (Tasks 5–7) · deploy boundary called out (Task 3, Global Constraints).
- **Placeholder scan:** backend tasks carry complete code; iOS view tasks describe the exact data flow + reuse named existing components (`PhotoMasonry`, `chip`, `masonryCell`) rather than vague stubs — the SwiftUI bodies follow the established `PhotoGalleryView` patterns. Each iOS task names exact files, methods, and the build-verify command.
- **Type consistency:** `Album {photoKeys, coverKey}` (Task 4) matches the bridge's enriched response (Task 1 `enrichAlbum`); `updateAlbum` add/remove use **keys** end-to-end (Tasks 2, 4, 6, 7); the route bodies (`photoKeys`, `coverKey`, `addKeys`, `removeKeys`) match `SiteClient`'s JSON keys.

## Notes for execution

- **Two repos, two verifications:** Phase 1 runs/tests in `/home/andy/andypandy` (vitest + tsc, locally runnable) and **needs a Vercel deploy** before iOS can talk to it. Phase 2 verifies via the `ios-tests` CI workflow + OTA. Sequence: Phase 1 (+ deploy) → Phase 2.
- iOS view tasks (5–7) can't be unit-tested; before writing them, read `PhotoGalleryView.swift` for the exact masonry/chip/cell helpers to reuse.
