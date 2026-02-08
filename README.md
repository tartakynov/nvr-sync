# nvr-sync

A Docker container that runs a nightly cron job to move Frigate NVR recordings from SSD to HDD, replacing them with symlinks so Frigate can still find its files.

Both this container and Frigate share the same volume mounts:
- `/media/frigate` — SSD
- `/media/frigate-hdd` — HDD (RAID5)

## Why not let Frigate write to HDD directly?

Frigate's constant read/write activity would prevent the HDDs from ever spinning down, keeping them at peak power consumption 24/7.

By letting Frigate write to SSD — where all Docker data also lives — the HDDs are only accessed when users actively interact with the data (viewing content, editing photos/videos). This keeps the HDDs in a low-power idle state most of the time.

The trade-off is that SSD capacity would quickly fill up with Frigate recordings. This script solves that by offloading recordings from SSD to HDD nightly, waking the drives only briefly for the sync.

## How it works

The script syncs the recordings folder between SSD and HDD without storing more data than Frigate intends to keep. Retention is controlled entirely through Frigate's config — no duplicate cleanup logic needed.

- **SSD → HDD:** Recordings on SSD that don't exist on HDD are moved to HDD, and symlinks are placed on the SSD so Frigate can still locate and replay them.
- **HDD cleanup:** Recordings on HDD whose corresponding symlinks no longer exist on SSD are deleted. If Frigate removed a file, it no longer wants it, so the HDD copy is cleaned up too.

## Docker Compose

> **Important:** Both containers must mount the SSD and HDD to the **same paths** inside the container. The sync script creates absolute symlinks from SSD to HDD — if the mount paths differ between containers, Frigate will not be able to follow the symlinks.

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

Replace `/path/to/ssd/frigate` and `/path/to/hdd/frigate` with the actual host paths for your SSD and HDD storage. The container-side paths (`/media/frigate` and `/media/frigate-hdd`) must stay the same in both containers.

## Reverting

The script supports reverting to the original state — moving files back to SSD and cleaning up the HDD. Use this if you no longer want to run the script.
