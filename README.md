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

## Introduction

Ce TD consiste à développer en C une petite bibliothèque permettant de créer, lire, écrire, afficher et calculer des matrices d’entiers. Le code est réparti en modules afin de séparer les interfaces (`.h`), les implémentations (`.c`) et le programme de démonstration.

Les objectifs principaux sont de pratiquer la programmation modulaire et la compilation séparée, de gérer dynamiquement la mémoire, de traiter proprement les erreurs et de vérifier l’absence de fuites mémoire.

À la date de rédaction de cette partie, **l’exercice 1 est terminé et ses 16 vérifications réussissent**. Valgrind indique également qu’aucune fuite mémoire ni erreur mémoire n’a été détectée pour `test_ex1`. Les exercices 2 à 4 ne sont pas documentés ici.

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

Pour une allocation réussie, `mat_allouer` effectue `n + 1` allocations : une pour le tableau de pointeurs et une pour chacune des `n` lignes. La destruction effectue également `n + 1` libérations. Si l’allocation d’une ligne échoue après que `k` lignes ont été allouées, la fonction libère ces `k` lignes et le tableau de pointeurs, soit `k + 1` appels à `free`. Si l’allocation initiale du tableau échoue, aucune libération n’est nécessaire.

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
