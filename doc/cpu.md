# Carte CPU (W65C02S) - Documentation Technique

## 1. Philosophie de la Carte
Cette carte constitue le cœur du système modulaire.  Le processeur WDC 65C02S pilote directement le fond de panier MECB modifié, s'appuyant sur les plans d'alimentation du PCB 4 couches et l'intégration locale du décodage (GAL) sur les cartes filles.

## 2. Câblage du Processeur (WDC 65C02S)

| Broche(s) 65C02S | Nom | Destination / Connexion | Remarque |
| :--- | :--- | :--- | :--- |
| **9 à 25** | `A0 - A15` | Connecteur MECB (Adresses) | Pilotage direct du bus. |
| **26 à 33** | `D0 - D7` | Connecteur MECB (Données) | Pilotage direct du bus. |
| **39** | `PHI2O` | Connecteur MECB (`CLK`) | Horloge système générée par le CPU. |
| **34** | `R/W` | Connecteur MECB (`R/W`) | Direction de transfert (Read/Write). |
| **4** | `/IRQ` | Connecteur MECB (`/IRQ`) | Tirage vers le 5V (Pull-up 3.3 kΩ) sur la carte CPU. |
| **6** | `/NMI` | Connecteur MECB (`/NMI`) | Tirage vers le 5V (Pull-up 3.3 kΩ) sur la carte CPU. |
| **40** | `/RES` | Sortie du DS1813 | Reçoit le signal de réinitialisation. |
| **37** | `PHI2` | Bloc Jumpers (Horloge) | Reçoit l'horloge sélectionnée. |
| **2** | `RDY` | `5V` (via Pull-up 3.3 kΩ) | Maintient le processeur actif. |
| **38** | `SOB` | `5V` (Direct) | Inutilisé. |
| **36** | `BE` | `5V` (Direct) | Active les bus internes (Bus Enable). |
| **1, 5** | `VPB`, `SYNC`| Non Connectées (NC) | Possibilité d'ajouter des points de test. |

## 3. Circuit de Reset (Superviseur DS1813)
Le composant **DS1813** remplace les circuits RC traditionnels. Il garantit une initialisation parfaite du processeur et du fond de panier, avec un temps de maintien de 150 ms (laissant l'oscillateur se stabiliser).

*   **Connexions du DS1813 :** Broches d'alimentation sur `5V` et `GND`.
*   **Sortie `/RST` :** Connectée à la broche 40 (`/RES`) du 65C02S **et** à la ligne `/RESET` du bus MECB.
*   **Pull-up global :** Une résistance de 10 kΩ relie la ligne `/RESET` au `5V` pour maintenir le bus propre.
*   **Bouton Reset :** Connecteur 2 pins relié entre la sortie `/RST` du DS1813 et la Masse (`GND`).

## 4. Génération et Sélection d'Horloge
Le système d'horloge fournit plusieurs fréquences sélectionnables via un bloc de cavaliers (jumpers), allant de la pleine vitesse (jusqu'à 8 MHz) à un mode pas-à-pas externe pour le débogage.

*   **Source Primaire :** Oscillateur actif (boîtier métal 4 broches, sur support tulipe pour échange facile). Connecté au `5V`, `GND`, avec sa sortie vers le diviseur et le bloc de sélection.
*   **Diviseur (74HC393) :**
    *   Entrée `1CP` : Reçoit le signal natif de l'oscillateur.
    *   Entrée `1MR` : Connectée à `GND`.
    *   Sorties : Division binaire `/2`, `/4`, `/8`, `/16` (ex: 4 MHz, 2 MHz, 1 MHz, 500 kHz).
*   **Entrée Externe (Pas-à-pas) :** Pin connectée à la source d'horloge manuelle externe (déjà conditionnée anti-rebond).
*   **Bloc de Sélection (Jumpers) :** Connecteur 2x6 pins. La rangée de gauche expose chaque fréquence disponible + l'entrée externe. La rangée de droite est commune et achemine le signal sélectionné vers l'entrée `PHI2` (Broche 37) du 65C02S.

## 5. Découplage et Intégrité du Signal
La stabilité à haute fréquence sans l'utilisation de buffers dépend strictement de la propreté de l'alimentation locale.

*   **Découplage IC :** Un condensateur céramique de **100 nF** doit être placé le plus près possible des broches `5V` et `GND` de chaque circuit intégré (65C02S, DS1813, 74HC393, Oscillateur).
*   **Filtrage Global :** Un condensateur électrolytique de **10 µF** est placé à proximité du connecteur DIN 41612 pour lisser les appels de courant globaux de la carte.