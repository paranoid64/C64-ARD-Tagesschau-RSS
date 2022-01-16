!to "ard-tagesschau.prg",cbm

*=$0801
  !byte $0B, $08, $0A, $00, $9E, $32, $30, $36, $31, $00, $00, $00

*=$080d

    ; WiC init
    lda $dd02
    ora #$01
    sta $dd02
    lda #$02 ; $02 = ~ 1 sec.timeout
    sta $a

    ;disable key repeat 
    lda #127
    sta $028a 
    
    ;  disable keyboard buffer
    ;lda #1
    ;sta $0289      

    ; set to 25 line text mode and turn on the screen
    lda #$1B
    sta $D011

    ; disable SHIFT-Commodore
    lda #$80
    sta $0291
    
    ; set screen memory ($0400) and charset bitmap offset ($2000)
    lda #$18
    sta $D018

    lda #$06                ; White fore and background
    sta $d020
    sta $d021     
    lda #$00                ; Black text color

    sta $0286 
    jsr $e544               ; Clr screen

    ; draw screen
    lda #$00
    sta $fb
    sta $fd
    sta $f7

    lda #$28
    sta $fc

    lda #$04
    sta $fe

    lda #$e8
    sta $f9
    lda #$2b
    sta $fa

    lda #$d8
    sta $f8

    ldx #$00
    ldy #$00
    lda ($fb),y
    sta ($fd),y
    lda ($f9),y
    sta ($f7),y
    iny
    bne *-9

    inc $fc
    inc $fe
    inc $fa
    inc $f8

    inx
    cpx #$04
    bne *-24
    
    jsr IncPage ; page 2
    jsr IncPage ; page 3

    jmp mainloop
    
mainloop:
    jsr $ffe4       ; Keyboard input
    beq mainloop    ; wenn keine Taste gedrückt --> zurück zur Eingabe
    tax
    cmp #$30
    bcc do00    ; space oder anderer ascii <48
    beq do1x    ; "0" (ist auch schon in x)
    cmp #$40
    bcs chars
dox    ; "1"-"9"
    sta cmdx+$22    ; nr in commando schreiben
    lda #<cmdx
    ldy #>cmdx
    jmp exec
chars    ldx #"1"
    cmp #"Z"        ;Seite 11
    beq do1x
    inx
    cmp #"X"        ;Seite 12
    beq do1x
    inx
    cmp #"C"        ;Seite 13
    beq do1x
    inx
    cmp #"V"        ;Seite 14
    beq do1x
    inx
    cmp #"B"        ;Seite 15
    beq do1x
    cmp #"E"        ;Exit
    beq exit
    cmp #"I"        ;Info
    beq info
    cmp #"M"        ;MENÜ
    beq do00
    
    bne mainloop

info
    lda #147          ; Steuerzeichen für Bildschirm löschen
    jsr $ffd2         ; Löschen durchführen
    ldx #00           ; Zeile  0
    ldy #00           ; Spalte 0
    clc               ; Carry-Flag = 0 Cursorposition setzen, = 1 Cursorposition lesen
    jsr $fff0         ; Cursor setzen

    lda #<text
    sta $fe
    lda #>text
    sta $ff

    jsr printtext           ; Print info
    jmp mainloop

do00:   
        jsr IncPage
        lda #<cmd00
        ldy #>cmd00
        jmp exec
        
IncPage:
        lda page
        sec
        sbc #$30    ; In Binärwert umrechnen
        clc
        adc #1     ; Eine Seite dazuzählen
        and #3     ; Auf drei begrenzen
        bne Store
        clc       ; Durch das AND kann der Wert 0 sein, aber du willst 1-3 und nicht 0-3
        adc #1
Store:
        clc
        adc #$30  ; Wieder in Zahl umwandeln
        sta page
        rts 
        
do1x:    stx cmd1x+$23    ; endziffer in commando schreiben
        lda #<cmd1x
        ldy #>cmd1x
        jmp exec
exec:   sta $fe
        sty $ff
        jsr send_string
        jsr getanswer
        jmp mainloop 

