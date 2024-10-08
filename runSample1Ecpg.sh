#!/bin/sh
ecpg Project.pgc
gcc C:/MinGW/include/postgresql -c Project.c
gcc -o Project Project.o C:/MinGW/lib -lecpg
./Project
