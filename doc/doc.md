# Spécifications Techniques : Ordinateur Rétro 6502 Modulaire

## 1. Vue d'Ensemble & Philosophie du Projet

* **Processeur principal :** WDC W65C02S (Boîtier DIP-40).
* **Architecture :** Bus modulaire fond de panier (Backplane) basé sur le standard **MECB** (Minimalist Europe Card Bus) adapté aux signaux natifs du 6502.
* **Horloge :** 8 MHz de base, avec circuit diviseur et mode pas-à-pas embarqués sur la carte CPU.
* **Philosophie :**
  * **Flexibilité totale :** Fond de panier passif avec port cartouche intégré. Broches réservées routées pour évolutions futures (bus 24-bits pour 65C816, DMA).
  * **Décodage distribué :** La Carte Mémoire embarque un GAL (`ATF22V10C`) qui orchestre la RAM, la ROM et pré-décode les signaux du port cartouche (`/CART_CE`, `/CART_IO`). Les cartes périphériques d'E/S embarquent leur propre petit GAL (`ATF16V8B`).
  * **Autonomie des cartes :** Les fonctions critiques (contrôle de flux série, carte SD, manettes) sont gérées localement sur chaque carte fille.
  * **Gestion de la mémoire (MMU) :** Carte mémoire unifiée extensible de **512 Ko à 1 Mo de SRAM** (par tranches de 16 Ko) et **32 Ko de ROM Interne** (sur Flash 39SF040), avec basculement logiciel vers le port cartouche externe.
  * **Chargement hybride :** Via Menu de Démarrage (Boot Menu) proposant EHBasic (ROM interne), WozMon (Série), ou l'exécution de la Cartouche (jusqu'à 4 Mo via Mapper).

## 2. Architecture du Bus Modulaire (Backplane : MECB)

Le système repose sur un bus passif utilisant des connecteurs industriels robustes **DIN 41612 (Type C, 64 broches, Rangées a et c)**.

**Signaux principaux :**
* **Alimentation :** `5V`, `GND` (Plans internes dédiés sur PCB 4 couches).
* **Bus d'Adresses :** `A0-A15` standards, `A16-A23` sur broches réservées.
* **Bus de Données :** `D0-D7`.
* **Signaux de Contrôle Natifs 6502 :** `CLK` (Horloge système synchronisée avec `PHI2`), `R/W`, `/RESET`, `/IRQ`, `/NMI`, `BE`, `RDY`.
* **Signaux Dédiés Cartouche (sur broches User 26-27) :** `/CART_DETECT` (`a26`), `/CART_CE` (`c26`), `/CART_IO` (`a27`).

## 3. Map Mémoire (Memory Map)

L'espace mémoire est aligné sur des blocs binaires de **16 Ko** pour maximiser les performances logicielles et exploiter 100 % de la SRAM, tout en isolant une page de **256 octets** pour les Entrées/Sorties.

