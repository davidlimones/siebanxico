#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Apr 19 12:27:48 2025
Actualizado: usa sie_catalogo_utils para limpiar valores, parsear
fecha_inicio/fecha_fin a fechas reales (antes venían como texto con un
punto final y en 6 formatos distintos según la periodicidad), deduplicar
correctamente, y exportar tanto CSV como Parquet.

Si catalogo_series_sie.csv ya trae 'sector' y 'link_estructura' (versión
actualizada de scrape_series_por_estructura.py), no hace falta ningún
merge -- se arma el catálogo directo. Si viene de una corrida vieja del
scraper (sin esas columnas), se completa el sector haciendo merge con
estructuras_directorio_final.csv.

@author: davidlimones
"""

import pandas as pd

from sie_catalogo_utils import construir_catalogo_final, guardar_catalogo

# Cargamos el catálogo de series (crudo, dtype=str + na_filter=False para
# no perder ceros a la izquierda ni convertir celdas vacías en NaN --
# algunas series vienen con metadata incompleta, p.ej. fecha_inicio vacía)
df_series = pd.read_csv("catalogo_series_sie.csv", dtype=str, na_filter=False)

df_estructuras = None
if 'sector' not in df_series.columns:
    df_estructuras = pd.read_csv("estructuras_directorio_final.csv", dtype=str, na_filter=False)

# Limpieza + parseo de fechas + dedup (ver sie_catalogo_utils.py)
df_final = construir_catalogo_final(df_series, df_estructuras)

# Guardamos: CSV (fechas en texto ISO aaaa-mm-dd) y Parquet (fechas como
# date32, columnas categóricas, comprimido con zstd -- mucho más liviano
# que el CSV y ya tipado para pandas/duckdb/el paquete siebanxico).
guardar_catalogo(
    df_final,
    csv_path="catalogo_series_sie_final.csv",
    parquet_path="catalogo_series_sie_final.parquet",
)
