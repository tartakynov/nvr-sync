# nvr-sync

A Docker container that runs a cron job to move Frigate NVR recordings from SSD to HDD, replacing them with symlinks so Frigate can still find its files.

Both this container and Frigate share the same volume mounts:
- `/media/frigate` — SSD
- `/media/frigate-hdd` — HDD

## Why not let Frigate write to HDD directly?

Frigate's constant read/write activity would prevent HDDs from spinning down, keeping them at peak power consumption 24/7.

By letting Frigate write to SSD — where all Docker data also lives — HDDs are only accessed when users actively interact with the data (viewing recordings, editing photos/videos). This keeps HDDs in a low-power idle state most of the time.

The trade-off is that SSD capacity fills up quickly with Frigate recordings. This script solves that by offloading recordings from SSD to HDD, waking the drives only briefly for the sync.

### SSD wear

**Daily writes:** ~10 GB (reasonable estimate for motion-only recording from a few cameras) = **~3.65 TB/year** logical writes

**Actual NAND writes:** SSDs experience write amplification (WA) — the controller must erase and rewrite blocks larger than your data. This typically multiplies writes by 1.5x-3x. At a conservative 2x WA, 10 GB/day becomes **~7.3 TB/year** of actual wear.

#### Endurance estimates

| SSD capacity | Typical TBW | Years to reach TBW at 10 GB/day (2x WA) |
|:-------------|:------------|:----------------------------------------|
| 250 GB       | 150 TBW     | ~20 years                               |
| 500 GB       | 300 TBW     | ~41 years                               |
| 1 TB         | 600 TBW     | ~82 years                               |
| 2 TB         | 1,200 TBW   | ~164 years                              |

**Important:** Write amplification increases as drives fill up. A 250 GB drive running near capacity will wear faster than these estimates suggest.

For larger drives (1+ TB), SSD wear is negligible — the drive will be obsolete before it wears out.

## How it works

The script syncs recordings between SSD and HDD without storing more data than Frigate intends to keep. Retention is controlled entirely through Frigate's config — no duplicate cleanup logic needed.

**SSD → HDD sync:**
- Recordings on SSD that don't exist on HDD are moved to HDD
- Symlinks are placed on the SSD so Frigate can still locate and replay them

**HDD cleanup:**
- Recordings on HDD whose corresponding symlinks no longer exist on SSD are deleted
- When Frigate removes a file, the HDD copy is automatically cleaned up

## Docker Compose

> **Important:** Both containers must mount the SSD and HDD to the **same paths** inside the container. The sync script creates absolute symlinks from SSD to HDD — if mount paths differ between containers, Frigate won't be able to follow the symlinks.
```yaml
services:
  frigate:
    container_name: frigate
    image: ghcr.io/blakeblackshear/frigate:stable
    restart: unless-stopped
    volumes:
      - /path/to/ssd/frigate:/media/frigate
      - /path/to/hdd/frigate:/media/frigate-hdd
      # ... other volumes as needed

  nvr-sync:
    container_name: nvr-sync
    build: .
    restart: unless-stopped
    environment:
      - CRON_SCHEDULE=0 2 * * *  # default: nightly at 2 AM
    volumes:
      - /path/to/ssd/frigate:/media/frigate
      - /path/to/hdd/frigate:/media/frigate-hdd
```

Replace `/path/to/ssd/frigate` and `/path/to/hdd/frigate` with your actual host paths. The container-side paths (`/media/frigate` and `/media/frigate-hdd`) must stay the same in both containers.

## Reverting

To revert to the original state — moving files back to SSD and cleaning up the HDD:
```bash
docker exec -it nvr-sync nvr-sync.sh revert
```