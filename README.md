# TD — Stockage de matrices en C

**Membres du binôme**
- Mathéo Lobjois — GitHub : `MatheoLobjois`
- Oscar Lousteau — GitHub : `Oscarlst-0`

**Groupe de TD :** `TD2`  


## Table des matières

- [Introduction](#introduction)
- [Conception](#conception)
- [Réalisation — Exercice 1 : allocation et destruction](#réalisation--exercice-1--allocation-et-destruction)
  - [Étapes 1.a et 1.b — `matrice.c`](#étapes-1a-et-1b--matricec)
  - [Étapes 1.c à 1.f — `matrice_alloc.c`](#étapes-1c-à-1f--matrice_allocc)
  - [Questions de réflexion](#questions-de-réflexion)
  - [Tests de l’exercice 1](#tests-de-lexercice-1)
  - [Vérification mémoire](#vérification-mémoire)
- [Réalisation — Exercice 2 : entrées-sorties](#réalisation--exercice-2--entrées-sorties)
  - [Étapes 2.a à 2.f — `matrice_io.c`](#étapes-2a-à-2f--matrice_ioc)
  - [Questions de réflexion](#questions-de-réflexion-1)
  - [Compilation et tests de l’exercice 2](#compilation-et-tests-de-lexercice-2)
- [Réalisation — Exercice 3 : calcul matriciel](#réalisation--exercice-3--calcul-matriciel)
  - [Addition — étapes 3.a à 3.d](#addition--étapes-3a-à-3d)
  - [Multiplication — étapes 3.e à 3.h](#multiplication--étapes-3e-à-3h)
  - [Questions de réflexion](#questions-de-réflexion-2)
  - [Compilation et tests de l’exercice 3](#compilation-et-tests-de-lexercice-3)

## Introduction

Ce TD consiste à développer en C une petite bibliothèque permettant de créer, lire, écrire, afficher et calculer des matrices d’entiers. Le code est réparti en modules afin de séparer les interfaces (`.h`), les implémentations (`.c`) et le programme de démonstration.

Les objectifs principaux sont de pratiquer la programmation modulaire et la compilation séparée, de gérer dynamiquement la mémoire, de traiter proprement les erreurs et de vérifier l’absence de fuites mémoire.

Les exercices 1 et 2 sont testés avec succès : `test_ex1` réussit ses 16 vérifications et `test_ex2` ses 14 vérifications. L’exercice 3 est également validé : `test_ex3` réussit ses 14 vérifications sur 14. Valgrind ne détecte aucune fuite ni erreur mémoire pour les trois programmes de test.

## Conception

### Organisation des modules

La bibliothèque prévue par le sujet est composée de quatre modules et d’un programme principal.

| Module | Rôle |
|---|---|
| `matrice.c` / `matrice.h` | Type `Matrice`, codes d’erreur, messages d’erreur et validation d’une matrice |
| `matrice_alloc.c` / `matrice_alloc.h` | Allocation et destruction des matrices |
| `matrice_io.c` / `matrice_io.h` | Lecture, écriture et affichage |
| `matrice_calcul.c` / `matrice_calcul.h` | Addition et multiplication |
| `main.c` | Programme de démonstration qui utilise les modules |

Le programme principal utilise les fonctions des modules pour lire les matrices, effectuer les calculs demandés, afficher le résultat et éventuellement l’enregistrer. Les modules d’entrées-sorties et de calcul s’appuient sur les fonctions communes et sur le module d’allocation. Le module de calcul n’a pas besoin du module d’entrées-sorties.

### Graphe des inclusions

Les dépendances principales sont les suivantes :

```text
matrice.c         -> matrice.h
matrice_alloc.c   -> matrice_alloc.h -> matrice.h
matrice_io.c      -> matrice_io.h -> matrice.h
matrice_calcul.c  -> matrice_calcul.h -> matrice.h
main.c            -> les en-têtes nécessaires aux fonctions utilisées
```

Chaque fichier `.c` inclut son propre en-tête afin que le compilateur puisse vérifier la cohérence entre les prototypes et les définitions. Les gardes `#ifndef`, `#define` et `#endif` empêchent qu’un même en-tête soit traité plusieurs fois dans une unité de compilation, ce qui éviterait notamment des redéfinitions de types.

### Représentation et propriété de la mémoire

Une matrice est représentée par une structure `Matrice` contenant un pointeur `int **coef`, un nombre de lignes et un nombre de colonnes. `coef` pointe vers un tableau de pointeurs ; chaque pointeur désigne une ligne d’entiers allouée séparément. Pour une matrice de 2 lignes et 3 colonnes, la mémoire peut être représentée schématiquement ainsi :

```text
variable m (structure Matrice)
+-------------------+
| coef  ------------|----+
| nb_lignes = 2     |    |
| nb_colonnes = 3   |    |
+-------------------+    v
                    tableau de pointeurs (coef)
                    +---------+---------+
                    | coef[0] | coef[1] |
                    +----|----+----|----+
                         |         |
                         v         v
                    ligne 0    ligne 1
                    +---+---+---+  +---+---+---+
                    | 0 | 0 | 0 |  | 0 | 0 | 0 |
                    +---+---+---+  +---+---+---+
```

Les lignes et le tableau de pointeurs sont des allocations distinctes. Avec `calloc`, les coefficients sont initialisés à zéro. À l’état `MATRICE_VIDE`, aucun stockage de coefficients n’est possédé par la matrice ; après `mat_detruire`, la structure revient à cet état.

#### Contrats de gestion mémoire du sujet (R1 à R7)

Les règles suivantes définissent qui initialise, conserve et libère la mémoire :

- **R1 — Initialisation :** toute variable de type `Matrice` est initialisée à `MATRICE_VIDE` dès sa déclaration.
- **R2 — Succès et transfert de propriété :** une fonction qui renvoie `MAT_OK` et remplit `*res` transfère la propriété du résultat à l’appelant. Celui-ci devra appeler `mat_detruire(&res)` (avec la variable de matrice concernée).
- **R3 — Échec :** une fonction qui échoue laisse `*res` égal à `MATRICE_VIDE` et libère tout ce qu’elle a alloué. L’appelant n’a rien à libérer.
- **R4 — Entrées non modifiées :** une fonction ne modifie ni ne libère jamais une matrice reçue en entrée sous la forme `const Matrice *`.
- **R5 — Paramètre de sortie :** l’ancien contenu de `*res` est écrasé. Si ce contenu possédait de la mémoire, l’appelant doit l’avoir détruite avant l’appel. `res` doit être distinct des paramètres d’entrée.
- **R6 — Destruction idempotente :** `mat_detruire` remet la matrice à `MATRICE_VIDE` ; un second appel est sans effet.
- **R7 — Flux de fichiers :** le code qui ouvre un fichier est responsable de sa fermeture. Les fonctions de `matrice_io` reçoivent un flux déjà ouvert et ne le ferment jamais.

Dans l’exercice 1, `mat_allouer` suit notamment R1 à R3 et R5 : le résultat doit être vide au départ, les allocations partielles sont nettoyées en cas d’échec, et la propriété est transférée à l’appelant uniquement en cas de succès. `mat_detruire` applique R6 en libérant d’abord chaque ligne, puis le tableau de pointeurs, avant de remettre la structure à `MATRICE_VIDE`. R4 et R7 seront également à respecter dans les fonctions qui manipulent des matrices en entrée et dans le module d’entrées-sorties.

La fonction `mat_calloc` permet de simuler des échecs d’allocation lorsque le programme de test est compilé avec `-DMAT_TEST_ALLOC`. En cas d’échec partiel, seules les lignes déjà allouées sont libérées, puis le tableau de pointeurs. Les dimensions sont contrôlées avant l’allocation et limitées à `MAT_DIM_MAX`. La détection des dépassements arithmétiques lors des calculs matriciels sera documentée avec l’exercice 3.

### Compilation de l’exercice 1

Commande utilisée pour compiler le test de l’exercice 1 :

```sh
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex1.c matrice.c matrice_alloc.c -o test_ex1
```

## Réalisation — Exercice 1 : allocation et destruction

L’exercice 1 porte sur `matrice.c` et `matrice_alloc.c`. Les extraits ci-dessous présentent uniquement les parties complétées, et non les fichiers entiers.

### Étapes 1.a et 1.b — `matrice.c`

**Étape 1.a — Messages d’erreur**

Deux cas ont été ajoutés à `mat_message_erreur` afin de renvoyer un message explicite pour les dimensions incompatibles et le dépassement de capacité d’un entier.

```c
case MAT_ERR_DIMENSIONS:
    return "dimensions incompatibles";
case MAT_ERR_DEPASSEMENT:
    return "dépassement de capacité d'entier";
```

**Étape 1.b — Validation d’une matrice**

`mat_est_valide` vérifie que le pointeur vers la matrice et le pointeur vers les coefficients ne sont pas nuls, et que les deux dimensions sont comprises entre `1` et `MAT_DIM_MAX`.

```c
return m != NULL
    && m->coef != NULL
    && m->nb_lignes >= 1 && m->nb_lignes <= MAT_DIM_MAX
    && m->nb_colonnes >= 1 && m->nb_colonnes <= MAT_DIM_MAX;
```

L’utilisation de `&&` permet de s’arrêter dès qu’une condition est fausse. Ainsi, si `m == NULL`, les champs de la structure ne sont pas consultés.

Code source : [`matrice.c`](matrice.c).

### Étapes 1.c à 1.f — `matrice_alloc.c`

**Étape 1.c — Refus des dimensions invalides**

Les dimensions sont contrôlées avant toute allocation. Une valeur inférieure à `1` ou supérieure à `MAT_DIM_MAX` entraîne le retour de `MAT_ERR_ARGUMENT`. Comme `*res` a déjà été initialisé à `MATRICE_VIDE`, le résultat reste vide en cas d’erreur.

```c
if (nb_lignes < 1 || nb_lignes > MAT_DIM_MAX
    || nb_colonnes < 1 || nb_colonnes > MAT_DIM_MAX)
    return MAT_ERR_ARGUMENT;
```

**Étape 1.d — Allocation des lignes et gestion d’un échec partiel**

Chaque ligne est allouée séparément avec `mat_calloc`. Si une allocation échoue, les lignes précédemment allouées sont libérées, puis le tableau de pointeurs. La fonction renvoie ensuite `MAT_ERR_ALLOCATION`.

```c
for (int i = 0; i < nb_lignes; i++) {
    coef[i] = mat_calloc((size_t)nb_colonnes, sizeof *coef[i]);
    if (coef[i] == NULL) {
        for (int k = i - 1; k >= 0; k--)
            free(coef[k]);
        free(coef);
        return MAT_ERR_ALLOCATION;
    }
}
```

**Étape 1.e — Validation du résultat**

La structure de sortie n’est renseignée qu’une fois toutes les allocations réussies. La fonction transfère alors la propriété de la mémoire à l’appelant en enregistrant le pointeur et les dimensions, puis renvoie `MAT_OK`.

```c
res->coef = coef;
res->nb_lignes = nb_lignes;
res->nb_colonnes = nb_colonnes;
return MAT_OK;
```

**Étape 1.f — Destruction**

La destruction libère les lignes avant le tableau de pointeurs. Enfin, l’affectation fournie remet la matrice à `MATRICE_VIDE`, ce qui rend un second appel sans danger.

```c
if (m->coef != NULL) {
    for (int i = 0; i < m->nb_lignes; i++) {
        free(m->coef[i]);
    }
    free(m->coef);
}
*m = MATRICE_VIDE;
```

Code source : [`matrice_alloc.c`](matrice_alloc.c).

### Questions de réflexion

#### Q3.1 — Pourquoi `mat_detruire` prend-elle un `Matrice *` et non un `Matrice` ?

`mat_detruire` doit modifier la matrice de l’appelant en remettant sa structure à `MATRICE_VIDE`. Il faut donc lui transmettre son adresse, de type `Matrice *`. Avec un passage par valeur, seule une copie de la structure serait modifiée : le pointeur de la variable d’origine ne serait pas remis à `NULL` et ses dimensions ne seraient pas remises à zéro. L’appelant pourrait alors conserver une structure contenant des adresses déjà libérées.

#### Q3.2 — Combien d’appels à `calloc` et à `free` pour une matrice de taille `n × p` ?

Pour une allocation réussie, `mat_allouer` effectue `n + 1` appels à `calloc` : un pour le tableau de pointeurs et un pour chacune des `n` lignes. La destruction effectue `n + 1` appels à `free`. Si l’allocation d’une ligne échoue après que `k` lignes ont été allouées, la fonction a effectué `k + 2` appels à `calloc` (en comptant l’appel qui échoue), puis libère les `k` lignes déjà allouées et le tableau de pointeurs, soit `k + 1` appels à `free`. Si l’allocation initiale du tableau échoue, un appel à `calloc` a été effectué et aucune libération n’est nécessaire.

#### Q3.3 — Pourquoi deux appels à `mat_detruire` sont-ils sans danger ? Qu’en est-il d’une copie `Matrice b = a` ?

Après le premier appel, `mat_detruire` affecte `MATRICE_VIDE` à la matrice. Au deuxième appel, `coef` vaut donc `NULL` et aucune zone déjà libérée n’est libérée à nouveau. En revanche, `Matrice b = a` copie seulement les champs et le pointeur, pas les données allouées. `a` et `b` désignent alors la même mémoire : détruire les deux structures l’une après l’autre peut provoquer une double libération. Il ne faut donc pas faire cette copie lorsqu’on souhaite partager la propriété de la mémoire.

#### Q3.4 — Pourquoi `mat_allouer` commence-t-elle par `*res = MATRICE_VIDE` avant de vérifier les dimensions ?

Cela garantit que le résultat est vide si les dimensions sont invalides ou si une allocation échoue. L’appelant peut ainsi s’appuyer sur la règle R3 : après un échec, `*res` vaut `MATRICE_VIDE` et la fonction a libéré les zones qu’elle avait réservées. Cette affectation suppose que `res` n’est pas `NULL`, ce qui est vérifié juste avant.

### Tests de l’exercice 1

Commande exécutée :

```sh
./test_ex1
```

Sortie du terminal :

```text
=== Exercice 1 : matrice.c ===
[OK]    (1.a) message pour MAT_ERR_DIMENSIONS
[OK]    (1.a) message pour MAT_ERR_DEPASSEMENT
[OK]    (1.b) une matrice 1 x 2 est valide
[OK]    (1.b) NULL n'est pas valide
[OK]    (1.b) MATRICE_VIDE n'est pas valide
[OK]    (1.b) une matrice de 0 ligne n'est pas valide

=== Exercice 1 : matrice_alloc.c ===
[OK]    (1.c) mat_allouer refuse 0 ligne
[OK]    (1.c) mat_allouer refuse -2 colonnes
[OK]    (1.c) mat_allouer refuse une dimension > MAT_DIM_MAX
[OK]    (1.e) mat_allouer(&m, 3, 4) renvoie MAT_OK
[OK]    (1.e) m a 3 lignes et 4 colonnes
[OK]    (1.d) tous les coefficients valent 0
[OK]    (1.f) apres mat_detruire, m est vide
[OK]    (1.f) un second mat_detruire est sans danger
[OK]    (1.f) mat_detruire(NULL) ne plante pas

=== Exercice 1 : echecs d'allocation simules ===
[OK]    (1.d) chaque echec renvoie MAT_ERR_ALLOCATION et laisse *res vide

Bilan : 16 / 16 verifications reussies.
Pensez a verifier l'absence de fuite : valgrind --leak-check=full ./test_ex1
```

**Bilan :** les 16 vérifications réussissent, y compris les tests simulant des échecs d’allocation. Cela confirme le refus des dimensions invalides, l’initialisation à zéro, la destruction et le maintien d’un résultat vide en cas d’échec d’allocation.

### Vérification mémoire

Commande exécutée :

```sh
valgrind --leak-check=full ./test_ex1
```

Résumé Valgrind :

```text
HEAP SUMMARY:
    in use at exit: 0 bytes in 0 blocks
  total heap usage: 11 allocs, 11 frees, 1,228 bytes allocated

All heap blocks were freed -- no leaks are possible

ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

**Conclusion :** toutes les zones allouées pendant le test ont été libérées. Valgrind ne signale ni fuite mémoire ni erreur mémoire pour `test_ex1`.


## Réalisation — Exercice 2 : entrées-sorties

L’exercice 2 porte sur le fichier `matrice_io.c`. Il consiste à afficher une matrice, à l’écrire dans un fichier texte, puis à la relire en détectant les données invalides.

Le format texte défini par le sujet est le suivant :
- la première ligne contient le nombre de lignes et le nombre de colonnes ;
- les lignes suivantes contiennent les coefficients, séparés par des espaces.

Les fonctions `mat_lire` et `mat_ecrire` reçoivent un flux déjà ouvert. Elles ne font donc appel ni à `fopen` ni à `fclose` : conformément à la règle R7, le code appelant ferme le flux.

### Étapes 2.a à 2.f — `matrice_io.c`

#### 2.a — Affichage d’une matrice

La fonction `mat_afficher` affiche le nom de la matrice et ses dimensions. Deux boucles imbriquées parcourent ensuite les lignes et les colonnes. Le format `%8d` réserve huit caractères pour chaque coefficient afin d’aligner les colonnes.

```c
for (int i = 0; i < m->nb_lignes; i++) {
    for (int j = 0; j < m->nb_colonnes; j++) {
        printf(" %8d", m->coef[i][j]);
    }
    putchar('\n');
}
```

#### 2.b — Écriture dans un fichier

La fonction `mat_ecrire` vérifie d’abord que le flux est valide et que la matrice est valide. Elle écrit ensuite les dimensions, puis les coefficients ligne par ligne.

Le premier coefficient de chaque ligne est écrit avec `%d`, et les suivants avec ` %d`. Cela évite de mettre un espace après le dernier coefficient de la ligne. Chaque opération d’écriture est vérifiée : un échec de `fprintf`, de `fputc` ou de `fflush` entraîne le retour de `MAT_ERR_ECRITURE`.

```c
for (int i = 0; i < m->nb_lignes; i++) {
    for (int j = 0; j < m->nb_colonnes; j++) {
        if (fprintf(f, j == 0 ? "%d" : " %d",
                    m->coef[i][j]) < 0) {
            return MAT_ERR_ECRITURE;
        }
    }
    if (fputc('\n', f) == EOF) {
        return MAT_ERR_ECRITURE;
    }
}
```

Après les écritures, `fflush(f)` force l’écriture du tampon. Si cette opération échoue, la fonction renvoie également `MAT_ERR_ECRITURE`. En cas de réussite, elle renvoie `MAT_OK`.

#### 2.c — Vérification des dimensions lues

La fonction `mat_lire` lit les deux dimensions avec la fonction interne `lire_entier`. Elle vérifie ensuite que chacune est comprise entre `1` et `MAT_DIM_MAX`.

```c
if (nb_lignes < 1 || nb_lignes > MAT_DIM_MAX ||
    nb_colonnes < 1 || nb_colonnes > MAT_DIM_MAX) {
    return MAT_ERR_FORMAT;
}
```

Si les dimensions ne respectent pas ces limites, la fonction renvoie `MAT_ERR_FORMAT`, car le problème vient du contenu du fichier.

#### 2.d — Allocation d’une matrice temporaire

Une matrice locale `tmp` est allouée aux dimensions lues.

```c
Matrice tmp;
err = mat_allouer(&tmp, nb_lignes, nb_colonnes);
if (err != MAT_OK) {
    return err;
}
```

L’utilisation d’une matrice temporaire permet de ne pas transmettre à l’appelant une matrice partiellement remplie. Si l’allocation échoue, `mat_lire` renvoie l’erreur obtenue.

#### 2.e — Lecture des coefficients

Deux boucles imbriquées parcourent la matrice temporaire. Chaque coefficient est lu par `lire_entier`, qui détecte notamment les données non numériques, les entiers hors de la plage d’un `int` et les fins de fichier prématurées.

```c
for (int i = 0; i < nb_lignes; i++) {
    for (int j = 0; j < nb_colonnes; j++) {
        err = lire_entier(f, &tmp.coef[i][j]);
        if (err != MAT_OK) {
            mat_detruire(&tmp);
            return err;
        }
    }
}
```

Si la lecture d’un coefficient échoue, `tmp` est détruite avant le retour. Cette étape est essentielle pour éviter les fuites mémoire. Comme `*res` a été initialisé à `MATRICE_VIDE` au début de la fonction, il reste vide en cas d’échec.

#### 2.f — Transfert du résultat

Lorsque toutes les lectures réussissent, la propriété de la matrice temporaire est transférée à l’appelant :

```c
*res = tmp;
return MAT_OK;
```

L’appelant devient responsable de la mémoire et devra appeler `mat_detruire` lorsqu’il n’aura plus besoin de la matrice, conformément à la règle R2.

### Questions de réflexion

#### Q4.1 — Pourquoi `mat_lire` remplit-elle d’abord une matrice locale ?

La matrice temporaire évite de transmettre un résultat incomplet à l’appelant. Si une lecture échoue, la fonction détruit la matrice temporaire et renvoie l’erreur. Le paramètre de sortie `*res` reste ainsi égal à `MATRICE_VIDE`. Le transfert n’a lieu que si tous les coefficients ont été lus correctement.

#### Q4.2 — La lecture impose-t-elle une ligne de texte par ligne de matrice ?

Non. `lire_entier` utilise `fscanf` avec le format `%31s`, qui ignore les espaces, les tabulations et les sauts de ligne avant de lire le prochain mot. Les coefficients peuvent donc être séparés par différents espaces blancs, même si les lignes du fichier ne correspondent pas exactement aux lignes de la matrice.

Cette tolérance facilite la lecture. À l’inverse, l’écriture produit un format régulier et défini, avec un espace entre les coefficients et un saut de ligne à la fin de chaque ligne.

#### Q4.3 — Comment lire deux matrices dans un même fichier ?

Après avoir lu les dimensions et tous les coefficients attendus, `mat_lire` laisse le flux positionné juste après le dernier coefficient. Il est donc possible d’appeler une deuxième fois `mat_lire` sur le même flux pour lire une seconde matrice, sans fermer ni rouvrir le fichier entre les deux appels.

#### Q4.4 — Pourquoi appeler `fflush` ? Cela dispense-t-il de vérifier `fclose` ?

`fflush` force l’écriture des données présentes dans le tampon et permet de détecter certaines erreurs avant que `mat_ecrire` renvoie `MAT_OK`. Cela ne dispense toutefois pas l’appelant de vérifier le résultat de `fclose`, car une erreur peut encore apparaître au moment de la fermeture du fichier.

### Compilation et tests de l’exercice 2

Pour compiler le programme de test de l’exercice 2 :

```sh
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex2.c matrice.c matrice_alloc.c matrice_io.c -o test_ex2
```

Puis lancer les tests et vérifier la mémoire :

```sh
./test_ex2
valgrind --leak-check=full ./test_ex2
```

Résultats obtenus lors de l’exécution :

- **14 / 14 vérifications réussies**.
- L’affichage de la matrice `4 × 3` est conforme aux quatre lignes attendues.
- L’écriture et la relecture fonctionnent ; le contenu relu est identique à la matrice initiale.
- Les espaces et sauts de ligne supplémentaires sont tolérés.
- Les fichiers incorrects sont détectés : fichier vide, dimension nulle ou négative, coefficient manquant, donnée non numérique et entier trop grand pour un `int`.
- L’échec d’allocation simulé renvoie correctement `MAT_ERR_ALLOCATION`.

Résumé Valgrind :

```text
HEAP SUMMARY:
    in use at exit: 0 bytes in 0 blocks
  total heap usage: 51 allocs, 51 frees, 60,728 bytes allocated
All heap blocks were freed -- no leaks are possible
ERROR SUMMARY: 0 errors from 0 contexts
```

**Conclusion :** les 14 vérifications de l’exercice 2 réussissent. Les 51 allocations recensées ont toutes été libérées ; Valgrind ne signale aucune fuite mémoire ni erreur mémoire.

## Réalisation — Exercice 3 : calcul matriciel

L’exercice 3 ajoute les opérations d’addition et de multiplication de matrices dans `matrice_calcul.c`. Les fonctions doivent vérifier les dimensions, allouer une matrice résultat indépendante, détecter les dépassements de capacité et respecter les règles de propriété mémoire décrites plus haut.

Le fichier fourni contient une fonction auxiliaire `verifier_parametres`, qui refuse notamment un pointeur de sortie `res` nul ou identique à l’une des entrées. Elle initialise `*res` à `MATRICE_VIDE` avant de vérifier les matrices d’entrée. La fonction `tient_dans_int` vérifie qu’une valeur calculée en `long long` peut être représentée par un `int`.

### Addition — étapes 3.a à 3.d

**3.a — Vérification des dimensions**

L’addition n’est définie que si les deux matrices ont le même nombre de lignes et le même nombre de colonnes. Sinon, la fonction renvoie `MAT_ERR_DIMENSIONS`.

```c
if (a->nb_lignes != b->nb_lignes ||
    a->nb_colonnes != b->nb_colonnes)
    return MAT_ERR_DIMENSIONS;
```

**3.b — Allocation du résultat**

Une matrice locale `r`, initialisée à `MATRICE_VIDE`, est allouée aux mêmes dimensions que `a`. Si `mat_allouer` échoue, l’erreur est renvoyée directement ; comme le résultat de sortie a été initialisé par `verifier_parametres`, `*res` reste vide.

```c
Matrice r = MATRICE_VIDE;
err = mat_allouer(&r, a->nb_lignes, a->nb_colonnes);
if (err != MAT_OK)
    return err;
```

**3.c — Calcul des coefficients et détection du dépassement**

Chaque coefficient du résultat est la somme des coefficients correspondants des deux matrices. La conversion en `long long` est faite avant l’addition afin d’éviter un dépassement de type `int` pendant le calcul. La somme est ensuite vérifiée avec `tient_dans_int`. Si elle ne tient pas dans un `int`, la matrice temporaire est détruite et la fonction renvoie `MAT_ERR_DEPASSEMENT`.

```c
long long s = (long long)a->coef[i][j] + b->coef[i][j];
if (!tient_dans_int(s)) {
    mat_detruire(&r);
    return MAT_ERR_DEPASSEMENT;
}
r.coef[i][j] = (int)s;
```

**3.d — Transfert du résultat**

Une fois tous les coefficients calculés, la propriété de la matrice locale `r` est transférée à `*res`, puis la fonction renvoie `MAT_OK` :

```c
*res = r;
return MAT_OK;
```

Cette étape est implémentée dans `matrice_calcul.c`. Le transfert copie la structure et son pointeur dans le paramètre de sortie ; il ne faut donc pas détruire `r` après cette affectation. L’appelant devient responsable de la mémoire du résultat et devra la libérer avec `mat_detruire`.

### Multiplication — étapes 3.e à 3.h

**3.e — Compatibilité des dimensions**

Le produit `a × b` est défini si le nombre de colonnes de `a` est égal au nombre de lignes de `b`.

```c
if (a->nb_colonnes != b->nb_lignes)
    return MAT_ERR_DIMENSIONS;
```

**3.f — Dimensions et allocation du résultat**

Si `a` a les dimensions `n × p` et `b` les dimensions `p × q`, le résultat a les dimensions `n × q`.

```c
Matrice r = MATRICE_VIDE;
err = mat_allouer(&r, a->nb_lignes, b->nb_colonnes);
if (err != MAT_OK)
    return err;
```

**3.g — Produit scalaire et dépassements**

Chaque coefficient `r[i][j]` est obtenu en calculant la somme des produits `a[i][k] * b[k][j]`. Le produit est calculé en `long long`, puis la somme est protégée contre un dépassement de `long long`. Enfin, la somme complète est vérifiée pour s’assurer qu’elle tient dans un `int`. En cas d’erreur, `r` est détruite avant le retour.

```c
long long s = 0;
for (int k = 0; k < a->nb_colonnes; k++) {
    long long p = (long long)a->coef[i][k] * b->coef[k][j];
    if ((p > 0 && s > LLONG_MAX - p) ||
        (p < 0 && s < LLONG_MIN - p)) {
        mat_detruire(&r);
        return MAT_ERR_DEPASSEMENT;
    }
    s += p;
}
if (!tient_dans_int(s)) {
    mat_detruire(&r);
    return MAT_ERR_DEPASSEMENT;
}
r.coef[i][j] = (int)s;
```

**3.h — Transfert du résultat**

La fonction `mat_multiplier` termine actuellement le calcul en transférant correctement la propriété de la matrice résultat :

```c
*res = r;
return MAT_OK;
```

Cette affectation transfère la structure et son pointeur ; il ne faut donc pas détruire `r` après ce transfert. La matrice de sortie devient responsable de la mémoire allouée.

### Questions de réflexion

#### Q5.1 — Que protège `const Matrice *a` ?

`const Matrice *a` empêche de modifier les membres de la structure `Matrice` à travers `a`, par exemple `a->nb_lignes = 5`. En revanche, si le membre `coef` est de type `int **`, le `const` ne rend pas les entiers pointés constants : l’expression `a->coef[0][0] = 7` reste autorisée par le compilateur. Pour empêcher aussi la modification des coefficients à travers ce pointeur, il faut concevoir le type de `coef` avec des pointeurs vers des entiers constants, par exemple `const int * const *coef` pour une vue de lecture seule adaptée. Ce changement de type doit être répercuté de manière cohérente dans les déclarations et les fonctions qui construisent ou modifient les matrices ; il ne suffit pas d’ajouter `const` au paramètre seul.

#### Q5.2 — Pourquoi refuser `mat_additionner(&a, &b, &a)` ?

Même si l’expression mathématique `a ← a + b` a un sens, le contrat de cette bibliothèque impose que le résultat soit distinct des matrices d’entrée. `verifier_parametres` refuse donc `res == a` ou `res == b`. Si cet alias était accepté avec l’implémentation actuelle, `*res = MATRICE_VIDE` au début de la fonction écraserait la structure `a` avant le calcul : le pointeur vers son allocation serait perdu, ce qui provoquerait une fuite mémoire et rendrait l’entrée invalide.

#### Q5.3 — Combien de multiplications effectue `mat_multiplier` ?

Pour une matrice `a` de taille `n × p` et une matrice `b` de taille `p × q`, chaque coefficient du résultat nécessite `p` multiplications. Il y a `n × q` coefficients dans le résultat : le nombre total de multiplications est donc `n × p × q`. Pour deux matrices `1000 × 1000`, cela représente `1000³ = 1 000 000 000`, soit **un milliard de multiplications**.

#### Q5.4 — Pourquoi ne pas tester le dépassement après `int s = a + b` ?

Si l’addition de deux `int` dépasse les limites du type, le comportement est indéfini en C. Le résultat peut donc déjà être invalide avant le test `s < a` ; le compilateur n’est pas tenu de produire un résultat qui permettrait de détecter le dépassement. Il faut élargir les opérandes avant l’opération, comme dans `(long long)a + b`, puis vérifier que le résultat tient dans la plage de `int` avant de le convertir.

### Compilation et tests de l’exercice 3

Commande utilisée :

```sh
gcc -std=c11 -Wall -Wextra -Wpedantic -g -DMAT_TEST_ALLOC \
    test_ex3.c matrice.c matrice_alloc.c matrice_calcul.c -o test_ex3
```

Exécution et contrôle mémoire :

```sh
./test_ex3
valgrind --leak-check=full ./test_ex3
```

**Résultat obtenu : 14 / 14 vérifications réussies.** Tous les tests d’addition, de multiplication et les cas particuliers passent :

```text
=== Exercice 3 : addition ===
[OK]    (3.a) (2 x 3) + (3 x 2) : MAT_ERR_DIMENSIONS
[OK]    (3.d) (2 x 3) + (2 x 3) : MAT_OK
[OK]    (3.c) a + b est correct
[OK]    a et b n'ont pas ete modifiees
[OK]    (3.b) le resultat possede sa propre memoire
[OK]    (3.c) INT_MAX + 1 : MAT_ERR_DEPASSEMENT
=== Exercice 3 : multiplication ===
[OK]    (3.e) (2 x 3) x (2 x 3) : MAT_ERR_DIMENSIONS
[OK]    (3.h) (2 x 3) x (3 x 2) : MAT_OK
[OK]    (3.g) a x c = (58 64 / 139 154)
[OK]    (3.f) (3 x 2) x (2 x 3) donne une matrice 3 x 3
[OK]    a et c n'ont pas ete modifiees
[OK]    (3.g) 2 x 10^10 depasse INT_MAX : MAT_ERR_DEPASSEMENT
=== Exercice 3 : cas particuliers ===
[OK]    resultat = entree refuse, a reste intacte
[OK]    (3.f) echec d'allocation : MAT_ERR_ALLOCATION, r vide

Bilan : 14 / 14 verifications reussies.
```

Les tests confirment la vérification des dimensions, la justesse des calculs, la détection des dépassements d’entiers, la non-modification des matrices d’entrée, l’indépendance de la mémoire du résultat et la gestion d’un échec d’allocation.

Résumé Valgrind obtenu :

```text
HEAP SUMMARY:
    in use at exit: 0 bytes in 0 blocks
  total heap usage: 37 allocs, 37 frees, 1,412 bytes allocated
All heap blocks were freed -- no leaks are possible
ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

Les 37 allocations ont toutes été libérées. Valgrind confirme l’absence de fuite mémoire et d’erreur mémoire pour `test_ex3`.

### Critères de validation de l’exercice 3

- [x] `test_ex3` compile sans avertissement visible dans la commande fournie.
- [x] `./test_ex3` affiche `Bilan : 14 / 14`.
- [x] Valgrind affiche `All heap blocks were freed -- no leaks are possible` et `ERROR SUMMARY: 0 errors from 0 contexts`.
- [x] Les étapes de calcul de `matrice_calcul.c` sont implémentées, notamment le transfert du résultat dans `mat_additionner` et `mat_multiplier`.