exit:

     lda #128
     sta $028a; enable key repeat 


    lda #$ff  ; Datenrichtung Port B Ausgang
    sta $dd03

    lda $dd00
    ora #$04                ; PA2 auf HIGH = ESP im Empfangsmodus
    sta $dd00
    
    lda #$0d
    jsr $ffd2
    jsr $ffd2
    
    lda #$00
    
    ;Wic64 Portal?
    lda $C00F
    cmp #$4c                ;$C00F auf jeden Fall $4c.
    beq wic64portal
    rts

wic64portal:    
    jmp $C00F               ;Zurück ins Win4 Portal

send_string:
    lda $dd02
    ora #$04
    sta $dd02               ; Datenrichtung Port A PA2 auf Ausgang
    lda #$ff                ; Datenrichtung Port B Ausgang
    sta $dd03
    lda $dd00
    ora #$04                ; PA2 auf HIGH = ESP im Empfangsmodus
    sta $dd00

    ldy #$01
    lda ($fe),y             ; Länge des Kommandos holen
    sec
    sbc #$01
    sta stringexit+1 ; Als Exit speichern
    
    ldy #$ff
string_next:
    iny
    lda ($fe),y
    jsr write_byte
stringexit:
    cpy #$00                ; Selbstmodifizierender Code - Hier wird die länge des Kommandos eingetragen -> Siehe Ende von send_string
    bne string_next
    rts
    
getanswer:
    lda #$00                ; Datenrichtung Port B Eingang
    sta $dd03
    lda $dd00
    and #251                ; PA2 auf LOW = ESP im Sendemodus
    sta $dd00 
    
    jsr read_byte           ;; Dummy Byte - IRQ anschieben

    jsr read_byte
    sta $1000
    tay

    jsr read_byte
    sta $1001
    tax
    
errorcheck:                 ; Answer 2 Byte = No data available
    cpy #$00
    bne goread
    cpx #$00          
    beq empty               ; Answer 2 Byte 00 00 = No data available
    cpx #$02                ; z.b. "!E" = Error
    bne goread
  
empty:
    rts
goread:
    jsr read_byte
    jsr $ffd2
    dex
    bne goread
    dey
    cpy #$ff
    bne goread
    rts
    
write_byte:
    sta $dd01             ; Bit 0..7: Userport Daten PB 0-7 schreiben

dowrite:
    lda $dd0d
    nop
    nop
    nop
    nop
    and #$10              ; Warten auf NMI FLAG2 = Byte wurde gelesen vom ESP
    beq dowrite
    rts
    
read_byte:
    ;jsr delay
  
doread:
    lda $dd0d
    nop
    nop
    nop
    nop
    and #$10              ; Warten auf NMI FLAG2 = Byte wurde gelesen vom ESP
    beq doread
    
    lda $dd01 
    sta $02
    rts

printtext:
    ldy #$00   
printloop:
    lda ($fe),y
    cmp #$00
    beq printdone
    jsr $ffd2
    ;jsr delay
    iny
    bne printloop
    inc $ff
    jmp printtext
printdone:
    rts

;delay:
;    lda #0
;    sta 162
;    jmp wait
;wait:                 
;    lda 162
;    cmp #1   ; hier einstellen
;    bne wait
;    rts

cmd00   !text "W",$23,$00,$01,"http://c64.lama-creation.de/m/" ; Start!byte W + len low!byte 26 + len high!byte 00 (0026) + command $01 httpget www...
page    !byte $31
        !byte $00
     
cmdx    !text "W",$23,$00,$01,"http://c64.lama-creation.de/d/x"
        !byte $00 
cmd1x   !text "W",$24,$00,$01,"http://c64.lama-creation.de/d/1x"
        !byte $00                
              
text:         !text $9E,$12,"ARD TAGESCHAU 1.5.1  ",$92,$0d 
              !text $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$0d 
              !text $0d
              !text $9f,"ASM  : C64 STUDIO 7.0",$0d
              !text "DEV  : PARANOID64 - FORUM64.DE",$0d
              !text "THEME: SNOOPY - FORUM64.DE",$0d
              !text $0d
              !text "VIELEN DANK AN YPS, SPARHAWK UND M. J.!",$0d
              !text $0d
              !text "# WE ",$D3," COMMODORE",$0d
              !text $0d
              !text $99,$12,"M",$9F,$92,"=MENU ",$99,$12,"E",$9F,$92,"=EXIT",$0d
              !byte $00

