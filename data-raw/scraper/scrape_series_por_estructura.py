#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Apr 18 21:44:50 2025
Actualizado: agrega sector y link_estructura a cada serie (para poder
armar el catálogo final sin depender de un merge por nombre de
estructura, que puede duplicar series -- ver sie_catalogo_utils.py), y
limpia los valores crudos del popover de metadatos (Banxico los entrega
con un punto final pegado, p. ej. "Diaria.", "16/04/2025.").

@author: davidlimones
"""

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import pandas as pd
import time

from sie_catalogo_utils import clean_valor

# Configuración
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

# Cargamos estructuras
estructuras_df = pd.read_csv("estructuras_directorio_final.csv")

# Data
series_data = []

for idx, row in estructuras_df.iterrows():
    sector = row['sector']
    estructura_titulo = row['titulo_estructura']
    estructura_url = row['link_estructura']

    print(f"📥 Entrando a estructura: {estructura_titulo}")
    driver.get(estructura_url)
    time.sleep(4)

    html = driver.page_source
    soup = BeautifulSoup(html, "html.parser")

    botones_series = soup.find_all("button", attrs={"data-original-title": "Metadatos"})

    if not botones_series:
        print(f"⚠️ No se encontraron series en la estructura: {estructura_titulo}")
        continue

    for boton in botones_series:
        try:
            data_content = boton.get("data-content")
            contenido_soup = BeautifulSoup(data_content, "html.parser")

            contenedor = contenido_soup.find("div", class_="bm-popover-metadatos")
            if not contenedor:
                print(f"⚠️ No se encontró contenedor de metadatos en una serie de: {estructura_titulo}")
                continue

            metadatos = {
                "codigo_serie": "",
                "periodicidad": "",
                "tipo_cifra": "",
                "unidad": "",
                "fecha_inicio": "",
                "fecha_fin": ""
            }

            for fila in contenedor.find_all("div", recursive=False):
                columnas = fila.find_all("div")
                if len(columnas) == 2:
                    etiqueta = columnas[0].get_text(strip=True).replace('\xa0', ' ').lower()
                    valor = clean_valor(columnas[1].get_text(strip=True))

                    if "serie" in etiqueta:
                        metadatos['codigo_serie'] = valor
                    elif "periodicidad" in etiqueta:
                        metadatos['periodicidad'] = valor
                    elif "tipo de cifra" in etiqueta:
                        metadatos['tipo_cifra'] = valor
                    elif "tipo de unidad" in etiqueta:
                        metadatos['unidad'] = valor
                    elif "fecha inicial" in etiqueta:
                        metadatos['fecha_inicio'] = valor
                    elif "fecha final" in etiqueta:
                        metadatos['fecha_fin'] = valor

            # Extraemos el nombre de la serie
            span = boton.find("span", class_="sr-only")
            if span:
                texto_span = span.get_text(strip=True)
                if "Mostrar metadatos de la serie" in texto_span:
                    nombre_serie = texto_span.replace("Mostrar metadatos de la serie", "").strip()
                else:
                    nombre_serie = ""
            else:
                nombre_serie = ""

            # Guardamos (con sector y link_estructura, para armar el catálogo
            # final sin ambigüedad -- ver nose.py / sie_catalogo_utils.py)
            series_data.append({
                "sector": sector,
                "estructura": estructura_titulo,
                "link_estructura": estructura_url,
                "codigo_serie": metadatos['codigo_serie'],
                "periodicidad": metadatos['periodicidad'],
                "tipo_cifra": metadatos['tipo_cifra'],
                "unidad": metadatos['unidad'],
                "fecha_inicio": metadatos['fecha_inicio'],
                "fecha_fin": metadatos['fecha_fin'],
                "titulo_serie": nombre_serie
            })

        except Exception as e:
            print(f"⚠️ Error procesando una serie en {estructura_titulo}: {e}")

# Creamos DataFrame final
df_series = pd.DataFrame(series_data)

# Orden de columnas
columnas = ["sector", "estructura", "link_estructura", "codigo_serie", "periodicidad",
            "tipo_cifra", "unidad", "fecha_inicio", "fecha_fin", "titulo_serie"]
df_series = df_series[columnas]

# Deduplicamos por si el mismo botón de metadatos quedó capturado más de
# una vez en la página (pasaba antes y era la causa de gran parte de las
# filas repetidas en el catálogo final).
antes = len(df_series)
df_series = df_series.drop_duplicates(
    subset=["sector", "link_estructura", "codigo_serie", "periodicidad",
            "tipo_cifra", "unidad", "fecha_inicio", "fecha_fin", "titulo_serie"]
).reset_index(drop=True)
print(f"Filas antes de deduplicar: {antes}, después: {len(df_series)}")

# Guardamos
df_series.to_csv("catalogo_series_sie.csv", index=False)
print("✅ Catálogo de series actualizado correctamente.")

driver.quit()
