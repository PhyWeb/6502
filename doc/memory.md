# Documentation Technique - Carte Mémoire Unifiée & Gestion Cartouche

## 1. Vue d'Ensemble de l'Architecture
La gestion de la mémoire vive (SRAM), de la mémoire morte interne (BIOS + EHBasic) et le contrôle du port cartouche sont centralisés sur une seule **Carte Mémoire Unifiée**. 
Grâce à un découpage en blocs de **16 Ko**, l'architecture exploite **100 % de la capacité de la SRAM (512 Ko de base, extensible à 1 Mo sur la même carte)** et permet de piloter aussi bien des cartouches simples (sans composant logique) que des méga-cartouches paginées jusqu'à **4 Mo**.

## 2. Spécifications et Composants de la Carte
* **SRAM 512 Ko à 1 Mo (`AS6C4008-55`, DIP-32, 55 ns) :** 
  * 1 puce installée = **512 Ko** (32 banques de 16 Ko).
  * 2ème support DIP-32 prévu sur le PCB = extensible à **1 Mo** (64 banques de 16 Ko).
* **Flash / ROM Interne (`SST39SF040`, DIP-32, 55-70 ns) :** Puce Flash de 512 Ko dont on utilise une tranche de **32 Ko** (broches `A15-A18` reliées à `GND` ou à des cavaliers pour choisir entre plusieurs images ROM).
* **GAL Principal (`ATF22V10C`, DIP-24) :** Décodeur d'adresses central du système et générateur des signaux de contrôle mémoire et cartouche.
* **Registre MMU (`74HC273`, DIP-20) :** Bascule D 8-bits **avec broche Reset matériel (`/MR`, Pin 1)** reliée à la ligne `/RESET` (`c2`) du bus MECB.
* **Forçage Banque 0 (`2x 74HC08` ou `74HC157`) :** Force matériellement les lignes d'adresses hautes de la SRAM (`SA14` à `SA18`) à `0` lorsque le CPU accède à la RAM Fixe (`$0000-$3FFF`, où `A14 = 0`), et laisse passer les bits `BANK0-BANK4` du `74HC273` lorsque le CPU accède à la RAM Bankée (`$4000-$7FFF`, où `A14 = 1`).
* **Buffer Tri-State (`74HC125`) :** Permet au CPU de lire l'état du signal `/CART_DETECT` (`a26`) sur le bit `D7` lors d'une lecture en `$8000`.

## 3. Map Mémoire et Pagination (Alignement 16 Ko)

