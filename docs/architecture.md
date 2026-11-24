# Architecture: Sol and Terra

## Objective

Demonstrate shoulder-level delegation in Arkhe without a shared ledger. Sol and Terra represent independent installations, not two replicas of one PostgreSQL database.

## Namespace and authority

| Property | Sol | Terra |
| --- | --- | --- |
| NAAN | `99999` (synthetic) | `99999` (synthetic) |
| NAAN description | `Federation Organisation` | `Federation Organisation` |
| Shoulder | `/s7` | `/s7` |
| Role | Delegating installation | Installation authorised to mint `/s7` |
| Minter (host) | `localhost:8257` | `localhost:8357` |
| Resolver (host) | `localhost:8258` | `localhost:8358` |
| Data persistence | Sol PostgreSQL ledger | Terra PostgreSQL ledger |

The numeric shoulder ID is **local to each database** and is not part of the ARK. Setup discovers the IDs instead of hardcoding them.

## Resolution protocol

A test ARK such as `ark:99999/s7btn1gtqqf` (recorded from the initial experiment) is minted on Terra.

1. A client requests `GET http://localhost:8258/ark:99999/s7btn1gtqqf` from Sol.
2. Sol recognises shoulder `/s7` as delegated and returns `303 See Other`, pointing to `http://localhost:8358/ark:99999/s7btn1gtqqf`.
3. The client requests Terra's resolver. Terra locates the ARK in its own ledger and returns `302 Found`, pointing to `https://example.org/federation-test`.
4. The last URL is a dummy test target and is outside the federation mechanism.

```text
Client --> Sol resolver :8258 --303--> Terra resolver :8358 --302--> target
              |                             |
            Sol DB                       Terra DB
```

The use of HTTP redirects is material: Sol tells the **client** where to go; the HTTP response does not demonstrate server-side proxying of the request. A `localhost` Location works for a client running on the Docker host, but not for an external client.

## Minting and delegated minting

Terra's API client is granted `ark:mint` for Terra's `/s7` shoulder. The automated script calls Terra's minter directly, passing a bearer credential. Sol's shoulder is marked `delegated`, with Terra's minter URL recorded. The automated tests verify **direct Terra minting** and **Sol-to-Terra resolution**, not an authenticated redirected mint request via Sol; such a test would need separate coverage and credential-handling policy.

## Responsibilities not included

- ARK persistence and namespace governance beyond this synthetic test
- Dataset replication or data-location discovery
- Choosing compute sites or load balancing
- FAIR Signposting or scientific metadata payloads
- Production authentication, resilience and operational support

## Deployment boundaries

The Compose project runs two PostgreSQL services with separate named volumes, two minters and two resolvers. Using one Compose file does not mean using one database. The application image is built from a pinned upstream Arkhe commit to make the source version explicit. Database volumes are persistent and **must not be deleted accidentally**.
