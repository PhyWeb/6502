# Fond de Panier (Backplane) - Documentation Technique

## 1. Philosophie et Topologie
Le fond de panier (backplane) est l'épine dorsale du système modulaire 6502. Entièrement passif, il ne contient aucune logique active et repose sur la robustesse de l'alimentation 4 couches et la qualité du routage pour garantir l'intégrité des signaux jusqu'à 8 MHz.

* **Format des Slots :** 8 connecteurs industriels **DIN 41612 (Type C, 64 broches, rangées a et c)**.
  * 7 slots verticaux pour les cartes système standards (CPU, Carte Mémoire, E/S, Série/SD, Audio, Vidéo).
  * 1 slot horizontal (coudé à 90°) placé en extrémité de bus, conçu pour le débogage (analyseur logique) ou les extensions.
* **Port Cartouche Intégré :** 1 connecteur Edge (Type Cartouche / ISA) est soudé directement sur le fond de panier. Il reçoit le bus d'adresses (`A0-A15`), le bus de données (`D0-D7`), `R/W`, `CLK`, `/RESET`, ainsi que les 3 lignes dédiées :
  * `/CART_DETECT` (`a26`) : Relié à la masse (`GND`) sur le PCB de la cartouche pour signaler sa présence physique.
  * `/CART_CE` (`c26`) : Signal Chip Enable pré-décodé par la Carte Mémoire pour la plage `$8100-$DFFF` (actif uniquement si `CART_EN = 1`).
  * `/CART_IO` (`a27`) : Signal d'écriture pré-décodé (`$8010-$801F`) permettant à une cartouche d'embarquer un simple registre `74HC273` pour paginer jusqu'à 4 Mo de ROM.

## 2. Alimentation et Filtrage
Une attention extrême est portée à la qualité de l'alimentation afin de compenser l'absence de buffers de bus.

* **Entrée d'Alimentation :** Connecteur **KF2510 ou JST VH** (2 broches, verrouillable). Il reçoit le 5V et la masse (GND) depuis l'embase d'alimentation du boîtier (ex: prise USB-C PD/5V 3A avec résistances 5.1 kΩ ou bloc secteur 5V).
* **Protection contre les Courts-Circuits :** Un fusible réarmable PTC (PolySwitch, ex: Littelfuse LVR100, calibré à ~3A) est placé en tête du circuit, immédiatement après l'entrée 5V.
* **Protection Inversion de Polarité :** Un transistor MOSFET Canal P **Logic-Level à très faible $R_{DS(on)}$** (ex: **SUP90P06** ou **IRF4905**, $< 0.02\ \Omega$ à $-4.5\text{V}$) est placé en série après le fusible (Drain côté entrée, Source côté système, Grille à la masse). Contrairement à un MOSFET standard (`IRF9540N`), il garantit une chute de tension inférieure à $40\text{ mV}$ sous $2\text{A}$.
* **Boutons d'Alimentation (Câblage en Parallèle) :**
  * **SW2 :** Interrupteur d'alimentation soudé directement sur le PCB (pour banc de test).
  * **J11 :** Connecteur 2 broches permettant de brancher l'interrupteur principal en façade du boîtier.
* **Routage de Puissance :** La zone d'entrée (`Connecteur ➔ PTC ➔ MOSFET ➔ Interrupteurs ➔ Condensateur 1000 µF`) est routée via de **larges polygones de cuivre** (ou pistes $\ge 2\text{ mm}$) et reliée aux plans internes via des grappes de 4 vias minimum.
* **Filtrage Étagé :**
  * *Filtrage d'entrée :* Un condensateur électrolytique de **1000 µF** en tête de carte.
  * *Filtrage localisé par slot :* Chaque connecteur DIN (et le port Cartouche) dispose à son pied d'un condensateur **électrolytique de 10 µF** et d'un **céramique de 100 nF**.

## 3. Circuit de Reset Manuel
La détection de l'appui sur le bouton Reset est centralisée sur le fond de panier (tandis que le superviseur DS1813 est sur la carte CPU).

* **Bouton de Test :** Bouton poussoir (Tact Switch) soudé sur le fond de panier.
* **Bouton de Façade :** Connecteur JST (2 broches) pour déporter le bouton Reset sur le boîtier.
* **Fonctionnement :** Câblés en parallèle, ils mettent la ligne globale `/RESET` (broche `c2`) à la masse (`GND`), ce qui déclenche le cycle calibré de 150 ms du DS1813.

## 4. Intégrité des Signaux et Pull-ups
* **Conception PCB 4 Couches :**
  * Couche 1 (Top) et Couche 4 (Bottom) : Signaux.
  * Couche 2 : Plan de Masse (`GND`) continu.
  * Couche 3 : Plan d'Alimentation (`5V`) continu.
* **Routage de l'Horloge :** La piste `CLK` (`c3`) est isolée et bordée d'un plan/piste de garde `GND` pour prévenir toute diaphonie (crosstalk) à 8 MHz.
* **Résistances de Tirage du Backplane (Pull-ups 3.3 kΩ vers 5V) :**
  * **`/RESET` (`c2`) :** Maintient la ligne à l'état haut au repos.
  * **`RDY` (`a2`) :** Maintient le processeur actif par défaut.
  * **`BE` (`a25`) :** Autorise le processeur à piloter les bus par défaut.
* *(Note : Les pull-ups de `/IRQ` et `/NMI` sont sur la carte CPU ; le pull-up de `/CART_DETECT` est sur la carte mémoire).*
* **Terminaisons :** Empreintes prévues en bout de bus pour l'ajout optionnel de réseaux de résistances (terminaison passive).

## 5. Tableau de Brochage du Bus
| Broche DIN | Rangée a | Rangée c | Description |
| :--- | :--- | :--- | :--- |
| **1** | 🔴 `5V` | 🔴 `5V` | Alimentation Globale |
| **2** | 🟠 `RDY` | 🟠 `/RES` | Ready / Reset |
| **3** | 🟠 `/IRQ` | 🟠 `CLK` | Interruption / Horloge Système (synchro `PHI2`) |
| **4** | 🟠 `/NMI` | 🟠 `R/W` | Non-Maskable Int. / Read-Write |
| **5 à 12** | 🟢 `A0` à `A7` | 🔵 `D0` à `D7` | Bus d'Adresses Bas / Bus de Données |
| **13** | 🟢 `A8` | 🟢 `A15` | Adresses |
| **14** | 🟢 `A9` | 🟢 `A14` | Adresses |
| **15** | 🟢 `A10` | 🟢 `A13` | Adresses |
| **16** | 🟢 `A11` | 🟢 `A12` | Adresses |
| **17 à 24** | 🟣 `A16` à `A23` | ⚪ *Réservé* | Extension d'Adresses 24-bits (Prêt pour 65C816) |
| **25** | 🟠 `BE` | ⚪ *Réservé* | Bus Enable (DMA) |
| **26** | 🟡 `/CART_DETECT` | 🟡 `/CART_CE` | Présence Cartouche (GND) / Activation ROM Cartouche |
| **27** | 🟡 `/CART_IO` | ⚪ *Libre / User* | Strobe Écriture Mapper Cartouche (`$8010-$801F`) |
| **28 à 31** | ⚪ *Libre / User* | ⚪ *Libre / User* | Signaux Customisés (Vidéo, Audio, etc.) |
| **32** | 🔴 `GND` | 🔴 `GND` | Masse Globale |