ORG $1A8000

; this code is run when the player presses L + R in a level to reset the current room
activate_room_reset:
		; if we are in first room of level, just level reset
		LDA $141A ; sublevel count
		AND #$7F
		BNE .room_reset
		
	.level_reset:
		JSL activate_level_reset
		RTL
		
	.room_reset:
		LDA #$01
		STA !l_r_function
		
		LDA !recent_screen_exit
		LDY !recent_secondary_flag
		JSL set_global_exit
		JSR trigger_screen_exit
		
		LDA #$20 ; bow sound
		STA $1DF9 ; apu i/o
		
		RTL
		
; this code is run when the player buffers L + R upon level load or reset
activate_midway_entrance:
		LDA #$03
		STA !l_r_function
		STZ !start_midway
		INC $13CE ; midway flag
		
		JSR get_level_low_byte ; use secondary exit that is equal to level number
		LDY #$01
		JSL set_global_exit
		JSR trigger_screen_exit
		
		LDA #$05 ; midway sound
		STA $1DF9 ; apu i/o
		
		RTL

; this code is run when the player presses L + R + A + B in a level to reset the entire level
activate_level_reset:
		LDA #$02
		STA !l_r_function
		
		JSR get_level_low_byte
		LDY #$00
		JSL set_global_exit
		JSR trigger_screen_exit
		
		LDA #$20 ; bow sound
		STA $1DF9 ; apu i/o
		
		RTL

; this code is run when the player presses L + R + X + Y in a level to advance to the next room
activate_room_advance:
		PHP
		LDA #$03
		STA !l_r_function
		
		; X = level bank
		LDX #$00
		LDA $13BF ; translevel number
		CMP #$25
		BCC .low_level_bank
		INX
	.low_level_bank:
		
		LDA $141A ; sublevel count
		AND #$7F
		BNE .load_from_backup
		
		; we just entered the level, so backup may not be available
		; we know we entered via screen exit, not from secondary exit
		JSR get_level_low_byte
		LDY #$00
		BRA .merge
	.load_from_backup:
		; we are in some sublevel, so backup is available
		LDA !recent_screen_exit
		LDY !recent_secondary_flag
	
	.merge:
		JSR get_next_sensible_exit
		PHX
		JSL set_global_exit
		JSR trigger_screen_exit
		
		LDA #$09 ; cape sound
		STA $1DF9 ; apu i/o
		
		PLA
		REP #$20
		AND #$00FF
		ASL #5
		STA !restore_room_xpos
		
		PLP
		RTL

; set the screen exit for all screens to be set to the exit number in A
; Y = 1 iff this exit is a secondary exit
set_global_exit:
		LDX #$20
	.loop_exits:
		DEX
		STA $19B8,X ; exit table
		BNE .loop_exits
		STY $1B93 ; secondary exit flag
		RTL

; get the low byte of the level number, not the translevel number
get_level_low_byte:
		LDA $13BF ; translevel number
		CMP #$25
		BCC .done
		SEC
		SBC #$24
	.done:
		RTS

; actually trigger the screen exit
trigger_screen_exit:
		LDA #$05
		STA $71 ; player animation trigger
		STZ $88
		STZ $89 ; pipe timers
		RTS

; given the current sub/level, return a sub/level that 'advances' one room forward
; given A = level number low byte, X = level number high byte, Y = secondary exit flag
; return A = level number low byte / secondary exit number, Y = secondary exit flag, X = mario x position
get_next_sensible_exit:
		PHP
		PHB
		PHK
		PLB
		CPX #$00
		BEQ .low_bank
		TAX
		CPY #$00
		BEQ .high_level_number
		LDA room_advance_table+$000,X
		LDY room_advance_table+$200,X
		PHY
		LDY room_advance_table+$100,X
		PLX
		BRA .done
	.high_level_number:
		LDA room_advance_table+$300,X
		LDY room_advance_table+$500,X
		PHY
		LDY room_advance_table+$400,X
		PLX
		BRA .done
		
	.low_bank:
		TAX
		CPY #$00
		BEQ .low_level_number
		LDA room_advance_table+$600,X
		LDY room_advance_table+$800,X
		PHY
		LDY room_advance_table+$700,X
		PLX
		BRA .done
	.low_level_number:
		LDA room_advance_table+$900,X
		LDY room_advance_table+$B00,X
		PHY
		LDY room_advance_table+$A00,X
		PLX
		
	.done:
		PLB
		PLP
		RTS
		
