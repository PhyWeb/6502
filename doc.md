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
- Signaux de Contrôle : `CLK` (Généré par la broche `PHI2` sortante du CPU), `/WR`, `/RD`, `/IORQ`, `/MREQ`, `/RESET`, `/INT`, `/NMI`.

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
- **Interface Utilisateur :** Cavaliers (Jumpers) pour la sélection de fréquence, et bouton poussoir pour le mode pas-à-pas.
- **Composants :** W65C02S, Oscillateur 8 MHz, Diviseur binaire (`74HC393`), Inverseur (`74HC14`), Superviseur de Reset (DS1813).
- **Horloge :** L'oscillateur 8 MHz entre dans `PHI0` (Pin 37). Le processeur conditionne le signal et le ressort sur `PHI2` (Pin 39). C'est ce signal `PHI2` (nommé `CLK` sur le bus MECB) qui cadence tout le système.

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
- **Topologie des Slots :** 7 ports DIN 41612 (Type C, rangées a et c). 6 ports verticaux pour les cartes de base, et 1 port horizontal (coudé à 90°) pour faciliter le débogage (analyseur logique) ou servir de futur port d'extension.
- **Alimentation Intégrée :** Le circuit d'alimentation est directement sur le backplane : connecteur Barrel Jack (5V), interrupteur, diode de protection, gros condensateurs de filtrage (ex: 1000µF) en entrée, et condensateurs céramiques de découplage (100nF) au plus près de chaque port DIN.
- **Intégrité du signal (Haute Fréquence - 8 MHz) :**
  - **Routage PCB 4 Couches :** Utilisation stricte de plans internes continus pour la Masse (Couche 2 : GND) et l'Alimentation (Couche 3 : 5V) pour bloquer les interférences.
  - **Isolation :** La piste d'horloge (`PHI2` / `CLK`) est entourée de plans de masse.
  - **Terminaisons :** Empreintes prévues aux extrémités du bus pour l'ajout éventuel de réseaux de résistances de tirage (Pull-up 3.3kΩ) afin d'absorber les rebonds de signaux.

---

## 7. Évolutions Futures (Roadmap)
- **Carte Son :** YM2149F ou AY-3-8910 (Sortie externe : Jack 3.5mm Audio Out).
- **Carte Vidéo (VDP) :** Yamaha V9958 ou TMS9918A (Sortie externe : Composite / S-Video / VGA).
- **Carte CPU V2 (16-bits) :** Mise à niveau avec WDC 65C816S, en utilisant un Latch `74HC573` pour démultiplexer et exploiter le bus 24-bits préparé sur les broches réservées du fond de panier.

---

## Annexe : Brochage Officiel du Bus MECB (Connecteur DIN 41612)

Connecteur DIN 41612 (Type C, 64 broches, rangées **a** et **c**).
*Note : Sur un système 6502, `CLK` = `PHI2`, `/INT` = `/IRQ`.*

**Code Couleur :**
*   🔴 Alimentation (Power)
*   🔵 Bus de Données (Data Bus, 8-bit)
*   🟢 Bus d'Adresses (Address Bus, 64K)
*   🟣 Extension d'Adresses (Address Bus Ext, 1M optional - *Routées pour futur CPU 16-bits*)
*   🟠 Signaux de Contrôle (Control Signals)
*   ⚪ Réservé / Libre (*resv* / *user*)

| Broche | Rangée a | Rangée c |
| :---: | :--- | :--- |
| **1** | 🔴 `5V` | 🔴 `5V` |
| **2** | 🔵 `D5` | 🔵 `D0` |
| **3** | 🔵 `D6` | 🔵 `D7` |
| **4** | 🔵 `D3` | 🔵 `D2` |
| **5** | 🔵 `D4` | 🟢 `A0` |
| **6** | 🟢 `A2` | 🟢 `A3` |
| **7** | 🟢 `A4` | 🟢 `A1` |
| **8** | 🟢 `A5` | 🟢 `A8` |
| **9** | 🟢 `A6` | 🟢 `A7` |
| **10** | ⚪ *resv* | 🟣 `A16` |
| **11** | ⚪ *resv* | ⚪ *resv* |
| **12** | ⚪ *resv* | 🟣 `A17` |
| **13** | ⚪ *user* | 🟣 `A18` |
| **14** | 🟣 `A19` | 🔵 `D1` |
| **15** | ⚪ *user* | ⚪ *user* |
| **16** | ⚪ *resv* | ⚪ *resv* |
| **17** | ⚪ *resv* | 🟢 `A11` |
| **18** | 🟢 `A14` | 🟢 `A10` |
| **19** | ⚪ *user* | ⚪ *resv* |
| **20** | 🟠 `/M1` | 🟠 `/NMI` |
| **21** | ⚪ *resv* | 🟠 `/INT` |
| **22** | ⚪ *resv* | 🟠 `/WR` |
| **23** | ⚪ *resv* | ⚪ *resv* |
| **24** | ⚪ *resv* | 🟠 `/RD` |
| **25** | ⚪ *resv* | ⚪ *resv* |
| **26** | ⚪ *resv* | ⚪ *resv* |
| **27** | 🟠 `/IORQ` | 🟢 `A12` |
| **28** | ⚪ *resv* | 🟢 `A15` |
| **29** | 🟢 `A13` | 🟠 `CLK` |
| **30** | 🟢 `A9` | 🟠 `/MREQ` |
| **31** | ⚪ *resv* | 🟠 `/RESET` |
| **32** | 🔴 `GND` | 🔴 `GND` |