| Plage d'Adresses | Taille | Description et Routage Matériel |
| :--- | :--- | :--- |
| **`$0000 - $3FFF`** | **16 Ko** | **RAM Fixe (SRAM)** : Page Zéro, Pile, Variables OS/Basic. La logique de forçage (`A14=0`) maintient `SA14..SA18 = 00000` et le GAL force la sélection de la Puce SRAM #1 (**Banque 0 garantie**). |
| **`$4000 - $7FFF`** | **16 Ko** | **RAM Bankée (SRAM)** : Fenêtre dynamique (`A14=1`). Les bits `BANK0..BANK4` pilotent `SA14..SA18`, et le GAL utilise `BANK5` pour activer soit la SRAM #1 (Banques 0-31), soit la SRAM #2 (Banques 32-63). |
| **`$8000 - $80FF`** | **256 o.** | **Entrées / Sorties (I/O)** : Toute mémoire (SRAM, Flash, Cartouche) est désactivée.<br>• `$8000-$800F` : Écriture registre MMU (`74HC273`) / Lecture `/CART_DETECT` sur `D7`.<br>• `$8010-$801F` : Génère `/CART_IO` (`a27`) vers le port cartouche.<br>• `$8020-$80FF` : Libre pour les cartes filles (VIA #1, VIA #2, UART). |
| **`$8100 - $DFFF`** | **~23,75 Ko** | **Espace Applicatif Basculable** :<br>• Si `CART_EN = 0` (défaut au Reset) : Active la **ROM Interne** (EHBasic).<br>• Si `CART_EN = 1` : Désactive la ROM Interne et active **`/CART_CE` (`c26`)** vers le Port Cartouche. |
| **`$E000 - $FFFF`** | **8 Ko** | **ROM Fixe (BIOS)** : Active toujours la **ROM Interne** (Boot Menu, WozMon, Routines I/O, Vecteurs `$FFFA-$FFFF`). |

## 4. Organisation du Registre MMU (`74HC273` à l'adresse `$8000`)

Au démarrage ou lors d'un appui sur le bouton Reset, la ligne `/RESET` met instantanément les 8 bits du `74HC273` à **`00000000`**.

* **Bits `D0` à `D4` (`BANK0` à `BANK4`) :** Sélectionnent la banque de 16 Ko (0 à 31) au sein d'une puce SRAM de 512 Ko.
* **Bit `D5` (`BANK5`) :** Sélectionne la puce SRAM active dans la fenêtre `$4000-$7FFF` (`0` = SRAM #1 de 512 Ko, `1` = SRAM #2 pour atteindre 1 Mo).
* **Bit `D6` :** Réservé (extension future à 2 Mo).
* **Bit `D7` (`CART_EN`) :** 
  * `0` (Valeur garantie au Reset) = Plage `$8100-$DFFF` routée sur la ROM Interne (EHBasic).
  * `1` = Plage `$8100-$DFFF` routée sur le Port Cartouche via `/CART_CE`.

## 5. Séquence de Démarrage (Boot Menu)
Puisque le `74HC273` force `CART_EN = 0` dès la mise sous tension, le 6502 démarre **100 % du temps** sur le BIOS en `$E000`, même si une cartouche est insérée :
1. **Initialisation :** Setup de la pile, des VIA et de l'UART.
2. **Test Cartouche :** Le BIOS exécute `BIT $8000` (ou `LDA $8000`). Si le bit `D7` vaut `0` (tiré à `GND` par la cartouche), une cartouche est présente.
3. **Menu Utilisateur :**
   * **[1] Lancer EHBasic :** `JMP $8100` (exécute EHBasic en ROM interne).
   * **[2] Lancer la Cartouche :** Écrit `LDA #$80` puis `STA $8000` (`CART_EN = 1`, Banque RAM = 0), puis `JMP $8100` (ou `JMP ($DFFA)` selon l'en-tête de la cartouche).
   * **[3] Lancer WozMon :** Reste dans le moniteur système en `$E000+`.

## 6. Conception des Cartouches (Simples & Mappers jusqu'à 4 Mo)

Grâce aux signaux `/CART_CE` (`c26`) et `/CART_IO` (`a27`) pré-calculés par le GAL de la Carte Mémoire, la fabrication de cartouches est extrêmement simple :

* **Cartouche Standard ($\le 23,75\text{ Ko}$) :**
  * Ne contient **qu'une seule puce ROM/EEPROM** (ex: `AT28C256` ou `SST39SF010`).
  * Broches `/CE` et `/OE` de la ROM reliées directement à `/CART_CE` (`c26`).
  * Broche `/CART_DETECT` (`a26`) reliée à `GND`.
* **Méga-Cartouche Paginée (512 Ko à 4 Mo) :**
  * Embarque une grosse mémoire Flash (ou plusieurs) + un unique registre **`74HC273`** (Mapper).
  * L'entrée `CLK` du `74HC273` de la cartouche est reliée directement à la broche **`/CART_IO` (`a27`)** et son `/MR` au `/RESET`.
  * En écrivant un numéro de page (`0` à `255`) à l'adresse **`$8010`** (`STA $8010`), le programme de la cartouche commute instantanément jusqu'à **256 banques** !

## 7. Équations Logiques du GAL (`ATF22V10C` - WinCUPL)

Pour respecter les timings d'accès à **8 MHz** (où la phase haute de `CLK` ne dure que ~62 ns), les signaux `/CE` des puces SRAM et Flash sont calculés **uniquement à partir des adresses** (sans attendre `CLK`), tandis que `/OE` et `/WE` sont validés par `CLK` :

```cupl
/* Entrées : A15..A8, A4, CLK, RW, CART_EN, BANK5 */

/* Définition de la page I/O ($8000 - $80FF) */
IO_PAGE = A15 & !A14 & !A13 & !A12 & !A11 & !A10 & !A9 & !A8 ;

/* Sélection des 2 puces SRAM (512 Ko chacune = 1 Mo total) */
/* En RAM Fixe ($0000-$3FFF : !A15 & !A14), on force toujours la Puce SRAM 1 */
/* En RAM Bankée ($4000-$7FFF : !A15 & A14), BANK5 choisit entre SRAM 1 et SRAM 2 */
!RAM1_CE = (!A15 & !A14) # (!A15 & A14 & !BANK5) ;
!RAM2_CE = (!A15 & A14 & BANK5) ;

/* Sélection de la ROM Interne :
   Active sur $E000-$FFFF (A15 & A14 & A13)
   OU sur $8100-$DFFF (A15 & !IO_PAGE) quand CART_EN est à 0 */
!ROM_CE  = (A15 & A14 & A13) # (A15 & !IO_PAGE & !CART_EN) ;

/* Sélection de la ROM Cartouche ($8100 -$DFFF uniquement si CART_EN = 1) */
/* Intègre CLK et RW pour pouvoir piloter directement /CE et /OE de la cartouche */
!CART_CE = A15 & !(A14 & A13) & !IO_PAGE & CART_EN & CLK & RW ;

/* Signaux de lecture/écriture globaux pour la Carte Mémoire */
!MEM_OE  = CLK & RW ;
!MEM_WE  = CLK & !RW ;

/* Décodage des registres I/O ($8000-$800F pour MMU, $8010-$801F pour Cartouche) */
MMU_WE   = IO_PAGE & !A4 & CLK & !RW ;   /* Relié au CLK du 74HC273 local */
!MMU_RD  = IO_PAGE & !A4 & CLK & RW ;    /* Relié au /OE du 74HC125 (/CART_DETECT) */
!CART_IO = IO_PAGE &  A4 & CLK & !RW ;   /* Envoyé sur le Backplane (broche a27) */