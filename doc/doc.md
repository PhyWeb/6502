# Spécifications Techniques : Ordinateur Rétro 6502 Modulaire

## 1. Vue d'Ensemble & Philosophie du Projet
- **Processeur principal :** WDC 65C02S.
- **Architecture :** Bus modulaire fond de panier (Backplane) basé sur le standard **MECB** (Minimalist Europe Card Bus).
- **Horloge :** 8 MHz de base, avec circuit diviseur et mode pas-à-pas embarqués sur la carte CPU.
- **Philosophie :** 
  - **Flexibilité totale :** Fond de panier 100% passif (Broches réservées routées pour évolutions futures, ex: bus 24-bits).
  - **Décodage distribué :** Chaque module embarque sa propre puce logique (ATF16V8B) pour déterminer quand il doit interagir avec le bus, réduisant l'espace I/O nécessaire.
  - **Autonomie des cartes :** Les fonctions critiques (contrôle de flux série, carte SD) sont gérées localement sur chaque carte pour éviter la dépendance au fond de panier.
  - **Gestion de la mémoire (MMU) :** Système de banques (512 Ko RAM / 512 Ko ROM).
  - **Chargement hybride :** Via port Série (Moniteur), via Lecteur Virtuel (SD) ou via Cartouches physiques.

---