room_advance_table:
		; =======================================
		; This bin file contains 12 tables that hold screen exit data to be used
		; by the advance room function. Each table is 0x100 bytes long.
		; Table 01: exit number to take if last exit was a secondary exit, bank 1
		; Table 02: secondary exit flag for above table number
		; Table 03: player x position data for above table (sssssxxx, s = screen, x = x pos / 2)
		; Table 04: exit number to take if last exit was a level exit, bank 1
		; Table 05: secondary exit flag for above table number
		; Table 06: player x position data for above table (sssssxxx, s = screen, x = x pos / 2)
		; Table 07: exit number to take if last exit was a secondary exit, bank 0
		; Table 08: secondary exit flag for above table number
		; Table 09: player x position data for above table (sssssxxx, s = screen, x = x pos / 2)
		; Table 10: exit number to take if last exit was a level exit, bank 0
		; Table 11: secondary exit flag for above table number
		; Table 12: player x position data for above table (sssssxxx, s = screen, x = x pos / 2)
		incbin "bin/room_advance_table.bin"
		; =======================================
		
; this code is run when the player presses R + select to make a save state
activate_save_state:
		LDA !in_record_mode
		ORA !in_playback_mode
		BNE .cancel
		LDA #$0E ; swim sound
		STA $1DF9 ; apu i/o
		STZ $4200 ; nmi disable
		
	-	LDA $4212
		BPL -
		
		LDA #$80
		STA $2100 ; force blank
		
		LDA !in_record_mode
		BEQ .no_tag
		LDA #$01
		STA !movie_location+$0E
	.no_tag:
		
		JSR go_save_state
		LDA !level_timer_minutes
		ORA !level_timer_seconds
		ORA !level_timer_frames
		STA.L !spliced_run
		LDA #$BD
		STA.L !save_state_exists
		
	-	LDA $4212
		BPL -
		
		LDA #$81
		STA $4200 ; nmi enable
		LDA #$0F
		STA $2100 ; exit force blank
	.cancel:
		RTL

go_save_state:
		PHP
		REP #$10
		
		; save wram $0000-$1FFF to wram $7FA800-$7FC7FF
		; mirrored wram
		LDX #$1FFF
	.loop_mirror:
		LDA $7E0000,X
		STA $7FA800,X
		DEX
		BPL .loop_mirror
		
		; save wram $C680-$C6DF to $704BE0-$704C3F
		; mode 7 boss tilemap
		LDX #$005F
	.loop_boss:
		LDA $7EC680,X
		STA $704BE0,X
		DEX
		BPL .loop_boss
		
		; save wram $7F9A7B-$7F9C7A to $704AE0-$704BDF
		; wiggler segments
		LDX #$01FF
	.loop_wiggler:
		LDA $7F9A7B,X
		STA $704AE0,X
		DEX
		BPL .loop_wiggler
		
		; save wram $B900-$C0FF to $704C40-$70543F
		; background tilemap
		LDX #$07FF
	.loop_background:
		LDA $7EB900,X
		STA $704C40,X
		DEX
		BPL .loop_background
		
		; save wram $C800-$FFFF to $700BA0-$70439F
		; level tilemap low byte
		LDX #$37FF
	.loop_tilemap_low:
		LDA $7EC800,X
		STA $700BA0,X
		DEX
		BPL .loop_tilemap_low
		
		; save wram $7FC800-$7FFFFF to $7043A0-$704A9F
		; level tilemap high bit
		; since only bit 0 is used for this data, crunch it into a 1:8 ratio
		; unrolled inner loop is used for the speed increase
		PHB
		LDA #$70
		PHA
		PLB
		
		LDX #$37F8
		LDY #$06FF
	.loop_tilemap_high:
		LDA $7FC800,X
		STA $00
		LDA $7FC801,X
		STA $01
		LDA $7FC802,X
		STA $02
		LDA $7FC803,X
		STA $03
		LDA $7FC804,X
		STA $04
		LDA $7FC805,X
		STA $05
		LDA $7FC806,X
		STA $06
		LDA $7FC807,X
		STA $07
		LDA #$00
		LSR $00
		ROL A
		LSR $01
		ROL A
		LSR $02
		ROL A
		LSR $03
		ROL A
		LSR $04
		ROL A
		LSR $05
		ROL A
		LSR $06
		ROL A
		LSR $07
		ROL A
		STA $43A0,Y ; $7043A0,Y
		DEX #8
		DEY
		BPL .loop_tilemap_high
		
		; do these separately because they actually use the upper 7 bits
		; mode 7 level tilemaps
		LDX #$001F
	.loop_mode7_bridge_a:
		LDA $7FC8B0,X
		STA $704AA0,X
		DEX
		BPL .loop_mode7_bridge_a
		
		LDX #$001F
	.loop_mode7_bridge_b:
		LDA $7FCA60,X
		STA $704AC0,X
		DEX
		BPL .loop_mode7_bridge_b
		
		PLB
		
		; save the stack pointer to $7F9C7B - $7F9C7C
		REP #$30
		TSX
		TXA
		STA $7F9C7B
		
		; save the currently used music to $7F9C7D
		SEP #$20
		LDA $2142
		STA $7F9C7D
		
	.done:
		PLP
		RTS

