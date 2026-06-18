# PICS — album create/edit in the iOS app

**Date:** 2026-06-19
**Repos:** Andy-Swiss-Knife (iOS) + andypandy/site (personal-site, Vercel)
**Status:** Approved design, pending implementation plan

## Summary

Add full album management to the PICS section of the iOS app: create, rename,
delete albums; add/remove photos to/from an album; set a cover; and browse an
album's photos. Albums **already exist server-side** in the afilmory photo site
(`andypandy/photos/`) — `AlbumInfo[]` in the manifest, with admin CRUD, rendered
at `pics.andypandy.org/album/[id]`. The app currently has **no** album concept.
This feature manages those same server albums, so changes **sync to the live
site** (no app-only album store). It spans two repos: a thin **personal-site
bridge** (new `/api/admin/albums*` routes) and the **iOS UI**.

## Context

- **afilmory albums** (`andypandy/photos/packages/typing/src/manifest.ts:17`):
  `AlbumInfo { id, name, description, photoIds: string[], coverPhotoId: string | null, createdAt }`.
  Album membership is a list of afilmory **photoIds**.
- **afilmory admin CRUD** (`andypandy/photos/apps/ssr/src/app/api/admin/albums/`):
  - `GET /api/admin/albums` → `AlbumInfo[]`
  - `POST /api/admin/albums` `{name, description?, photoIds?, coverPhotoId?}` → `AlbumInfo` (201)
  - `GET /api/admin/albums/[id]` → `AlbumInfo`
  - `PATCH /api/admin/albums/[id]` `{name?, description?, coverPhotoId?, addPhotoIds?[], removePhotoIds?[]}` → `AlbumInfo`
  - `DELETE /api/admin/albums/[id]` → `{success: true}`
  - Album pages are `force-dynamic`, so edits appear **without a rebuild**.
- **personal-site ↔ afilmory bridge** (`andypandy/site/lib/afilmory.ts`): already
  authenticates to afilmory's admin API via a deterministic admin-password cookie
  (`AFILMORY_ADMIN_PASSWORD` + `ADMIN_SALT`), already does admin writes
  (ingest/EXIF), and exposes `idFromKey(key)` to derive an afilmory photoId from a
  photo's R2 key.
- **iOS PICS** (`Sources/Views/Photos/PhotoGalleryView.swift`,
  `Sources/Services/SiteClient.swift`): the gallery lists `R2Photo { key, url,
  thumbnailUrl, size, lastModified, dateTaken, width, height }` via
  `SiteClient.listR2Photos(prefix:)` → `GET /api/admin/r2-photos` (Bearer
  `PUBLISH_SECRET`, held by `SiteAuth`). It has a folder-prefix filter, a SELECT
  multi-select mode (used for delete), and a masonry grid (`PhotoMasonry`). No
  album concept.
- **Key↔photoId mapping:** the app deals only in photo **keys** (which it has).
  The personal-site bridge is the **only** place key→photoId mapping happens (via
  `idFromKey`), keeping one clear boundary.

## Goals

1. The app can **create, rename, delete** albums (synced to afilmory → the site).
2. The app can **add/remove photos** to/from an album and **set a cover**.
3. The app can **browse** albums and an album's photos.

## Non-goals

- No app-only/offline album store — afilmory is the source of truth.
- No changes to afilmory itself (its album CRUD already exists and is reused).
- No reordering of photos within an album (afilmory stores `photoIds` as a set;
  ordering is out of scope).
- No new auth model — reuse the existing `Bearer PUBLISH_SECRET` (app↔site) and
  admin-cookie (site↔afilmory).

## Design

### 1. Backend bridge (`andypandy/site`)

**`lib/afilmory.ts`** — add functions mirroring the existing admin-write pattern
(build the admin cookie, call afilmory):
- `listAlbums(): Promise<AlbumInfo[]>` → `GET {AFILMORY}/api/admin/albums`
- `createAlbum({name, description?, photoKeys?, coverKey?})` → maps keys→photoIds
  via `idFromKey`, `POST .../albums`
- `updateAlbum(id, {name?, description?, coverKey?, addKeys?, removeKeys?})` →
  maps keys→photoIds, `PATCH .../albums/[id]`
- `deleteAlbum(id)` → `DELETE .../albums/[id]`

