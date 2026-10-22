#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Apr 18 21:05:51 2025

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

# Configuración
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

# Entramos a la página principal del SIE
driver.get("https://www.banxico.org.mx/SieInternet/")
time.sleep(5)

# Sacamos todos los sectores
sectores = []

soup = BeautifulSoup(driver.page_source, "html.parser")
sector_links = soup.select("a[href*='consultarDirectorioInternetAction']")

for link in sector_links:
    # Solo agarramos el texto directo del <a> SIN meternos en los hijos (como <span>)
    nombre_sector = link.find(text=True, recursive=False).strip()
    href = link.get("href")
    link_completo = f"https://www.banxico.org.mx{href}"

    sectores.append({
        "sector": nombre_sector,
        "link": link_completo
    })

# Creamos DataFrame de sectores
df_sectores = pd.DataFrame(sectores)

# Ahora sí: scrapeamos todas las estructuras de todos los sectores
lista_estructuras = []

for idx, row in df_sectores.iterrows():
    nombre_sector = row['sector']
    url_sector = row['link']

    print(f"📥 Entrando a sector: {nombre_sector}")

    driver.get(url_sector)
    time.sleep(6)

    # Expandimos todos los botones de "ver más" si existen
    try:
        botones = driver.find_elements(By.CSS_SELECTOR, "button.mostrarElementoRamaAbierta")
        print(f"🔎 Encontrados {len(botones)} botones de despliegue.")

        for boton in botones:
            try:
                driver.execute_script("arguments[0].click();", boton)
                time.sleep(2.5)
            except Exception as e:
                print(f"⚠️ No se pudo clickear un botón: {e}")
    except Exception as e:
        print(f"⚠️ No se pudieron encontrar botones: {e}")

    # Refrescamos el page source
    html = driver.page_source
    soup = BeautifulSoup(html, "html.parser")

    # Buscamos los links a las estructuras
    links_estructuras = soup.select("a[href*='accion=consultarCuadro&idCuadro=']")

    for link_tag in links_estructuras:
        titulo = link_tag.get_text(strip=True)
        href = link_tag.get("href")
        link_completo = f"https://www.banxico.org.mx{href}"

        lista_estructuras.append({
            "sector": nombre_sector,
            "titulo_estructura": titulo,
            "link_estructura": link_completo
        })

# Convertimos a DataFrame y quitamos duplicados
df_estructuras = pd.DataFrame(lista_estructuras).drop_duplicates()

print(df_estructuras)

# Guardamos
df_estructuras.to_csv("estructuras_directorio_final.csv", index=False)

print("✅ Catálogo de estructuras guardado correctamente.")

driver.quit()