| Plage d'Adresses | Taille | Description | Allocation |
| :--- | :--- | :--- | :--- |
| **`$0000 - $3FFF`** | **16 Ko** | **RAM Fixe** | Page Zéro, Pile (`$01`), Variables Système et Basic. Forcé matériellement sur la Banque 0 de la SRAM. |
| **`$4000 - $7FFF`** | **16 Ko** | **RAM Bankée** | Fenêtre dynamique pointant sur l'une des 32 banques (512 Ko) ou 64 banques (1 Mo) de 16 Ko de la SRAM. |
| **`$8000 - $80FF`** | **256 octets** | **Entrées / Sorties (I/O)** | `$8000-$800F` : Registre MMU (`74HC273`) & État Cartouche.<br>`$8010-$801F` : Registre Mapper Cartouche (`/CART_IO`).<br>`$8020-$80FF` : Périphériques (VIA #1, VIA #2, UART). |
| **`$8100 - $DFFF`** | **~23,75 Ko** | **Espace Applicatif (Basculable)** | Par défaut (`CART_EN = 0`), pointe sur la **ROM Interne** (EHBasic). Si `CART_EN = 1`, active `/CART_CE` vers le **Port Cartouche**. |
| **`$E000 - $FFFF`** | **8 Ko** | **ROM Fixe (BIOS)** | Moniteur série (WozMon), Bootloader, et Vecteurs d'interruption (`$FFFA-$FFFF`). Fixé matériellement à la **ROM Interne**. |

## 4. Description des Modules Principaux

### A. Carte CPU (6502 Core Card)
* **Ports Externes :** Aucun (Interne uniquement).
* **Interface Utilisateur :** Cavaliers (Jumpers) pour la sélection de fréquence (500 kHz à 8 MHz) et connecteur pour horloge externe pas-à-pas. *(Le bouton Reset est centralisé sur le fond de panier).*
* **Composants :** WDC W65C02S, Oscillateur 8 MHz, Diviseur binaire (`74HC393`), Superviseur de Reset (`DS1813`).
* **Horloge Haute Fréquence :** Pour garantir des timings optimaux à 8 MHz sans subir le délai de propagation interne du CPU, le signal d'horloge sélectionné attaque simultanément la broche `PHI2` (Pin 37) du W65C02S et la ligne `CLK` (`c3`) du bus MECB.

### B. Carte Mémoire Unifiée (RAM, ROM & Contrôleur Cartouche)
* **Ports Externes :** Aucun.
* **Composants :** 1x ou 2x AS6C4008-55 (512 Ko ou 1 Mo SRAM), SST39SF040 (Flash 512 Ko configurée en 32 Ko utiles), `ATF22V10C` (GAL principal), `74HC273` (Registre 8-bits avec Reset matériel), `74HC08` ou `74HC157` (Logique de forçage Banque 0), `74HC125` (Buffer Tri-State pour lecture de `/CART_DETECT`).
* **Rôle :** Le GAL gère l'activation de la SRAM, de la Flash et génère `/CART_CE` et `/CART_IO`. Au démarrage, le `74HC273` est mis à zéro par `/RESET`, garantissant le boot sur le BIOS et la sélection de la ROM interne.

### C. Carte E/S (Joueurs : Clavier, Souris & Manettes NES)
* **Ports Externes (Façade) :** 1x PS/2 (Clavier), 1x PS/2 (Souris), 2x Connecteurs Manettes NES.
* **Composants :** WDC W65C22S (VIA #1), `ATF16V8B`, `74HC595` (Registre à décalage), `74HC14` (Schmitt Trigger), Diode Schottky `1N5819` (en série sur `/IRQ` pour convertir la sortie Push-Pull du W65C22S en Open-Drain).
* **Allocation du VIA (16 GPIO) :**
  * *Port A (8 broches) :* Lecture de l'octet du **Clavier PS/2** via le `74HC595` (0 % de charge CPU).
  * *Port B (Broches 0-3) :* **2x Manettes NES** (`LATCH` et `CLOCK` partagés, `DATA_1`, `DATA_2`).
  * *Port B (Broches 4-5) :* **Souris PS/2** (`CLOCK` et `DATA` gérés en bit-banging).

### D. Carte Communication Série & Lecteur Virtuel SD
* **Ports Externes (Façade) :** 1x Port USB/Série (FTDI) ou DB9, 1x Lecteur MicroSD (SPI).
* **Composants :** WDC W65C51N (UART), WDC W65C22S (VIA #2 dédié avec diode `1N5819` sur `/IRQ`), Oscillateur 1.8432 MHz, `ATF16V8B`.
* **Autonomie :** Le VIA #2 gère le contrôle de flux matériel (`RTS`/`CTS`) de l'UART et pilote la carte MicroSD en SPI.

## 5. Logiciel & Firmware (Software Stack)

* **BIOS / Bootloader (`$E000 - $FFFF`) :**
  * Initialisation matérielle et lecture du bit `D7` en `$8000` (`/CART_DETECT`).
  * Affichage du **Menu de Démarrage (Boot Menu)** : `(1) Lancer EHBasic`, `(2) Lancer la Cartouche` (si détectée), `(3) Lancer WozMon`.
  * Basculement logiciel (`CART_EN = 1` via `STA $8000`) pour désactiver EHBasic et activer `/CART_CE` vers le port cartouche sur `$8100-$DFFF`.
  * Contournement logiciel du bug de transmission du WDC 65C51N et routines SPI/PS2.

## 6. Conception du Fond de Panier (Backplane PCB Design)

* **Topologie :** 8 connecteurs DIN 41612 (7 verticaux + 1 horizontal coudé à 90° en bout de bus pour l'analyseur logique) + 1 connecteur Edge pour Cartouche.
* **Alimentation :** Entrée 5V sur connecteur haute intensité (KF2510 / JST VH), protégée par un fusible réarmable PTC (3A) et un MOSFET Canal P Logic-Level (`SUP90P06` ou `IRF4905`) contre les inversions de polarité. Filtrage par condensateur 1000 µF en tête et couple `10 µF + 100 nF` au pied de chaque slot DIN.
* **Intégrité du Signal (8 MHz) :** PCB 4 couches (Couche 2 : GND continu, Couche 3 : 5V continu). Pull-ups de 3.3 kΩ sur `/RESET`, `RDY` et `BE`.

## 7. Brochage Officiel du Bus (MECB 6502 Optimisé)

| Broche DIN | Rangée a (Côté Gauche du CPU) | Rangée c (Côté Droit du CPU) | Explication du routage |
| :--- | :--- | :--- | :--- |
| **1** | 🔴 `5V` | 🔴 `5V` | Alimentation globale (Haut du connecteur). |
| **2** | 🟠 `RDY` *(CPU Pin 2)* | 🟠 `/RES` *(CPU Pin 40)* | Pause DMA / Reset global. |
| **3** | 🟠 `/IRQ` *(CPU Pin 4)* | 🟠 `CLK` *(Horloge Système)* | Interruption / Horloge synchronisée `PHI2`. |
| **4** | 🟠 `/NMI` *(CPU Pin 6)* | 🟠 `R/W` *(CPU Pin 34)* | Non-Maskable Int. / Read-Write. |
| **5 à 12** | 🟢 `A0` à `A7` *(Pins 9-16)* | 🔵 `D0` à `D7` *(Pins 33-26)* | Bus d'Adresses Bas / Bus de Données. |
| **13** | 🟢 `A8` *(CPU Pin 17)* | 🟢 `A15` *(CPU Pin 25)* | Croisement astucieux pour routage droit. |
| **14** | 🟢 `A9` *(CPU Pin 18)* | 🟢 `A14` *(CPU Pin 24)* | Adresses hautes. |
| **15** | 🟢 `A10` *(CPU Pin 19)* | 🟢 `A13` *(CPU Pin 23)* | Adresses hautes. |
| **16** | 🟢 `A11` *(CPU Pin 20)* | 🟢 `A12` *(CPU Pin 22)* | Fin du bus 16-bits du 6502. |
| **17 à 24** | 🟣 `A16` à `A23` *(Futur 65C816)* | ⚪ *Réservé* | Extension d'adresses 24-bits. |
| **25** | 🟠 `BE` *(CPU Pin 36)* | ⚪ *Réservé* | Bus Enable (DMA / Multi-CPU). |
| **26** | 🟡 `/CART_DETECT` | 🟡 `/CART_CE` | Détection présence (GND) / Activation ROM Cartouche. |
| **27** | 🟡 `/CART_IO` | ⚪ *Libre / User* | Strobe d'écriture Mapper Cartouche (`$8010-$801F`). |
| **28 à 31** | ⚪ *Libre / User* | ⚪ *Libre / User* | Signaux personnalisés (Audio, Vidéo, etc.). |
| **32** | 🔴 `GND` | 🔴 `GND` | Masse globale (Bas du connecteur). |