## 2. Architecture du Bus Modulaire (Backplane : MECB)
Le système repose sur un bus passif utilisant des connecteurs industriels robustes **DIN 41612 (64 broches, Rangées a et c)**. 
*(Aucun signal de sélection de puce /CS ne circule sur le bus d'adresses général, chaque carte gère son propre décodage).*

**Signaux principaux :**
- Alimentation (`5V`, `GND`).
- Bus d'Adresses (`A0-A19` standards, `A20-A23` sur broches réservées) et Bus de Données (`D0-D7`).
- Signaux de Contrôle : `CLK` (Généré par la broche `PHI2O` sortante du CPU), `/WR`, `/RD`, `/IORQ`, `/MREQ`, `/RESET`, `/INT`, `/NMI`.

---

## 3. Map Mémoire (Memory Map)
L'espace Entrées/Sorties est drastiquement réduit à 256 octets grâce au décodage complet (`A8` à `A15`) effectué par les GAL locaux.

| Plage d'Adresses | Taille | Description | Allocation |
| :--- | :--- | :--- | :--- |
| `$0000 - $1FFF` | 8 Ko | **RAM Fixe** | Page Zéro, Pile (`$01`), Variables Système. Forcé sur la Banque 0 de la SRAM. |
| `$2000 - $7FFF` | 24 Ko | **RAM Bankée** | Fenêtre pointant sur l'une des 32 banques (de 24 Ko) de la SRAM. |
| `$8000 - $80FF` | 256 octets | **Entrées / Sorties (I/O)**| Périphériques : VIA #1 (Joueurs), UART + VIA #2 (Série/SD), Registres MMU. |
| `$8100 - $DFFF` | ~23,75 Ko | **Cartouche / ROM Bankée** | Espace applicatif. Exécute la Cartouche si insérée, sinon pointe sur la Flash interne. |
| `$E000 - $FFFF` | 8 Ko | **ROM Fixe (BIOS)** | Moniteur série, Bootloader, et Vecteurs d'interruption (`$FFFA-$FFFF`). |

---

## 4. Description des Modules Principaux

### A. Carte CPU (6502 Core Card)
- **Ports Externes :** Aucun (Interne uniquement).
- **Interface Utilisateur :** Cavaliers (Jumpers) pour la sélection de fréquence, et pins pour relier une horloge externe (pas à pas notamment), pins pour relier le bouton reset.
- **Composants :** W65C02S, Oscillateur 8 MHz, Diviseur binaire (`74HC393`), Inverseur (`74HC14`), Superviseur de Reset (DS1813).
- **Horloge :** L'oscillateur 8 MHz entre dans `PHI2` (Pin 37). Le processeur conditionne le signal et le ressort sur `PHI2O` (Pin 39). C'est ce signal `PHI2O` (nommé `CLK` sur le bus MECB) qui cadence tout le système.

### B. Carte Mémoire RAM & MMU
- **Ports Externes :** Aucun.
- **Composants :** AS6C4008-55 (512 Ko SRAM), ATF16V8B, `74HC574` (Registre de banque).
- **Rôle :** Le GAL gère l'activation de la SRAM et le forçage matériel des 8 premiers Ko (`$0000-$1FFF`) sur la Banque 0.

### C. Carte E/S (Joueurs : Clavier, Souris & Manettes NES)
- **Ports Externes (Façade) :** 1x PS/2 (Clavier), 1x PS/2 (Souris), 2x Connecteurs Manettes NES.
- **Composants :** WDC 65C22 (VIA #1), ATF16V8B, `74HC595` (Registre à décalage), `74HC14` (Schmitt Trigger).
- **Allocation du VIA (16 GPIO) :**
  - *Port A (8 broches) :* Lecture de l'octet du **Clavier PS/2** via le `74HC595` (Méthode RC de Ben Eater, 0% de charge CPU).
  - *Port B (Broches 0-3) :* **2x Manettes NES** (`LATCH` et `CLOCK` partagés, `DATA_1`, `DATA_2`).
  - *Port B (Broches 4-5) :* **Souris PS/2** (`CLOCK` et `DATA` branchés en direct).
- **Gestion Souris (Bit-Banging) :** La souris nécessitant une communication bidirectionnelle, elle est gérée en *bit-banging* par le 6502 (~11% de charge CPU uniquement durant le mouvement).

### D. Carte Communication Série & Lecteur Virtuel SD
- **Ports Externes (Façade) :** 1x Port USB/Série (FTDI) OU DB9 (RS232), 1x Lecteur MicroSD (SPI).
- **Composants :** WDC 65C51 (UART), WDC 65C22 (VIA #2 dédié), FTDI (USB), Module Carte SD, Oscillateur 1.8432 MHz, ATF16V8B.
- **Autonomie :** Le VIA #2 est présent sur la même carte que l'UART pour gérer le `RTS`/`CTS` localement. Les broches restantes pilotent la carte MicroSD en SPI (bit-banging) pour servir de "lecteur de disquettes" virtuel.

### E. Carte ROM / Port Cartouche
- **Ports Externes (Haut du boîtier) :** 1x Connecteur Edge (Type ISA ou Cartouche standard).
- **Composants :** 39SF040-55 (512 Ko Flash), Connecteur Edge, ATF16V8B, `74HC574` (Registre de banque ROM).
- **Fonctionnement :** L'insertion d'une cartouche désactive la broche `/CE` de la Flash interne via une détection matérielle, donnant la priorité au bus externe sur la plage `$8100-$DFFF`.

---

## 5. Logiciel & Firmware (Software Stack)
- **BIOS / Bootloader (ROM Fixe 8 Ko) :** 
  - Détection de signature de cartouche (`$8100-$8101`). Si présente -> `JMP $8102`.
  - Contournement logiciel du bug WDC 65C51 (transmission) via boucle d'attente (délai).
  - Menu série de démarrage et exécution de **WozMon**.
  - Routines de bit-banging pour la lecture de la carte SD (SPI) et de la souris PS/2.
- **Environnement de Travail (ROM Bankée - Banque 1) :**
  - **EHBasic** prêt à l'emploi.

---

## 6. Conception du Fond de Panier (Backplane PCB Design)
- **Topologie des Slots :** 8 ports DIN 41612 (Type C, rangées a et c). 7 ports verticaux pour les cartes de base, et 1 port horizontal (coudé à 90°) pour faciliter le débogage (analyseur logique) ou servir de futur port d'extension.
- **Alimentation Intégrée :** Le circuit d'alimentation est directement sur le backplane : connecteur Barrel Jack (5V), interrupteur (prévoire possibilité de passer par un bouton externe), diode de protection(attention : chute de tension, privilegier un mosfet canal P ?), gros condensateurs de filtrage (ex: 1000µF) en entrée, et condensateurs céramiques de découplage (100nF) au plus près de chaque port DIN.
- **Intégrité du signal (Haute Fréquence - 8 MHz) :**
  - **Routage PCB 4 Couches :** Utilisation stricte de plans internes continus pour la Masse (Couche 2 : GND) et l'Alimentation (Couche 3 : 5V) pour bloquer les interférences.
  - **Isolation :** La piste d'horloge (`PHI2O` / `CLK`) est entourée de plans de masse.
  - **Terminaisons :** Empreintes prévues aux extrémités du bus pour l'ajout éventuel de réseaux de résistances de tirage (Pull-up 3.3kΩ) afin d'absorber les rebonds de signaux.

- **Notes :**
  - Prévoir un pullup de 10k sur la ligne reset au cas ou la carte cpu est pas présente.

---

## 7. Évolutions Futures (Roadmap)
- **Carte Son :** YM2149F ou AY-3-8910 (Sortie externe : Jack 3.5mm Audio Out).
- **Carte Vidéo (VDP) :** Yamaha V9958 ou TMS9918A (Sortie externe : Composite / S-Video / VGA).
- **Carte CPU V2 (16-bits) :** Mise à niveau avec WDC 65C816S, en utilisant un Latch `74HC573` pour démultiplexer et exploiter le bus 24-bits préparé sur les broches réservées du fond de panier.

---

### Le brochage optimisé (Bus 6502 Direct - Prêt pour 65C816)

**Code Couleur :**
*   🔴 Alimentation (Power)
*   🔵 Bus de Données (Data Bus, 8-bit)
*   🟢 Bus d'Adresses (Address Bus, 64 Ko natif)
*   🟣 Extension d'Adresses (Address Bus Ext, 16 Mo pour futur 65C816)
*   🟠 Signaux de Contrôle 6502
*   ⚪ Réservé / Libre (*resv* / *user*)

| Broche DIN | Rangée a (Côté Gauche du CPU) | Rangée c (Côté Droit du CPU) | Explication du routage |
| :---: | :--- | :--- | :--- |
| **1** | 🔴 `5V` | 🔴 `5V` | Alimentation globale (Haut du connecteur). |
| **2** | ⚪ *réservé* | 🟠 `/RES` *(CPU Pin 40)* | Ligne droite depuis le haut droit du CPU. |
| **3** | 🟠 `/IRQ` *(CPU Pin 4)* | 🟠 `PHI2O` *(CPU Pin 39)* | Ligne droite. |
| **4** | 🟠 `/NMI` *(CPU Pin 6)* | 🟠 `R/W` *(CPU Pin 34)* | Ligne droite. |
| **5** | 🟢 `A0` *(CPU Pin 9)* | 🔵 `D0` *(CPU Pin 33)* | **Début des bus (Lignes droites parallèles)** |
| **6** | 🟢 `A1` *(CPU Pin 10)* | 🔵 `D1` *(CPU Pin 32)* | |
| **7** | 🟢 `A2` *(CPU Pin 11)* | 🔵 `D2` *(CPU Pin 31)* | |
| **8** | 🟢 `A3` *(CPU Pin 12)* | 🔵 `D3` *(CPU Pin 30)* | |
| **9** | 🟢 `A4` *(CPU Pin 13)* | 🔵 `D4` *(CPU Pin 29)* | |
| **10** | 🟢 `A5` *(CPU Pin 14)* | 🔵 `D5` *(CPU Pin 28)* | |
| **11** | 🟢 `A6` *(CPU Pin 15)* | 🔵 `D6` *(CPU Pin 27)* | |
| **12** | 🟢 `A7` *(CPU Pin 16)* | 🔵 `D7` *(CPU Pin 26)* | |
| **13** | 🟢 `A8` *(CPU Pin 17)* | 🟢 `A15` *(CPU Pin 25)* | |
| **14** | 🟢 `A9` *(CPU Pin 18)* | 🟢 `A14` *(CPU Pin 24)* | |
| **15** | 🟢 `A10` *(CPU Pin 19)* | 🟢 `A13` *(CPU Pin 23)* | |
| **16** | 🟢 `A11` *(CPU Pin 20)* | 🟢 `A12` *(CPU Pin 22)* | **Fin des bus du 6502 (Bas du CPU)** |
| **17** | 🟣 `A16` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **18** | 🟣 `A17` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **19** | 🟣 `A18` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **20** | 🟣 `A19` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **21** | 🟣 `A20` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **22** | 🟣 `A21` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **23** | 🟣 `A22` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **24** | 🟣 `A23` *(Futur 65C816)* | ⚪ *réservé* | Extension adresse 24-bits |
| **25 à 31**| ⚪ *libres / user* | ⚪ *libres / user* | Signaux personnalisés (audio, vidéo, I/O) |
| **32** | 🔴 `GND` | 🔴 `GND` | Masse globale (Bas du connecteur). |

## Annexe : GALs et timings
Puisque tu utilises cette architecture, voici le point crucial pour la programmation de tes GALs (WinCUPL / GALasm) pour que le timing fonctionne :

Chip Select (/CS ou /CE) : L'équation qui active la mémoire NE DOIT PAS inclure l'horloge système (PHI2O / CLK). Elle doit dépendre uniquement du bus d'adresses (A8-A19). Ainsi, la puce mémoire s'allume et se prépare dès la phase basse de l'horloge.

Output Enable (/OE pour la lecture) et Write Enable (/WE pour l'écriture) : Ces signaux DOIVENT inclure l'horloge système (PHI2O / CLK) dans l'équation du GAL. C'est ce qui garantit que la SRAM ou la Flash n'écrit ou ne pousse ses données sur le bus que lorsque le 6502 est prêt (phase haute).

Exemple simplifié d'équation pour la RAM ($0000 - $7FFF) :
RAM_CS = !A15 ;
RAM_OE = RAM_CS & PHI2O & RW ; (Sort les données uniquement sur phase haute)
RAM_WE = RAM_CS & PHI2O & !RW ; (Écrit uniquement sur phase haute)