; this code is run when the player presses L + select to load a save state
activate_load_state:
		LDA !in_record_mode
		ORA !in_playback_mode
		BNE .done_waiting
		STZ $4200 ; nmi disable
		
	-	LDA $4212
		BPL -
		
		LDA #$80
		STA $2100 ; force blank
		
		JSR go_load_state
	.done:
		JSR restore_hardware_regs
		
		JSR restore_all_graphics
		JSR restore_all_tilemaps
		JSR restore_all_palettes
		
		LDA !level_timer_minutes
		ORA !level_timer_seconds
		ORA !level_timer_frames
		STA !spliced_run
		
		LDA !status_dynmeter
		ORA !status_slots
		BEQ .no_slot_graphics
		JSL load_slots_graphics
	.no_slot_graphics:
		
		LDA #$81
		STA $4200 ; nmi enable

		LDA.L !status_statedelay
		INC A
		ASL #3
		TAX
	.loop:
		DEX
		BEQ .done_waiting
		WAI ; wait for NMI
		STZ $2100
		WAI ; wait for IRQ
		STZ $2100
		INC !previous_sixty_hz ; waiting here shouldn't count as lag
		BRA .loop
	
	.done_waiting:
		RTL
		
go_load_state:
		PHP
		
		LDA !in_record_mode
		BNE .sorry
		LDA !in_playback_mode
		BEQ .letsgo
	.sorry:
		JMP .done
	.letsgo:
		
		REP #$10
		
		; load wram $7FA800-$7FC7FF to wram $0000-$1FFF
		; mirror wram
		; copy old graphics files into state
		LDX #$0007
	.loop_graphics_files:
		LDA $7E0101,X
		STA $7F9C7E,X
		DEX
		BPL .loop_graphics_files
		LDX #$1FFF
	.loop_mirror:
		LDA $7FA800,X
		STA $7E0000,X
		DEX
		BPL .loop_mirror
		
		; load $704BE0-$704C3F to wram $C680-$C6DF
		; mode 7 boss tilemap
		LDX #$005F
	.loop_boss:
		LDA $704BE0,X
		STA $7EC680,X
		DEX
		BPL .loop_boss
		
		; load $704AE0-$704BDF to wram $7F9A7B-$7F9C7A
		; wiggler segments
		LDX #$01FF
	.loop_wiggler:
		LDA $704AE0,X
		STA $7F9A7B,X
		DEX
		BPL .loop_wiggler
		
		; load $704C40-$70543F to wram $B900-$C0FF
		; background tilemap
		LDX #$07FF
	.loop_background:
		LDA $704C40,X
		STA $7EB900,X
		DEX
		BPL .loop_background
		
		; load $700BA0-$70439F to wram $C800-$FFFF
		LDX #$37FF
	.loop_tilemap_low:
		LDA $700BA0,X
		STA $7EC800,X
		DEX
		BPL .loop_tilemap_low
		
		; load $7043A0-$704A9F to wram $7FC800-$7FFFFF
		; since only bit 0 is used for this data, expand it into a 8:1 ratio
		; unrolled inner loop is used for the speed increase
		LDX #$0007
	.loop_prepare_scratch:
		STZ $00,X
		DEX
		BPL .loop_prepare_scratch
		
		PHB
		LDA #$70
		PHA
		PLB
		
		LDX #$37F8
		LDY #$06FF
	.loop_tilemap_high:
		LDA $43A0,Y ; $7043A0,Y
		LSR $07
		ROR A
		ROL $07
		LSR $06
		ROR A
		ROL $06
		LSR $05
		ROR A
		ROL $05
		LSR $04
		ROR A
		ROL $04
		LSR $03
		ROR A
		ROL $03
		LSR $02
		ROR A
		ROL $02
		LSR $01
		ROR A
		ROL $01
		LSR $00
		ROR A
		ROL $00
		LDA $00
		STA $7FC800,X
		LDA $01
		STA $7FC801,X
		LDA $02
		STA $7FC802,X
		LDA $03
		STA $7FC803,X
		LDA $04
		STA $7FC804,X
		LDA $05
		STA $7FC805,X
		LDA $06
		STA $7FC806,X
		LDA $07
		STA $7FC807,X
		DEX #8
		DEY
		BPL .loop_tilemap_high
		
		; do these separately because they actually use the upper 7 bits
		LDX #$001F
	.loop_mode7_bridge_a:
		LDA $704AA0,X
		STA $7FC8B0,X
		DEX
		BPL .loop_mode7_bridge_a
		
		LDX #$001F
	.loop_mode7_bridge_b:
		LDA $704AC0,X
		STA $7FCA60,X
		DEX
		BPL .loop_mode7_bridge_b
		
		PLB
		
		; load the stack pointer from $7F9C7B - $7F9C7C
		REP #$30
		LDA $7F9C7B
		TAX
		TXS
		
		; load the currently used music from $7F9C7D
		SEP #$20
		LDA $7F9C7D
		CMP $2142
		BEQ .same_music
		STA $2142
	.same_music:
		REP #$20
		
		; since we restored the stack, we need to update the return
		; address of this routine to what we want it to be. otherwise,
		; it would return to the save state routine.
		LDX #activate_load_state_done-1
		TXA
		STA $02,S
		
	.done:
		PLP
		RTS

