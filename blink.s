PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
PCR = $600c
IFR = $600d
IER = $600e

kb_wptr = $0000
kb_rptr = $0001
kb_flags = $0002

RELEASE = %00000001
SHIFT   = %00000010

kb_buffer = $0200  ; 256-byte kb buffer 0200-02ff

E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs

  lda #$01
  sta PCR
  lda #$82
  sta IER
  cli

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%00000000 ; Set all pins on port A to input
  sta DDRA

  jsr lcd_init
  lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  lda #$00
  sta kb_flags
  sta kb_wptr
  sta kb_rptr

loop:
  sei
  lda kb_rptr
  cmp kb_wptr
  cli
  bne key_pressed
  jmp loop

key_pressed:
  ldx kb_rptr
  lda kb_buffer, x
  cmp #$0a           ; enter - go to second line
  beq enter_pressed
  cmp #$1b           ; escape - clear display
  beq esc_pressed

  jsr print_char

  inc kb_rptr
  jmp loop

enter_pressed:
  lda #%10101000 ; put cursor at position 40
  jsr lcd_instruction
  inc kb_rptr
  jmp loop

esc_pressed:
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  inc kb_rptr
  jmp loop

lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB       ; Read low nibble
  pla             ; Get high nibble off stack
  and #%00001000
  bne lcdbusy

  lda #RW
  sta PORTB
  lda #%11111111  ; LCD data is output
  sta DDRB
  pla
  rts

lcd_init:
  lda #%00000010 ; Set 4-bit mode
  sta PORTB
  ora #E
  sta PORTB
  and #%00001111
  sta PORTB
  rts

lcd_instruction:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta PORTB
  ora #E         ; Set E bit to send instruction
  sta PORTB
  eor #E         ; Clear E bit
  sta PORTB
  pla
  and #%00001111 ; Send low 4 bits
  sta PORTB
  ora #E         ; Set E bit to send instruction
  sta PORTB
  eor #E         ; Clear E bit
  sta PORTB
  rts

print_char:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta PORTB
  ora #E          ; Set E bit to send instruction
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  pla
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta PORTB
  ora #E          ; Set E bit to send instruction
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  rts


; IRQ vector points here
keyboard_interrupt:
  pha
  txa
  pha
  ;lda kb_flags
  lda #$21           ; Oon force le code ASCII du point d'exclamation '!'
  jsr print_char     ; On l'affiche DIRECTEMENT depuis l'interruption
  and #RELEASE   ; check if we're releasing a key
  beq read_key   ; otherwise, read the key

  lda kb_flags
  eor #RELEASE   ; flip the releasing bit
  sta kb_flags
  lda PORTA      ; read key value that's being released
  cmp #$12       ; left shift
  beq shift_up
  cmp #$59       ; right shift
  beq shift_up
  jmp exit

shift_up:
  lda kb_flags
  eor #SHIFT  ; flip the shift bit
  sta kb_flags
  jmp exit

read_key:
  lda PORTA
  cmp #$f0        ; if releasing a key
  beq key_release ; set the releasing bit
  cmp #$12        ; left shift
  beq shift_down
  cmp #$59        ; right shift
  beq shift_down

  tax
  lda kb_flags
  and #SHIFT
  bne shifted_key

  lda keymap, x   ; map to character code
  jmp push_key

shifted_key:
  lda keymap_shifted, x   ; map to character code

push_key:
  ldx kb_wptr
  sta kb_buffer, x
  inc kb_wptr
  jmp exit

shift_down:
  lda kb_flags
  ora #SHIFT
  sta kb_flags
  jmp exit

key_release:
  lda kb_flags
  ora #RELEASE
  sta kb_flags

exit:
  pla
  tax
  pla
  rti


nmi:
  rti

  .org $fd00
keymap:
  ; 00-0F : Touches spéciales / F-keys
  .byte "?????", $09, "`????????" ; 05=Tab
  ; 10-1F : A, Z, 1, 2, Q, W
  .byte "?????a&???wszqé?" ; 12=Shift, 15=a, 16=1/&, 1A=w, 1B=s, 1C=q, 1D=z, 1E=2/é
  ; 20-2F : C, X, D, E, 4, 3, V, F, T, R, 5
  .byte "?cxde\"'?? vftr(?" ; 21=c, 22=x, 23=d, 24=e, 25=4/", 26=3/', 29=Espace, 2A=v, 2B=f, 2C=t, 2D=r, 2E=5/(
  ; 30-3F : N, B, H, G, Y, 6, M, J, U, 7, 8
  .byte "?nbhgy-???,juè_?" ; 31=n, 32=b, 33=h, 34=g, 35=y, 36=6/-, 3A=m, 3B=j, 3C=u, 3D=7/è, 3E=8/_
  ; 40-4F : ;, K, I, O, 0, 9, ,, ., L, :, P, )
  .byte "?;kioçà??:/lp)?" ; 41=; (virgule), 42=k, 43=i, 44=o, 45=0/à, 46=9/ç, 49=:, 4A=!, 4B=l, 4C=m, 4D=p, 4E=)/°
  ; 50-5F : =, $, *, Entrée, ^, $
  .byte "??^*=", $0a, "$??$^??" ; 5A=Entrée ($0A)
  ; 60-6F : Backspace
  .byte "?????", $08, "?????" ; 66=Backspace ($08)
  ; 70-7F : Pavé numérique & Echap
  .byte "0.2568", $1b, "??+3-*9??" ; 76=Echap ($1B)
  ; 80-FF : Remplissage avec des '?' pour aligner la table sur 256 octets
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF

keymap_shifted:
  ; 00-0F
  .byte "?????", $09, "~????????"
  ; 10-1F : A, Z, 1, 2, Q, W
  .byte "?????A1???WSZQ2?"
  ; 20-2F : C, X, D, E, 4, 3, V, F, T, R, 5
  .byte "?CXDE34?? VFTR5?"
  ; 30-3F : N, B, H, G, Y, 6, M, J, U, 7, 8
  .byte "?NBHGY6???MJU78?"
  ; 40-4F : ., K, I, O, 0, 9, ?, /, L, %, P, °
  .byte "?.KIO09??./LP°?"
  ; 50-5F : +, £, µ, Entrée, ¨, £
  .byte "??+£µ", $0a, "£??¨£??"
  ; 60-6F : Backspace
  .byte "?????", $08, "?????"
  ; 70-7F : Pavé numérique & Echap
  .byte "0.2568", $1b, "??+3-*9??"
  ; 80-FF : Remplissage
  .byte "????????????????"
  .byte "????????????????"
  .byte "????????????????"
  .byte "????????????????"
  .byte "????????????????"
  .byte "????????????????"
  .byte "????????????????"
  .byte "????????????????"

; Reset/IRQ vectors
  .org $fffa
  .word nmi
  .word reset
  .word keyboard_interrupt
