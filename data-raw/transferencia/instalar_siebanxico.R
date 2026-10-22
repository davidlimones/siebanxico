# Instala siebanxico desde el .tar.gz que esta en la misma carpeta que este
# script. En R, desde esa carpeta:
#   setwd("ruta/a/la/carpeta")
#   source("instalar_siebanxico.R")

dependencias <- c("httr", "jsonlite", "glue", "tibble", "dplyr", "purrr",
                  "stringr", "stringi")
lib <- .libPaths()[1]   # cambia si necesitas otra biblioteca

paquete <- list.files(pattern = "^siebanxico_.*\\.tar\\.gz$")
if (length(paquete) != 1) stop("Debe haber exactamente un siebanxico_*.tar.gz aqui.")

faltan <- setdiff(dependencias, rownames(installed.packages()))
if (length(faltan) > 0) {
  stop("Faltan dependencias: ", paste(faltan, collapse = ", "),
       ". Instalalas o pidelas a TI antes de continuar.")
}

if ("siebanxico" %in% loadedNamespaces()) unloadNamespace("siebanxico")
if ("siebanxico" %in% rownames(installed.packages(lib.loc = lib))) {
  remove.packages("siebanxico", lib = lib)
}

install.packages(paquete, repos = NULL, type = "source", lib = lib)

library(siebanxico, lib.loc = lib)
cat("\nsiebanxico", as.character(packageVersion("siebanxico", lib.loc = lib)), "instalado.\n")
if (exists("catalogo_series_sie", envir = asNamespace("siebanxico"), inherits = FALSE)) {
  resumen_catalogo()
} else {
  warning("El catalogo interno no esta disponible en esta instalacion.")
}
cat("\nSiguiente paso: set_sie_token('TU_TOKEN')\n")
