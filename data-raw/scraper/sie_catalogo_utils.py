#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sie_catalogo_utils.py

Funciones compartidas para limpiar, parsear y exportar el catálogo de
series del SIE (Banxico). Usado por scrape_series_por_estructura.py y
por el script que arma el catálogo final (nose.py).

Por qué existe este módulo:
- El popover de "Metadatos" del SIE trae los valores con un punto final
  pegado (p. ej. "Diaria.", "16/04/2025.") porque así está en el HTML
  de Banxico. Si no se limpia, romper cualquier parseo de fecha aguas
  abajo (incluyendo el paquete siebanxico).
- El formato de fecha_inicio/fecha_fin cambia según la periodicidad de
  la serie: dd/mm/aaaa (Diaria), "Mon aaaa" (Mensual), "Mon-Mon aaaa"
  (Bimestral/Trimestral/Semestral), "aaaa" (Anual) y "NQ Mon aaaa"
  (Quincenal, 1Q = primera quincena, 2Q = segunda). Sin este parser,
  solo ~1.5% de las series (las diarias) tendrían fecha utilizable.
"""

import calendar
import datetime
import re
import unicodedata

import pandas as pd

try:
    import pyarrow as pa
    import pyarrow.parquet as pq
    _HAS_PYARROW = True
except ImportError:
    _HAS_PYARROW = False

MESES = {
    'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12,
}

# Columnas del catálogo que el sitio de Banxico entrega con un punto final
# pegado al valor (a diferencia de sector/estructura/titulo_serie).
COLUMNAS_CON_PUNTO = [
    'codigo_serie', 'periodicidad', 'tipo_cifra', 'unidad',
    'fecha_inicio', 'fecha_fin',
]

# Llave natural para detectar filas duplicadas del catálogo (misma serie,
# mismo cuadro/estructura, mismos metadatos).
LLAVE_NATURAL = [
    'sector', 'estructura', 'codigo_serie', 'periodicidad', 'tipo_cifra',
    'unidad', 'fecha_inicio_raw', 'fecha_fin_raw', 'titulo_serie',
]


def norm_space(s):
    """Reemplaza espacios non-breaking (\\xa0, comunes en HTML de Banxico)
    y colapsa espacios repetidos."""
    if not isinstance(s, str):
        return s
    s = s.replace('\xa0', ' ')
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def strip_dot(s):
    """Quita el punto final que Banxico agrega a estos valores en el
    popover de metadatos."""
    if not isinstance(s, str):
        return s
    s = s.strip()
    if s.endswith('.'):
        s = s[:-1]
    return s.strip()


def clean_valor(s):
    """Limpieza estándar para un valor crudo capturado del popover de
    metadatos: normaliza espacios y quita el punto final."""
    return strip_dot(norm_space(s))


def _last_day(y, m):
    return calendar.monthrange(y, m)[1]


def _mes_a_numero(mon):
    mon = unicodedata.normalize('NFKD', mon.lower()).encode('ascii', 'ignore').decode()
    return MESES.get(mon[:3])


def parse_period(raw, boundary):
    """Convierte una fecha cruda del SIE (ya limpia, sin punto final) a un
    datetime.date puro (sin hora / sin zona horaria).

    boundary: 'start' -> fecha_inicio (borde inicial del periodo etiquetado)
              'end'   -> fecha_fin (borde final del periodo etiquetado)

    Formatos soportados (según periodicidad):
      - dd/mm/aaaa                 (Diaria)
      - aaaa                       (Anual)
      - [1|2]Q Mon aaaa            (Quincenal)
      - Mon-Mon aaaa               (Bimestral / Trimestral / Semestral)
      - Mon aaaa                   (Mensual)

    Devuelve None si el string está vacío o no calza con ningún formato
    conocido (en vez de fallar silenciosamente con una fecha incorrecta).
    """
    if raw is None or not isinstance(raw, str) or not raw.strip():
        return None
    s = raw.strip()

    m = re.fullmatch(r'(\d{2})/(\d{2})/(\d{4})', s)
    if m:
        d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
        return datetime.date(y, mo, d)

    m = re.fullmatch(r'(\d{4})', s)
    if m:
        y = int(m.group(1))
        return datetime.date(y, 1, 1) if boundary == 'start' else datetime.date(y, 12, 31)

    m = re.fullmatch(r'([12])Q\s+([A-Za-zÁÉÍÓÚáéíóú]{3})\s+(\d{4})', s)
    if m:
        q, mon, y = m.group(1), m.group(2), int(m.group(3))
        mo = _mes_a_numero(mon)
        if mo is None:
            return None
        return datetime.date(y, mo, 1) if q == '1' else datetime.date(y, mo, _last_day(y, mo))

    m = re.fullmatch(r'([A-Za-zÁÉÍÓÚáéíóú]{3})-([A-Za-zÁÉÍÓÚáéíóú]{3})\s+(\d{4})', s)
    if m:
        mon1, mon2, y = m.group(1), m.group(2), int(m.group(3))
        mo1, mo2 = _mes_a_numero(mon1), _mes_a_numero(mon2)
        if mo1 is None or mo2 is None:
            return None
        if boundary == 'start':
            return datetime.date(y, mo1, 1)
        y2 = y if mo2 >= mo1 else y + 1  # por si algún rango cruza fin de año
        return datetime.date(y2, mo2, _last_day(y2, mo2))

    m = re.fullmatch(r'([A-Za-zÁÉÍÓÚáéíóú]{3,4})\s+(\d{4})', s)
    if m:
        mon, y = m.group(1), int(m.group(2))
        mo = _mes_a_numero(mon)
        if mo is None:
            return None
        return datetime.date(y, mo, 1) if boundary == 'start' else datetime.date(y, mo, _last_day(y, mo))

    return None


def construir_catalogo_final(df_series, df_estructuras=None):
    """Toma el catálogo crudo de series (salida de scrape_series_por_estructura.py)
    y arma la versión final: limpia texto, parsea fechas, deduplica y agrega
    `sector` si hace falta.

    Espera que df_series ya traiga columnas dot-stripped (si viene del
    scraper actualizado) pero es tolerante a valores crudos con punto por
    si se le pasa un CSV viejo.

    Si df_series no trae 'sector'/'link_estructura' (catálogos generados
    con una versión vieja del scraper), se hace merge con df_estructuras
    por 'link_estructura' si está disponible, o como último recurso por
    'titulo_estructura' (nombre) -- ese último caso puede generar
    duplicados si el mismo nombre de estructura corresponde a más de un
    cuadro, así que se imprime una advertencia.
    """
    df = df_series.copy()

    for c in df.columns:
        df[c] = df[c].map(norm_space)
    for c in COLUMNAS_CON_PUNTO:
        if c in df.columns:
            df[c] = df[c].map(strip_dot)

    if 'sector' not in df.columns:
        if df_estructuras is None:
            raise ValueError(
                "df_series no trae 'sector' y no se pasó df_estructuras para completarlo."
            )
        df_estr = df_estructuras.copy()
        for c in df_estr.columns:
            df_estr[c] = df_estr[c].map(norm_space)

        if 'link_estructura' in df.columns and 'link_estructura' in df_estr.columns:
            df_estr = df_estr.drop_duplicates(subset=['link_estructura'])
            df = df.merge(df_estr[['link_estructura', 'sector']], on='link_estructura', how='left')
        else:
            print("⚠️ catálogo sin 'link_estructura': haciendo merge por nombre de "
                  "estructura (titulo_estructura). Esto puede duplicar series si el "
                  "mismo nombre de estructura corresponde a más de un cuadro en el SIE.")
            df_estr = df_estr.drop_duplicates(subset=['sector', 'titulo_estructura'])
            df = df.merge(
                df_estr[['titulo_estructura', 'sector']],
                left_on='estructura', right_on='titulo_estructura', how='left',
            )
            if 'titulo_estructura' in df.columns:
                df = df.drop(columns=['titulo_estructura'])

    df['fecha_inicio_raw'] = df['fecha_inicio']
    df['fecha_fin_raw'] = df['fecha_fin']
    df['fecha_inicio'] = df['fecha_inicio_raw'].map(lambda s: parse_period(s, 'start'))
    df['fecha_fin'] = df['fecha_fin_raw'].map(lambda s: parse_period(s, 'end'))

    n_no_parseadas_i = ((df['fecha_inicio'].isna()) & (df['fecha_inicio_raw'] != '')).sum()
    n_no_parseadas_f = ((df['fecha_fin'].isna()) & (df['fecha_fin_raw'] != '')).sum()
    if n_no_parseadas_i or n_no_parseadas_f:
        print(f"⚠️ fechas que no se pudieron parsear: {n_no_parseadas_i} en fecha_inicio, "
              f"{n_no_parseadas_f} en fecha_fin (quedan como NaT, revisar formatos nuevos).")

    # Series sin fecha_inicio NI fecha_fin: confirmamos a mano (ver SR2750,
    # "Empleo total del IMSS" en Región Centro del cuadro CR122) que esto
    # significa que Banxico nunca publicó datos para esa serie -- el código
    # existe en el directorio pero no hay nada que consultar. Se descartan
    # del catálogo final en vez de dejarlas con fechas nulas, porque el
    # paquete siebanxico no va a poder traer datos de todos modos.
    sin_datos = df['fecha_inicio'].isna() & df['fecha_fin'].isna()
    if sin_datos.any():
        codigos_sin_datos = df.loc[sin_datos, 'codigo_serie'].tolist()
        print(f"Se descartaron las series: {','.join(codigos_sin_datos)} por falta de "
              f"valores de fecha de inicio y final")
        df = df[~sin_datos].reset_index(drop=True)

    llave = [c for c in LLAVE_NATURAL if c in df.columns]
    antes = len(df)
    df = df.drop_duplicates(subset=llave).reset_index(drop=True)
    print(f"Filas antes de deduplicar: {antes}, después: {len(df)} (se quitaron {antes - len(df)}).")

    # Series con más de un título distinto bajo el mismo código: esto refleja
    # cómo Banxico organiza sus cuadros (una misma clave de serie puede
    # aparecer con etiquetas de fila distintas en tablas distintas) y no se
    # corrige aquí automáticamente porque no hay forma de saber cuál título
    # es el "correcto" sin mirar el cuadro fuente.
    dup_titulo = df.groupby('codigo_serie')['titulo_serie'].nunique()
    n_ambiguos = (dup_titulo > 1).sum()
    if n_ambiguos:
        print(f"ℹ️ {n_ambiguos} codigo_serie tienen más de un titulo_serie distinto "
              f"(de {len(dup_titulo)} códigos únicos) — revisar manualmente si es relevante.")

    columnas_final = [
        'sector', 'estructura', 'codigo_serie', 'periodicidad', 'tipo_cifra', 'unidad',
        'fecha_inicio', 'fecha_fin', 'fecha_inicio_raw', 'fecha_fin_raw', 'titulo_serie',
    ]
    columnas_final = [c for c in columnas_final if c in df.columns]
    return df[columnas_final]


def guardar_catalogo(df_final, csv_path, parquet_path=None):
    """Guarda el catálogo final en CSV (fechas como texto ISO) y,
    opcionalmente, en Parquet con tipos correctos (fecha como date32,
    columnas de baja cardinalidad como category) y compresión zstd.

    Escribe primero a un archivo temporal y luego renombra (os.replace)
    en vez de escribir directo sobre csv_path/parquet_path. Esto evita
    fallar con "Resource deadlock avoided" cuando el archivo de destino
    es un placeholder de iCloud no descargado (pasa seguido si Drive/
    iCloud tiene la carpeta del proyecto sincronizada), y de paso deja
    la escritura atómica: si algo truena a la mitad, el archivo anterior
    queda intacto.
    """
    import os

    csv_out = df_final.copy()
    csv_out['fecha_inicio'] = csv_out['fecha_inicio'].map(lambda d: d.isoformat() if pd.notna(d) else '')
    csv_out['fecha_fin'] = csv_out['fecha_fin'].map(lambda d: d.isoformat() if pd.notna(d) else '')
    csv_tmp = str(csv_path) + '.tmp'
    csv_out.to_csv(csv_tmp, index=False, encoding='utf-8')
    os.replace(csv_tmp, csv_path)
    print(f"✅ CSV guardado: {csv_path} ({len(csv_out)} filas)")

    if parquet_path is None:
        return
    if not _HAS_PYARROW:
        print("⚠️ pyarrow no está instalado -- no se generó el Parquet. "
              "Instala con: pip install pyarrow")
        return

    pq_df = df_final.copy()
    for c in ['sector', 'periodicidad', 'tipo_cifra', 'unidad']:
        if c in pq_df.columns:
            pq_df[c] = pq_df[c].astype('category')
    for c in ['estructura', 'codigo_serie', 'titulo_serie', 'fecha_inicio_raw', 'fecha_fin_raw']:
        if c in pq_df.columns:
            pq_df[c] = pq_df[c].astype('string')

    table = pa.Table.from_pandas(pq_df, preserve_index=False)
    schema = table.schema
    fields = list(schema)
    for col in ['fecha_inicio', 'fecha_fin']:
        if col in schema.names:
            fields[schema.get_field_index(col)] = pa.field(col, pa.date32())
    table = table.cast(pa.schema(fields))
    parquet_tmp = str(parquet_path) + '.tmp'
    pq.write_table(table, parquet_tmp, compression='zstd')
    os.replace(parquet_tmp, parquet_path)
    print(f"✅ Parquet guardado: {parquet_path}")