; since we can't restore the hardware registers directly (they are non-readable),
; we have to use smw's hardware register mirrors to restore the actual registers.
; we do this manually because smw only restores mirrors to registers at certain
; points in the game, we want to do this immediately after a load state.
restore_hardware_regs:
		LDA $0DB0 ; mosaic mirror
		ORA #$03
		STA $2106 ; mosaic
		
		LDA $0D9D ; tm mirror
		STA $212C ; tm
		STA $212E ; tmw
		LDA $0D9E ; ts mirror
		STA $212D ; ts
		STA $212F ; tsw
		
		LDA #$23 ; sometimes #$59 ($008416)
		STA $2107 ; gb1sc
		LDA #$33
		STA $2108 ; gb2sc
		LDA #$53
		STA $2109 ; gb3sc
		LDA #$00 ; sometimes #$07 ($008416)
		STA $210B ; bg12nba
		LDA #$04
		STA $210C ; bg34nba
		RTS
		
vram_locations:
		dw $7800,$7000,$6800,$6000
		dw $1800,$1000,$0800,$0000

; restore all graphics files from $0101-$0108
restore_all_graphics:
		PHP
		PHB
		PHK
		PLB
		REP #$30
		LDX #$0007
		
	-	PHX
		TXA
		ASL A
		TAX
		LDY vram_locations,X
		PLX
		PHX
		SEP #$20
		LDA $7F9C7E,X
		CMP $0101,X
		BEQ +
		LDA $0101,X
		LDX #$1000
		JSL load_a_graphics
		
	+	PLX
		DEX
		BPL -	
		PLB
		PLP
		RTS

; thank you Kaizoman for the help for the following routines!
decompress_it:
		PHX
		PHY
		PHP
		CMP #$7F
		BCS +
		TAX
		SEP #$30
		LDA $00B992,X
		STA $8A
		LDA $00B9C4,X
		STA $8B
		LDA $00B9F6,X
		STA $8C
		
		PHK
		PER $0005
		PHB
		PHY
		JML $00BA47
	 
	+	PLP
		PLY
		PLX
		RTL

load_a_graphics:
		PHP
		PHA
		LDA #$7E
		STA $02
		REP #$20
		LDA #$AD00
		STA $00
		SEP #$20
		PLA
		PHA
		JSL decompress_it ; decompress to $7EAD00
		STY $2116
		SEP #$30
		PLA
		
		JSL upload_3bpp_to_vram

		PLP
		RTL

; restore all tilemaps from respective data
restore_all_tilemaps:
		PHP
		
		PHB
		LDA #$00
		PHA
		PLB
		JSL $05809E ; layer 1 & 2
		PLB
		
		REP #$10

		; clear layer 3 tilemap
		LDA #$FC
		STA $0F
		STZ $2115 ; vram increment
		LDX #$50A0
		STX $2116 ; vram address
		LDX #$000F
		STX $4302 ; dma0 destination address
		LDA #$7E
		STA $4304 ; dma0 destination bank
		LDX #$1EC0
		STX $4305 ; dma0 length
		LDX #$1809 ; $2118 vram data write
		STX $4300 ; dma0 parameters, source
		LDA #$01 ; channel 0
		STA $420B ; dma enable
		
		SEP #$30
		LDA $1931
		ASL A
		CLC
		ADC $1931
		STA $00
		JSL update_layer3_tilemap
		
		PLP
		RTS

; restore all palettes from respective data
restore_all_palettes:
		PHP
		REP #$10
		SEP #$20

		LDA #$00
		STA $2121 ; cgram address
		LDX #$0703
		STX $4302 ; dma0 destination address
		LDA #$7E
		STA $4304 ; dma0 destination bank
		LDX #$0200
		STX $4305 ; dma0 length
		STZ $4300 ; dma0 parameters
		LDA #$22 ; $2122 cgram data write
		STA $4301 ; dma0 source
		LDA #$01 ; channel 0
		STA $420B ; dma enable
		
		PLP
		RTS
		