**New routes** (authed with `Bearer PUBLISH_SECRET`, same guard as the other
`/api/admin/*` routes — see `app/api/admin/r2-photos/route.ts`):
- `app/api/admin/albums/route.ts` — `GET` (list), `POST` (create).
- `app/api/admin/albums/[id]/route.ts` — `PATCH` (rename/cover/add/remove),
  `DELETE`.

The route layer accepts the app's **photo keys** for membership/cover; the lib
layer converts to photoIds. Responses return `AlbumInfo` (with `photoIds`); the
app does not need to round-trip keys back (it matches album membership against its
photo list by deriving — see §2 note).

> **Deploy:** these are personal-site changes → a **Vercel deploy** of
> `andypandy/site`, separate from the iOS OTA pipeline. Flagged for the
> implementation phase (push/deploy handled with the user).

### 2. iOS (`Andy-Swiss-Knife`)

**`SiteClient`** — add the model + methods:
- `struct Album: Codable, Identifiable { id, name, description, photoIds: [String], coverPhotoId: String?, createdAt }`
  (matches afilmory; `photoIds` are afilmory ids).
- `listAlbums() async throws -> [Album]`
- `createAlbum(name:description:photoKeys:coverKey:) async throws -> Album`
- `updateAlbum(id:name:description:coverKey:addKeys:removeKeys:) async throws -> Album`
- `deleteAlbum(id:) async throws`

> **Membership display:** afilmory returns membership as `photoIds`, while the
> gallery works in `R2Photo.key`s. **Decision:** the bridge enriches every album
> response with a `photoKeys: string[]` field (the server maps each `photoId` → its
> R2 key via the afilmory manifest, which carries both `id` and `s3Key`). The app
> filters its `R2Photo` list by `photoKeys` to show an album's contents and never
> computes `idFromKey` itself — all key↔id mapping stays server-side. The iOS
> `Album` model carries `photoKeys: [String]` (used by the UI) in addition to the
> raw `photoIds`.

**Views** (`Sources/Views/Photos/`):
- `AlbumsView` — the album list (cover thumbnail + name + count), `+ NEW ALBUM`.
- `AlbumDetailView` — the album's photos in `PhotoMasonry`; rename / set-cover /
  delete menu; SELECT → `REMOVE FROM ALBUM`; `+ ADD PHOTOS` (multi-select of the
  library → add keys).
- `PhotoGalleryView` — add a `PHOTOS | ALBUMS` segment to the header; in SELECT
  mode add an `ADD TO ALBUM` action (pick existing or create) alongside DELETE.
- A small `AddToAlbumSheet` (pick an existing album or create a new one for the
  selected keys).

All views reuse the existing brutalist styling (`AppColors`, monospaced chips,
`PhotoMasonry`, `HairlineDivider`).

## Files touched

**andypandy/site:**
- `lib/afilmory.ts` — add `listAlbums/createAlbum/updateAlbum/deleteAlbum`.
- `app/api/admin/albums/route.ts` (new) — GET, POST.
- `app/api/admin/albums/[id]/route.ts` (new) — PATCH, DELETE.

**Andy-Swiss-Knife:**
- `Sources/Services/SiteClient.swift` — `Album` model + 4 methods.
- `Sources/Views/Photos/AlbumsView.swift` (new), `AlbumDetailView.swift` (new),
  `AddToAlbumSheet.swift` (new).
- `Sources/Views/Photos/PhotoGalleryView.swift` — PHOTOS/ALBUMS segment + ADD TO
  ALBUM in SELECT mode.

## Edge cases

- **Photo not in the manifest yet** (uploaded but unprocessed) → `idFromKey` still
  derives a stable id, so it can be added to an album; it renders once afilmory
  processes it. The app shows whatever it has.
- **Album with a deleted cover photo** → `coverPhotoId` may dangle; the list shows
  a placeholder (first member or an empty tile).
- **Empty album** → detail view shows an empty state + `+ ADD PHOTOS`.
- **Auth not linked** (`SiteAuth` unset) → ALBUMS shows the same locked view as
  PHOTOS.
- **Stale list** → pull-to-refresh re-fetches albums (like the gallery).

## Testing

- **Backend:** unit-test the key↔photoId mapping in the album lib functions
  (pure, given a manifest); manual curl of the new routes with the Bearer token.
- **iOS:** build clean (Swift 6, iOS 17). Manual: create → add photos → set cover
  → rename → remove → delete, confirming each reflects on `pics.andypandy.org`.
- **Cross-repo:** verify an app-created album appears on the live site and an
  app-deleted album disappears.