; Character bitmap definitions 2k
*=$2000
  !byte $1C, $22, $4A, $56, $44, $20, $1E, $00
  !byte $18, $24, $42, $7E, $42, $42, $42, $00
  !byte $7C, $22, $22, $3C, $22, $22, $7C, $00
  !byte $1C, $22, $40, $40, $40, $22, $1C, $00
  !byte $78, $24, $22, $22, $22, $24, $78, $00
  !byte $7E, $40, $40, $78, $40, $40, $7E, $00
  !byte $7E, $40, $40, $78, $40, $40, $40, $00
  !byte $1C, $22, $40, $4E, $42, $22, $1C, $00
  !byte $42, $42, $42, $7E, $42, $42, $42, $00
  !byte $1C, $08, $08, $08, $08, $08, $1C, $00
  !byte $0E, $04, $04, $04, $04, $44, $38, $00
  !byte $42, $44, $48, $70, $48, $44, $42, $00
  !byte $40, $40, $40, $40, $40, $40, $7E, $00
  !byte $42, $66, $5A, $5A, $42, $42, $42, $00
  !byte $42, $62, $52, $4A, $46, $42, $42, $00
  !byte $18, $24, $42, $42, $42, $24, $18, $00
  !byte $7C, $42, $42, $7C, $40, $40, $40, $00
  !byte $18, $24, $42, $42, $4A, $24, $1A, $00
  !byte $7C, $42, $42, $7C, $48, $44, $42, $00
  !byte $3C, $42, $40, $3C, $02, $42, $3C, $00
  !byte $3E, $08, $08, $08, $08, $08, $08, $00
  !byte $42, $42, $42, $42, $42, $42, $3C, $00
  !byte $42, $42, $42, $24, $24, $18, $18, $00
  !byte $42, $42, $42, $5A, $5A, $66, $42, $00
  !byte $42, $42, $24, $18, $24, $42, $42, $00
  !byte $22, $22, $22, $1C, $08, $08, $08, $00
  !byte $7E, $02, $04, $18, $20, $40, $7E, $00
  !byte $3C, $20, $20, $20, $20, $20, $3C, $00
  !byte $00, $40, $20, $10, $08, $04, $02, $00
  !byte $3C, $04, $04, $04, $04, $04, $3C, $00
  !byte $00, $08, $1C, $2A, $08, $08, $08, $08
  !byte $00, $00, $10, $20, $7F, $20, $10, $00
  !byte $00, $00, $00, $00, $00, $00, $00, $00
  !byte $08, $08, $08, $08, $00, $00, $08, $00
  !byte $24, $24, $24, $00, $00, $00, $00, $00
  !byte $24, $24, $7E, $24, $7E, $24, $24, $00
  !byte $08, $1E, $28, $1C, $0A, $3C, $08, $00
  !byte $00, $62, $64, $08, $10, $26, $46, $00
  !byte $30, $48, $48, $30, $4A, $44, $3A, $00
  !byte $04, $08, $10, $00, $00, $00, $00, $00
  !byte $04, $08, $10, $10, $10, $08, $04, $00
  !byte $20, $10, $08, $08, $08, $10, $20, $00
  !byte $08, $2A, $1C, $3E, $1C, $2A, $08, $00
  !byte $00, $08, $08, $3E, $08, $08, $00, $00
  !byte $00, $00, $00, $00, $00, $08, $08, $10
  !byte $00, $00, $00, $7E, $00, $00, $00, $00
  !byte $00, $00, $00, $00, $00, $18, $18, $00
  !byte $00, $02, $04, $08, $10, $20, $40, $00
  !byte $3C, $42, $46, $5A, $62, $42, $3C, $00
  !byte $08, $18, $28, $08, $08, $08, $3E, $00
  !byte $3C, $42, $02, $0C, $30, $40, $7E, $00
  !byte $3C, $42, $02, $1C, $02, $42, $3C, $00
  !byte $04, $0C, $14, $24, $7E, $04, $04, $00
  !byte $7E, $40, $78, $04, $02, $44, $38, $00
  !byte $1C, $20, $40, $7C, $42, $42, $3C, $00
  !byte $7E, $42, $04, $08, $10, $10, $10, $00
  !byte $3C, $42, $42, $3C, $42, $42, $3C, $00
  !byte $3C, $42, $42, $3E, $02, $04, $38, $00
  !byte $00, $00, $08, $00, $00, $08, $00, $00
  !byte $00, $00, $08, $00, $00, $08, $08, $10
  !byte $0E, $18, $30, $60, $30, $18, $0E, $00
  !byte $00, $00, $7E, $00, $7E, $00, $00, $00
  !byte $70, $18, $0C, $06, $0C, $18, $70, $00
  !byte $3C, $42, $02, $0C, $10, $00, $10, $00
  !byte $00, $00, $00, $00, $FF, $00, $00, $00
  !byte $08, $1C, $3E, $7F, $7F, $1C, $3E, $00
  !byte $10, $10, $10, $10, $10, $10, $10, $10
  !byte $00, $00, $00, $FF, $00, $00, $00, $00
  !byte $00, $00, $FF, $00, $00, $00, $00, $00
  !byte $00, $FF, $00, $00, $00, $00, $00, $00
  !byte $00, $00, $00, $00, $00, $FF, $00, $00
  !byte $20, $20, $20, $20, $20, $20, $20, $20
  !byte $04, $04, $04, $04, $04, $04, $04, $04
  !byte $00, $00, $00, $00, $E0, $10, $08, $08
  !byte $08, $08, $08, $04, $03, $00, $00, $00
  !byte $08, $08, $08, $10, $E0, $00, $00, $00
  !byte $80, $80, $80, $80, $80, $80, $80, $FF
  !byte $80, $40, $20, $10, $08, $04, $02, $01
  !byte $01, $02, $04, $08, $10, $20, $40, $80
  !byte $FF, $80, $80, $80, $80, $80, $80, $80
  !byte $FF, $01, $01, $01, $01, $01, $01, $01
  !byte $00, $3C, $7E, $7E, $7E, $7E, $3C, $00
  !byte $00, $00, $00, $00, $00, $00, $FF, $00
  !byte $36, $7F, $7F, $7F, $3E, $1C, $08, $00
  !byte $40, $40, $40, $40, $40, $40, $40, $40
  !byte $00, $00, $00, $00, $03, $04, $08, $08
  !byte $81, $42, $24, $18, $18, $24, $42, $81
  !byte $00, $3C, $42, $42, $42, $42, $3C, $00
  !byte $08, $1C, $2A, $77, $2A, $08, $08, $00
  !byte $02, $02, $02, $02, $02, $02, $02, $02
  !byte $08, $1C, $3E, $7F, $3E, $1C, $08, $00
  !byte $08, $08, $08, $08, $FF, $08, $08, $08
  !byte $A0, $50, $A0, $50, $A0, $50, $A0, $50
  !byte $08, $08, $08, $08, $08, $08, $08, $08
  !byte $00, $00, $01, $3E, $54, $14, $14, $00
  !byte $FF, $7F, $3F, $1F, $0F, $07, $03, $01
  !byte $00, $00, $00, $00, $00, $00, $00, $00
  !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0
  !byte $00, $00, $00, $00, $FF, $FF, $FF, $FF
  !byte $FF, $00, $00, $00, $00, $00, $00, $00
  !byte $00, $00, $00, $00, $00, $00, $00, $FF
  !byte $80, $80, $80, $80, $80, $80, $80, $80
  !byte $AA, $55, $AA, $55, $AA, $55, $AA, $55
  !byte $01, $01, $01, $01, $01, $01, $01, $01
  !byte $00, $00, $00, $00, $AA, $55, $AA, $55
  !byte $FF, $FE, $FC, $F8, $F0, $E0, $C0, $80
  !byte $03, $03, $03, $03, $03, $03, $03, $03
  !byte $08, $08, $08, $08, $0F, $08, $08, $08
  !byte $00, $00, $00, $00, $0F, $0F, $0F, $0F
  !byte $08, $08, $08, $08, $0F, $00, $00, $00
  !byte $00, $00, $00, $00, $F8, $08, $08, $08
  !byte $00, $00, $00, $00, $00, $00, $FF, $FF
  !byte $00, $00, $00, $00, $0F, $08, $08, $08
  !byte $08, $08, $08, $08, $FF, $00, $00, $00
  !byte $00, $00, $00, $00, $FF, $08, $08, $08
  !byte $08, $08, $08, $08, $F8, $08, $08, $08
  !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
  !byte $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
  !byte $07, $07, $07, $07, $07, $07, $07, $07
  !byte $FF, $FF, $00, $00, $00, $00, $00, $00
  !byte $FF, $FF, $FF, $00, $00, $00, $00, $00
  !byte $00, $00, $00, $00, $00, $FF, $FF, $FF
  !byte $01, $01, $01, $01, $01, $01, $01, $FF
  !byte $00, $00, $00, $00, $F0, $F0, $F0, $F0
  !byte $0F, $0F, $0F, $0F, $00, $00, $00, $00
  !byte $08, $08, $08, $08, $F8, $00, $00, $00
  !byte $F0, $F0, $F0, $F0, $00, $00, $00, $00
  !byte $F0, $F0, $F0, $F0, $0F, $0F, $0F, $0F
  !byte $E3, $DD, $B5, $A9, $B3, $DF, $E1, $FF
  !byte $E7, $DB, $BD, $81, $BD, $BD, $BD, $FF
  !byte $83, $DD, $DD, $C3, $DD, $DD, $83, $FF
  !byte $E3, $DD, $BF, $BF, $BF, $DD, $E3, $FF
  !byte $87, $DB, $DD, $DD, $DD, $DB, $87, $FF
  !byte $81, $BF, $BF, $87, $BF, $BF, $81, $FF
  !byte $81, $BF, $BF, $87, $BF, $BF, $BF, $FF
  !byte $E3, $DD, $BF, $B1, $BD, $DD, $E3, $FF
  !byte $BD, $BD, $BD, $81, $BD, $BD, $BD, $FF
  !byte $E3, $F7, $F7, $F7, $F7, $F7, $E3, $FF
  !byte $F1, $FB, $FB, $FB, $FB, $BB, $C7, $FF
  !byte $BD, $BB, $B7, $8F, $B7, $BB, $BD, $FF
  !byte $BF, $BF, $BF, $BF, $BF, $BF, $81, $FF
  !byte $BD, $99, $A5, $A5, $BD, $BD, $BD, $FF
  !byte $BD, $9D, $AD, $B5, $B9, $BD, $BD, $FF
  !byte $E7, $DB, $BD, $BD, $BD, $DB, $E7, $FF
  !byte $83, $BD, $BD, $83, $BF, $BF, $BF, $FF
  !byte $E7, $DB, $BD, $BD, $B5, $DB, $E5, $FF
  !byte $83, $BD, $BD, $83, $B7, $BB, $BD, $FF
  !byte $C3, $BD, $BF, $C3, $FD, $BD, $C3, $FF
  !byte $C1, $F7, $F7, $F7, $F7, $F7, $F7, $FF
  !byte $BD, $BD, $BD, $BD, $BD, $BD, $C3, $FF
  !byte $BD, $BD, $BD, $DB, $DB, $E7, $E7, $FF
  !byte $BD, $BD, $BD, $A5, $A5, $99, $BD, $FF
  !byte $BD, $BD, $DB, $E7, $DB, $BD, $BD, $FF
  !byte $DD, $DD, $DD, $E3, $F7, $F7, $F7, $FF
  !byte $81, $FD, $FB, $E7, $DF, $BF, $81, $FF
  !byte $C3, $DF, $DF, $DF, $DF, $DF, $C3, $FF
  !byte $FF, $BF, $DF, $EF, $F7, $FB, $FD, $FF
  !byte $C3, $FB, $FB, $FB, $FB, $FB, $C3, $FF
  !byte $FF, $F7, $E3, $D5, $F7, $F7, $F7, $F7
  !byte $FF, $FF, $EF, $DF, $80, $DF, $EF, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
  !byte $F7, $F7, $F7, $F7, $FF, $FF, $F7, $FF
  !byte $DB, $DB, $DB, $FF, $FF, $FF, $FF, $FF
  !byte $DB, $DB, $81, $DB, $81, $DB, $DB, $FF
  !byte $F7, $E1, $D7, $E3, $F5, $C3, $F7, $FF
  !byte $FF, $9D, $9B, $F7, $EF, $D9, $B9, $FF
  !byte $CF, $B7, $B7, $CF, $B5, $BB, $C5, $FF
  !byte $FB, $F7, $EF, $FF, $FF, $FF, $FF, $FF
  !byte $FB, $F7, $EF, $EF, $EF, $F7, $FB, $FF
  !byte $DF, $EF, $F7, $F7, $F7, $EF, $DF, $FF
  !byte $F7, $D5, $E3, $C1, $E3, $D5, $F7, $FF
  !byte $FF, $F7, $F7, $C1, $F7, $F7, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $F7, $F7, $EF
  !byte $FF, $FF, $FF, $81, $FF, $FF, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $E7, $E7, $FF
  !byte $FF, $FD, $FB, $F7, $EF, $DF, $BF, $FF
  !byte $C3, $BD, $B9, $A5, $9D, $BD, $C3, $FF
  !byte $F7, $E7, $D7, $F7, $F7, $F7, $C1, $FF
  !byte $C3, $BD, $FD, $F3, $CF, $BF, $81, $FF
  !byte $C3, $BD, $FD, $E3, $FD, $BD, $C3, $FF
  !byte $FB, $F3, $EB, $DB, $81, $FB, $FB, $FF
  !byte $81, $BF, $87, $FB, $FD, $BB, $C7, $FF
  !byte $E3, $DF, $BF, $83, $BD, $BD, $C3, $FF
  !byte $81, $BD, $FB, $F7, $EF, $EF, $EF, $FF
  !byte $C3, $BD, $BD, $C3, $BD, $BD, $C3, $FF
  !byte $C3, $BD, $BD, $C1, $FD, $FB, $C7, $FF
  !byte $FF, $FF, $F7, $FF, $FF, $F7, $FF, $FF
  !byte $FF, $FF, $F7, $FF, $FF, $F7, $F7, $EF
  !byte $F1, $E7, $CF, $9F, $CF, $E7, $F1, $FF
  !byte $FF, $FF, $81, $FF, $81, $FF, $FF, $FF
  !byte $8F, $E7, $F3, $F9, $F3, $E7, $8F, $FF
  !byte $C3, $BD, $FD, $F3, $EF, $FF, $EF, $FF
  !byte $FF, $FF, $FF, $FF, $00, $FF, $FF, $FF
  !byte $F7, $E3, $C1, $80, $80, $E3, $C1, $FF
  !byte $EF, $EF, $EF, $EF, $EF, $EF, $EF, $EF
  !byte $FF, $FF, $FF, $00, $FF, $FF, $FF, $FF
  !byte $FF, $FF, $00, $FF, $FF, $FF, $FF, $FF
  !byte $FF, $00, $FF, $FF, $FF, $FF, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $00, $FF, $FF
  !byte $DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF
  !byte $FB, $FB, $FB, $FB, $FB, $FB, $FB, $FB
  !byte $FF, $FF, $FF, $FF, $1F, $EF, $F7, $F7
  !byte $F7, $F7, $F7, $FB, $FC, $FF, $FF, $FF
  !byte $F7, $F7, $F7, $EF, $1F, $FF, $FF, $FF
  !byte $7F, $7F, $7F, $7F, $7F, $7F, $7F, $00
  !byte $7F, $BF, $DF, $EF, $F7, $FB, $FD, $FE
  !byte $FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F
  !byte $00, $7F, $7F, $7F, $7F, $7F, $7F, $7F
  !byte $00, $FE, $FE, $FE, $FE, $FE, $FE, $FE
  !byte $FF, $C3, $81, $81, $81, $81, $C3, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $FF, $00, $FF
  !byte $C9, $80, $80, $80, $C1, $E3, $F7, $FF
  !byte $BF, $BF, $BF, $BF, $BF, $BF, $BF, $BF
  !byte $FF, $FF, $FF, $FF, $FC, $FB, $F7, $F7
  !byte $7E, $BD, $DB, $E7, $E7, $DB, $BD, $7E
  !byte $FF, $C3, $BD, $BD, $BD, $BD, $C3, $FF
  !byte $F7, $E3, $D5, $88, $D5, $F7, $F7, $FF
  !byte $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD
  !byte $F7, $E3, $C1, $80, $C1, $E3, $F7, $FF
  !byte $F7, $F7, $F7, $F7, $00, $F7, $F7, $F7
  !byte $5F, $AF, $5F, $AF, $5F, $AF, $5F, $AF
  !byte $F7, $F7, $F7, $F7, $F7, $F7, $F7, $F7
  !byte $FF, $FF, $FE, $C1, $AB, $EB, $EB, $FF
  !byte $00, $80, $C0, $E0, $F0, $F8, $FC, $FE
  !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
  !byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
  !byte $FF, $FF, $FF, $FF, $00, $00, $00, $00
  !byte $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00
  !byte $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F
  !byte $55, $AA, $55, $AA, $55, $AA, $55, $AA
  !byte $FE, $FE, $FE, $FE, $FE, $FE, $FE, $FE
  !byte $FF, $FF, $FF, $FF, $55, $AA, $55, $AA
  !byte $00, $01, $03, $07, $0F, $1F, $3F, $7F
  !byte $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC
  !byte $F7, $F7, $F7, $F7, $F0, $F7, $F7, $F7
  !byte $FF, $FF, $FF, $FF, $F0, $F0, $F0, $F0
  !byte $F7, $F7, $F7, $F7, $F0, $FF, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $07, $F7, $F7, $F7
  !byte $FF, $FF, $FF, $FF, $FF, $FF, $00, $00
  !byte $FF, $FF, $FF, $FF, $F0, $F7, $F7, $F7
  !byte $F7, $F7, $F7, $F7, $00, $FF, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $00, $F7, $F7, $F7
  !byte $F7, $F7, $F7, $F7, $07, $F7, $F7, $F7
  !byte $3F, $3F, $3F, $3F, $3F, $3F, $3F, $3F
  !byte $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F
  !byte $F8, $F8, $F8, $F8, $F8, $F8, $F8, $F8
  !byte $00, $00, $FF, $FF, $FF, $FF, $FF, $FF
  !byte $00, $00, $00, $FF, $FF, $FF, $FF, $FF
  !byte $FF, $FF, $FF, $FF, $FF, $00, $00, $00
  !byte $0C, $18, $24, $42, $7E, $42, $42, $00
  !byte $24, $24, $24, $00, $00, $00, $00, $00
  !byte $1C, $22, $22, $3C, $22, $22, $2C, $20
  !byte $42, $18, $24, $42, $7E, $42, $42, $00
  !byte $42, $18, $24, $42, $42, $24, $18, $00
  !byte $44, $00, $44, $44, $44, $44, $38, $00

; screen character data
*=$2800
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $E9, $A0, $DF, $20, $A0, $A0, $DF, $20, $A0, $A0, $DF, $20, $20, $20, $64, $6F, $79, $62, $F8, $F7, $E3, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $20, $20, $20, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $A0, $A0, $A0, $20, $A0, $A0, $20, $20, $A0, $20, $A0, $20, $20, $20, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $20, $A0, $A0, $69, $20, $20, $20, $E4, $EF, $F9, $A0, $A0, $A0, $A0, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $A0, $A0, $A0, $A0, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $94, $81, $87, $85, $93, $93, $83, $88, $81, $95, $AE, $84, $85, $20, $20, $20, $20, $A0, $A0, $A0, $A0, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $A0, $A0, $A0, $A0, $A0, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $E4, $EF, $F9, $E2, $78, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $13, $10, $01, $03, $05, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
  !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

; screen color data
*=$2be8
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E
  !byte $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E, $0E