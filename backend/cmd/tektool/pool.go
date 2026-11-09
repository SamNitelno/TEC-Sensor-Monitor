package main

import "github.com/jackc/pgx/v5/pgxpool"

type pgxPool struct{ *pgxpool.Pool }
