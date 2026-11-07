# Bubble Bobble: high-score persistence

This is an unofficial JTCORES fork. The original core and JTFRAME are by
Jose Tejada Gomez (Jotego) and their respective contributors. High-score
integration and the Bubble Bobble adapter are by J. M. Artés.

The shared engine derives from Alan Steremberg and Jim Gregory's
[Hiscores_MiSTer](https://github.com/JimmyStones/Hiscores_MiSTer), through the
[Bagman implementation](https://github.com/MiSTer-devel/Arcade-Bagman_MiSTer).
Existing copyright and license notices are retained. Core and engine changes
are GPL-3.0-or-later; generated MRA retains its original license notice.
The [MAME hiscore.dat](https://github.com/mamedev/mame/blob/master/plugins/hiscore/hiscore.dat)
profile comes from Leezer / the Unofficial Hiscore.dat project.

## Install and use

Use the matching files in [releases](releases): copy `JTBUBL_Hiscore.rbf` to
`_Arcade/cores` and `Bubble Bobble (Hiscore).mra` to `_Arcade`. ROM files are
not included. Keep the official files if you want to retain the original core.
The supported set is `bublbobl`, labelled Bubble Bobble (Japan, Ver 0.1).
Tokio and other Bubble Bobble variants are not enabled or claimed as tested.

Enable **Autosave Hiscores**, finish entering initials and open the OSD to
save changed data. Reload the same MRA to restore the scores. The dump is
86 bytes and includes scores, initials and special-item counters. Changes to
those counters can legitimately trigger a save without a new high score.
Do not rename an existing MRA without also migrating its MiSTer NVRAM file.

On 8 November 2026, J. M. Artés confirmed that the saved score appears both in
the high-score table and in the upper HISCORE indicator after reloading.
Compilation and installation alone are not treated as physical validation.

## Implementation

The adapter waits for both Z80s to acknowledge BUSRQ, then borrows the main
port of the shared E000-F7FF RAM. The second CPU cannot write during ownership.
The MCU communication RAM and the video path remain unchanged.

Restoration must wait for the actual game initialization, not just apparently
valid RAM. The boot RAM test also writes E64E. The adapter therefore observes
E676=48 (the final initialization byte of the first score-table range) followed
by the normal CPU write to E64E. Both CPUs must also be out of reset. This
prevents the ROM from replacing the restored upper score with its initial
value, such as 30000. There is no ROM patch or custom score renderer.

All 47 ranges and validation bytes match MAME. `JTFRAME_HISCORE_CFGW=6` provides
64 descriptor slots; cores without the macro retain 16. The existing shared
engine, change detection, and IOCTL indices 5/6 are reused. Existing 86-byte
dumps retain their format. A dump produced by an earlier broken version may
contain a correct table but an outdated upper-score field at offsets 38-40;
back up that dump before repairing it. Do not replace a higher upper score
with a lower table value from a game not yet entered into the table.

The shared persistence layer also supports the previously validated JT1942
family (1942, Vulgus and Higemaru); their profiles are unchanged by this patch.

## Build

Use the source revision containing these release files, a configured JTFRAME
build environment and Quartus 19.1. Follow the repository's standard JTFRAME
setup and initialize the required submodules, including JTOPL and JT12/JT49.

```sh
source modules/jtframe/bin/setprj.sh --quiet
jtframe mra bubl --setname bublbobl --skipROM --skipPocket
jtcore bubl -mr --nolinter --nodbg --incremental
```

The MRA generator produces `Bubble Bobble (Japan, Ver 0.1).mra`; the release
changes only its name and RBF reference. The compiled `jtbubl.rbf` is renamed
`JTBUBL_Hiscore.rbf`. Release SHA-256 values are in `releases/SHA256SUMS`.
No new MiSTer Main build is required.
