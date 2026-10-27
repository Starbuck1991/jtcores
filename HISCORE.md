# Optional high-score persistence for JTFRAME

This unofficial JTCORES fork adds an opt-in high-score load/save system for
MiSTer arcade cores. It keeps game-specific address maps outside the common
engine, so additional games can reuse the same infrastructure with a small
memory adapter and a declarative profile.

The implementation currently includes validated profiles for:

- 1942
- Vulgus
- Pirate Ship Higemaru

The three games share the `JT1942_Hiscore.rbf` build and use separate MiSTer
NVRAM files. The MRA name is deliberately suffixed with `(Hiscore)` so these
builds are not mistaken for official JTCORES releases.

## Architecture

The feature is split into three layers:

1. A generic JTFRAME engine that interprets MAME `hiscore.dat`-style ranges,
   waits for validation bytes, restores saved data and uploads only changed
   scores.
2. A request/acknowledge memory interface that lets each core safely expose
   the required RAM without embedding a game memory map in JTFRAME.
3. Per-machine profiles in `mame2mra.toml`, emitted automatically as MRA ROM
   index 5 plus NVRAM index 6 by `mame2mra`.

The MiSTer OSD option controls autosave. Opening the OSD checks the configured
ranges; enabling autosave while the OSD is already open also rechecks them, so
a score made before enabling the option is not left pending.

## Attribution

The high-score state machine was adapted from `rtl/hiscore.v` in
[Arcade-Bagman_MiSTer](https://github.com/MiSTer-devel/Arcade-Bagman_MiSTer),
which in turn comes from
[Hiscores_MiSTer](https://github.com/JimmyStones/Hiscores_MiSTer), originally
copyright Alan Steremberg and Jim Gregory. Their notices and GPL terms remain
in `jtframe_hiscore.v`.

The 1942, Vulgus and Higemaru address ranges were transcribed from
[MAME's `plugins/hiscore/hiscore.dat`](https://github.com/mamedev/mame/blob/master/plugins/hiscore/hiscore.dat).
That database credits Leezer for otherwise unnamed entries and states that it
is based on the Unofficial Hiscore.dat project formerly hosted by MAMEWorld.

The JTFRAME transport, memory transaction interface, MRA generator, JT1942
adapter and game profiles were integrated in 2026 by **J. M. Artés**, with
development assistance from OpenAI Codex.

JTCORES and JTFRAME remain the work of Jotego and their existing contributors.
This fork is independent and is not an official Jotego release.

## License and distribution

The fork is distributed under GPLv3, matching JTCORES and Hiscores_MiSTer.
Modified source is identified in file headers and Git history. Any distributed
RBF should point to the exact corresponding source revision. Arcade ROMs are
not included and must not be distributed with the binaries.

## Verification

The real engine and MiSTer IOCTL transport have a standalone Quartus 19.1
elaboration project under `modules/jtframe/ver/hiscore`. The JT1942 build and
the three listed games have been tested on MiSTer hardware; each new game still
requires hardware validation of its memory ranges and restore timing.
