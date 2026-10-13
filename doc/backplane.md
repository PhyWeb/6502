# Fond de Panier (Backplane) - Documentation Technique

## 1. Philosophie et Topologie
Le fond de panier (backplane) est l'épine dorsale du système modulaire 6502. Entièrement passif, il ne contient aucune logique active (aucun buffer de bus) et repose sur la robustesse de l'alimentation et la qualité du routage pour garantir l'intégrité des signaux à haute fréquence.

* **Format des Slots :** 8 connecteurs industriels **DIN 41612 (Type C, 64 broches, rangées a et c)**.
* **Topologie :**
  * 7 slots verticaux pour les cartes système standards (CPU, RAM, ROM, I/O, etc.).
  * 1 slot horizontal (coudé à 90°) placé en extrémité de bus, conçu pour faciliter le débogage (branchement d'un analyseur logique) ou pour accueillir de futures extensions matérielles.

## 2. Alimentation et Filtrage
Une attention extrême est portée à la qualité de l'alimentation afin de compenser l'absence de buffers de bus.

* **Entrée d'Alimentation :** Connecteur JST XH ou KF2510 (2 broches, pas de 2.50 mm / 2.54 mm). Ce connecteur interne polarisé reçoit le 5V et la masse (GND) depuis une prise d'alimentation déportée sur le boîtier (ex: embase USB-C panel mount avec résistances 5.1 kΩ intégrées au câble).
* **Protection contre les Courts-Circuits :** Un fusible réarmable PTC (PolySwitch, ex: Littelfuse LVR100 ou équivalent, calibré à ~2.5A/3A) est placé tout en tête du circuit, immédiatement après l'entrée 5V. Il protège les pistes du fond de panier et l'alimentation externe en cas de court-circuit matériel.
* **Protection Inversion de Polarité :** Un transistor MOSFET Canal P (**IRF9540N**) est placé en série après le fusible. Contrairement à une simple diode, il protège le système avec une chute de tension presque nulle.
* **Boutons d'Alimentation (Câblage en Parallèle) :**
  * **SW2 :** Interrupteur d'alimentation soudé directement sur le PCB (pour un usage sur banc de test).
  * **J11 :** Connecteur JST (2 broches) permettant de brancher un interrupteur principal déporté en façade du boîtier.
  * *Fonctionnement :* Ces deux éléments sont câblés en parallèle. La fermeture de l'un ou de l'autre suffit à allumer l'ordinateur, permettant d'utiliser la machine indifféremment nue sur un bureau ou fermée dans son boîtier.
* **Routage de Puissance (Zone Critique) :** La zone d'alimentation (JST d'entrée ➔ Fusible PTC ➔ MOSFET ➔ Interrupteurs ➔ Condensateur 1000 µF) concentre tout l'appel de courant du système. Elle ne doit pas être routée avec des pistes standards (0.25 mm) mais avec de **larges polygones de cuivre** (zones remplies) ou des pistes de **1.5 mm à 2 mm minimum**. Le passage du courant vers les plans internes (Couches 2 et 3) doit s'effectuer via de multiples vias (3 à 4 alignés) pour éviter toute chute de tension (Voltage Drop) fatale aux signaux 8 MHz.
* **Filtrage Étagé :**
  * *Filtrage d'entrée :* Un gros condensateur électrolytique (ex: 1000 µF) en amont pour lisser l'alimentation globale issue du bloc secteur.
  * *Filtrage localisé par slot :* Chaque connecteur DIN dispose, à son pied, de son propre duo de condensateurs : **un électrolytique de 10 µF** (pour le tirage de courant global de la carte fille) et **un céramique de 100 nF** (pour le filtrage haute fréquence du connecteur). Les cartes filles sont ainsi déchargées de la nécessité d'embarquer des condensateurs électrolytiques.

## 3. Circuit de Reset
La gestion du déclenchement manuel du Reset est centralisée sur la backplane (tandis que la carte CPU abrite la logique DS1813 pour conditionner le signal).

* **Bouton de Test :** Bouton poussoir (Tact Switch) soudé sur le PCB pour faciliter les tests à nu.
* **Bouton de Façade :** Connecteur JST (2 broches) pour brancher le bouton Reset de la façade du boîtier de manière sécurisée et polarisée.
* **Fonctionnement :** Ces deux éléments sont câblés en parallèle. Appuyer sur l'un d'eux met simplement la ligne globale `/RESET` (broche `c2`) à la masse (`GND`).

## 4. Intégrité des Signaux et Pull-ups
Le backplane assure la stabilité des signaux asynchrones et d'attente du bus.

* **Conception PCB 4 Couches :**
  * Couche 1 (Top) et Couche 4 (Bottom) dédiées au routage des signaux.
  * Couche 2 dédiée à un plan de Masse (`GND`) continu.
  * Couche 3 dédiée à un plan d'Alimentation (`5V`) continu.
* **Routage de l'Horloge :** Le signal `PHI2O` (`CLK`) doit être isolé le plus possible et idéalement entouré de pistes/plans de masse pour éviter la diaphonie avec le bus de données.
* **Résistances de Tirage (Pull-ups 3.3 kΩ) :**
  * **`/RESET` :** Maintient la ligne inactive à l'état haut par défaut.
  * **`RDY` :** Maintient le processeur actif par défaut (prépare l'usage futur du DMA).
  * **`BE` (Bus Enable) :** Autorise le processeur à piloter le bus par défaut (prépare l'usage futur du DMA).
* *(Note : Les pull-ups de `/IRQ` et `/NMI` sont gérés de manière distribuée, directement sur la carte CPU).*
* **Terminaisons :** Des empreintes peuvent être prévues aux extrémités du bus principal pour l'ajout éventuel de réseaux de résistances (Resistor Networks), au cas où des rebonds de signaux se manifesteraient à haute fréquence.

## 5. Brochage du Bus (Standard MECB adapté)
Le câblage tire parti des rangées `a` et `c` du DIN 41612. Les broches de la rangée `c` (`c13` à `c16`) croisent astucieusement les adresses hautes pour permettre un routage direct et parallèle depuis le CPU sans croisements sur le PCB.

| Broche DIN | Rangée a | Rangée c | Description |
| :--- | :--- | :--- | :--- |
| **1** | 🔴 `5V` | 🔴 `5V` | Alimentation Globale |
| **2** | 🟠 `RDY` | 🟠 `/RES` | Ready / Reset |
| **3** | 🟠 `/IRQ` | 🟠 `CLK` (`PHI2O`) | Interruption / Horloge Système |
| **4** | 🟠 `/NMI` | 🟠 `R/W` | Non-Maskable Int. / Read-Write |
| **5 à 12** | 🟢 `A0` à `A7` | 🔵 `D0` à `D7` | Bus d'Adresses Bas / Bus de Données |
| **13** | 🟢 `A8` | 🟢 `A15` | Adresses |
| **14** | 🟢 `A9` | 🟢 `A14` | Adresses |
| **15** | 🟢 `A10` | 🟢 `A13` | Adresses |
| **16** | 🟢 `A11` | 🟢 `A12` | Adresses |
| **17 à 24** | 🟣 `A16` à `A23` | ⚪ *Réservé* | Extension d'Adresses 24-bits (Prêt pour 65C816) |
| **25** | 🟠 `BE` | ⚪ *Réservé* | Bus Enable (DMA) |
| **26 à 31** | ⚪ *Libre / User* | ⚪ *Libre / User* | Signaux Customisés (Vidéo, Audio, etc.) |
| **32** | 🔴 `GND` | 🔴 `GND` | Masse Globale |