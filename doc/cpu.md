# Carte CPU (W65C02S) - Documentation Technique

## 1. Philosophie de la Carte
Cette carte constitue le cœur du système modulaire. Le processeur WDC 65C02S pilote directement le fond de panier MECB modifié (incluant désormais la préparation au DMA via les signaux `BE` et `RDY`), s'appuyant sur les plans d'alimentation du PCB 4 couches et l'intégration locale du décodage (GAL) sur les cartes filles.

## 2. Câblage du Processeur (WDC 65C02S - Boîtier DIP-40)

| Broche(s) 65C02S | Nom | Destination / Connexion | Remarque |
| :--- | :--- | :--- | :--- |
| **9 à 25** | `A0 - A15` | Connecteur MECB (Adresses) | Pilotage direct du bus. |
| **26 à 33** | `D0 - D7` | Connecteur MECB (Données) | Pilotage direct du bus. |
| **39** | `PHI2O` | Connecteur MECB (`CLK`) | Horloge système générée par le CPU. |
| **34** | `R/W` | Connecteur MECB (`R/W`) | Direction de transfert (Read/Write). |
| **4** | `/IRQ` | Connecteur MECB (`/IRQ`) | Tirage vers le 5V (Pull-up 3.3 kΩ) sur la carte CPU*. |
| **6** | `/NMI` | Connecteur MECB (`/NMI`) | Tirage vers le 5V (Pull-up 3.3 kΩ) sur la carte CPU*. |
| **40** | `/RES` | Connecteur MECB (`/RESET`) & DS1813 | Reçoit le signal de réinitialisation. |
| **37** | `PHI2` | Bloc Jumpers (Horloge) | Reçoit l'horloge sélectionnée. |
| **2** | `RDY` | Connecteur MECB (`RDY`) | Tirage vers le 5V (Pull-up 3.3 kΩ) sur le fond de panier*. Permet la mise en pause externe (DMA). |
| **36** | `BE` | Connecteur MECB (`BE`) | Tirage vers le 5V (Pull-up 3.3 kΩ) sur le fond de panier. Permet la déconnexion des bus (DMA). |
| **38** | `SOB` | `5V` (Direct ou Pull-up) | **Entrée critique :** Maintenue à l'état haut pour empêcher le déclenchement erratique du flag Overflow par les parasites. |
| **1, 5** | `VPB`, `SYNC` | Non Connectées (NC) | Sorties. Possibilité d'ajouter des points de test. *(Broche 44 MLB retirée car exclusive aux boîtiers CMS).* |

## 3. Circuit de Reset (Superviseur DS1813)
Le composant **DS1813** remplace les circuits RC traditionnels. Il garantit une initialisation parfaite du processeur et du fond de panier, avec un temps de maintien de 150 ms (laissant l'oscillateur se stabiliser). 

*Architecture de Reset Distribué :*
- **Connexions du DS1813 :** Broches d'alimentation sur `5V` et `GND`.
- **Sortie `/RST` :** Connectée à la broche 40 (`/RES`) du 65C02S **et** à la ligne `/RESET` du bus MECB.
- **Pull-up :** Aucun pull-up additionnel n'est requis sur la carte CPU pour le reset (le DS1813 intègre déjà un pull-up de ~5.5 kΩ). Une résistance de tirage de 3.3 kΩ se trouve sur le fond de panier.
- **Bouton Reset :** Le bouton est déporté en façade du boîtier et branché sur le fond de panier (reliant la ligne globale `/RESET` à la Masse). Le DS1813 sur la carte CPU détectera cette mise à la masse, absorbera les rebonds matériels, et prolongera le signal à 0V pendant 150 ms pour garantir un démarrage synchronisé de l'ordinateur.

## 4. Génération et Sélection d'Horloge
Le système d'horloge fournit plusieurs fréquences sélectionnables via un bloc de cavaliers (jumpers), allant de la pleine vitesse (jusqu'à 8 MHz) à un mode pas-à-pas externe pour le débogage.

- **Source Primaire :** Oscillateur actif (boîtier métal 4 broches, sur support tulipe pour échange facile). Connecté au `5V`, `GND`, avec sa sortie vers le diviseur et le bloc de sélection.
- **Diviseur (74HC393 - Utilisation d'un seul compteur sur les deux) :**
  - Entrée `1CP` (Pin 1) : Reçoit le signal natif 8 MHz de l'oscillateur.
  - Entrée `1MR` (Pin 2) : Connectée à `GND`.
  - Sorties utilisées : `1Q0` (4 MHz), `1Q1` (2 MHz), `1Q2` (1 MHz), `1Q3` (500 kHz).
  - *Gestion de la moitié inutilisée :* Les entrées `2CP` (Pin 12) et `2MR` (Pin 13) sont reliées à `GND` pour éviter les oscillations parasites. Les sorties `2Q` sont laissées non connectées.
- **Entrée Externe (Pas-à-pas) :** Pin connectée à la source d'horloge manuelle externe (déjà conditionnée anti-rebond).
- **Bloc de Sélection (Jumpers) :** Connecteur 2x6 pins. La rangée de gauche expose chaque fréquence disponible + l'entrée externe. La rangée de droite est commune et achemine le signal sélectionné vers l'entrée **`PHI2`** (Broche 37) du 65C02S. *(Attention : un changement de cavalier à chaud provoque des glitchs d'horloge ; toujours éteindre ou maintenir le reset enfoncé pendant la manipulation).*

## 5. Découplage et Intégrité du Signal
La stabilité à haute fréquence sans l'utilisation de buffers de bus dépend strictement de la propreté de l'alimentation locale.

- **Découplage IC :** Un condensateur céramique de **100 nF** doit être placé le plus près possible des broches `5V` et `GND` de chaque circuit intégré (65C02S, DS1813, 74HC393, Oscillateur).
- **Filtrage Global :** Un condensateur électrolytique de **10 µF** est placé à proximité du connecteur DIN 41612 pour lisser les appels de courant globaux de la carte.