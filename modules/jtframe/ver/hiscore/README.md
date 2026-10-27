# Standalone high-score elaboration

This minimal Quartus project elaborates two components independently from any
game:

- the MAME-compatible high-score engine and its memory transaction interface;
- MiSTer IOCTL decoding for configuration, NVRAM download and upload.

Run Quartus 19.1 from this directory:

```powershell
quartus_map --read_settings_files=on --write_settings_files=off hiscore_lint -c hiscore_lint
```

Expected summary:

```text
Quartus Prime Analysis & Synthesis was successful. 0 errors
```

This detects HDL integration and elaboration errors. Hardware validation is
still required for every core adapter and game profile.
