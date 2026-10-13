# Documentation Technique - Cartes Mémoire (RAM, ROM & MMU)

## 1. Vue d'Ensemble de l'Architecture
L'architecture de la mémoire de l'ordinateur repose sur un système de banques (MMU) capable de gérer 512 Ko de RAM et 512 Ko de ROM. Le décodage d'adresse n'est pas centralisé sur le fond de panier, mais distribué : chaque module mémoire embarque sa propre puce logique (ATF16V8B) pour décider quand il doit interagir avec le bus. Cette méthode permet de réduire considérablement l'espace nécessaire pour les Entrées/Sorties.

## 2. Spécifications de la Carte Mémoire RAM & MMU
Cette carte est responsable de la mémoire vive du système et de la pagination.
* **Composants principaux :** La carte intègre une puce SRAM de 512 Ko (AS6C4008-55), un GAL (ATF16V8B) pour le décodage, et un registre de banque (`74HC574`).
* **Connectivité externe :** La carte ne possède aucun port externe.
* **Zone de RAM Fixe :** Le GAL force matériellement les 8 premiers Ko de l'espace mémoire (de `$0000` à `$1FFF`) sur la Banque 0 de la SRAM. Cette zone fixe et sécurisée abrite la Page Zéro, la Pile du 6502 (située en `$01`), ainsi que les variables système.
* **Zone de RAM Bankée :** L'espace d'adressage allant de `$2000` à `$7FFF` (soit 24 Ko) sert de fenêtre mémoire. Elle pointe dynamiquement vers l'une des 32 banques de 24 Ko disponibles dans la SRAM de 512 Ko.

## 3. Spécifications de la Carte ROM & Port Cartouche
Cette carte gère la mémoire morte, le chargement du système et l'exécution de logiciels depuis des supports physiques.
* **Composants principaux :** Elle est équipée d'une mémoire Flash de 512 Ko (39SF040-55), d'un connecteur Edge, d'un GAL (ATF16V8B) et d'un registre de banque ROM (`74HC574`).
* **Connectivité externe :** Un connecteur Edge (de type ISA ou format cartouche standard) est situé sur le haut du boîtier pour l'insertion physique de cartouches.
* **Zone de ROM Fixe (BIOS) :** Les 8 derniers Ko de la mémoire (plage `$E000` à `$FFFF`) sont fixés au BIOS du système. On y trouve le moniteur de démarrage, WozMon, le bootloader, les routines de bit-banging pour lire la carte SD (en SPI) et la souris, ainsi que les vecteurs d'interruption en fin de mémoire (de `$FFFA` à `$FFFF`).
* **Espace Applicatif et Priorité matérielle :** La zone de `$8100` à `$DFFF` (environ 23,75 Ko) est dédiée à l'exécution de programmes. Si aucune cartouche n'est présente, cette plage pointe sur la Flash interne (où la Banque 1 abrite EHBasic prêt à l'emploi). En revanche, si une cartouche est insérée, une détection matérielle vient désactiver la broche `/CE` de la Flash interne. Le bus externe prend alors automatiquement la priorité sur cette plage d'adresses.

## 4. Logique de Décodage (GAL) et Timings d'Horloge
Pour que ces mémoires communiquent de manière fiable à haute fréquence (8 MHz) avec le processeur WDC 65C02S, les puces GAL doivent être programmées en respectant des règles de timing très strictes.
* **Activation de la Puce (/CS ou /CE) :** L'équation logique activant la sélection de la puce ne doit dépendre que du bus d'adresses (`A8` à `A19`). Elle ne doit surtout pas inclure l'horloge système (`PHI2O` / `CLK`). Ainsi, la SRAM ou la Flash s'allume et commence à se préparer dès la phase basse de l'horloge.
* **Autorisation de Sortie et d'Écriture (/OE et /WE) :** À l'inverse, les signaux contrôlant la lecture (`/OE`) ou l'écriture (`/WE`) doivent impérativement inclure le signal de l'horloge système (`PHI2O` / `CLK`) dans leur équation. C'est cette sécurité qui garantit que la mémoire n'écrira ou ne mettra ses données sur le bus que pendant la phase haute du cycle, moment où le 6502 est prêt à les traiter.

## 5. Intégration Mécanique et Électrique (Backplane)
* **Connexion au Bus :** Les cartes mémoires s'insèrent dans les connecteurs industriels robustes DIN 41612 (64 broches, utilisant les rangées a et c) du fond de panier MECB.
* **Alimentation et Filtrage partagé :** L'alimentation 5V est récupérée sur la broche 1 (`a1`, `c1`), et la masse sur la broche 32 (`a32`, `c32`). Les cartes RAM et ROM n'ont pas besoin d'embarquer de condensateurs électrolytiques pour lisser l'alimentation globale. Cette tâche est déléguée au fond de panier qui fournit, au pied de chaque connecteur DIN, un binôme de condensateurs composé d'un modèle électrolytique de 10 µF (pour l'appel de courant) et d'un modèle céramique de 100 nF (pour le filtrage haute fréquence).