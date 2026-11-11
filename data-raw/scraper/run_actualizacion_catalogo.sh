#!/bin/bash
# Actualiza el catálogo del SIE: scrapea, limpia, copia el Parquet a data-raw/,
# reconstruye R/sysdata.rda, corre las pruebas y reinstala el paquete si pasan.
#
# El código vive en este directorio; los datos de trabajo (CSV, logs y el
# entorno virtual venv_sie) viven fuera del repo, en $SIE_DATA_DIR.
#
# Uso manual:  caffeinate -i bash data-raw/scraper/run_actualizacion_catalogo.sh
# Programado:  ver com.davidlimones.actualizar_catalogo_sie.plist (1 ene y 1 jul)

set -uo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(cd "$CODE_DIR/../.." && pwd)"
DATA_DIR="${SIE_DATA_DIR:-$HOME/Documents/siebanxico_scraper}"
LOG_DIR="$DATA_DIR/logs"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/actualizacion_${TS}.log"

mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Iniciando actualización del catálogo SIE ==="
cd "$DATA_DIR" || { log "ERROR: no existe $DATA_DIR"; exit 1; }

[ -f "venv_sie/bin/activate" ] || { log "ERROR: falta $DATA_DIR/venv_sie"; exit 1; }
# shellcheck disable=SC1091
source venv_sie/bin/activate

for f in estructuras_directorio_final.csv catalogo_series_sie.csv; do
  [ -f "$f" ] && cp "$f" "${f%.csv}_bak_${TS}.csv"
done
log "Backups creados (_bak_${TS})"

paso() {  # paso <n/3> <script.py>
  log "Paso $1: $2"
  python3 "$CODE_DIR/$2" >>"$LOG_FILE" 2>&1 || { log "ERROR en $2, abortando"; exit 1; }
}
paso 1/3 scrape_catalogo_estructuras.py
paso 2/3 scrape_series_por_estructura.py   # varias horas
paso 3/3 nose.py

[ -f catalogo_series_sie_final.parquet ] || { log "ERROR: no se generó el Parquet"; exit 1; }
cp catalogo_series_sie_final.parquet "$PKG_DIR/data-raw/catalogo_series_sie_final.parquet"
log "Parquet copiado a $PKG_DIR/data-raw/"

if command -v Rscript >/dev/null 2>&1; then
  log "Reconstruyendo sysdata.rda, corriendo pruebas y reinstalando si todo pasa..."
  (cd "$PKG_DIR" && Rscript -e '
    source("data-raw/construir_catalogo.R")
    df <- as.data.frame(devtools::test())
    if (any(df$failed > 0)) stop("Hay pruebas fallidas: NO se reinstala el paquete.")
    devtools::install(upgrade = "never")
  ') >>"$LOG_FILE" 2>&1 \
    && log "Catálogo reconstruido, pruebas OK y paquete reinstalado." \
    || log "AVISO: falló la parte de R; el paquete instalado sigue siendo el anterior. Revisa $LOG_FILE"
else
  log "AVISO: Rscript no está en el PATH; corre construir_catalogo.R y las pruebas a mano."
fi

log "=== Terminado. No se hizo commit ni push. ==="
