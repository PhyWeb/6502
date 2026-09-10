PORTB       = $6000
DDRB        = $6002

; --- Adresses du 6551 ACIA ---
ACIA_DATA   = $5000
ACIA_STATUS = $5001
ACIA_CMD    = $5002
ACIA_CTRL   = $5003

; --- Control Bits LCD (Port B VIA) ---
E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs

  ; 1. Initialisation du VIA (Port B en sortie pour le LCD)
  lda #%11111111
  sta DDRB

  ; 2. Initialisation du LCD (Mode 4 bits)
  jsr lcd_init
  lda #%00101000     ; Mode 4-bit, 2 lignes, 5x8
  jsr lcd_instruction
  lda #%00001110     ; Écran ON, curseur ON
  jsr lcd_instruction
  lda #%00000001     ; Effacer l'écran
  jsr lcd_instruction

  ; 3. Affichage du bandeau de démarrage "RX:"
  lda #'R'
  jsr print_char
  lda #'X'
  jsr print_char
  lda #':'
  jsr print_char

  ; 4. Soft Reset & Initialisation du 6551 ACIA
  sta ACIA_STATUS    ; Écriture quelconque dans STATUS = Soft Reset 6551
  lda #$1F           ; 19200 bauds, 8 bits, 1 stop bit, horloge interne
  sta ACIA_CTRL
  lda #$0B           ; Pas de parité, pas d'écho, pas d'interruption
  sta ACIA_CMD

  ; Vider le buffer de réception initial
  lda ACIA_DATA

rx_loop:
  ; 5. Attente active de réception d'un octet (Bit 3 du STATUS = Receiver Full)
  lda ACIA_STATUS
  and #$08           ; Masque sur le bit 3 (1 = octet reçu)
  beq rx_loop        ; Tant que le bit 3 est à 0, on attend

  ; 6. Lecture de la donnée
  lda ACIA_DATA      ; Lire le caractère reçu

  ; 7. Repositionner le curseur juste après "RX:" (Adresse DDRAM $03)
  pha                ; Sauvegarder l'octet reçu
  lda #$83           ; Instruction $80 + offset $03
  jsr lcd_instruction
  pla                ; Restaurer l'octet reçu

  ; 8. Affichage en Hexadécimal (2 caractères)
  jsr print_hex

  jmp rx_loop        ; BOUCLE INFINIE : Attend le caractère suivant

; --- Routines d'affichage Hexadécimal ---

print_hex:
  pha                ; Sauvegarde la valeur
  lsr
  lsr
  lsr
  lsr                ; Nibble fort
  jsr print_nibble
  pla                ; Restaure la valeur
  and #$0F           ; Nibble faible
  jsr print_nibble
  rts

print_nibble:
  cmp #10
  bcc is_digit
  clc
  adc #6             ; Ajustement ASCII pour les lettres A-F
is_digit:
  clc
  adc #'0'
  jsr print_char
  rts

; --- Routines de contrôle de l'écran LCD ---

lcd_wait:
  pha
  lda #%11110000     ; Passer les pins de données en entrée
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB          ; Lecture du nibble fort (Busy Flag)
  pha
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB          ; Lecture du nibble faible
  pla
  and #%00001000     ; Masque sur le Busy Flag
  bne lcdbusy

  lda #RW
  sta PORTB
  lda #%11111111     ; Remettre le port B en sortie
  sta DDRB
  pla
  rts

lcd_init:
  lda #%00000010     ; Passage en mode 4-bit
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
  lsr                ; Nibble fort
  sta PORTB
  ora #E
  sta PORTB
  eor #E
  sta PORTB
  pla
  and #%00001111     ; Nibble faible
  sta PORTB
  ora #E
  sta PORTB
  eor #E
  sta PORTB
  rts

print_char:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr                ; Nibble fort
  ora #RS            ; Mode Donnée (RS = 1)
  sta PORTB
  ora #E
  sta PORTB
  eor #E
  sta PORTB
  pla
  and #%00001111     ; Nibble faible
  ora #RS            ; Mode Donnée (RS = 1)
  sta PORTB
  ora #E
  sta PORTB
  eor #E
  sta PORTB
  rts

nmi:
  rti

irq:
  rti

; --- Vecteurs d'interruption ---
  .org $fffa
  .word nmi
  .word reset
  .word irq