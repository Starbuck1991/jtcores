/* SPDX-FileCopyrightText: 2026 J. M. Artés
 * SPDX-License-Identifier: GPL-3.0-or-later */

package mra

import (
	"fmt"

	"jotego/jtframe/macros"
	. "jotego/jtframe/xmlnode"
)

const (
	defaultHiscoreConfigIndex = 5
	defaultHiscoreDataIndex   = 6
	defaultHiscoreScoreWidth  = 9
	maxHiscoreEntries         = 16
)

func make_hiscore(root *XMLNode, machine *MachineXML, cfg Mame2MRA) error {
	k := bestMatch(len(cfg.Hiscore.Games), func(k int) int {
		return cfg.Hiscore.Games[k].Match(machine)
	})
	if k < 0 {
		return nil
	}

	game := cfg.Hiscore.Games[k]
	if len(game.Entries) == 0 {
		return fmt.Errorf("hiscore profile for %s has no entries", machine.Name)
	}
	if len(game.Entries) > maxHiscoreEntries {
		return fmt.Errorf("hiscore profile for %s has %d entries; maximum is %d",
			machine.Name, len(game.Entries), maxHiscoreEntries)
	}

	configIndex := cfg.Hiscore.Config_index
	dataIndex := cfg.Hiscore.Data_index
	if configIndex == 0 {
		configIndex = hiscoreMacroOrDefault("JTFRAME_HISCORE_CFGIDX", defaultHiscoreConfigIndex)
	}
	if dataIndex == 0 {
		dataIndex = hiscoreMacroOrDefault("JTFRAME_HISCORE_DATAIDX", defaultHiscoreDataIndex)
	}
	if configIndex == dataIndex {
		return fmt.Errorf("hiscore config and data indices are both %d", configIndex)
	}

	setHiscoreDefaults(&game)
	raw := make([]byte, 0, 16+8*len(game.Entries))
	raw = append32(raw, game.Start_wait)
	raw = append16(raw, game.Check_wait)
	raw = append16(raw, game.Check_hold)
	raw = append16(raw, game.Write_hold)
	raw = append16(raw, game.Write_repeat)
	raw = append16(raw, game.Write_repeat_wait)
	raw = append(raw, byte(game.Pause_padding), byte(game.Change_mask))

	total := 0
	for _, entry := range game.Entries {
		if entry.Address > 0xffffff {
			return fmt.Errorf("hiscore entry address %08X exceeds the 24-bit engine address space", entry.Address)
		}
		if entry.Length < 1 || entry.Length > 0xffff {
			return fmt.Errorf("hiscore entry at %08X has invalid length %d", entry.Address, entry.Length)
		}
		if entry.Start < 0 || entry.Start > 0xff || entry.End < 0 || entry.End > 0xff {
			return fmt.Errorf("hiscore entry at %08X has a validation byte outside 00-FF", entry.Address)
		}
		total += entry.Length
		raw = append32(raw, int(entry.Address))
		raw = append16(raw, entry.Length)
		raw = append(raw, byte(entry.Start), byte(entry.End))
	}
	if game.Change_mask != 0 {
		return fmt.Errorf("hiscore profile for %s requests a change mask, but mask data is not yet supported", machine.Name)
	}
	scoreWidth := hiscoreMacroOrDefault("JTFRAME_HISCORE_SCOREW", defaultHiscoreScoreWidth)
	if scoreWidth < 1 || scoreWidth > 30 {
		return fmt.Errorf("JTFRAME_HISCORE_SCOREW has invalid value %d", scoreWidth)
	}
	maxHiscoreData := 1 << scoreWidth
	if total > maxHiscoreData {
		return fmt.Errorf("hiscore profile for %s uses %d bytes; maximum is %d",
			machine.Name, total, maxHiscoreData)
	}

	root.AddNode("rom").AddIntAttr("index", configIndex).AddAttr("md5", "none").
		AddNode("part").SetText("\n" + hexdump(raw, 16))
	root.AddNode("nvram").AddIntAttr("index", dataIndex).AddIntAttr("size", total)
	return nil
}

func hiscoreMacroOrDefault(name string, fallback int) int {
	if macros.Get(name) == "" {
		return fallback
	}
	return macros.GetInt(name)
}

func setHiscoreDefaults(cfg *HiscoreCfg) {
	if cfg.Start_wait == 0 {
		cfg.Start_wait = 0xffff
	}
	if cfg.Check_wait == 0 {
		cfg.Check_wait = 0xff
	}
	if cfg.Check_hold == 0 {
		cfg.Check_hold = 2
	}
	if cfg.Write_hold == 0 {
		cfg.Write_hold = 2
	}
	if cfg.Write_repeat == 0 {
		cfg.Write_repeat = 1
	}
	if cfg.Write_repeat_wait == 0 {
		cfg.Write_repeat_wait = 0xff
	}
	if cfg.Pause_padding == 0 {
		cfg.Pause_padding = 2
	}
}

func append16(dst []byte, value int) []byte {
	return append(dst, byte(value>>8), byte(value))
}

func append32(dst []byte, value int) []byte {
	return append(dst, byte(value>>24), byte(value>>16), byte(value>>8), byte(value))
}
