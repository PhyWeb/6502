# Documentation Technique - Carte Mémoire Unifiée & Gestion Cartouche

## 1. Vue d'Ensemble de l'Architecture
Dans cette architecture optimisée, la gestion de la mémoire (RAM et ROM) est centralisée sur une seule et unique carte. Le port d'extension pour les cartouches (Connecteur Edge) n'est plus sur une carte fille, mais directement soudé et intégré au fond de panier (Backplane) passif de l'ordinateur[cite: 1, 3]. 

Cette "Carte Mémoire Unifiée" agit comme le chef d'orchestre du système de stockage. Elle gère la mémoire vive (SRAM), la mémoire morte interne (BIOS et EHBasic), et coordonne logiciellement le transfert du bus d'adresses vers le port cartouche externe.

## 2. Spécifications de la Carte Mémoire Unifiée
* **Composants principaux :**
  * **SRAM 512 Ko** (AS6C4008-55) : Pour la mémoire vive[cite: 3].
  * **EEPROM / Flash 32 Ko** (ex: 28C256 ou 39SF040) : Pour la ROM interne.
  * **GAL** (ATF16V8B) : Puce logique gérant le décodage d'adresses de tout le système[cite: 3].
  * **Registre octal** (`74HC574`) : Utilisé pour la pagination (Banking) de la RAM et le contrôle d'activation de la cartouche[cite: 3].
  * **Buffer Tri-State** (ex: `74HC125` ou `74HC244`) : Pour permettre au processeur de lire l'état de détection matérielle de la cartouche.

* **Connexion :** La carte s'insère dans l'un des slots verticaux DIN 41612 (Rangées a et c) du fond de panier[cite: 1, 3].

## 3. Map Mémoire et Pagination

L'espace mémoire est découpé par le GAL de la carte unifiée. La zone Entrées/Sorties (I/O) reste strictement réservée et protégée sur une petite plage de 256 octets[cite: 3].

| Plage d'Adresses | Taille | Description et Routage | 
| ----- | ----- | ----- | 
| `$0000 - $1FFF` | 8 Ko | **RAM Fixe (SRAM)** : Page Zéro, Pile, Variables. Forcé sur la Banque 0[cite: 3]. | 
| `$2000 - $7FFF` | 24 Ko | **RAM Bankée (SRAM)** : Fenêtre dynamique pointant vers l'une des 32 banques[cite: 3]. | 
| `$8000 - $80FF` | 256 o. | **Entrées / Sorties (I/O)** : Réservé aux périphériques (VIA, UART)[cite: 3] et aux registres de la carte mémoire (ex: `$8000`). | 
| `$8100 - $DFFF` | ~23,75 Ko | **Espace Applicatif (Basculable)** : Par défaut, pointe vers la **ROM Interne** (EHBasic)[cite: 3]. Peut être basculé vers le **Port Cartouche** par le logiciel. | 
| `$E000 - $FFFF` | 8 Ko | **ROM Fixe (BIOS)** : Pointe toujours vers la **ROM Interne**. Contient WozMon, le bootloader, les routines matérielles et vecteurs d'interruption[cite: 3]. | 

## 4. Gestion de la Cartouche et Latch Logiciel
Le système de cartouche repose sur une coopération entre le fond de panier, le registre de la carte mémoire, et le logiciel (BIOS).

### A. Détection Physique (Fond de Panier -> Carte Mémoire)
Le connecteur Edge étant sur le fond de panier[cite: 1], une broche libre du bus MECB (ex: dans les broches `a26` à `a31` ou rangée `c` libres) est définie comme le signal `/CART_DETECT`[cite: 1, 3].
* Sur le fond de panier, insérer une cartouche relie physiquement cette ligne à la masse (`GND`).
* Sur la carte mémoire, cette ligne est tirée à 5V (Pull-up) et connectée à l'entrée d'un **Buffer Tri-State**.
* Le CPU peut lire l'état de ce signal en lisant une adresse I/O spécifique (ex: `LDA $8000`), ce qui active le buffer et pousse l'état (1 ou 0) sur le bit de données `D7`.

### B. Activation Matérielle (Latch Logiciel `CART_EN`)
Le composant `74HC574` possède 8 bits de sortie[cite: 3]. 
* **5 bits** sont utilisés pour paginer les 512 Ko de SRAM (32 banques de 24 Ko)[cite: 3].
* **1 bit** est défini comme **`CART_EN`** (Cartridge Enable).
* Le CPU écrit dans ce registre via une adresse I/O (ex: `STA $8000`).
* **Si `CART_EN = 0` (Par défaut au Reset) :** Le GAL force l'activation de la ROM interne sur la plage `$8100 - $DFFF`[cite: 3]. La cartouche est ignorée.
* **Si `CART_EN = 1` :** Le GAL désactive la ROM interne sur la plage `$8100 - $DFFF` et libère le bus, permettant à la cartouche de répondre aux requêtes d'adresse[cite: 3].

## 5. Séquence de Démarrage (Boot Menu)
Puisque le signal `CART_EN` est initialisé à `0` lors d'un Reset matériel, la machine démarre **toujours** sur la ROM interne (le BIOS) en `$E000`, indépendamment de la présence d'une cartouche[cite: 3].

Le BIOS exécute la séquence suivante :
1. **Initialisation :** Setup du processeur et des registres VIA.
2. **Vérification Cartouche :** Le logiciel lit le registre d'état (`LDA $8000`). Il regarde le bit `D7`.
3. **Affichage du Menu :** L'ordinateur affiche un menu (via le port série) avec 3 choix principaux :
   * **[1] Lancer EHBasic :** Fait un simple `JMP` vers l'adresse d'EHBasic situé dans la ROM interne en `$8100`[cite: 3].
   * **[2] Lancer la Cartouche :** Uniquement si le bit `D7` indique une présence. Le logiciel met `CART_EN` à `1` (`STA $8000`), ce qui fait disparaître EHBasic du bus au profit de la cartouche, puis effectue un saut (`JMP $8100`) ou lit le vecteur de la cartouche[cite: 3].
   * **[3] WozMon (Moniteur) :** Reste dans le BIOS en ROM fixe pour permettre l'envoi de code en SRAM via le port série[cite: 3].

## 6. Conception des Cartouches (Architecture "Mapper")
Afin de conserver une Carte Mémoire simple, la logique de pagination (Banking) des jeux volumineux n'est pas gérée par la carte mère.
* Une cartouche simple (≤ 23,75 Ko) ne contient qu'une puce ROM reliée directement au connecteur Edge.
* Une cartouche évoluée (ex: 512 Ko) doit embarquer **sa propre puce de registre** (son propre `74HC574` ou circuit logique équivalent) pour servir de "Mapper".
* Ce composant embarqué écoutera le bus d'adresses et changera les banques de la ROM de la cartouche lorsqu'il interceptera des écritures du CPU sur une adresse I/O allouée aux cartouches (ex: `$8010`).