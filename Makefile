CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -g

all: test_ex1 test_ex2 test_ex3 demo_matrices

test_ex1: test_ex1.c matrice.c matrice_alloc.c matrice.h matrice_alloc.h
	$(CC) $(CFLAGS) -DMAT_TEST_ALLOC test_ex1.c matrice.c matrice_alloc.c -o test_ex1

test_ex2: test_ex2.c matrice.c matrice_alloc.c matrice_io.c matrice.h matrice_alloc.h matrice_io.h
	$(CC) $(CFLAGS) -DMAT_TEST_ALLOC test_ex2.c matrice.c matrice_alloc.c matrice_io.c -o test_ex2

test_ex3: test_ex3.c matrice.c matrice_alloc.c matrice_calcul.c matrice.h matrice_alloc.h matrice_calcul.h
	$(CC) $(CFLAGS) -DMAT_TEST_ALLOC test_ex3.c matrice.c matrice_alloc.c matrice_calcul.c -o test_ex3

demo_matrices: main.c matrice.c matrice_alloc.c matrice_io.c matrice_calcul.c matrice.h matrice_alloc.h matrice_io.h matrice_calcul.h
	$(CC) $(CFLAGS) main.c matrice.c matrice_alloc.c matrice_io.c matrice_calcul.c -o demo_matrices

clean:
	rm -f *.o test_ex1 test_ex2 test_ex3 demo_matrices test_ex2_sortie.txt
