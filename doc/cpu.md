# Carte CPU (W65C02S) - Documentation Technique

## 1. Philosophie de la Carte
Cette carte constitue le cœur du système modulaire. Le processeur **WDC W65C02S** pilote directement le fond de panier MECB (incluant la préparation au DMA via `BE` et `RDY`). Pour garantir une marge de timing maximale à **8 MHz**, l'horloge système est distribuée en parallèle directement depuis la sélection d'horloge vers l'entrée `PHI2` du CPU et la ligne `CLK` du bus fond de panier.

## 2. Câblage du Processeur (WDC W65C02S - Boîtier DIP-40)

| Broche(s) 65C02S | Nom | Destination / Connexion | Remarque |
| :--- | :--- | :--- | :--- |
| **9-20, 22-25** | `A0 - A15` | Connecteur MECB (`a5-a16`, `c13-c16`) | Pilotage direct du bus (Pin 21 = `GND`). |
| **26 à 33** | `D0 - D7` | Connecteur MECB (`c5-c12`) | Pilotage direct du bus de données. |
| **8, 21** | `VDD`, `VSS` | `5V`, `GND` | Alimentation du processeur + capa `100 nF` au plus près. |
| **37** | `PHI2` | Bloc Jumpers (Horloge) **&** MECB (`CLK` `c3`) | Reçoit l'horloge sélectionnée en même temps que le bus MECB. |
| **39** | `PHI2O` | Non Connectée (NC) / Point de test | Non utilisée à 8 MHz pour éviter le retard de propagation interne du CPU. |
| **34** | `R/W` | Connecteur MECB (`R/W` `c4`) | Direction de transfert (Read = `1`, Write = `0`). |
| **4** | `/IRQ` | Connecteur MECB (`/IRQ` `a3`) | Pull-up de **3.3 kΩ** vers `5V` présent sur cette carte CPU. |
| **6** | `/NMI` | Connecteur MECB (`/NMI` `a4`) | Pull-up de **3.3 kΩ** vers `5V` présent sur cette carte CPU. |
| **40** | `/RES` | Connecteur MECB (`/RES` `c2`) & DS1813 | Reçoit et diffuse le signal de réinitialisation. |
| **2** | `RDY` | Connecteur MECB (`RDY` `a2`) | Pull-up de 3.3 kΩ sur le fond de panier (Pause / DMA). |
| **36** | `BE` | Connecteur MECB (`BE` `a25`) | Pull-up de 3.3 kΩ sur le fond de panier (Haute impédance / DMA). |
| **38** | `SOB` | `5V` (ou Pull-up 3.3 kΩ) | **Entrée critique :** Maintenue à l'état haut pour bloquer le flag Overflow. |
| **1, 5, 3, 35** | `VPB`, `SYNC`, `PHI1O`, `NC` | Points de test (NC) | Sorties d'état / broches non connectées. |

## 3. Circuit de Reset (Superviseur DS1813)
Le composant **DS1813** (boîtier TO-92) remplace les circuits RC traditionnels et garantit un maintien du Reset à `0V` pendant **150 ms** après la stabilisation du 5V ou après le relâchement du bouton Reset.

* **Connexions :** Broche `VCC` au `5V`, broche `GND` à la masse, broche `/RST` reliée à la fois à la broche 40 (`/RES`) du W65C02S et à la broche `c2` (`/RES`) du connecteur MECB.
* **Fonctionnement bidirectionnel :** Lorsqu'un bouton Reset (situé sur le fond de panier ou en façade) tire la ligne `c2` à la masse, le DS1813 détecte ce front descendant, filtre les rebonds mécaniques et maintient proprement toute la ligne `/RES` (CPU + Registre MMU `74HC273` + Cartouche) à `0V` pendant 150 ms.

## 4. Génération et Sélection d'Horloge
Le système d'horloge fournit plusieurs fréquences sélectionnables par cavalier (jumper), de 8 MHz jusqu'au mode pas-à-pas.

* **Source Primaire :** Oscillateur actif **8 MHz** (format DIP-14 ou DIP-8 métal sur support tulipe).
* **Diviseur de Fréquence (`74HC393`) :**
  * Entrée `1CP` (Pin 1) : Reçoit le signal 8 MHz de l'oscillateur.
  * Entrée `1MR` (Pin 2) : Reliée à `GND`.
  * Sorties : `1Q0` (**4 MHz**), `1Q1` (**2 MHz**), `1Q2` (**1 MHz**), `1Q3` (**500 kHz**).
  * *Seconde moitié inutilisée :* Les entrées `2CP` (Pin 12) et `2MR` (Pin 13) sont reliées à `GND`.
* **Entrée Externe (Pas-à-pas) :** Connecteur 2 broches pour injecter une horloge manuelle anti-rebond.
* **Bloc de Sélection (Jumpers 2x6) :** Sélectionne la source (8 MHz, 4 MHz, 2 MHz, 1 MHz, 500 kHz, Externe) et l'envoie simultanément sur l'entrée **`PHI2` (Pin 37)** du CPU et sur la broche **`CLK` (`c3`)** du bus MECB. *(Ne jamais déplacer le cavalier sous tension sans maintenir le bouton Reset enfoncé).*

## 5. Découplage Local
* Un condensateur céramique de **100 nF** est placé au plus près des broches d'alimentation de chaque composant (`W65C02S`, `74HC393`, `Oscillateur`).
* Le filtrage basse fréquence est assuré par le condensateur de **10 µF** présent au pied du slot DIN sur le fond de panier.