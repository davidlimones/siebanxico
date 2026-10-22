# Genera el paquete listo para llevar a otra computadora (incluye el catalogo
# interno, que NO esta en GitHub). Correr desde la raiz del proyecto:
#   source("data-raw/transferencia/exportar_paquete.R")

destino <- file.path(Sys.getenv("HOME"), "Library/Mobile Documents",
                     "com~apple~CloudDocs", "Transferencia_banco")

if (!file.exists("DESCRIPTION")) stop("Corre esto desde la raiz del proyecto.")
if (!file.exists("R/sysdata.rda")) stop("Falta R/sysdata.rda (el catalogo).")

sucio <- system2("git", c("status", "--porcelain"), stdout = TRUE)
if (length(sucio) > 0) {
  warning("Hay cambios sin commit; el paquete incluira el estado actual:\n",
          paste(sucio, collapse = "\n"), call. = FALSE)
}
commit <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)
version <- read.dcf("DESCRIPTION", fields = "Version")[1, 1]

dir.create(destino, showWarnings = FALSE, recursive = TRUE)
tmp <- tempfile("build_"); dir.create(tmp)
tar <- devtools::build(path = tmp, quiet = TRUE)

# Nunca debe viajar un token ni archivos de trabajo
contenido <- utils::untar(tar, list = TRUE)
if (any(grepl("prueba_manual|data-raw|\\.Rproj\\.user", contenido))) {
  stop("El paquete incluye archivos que no deberian viajar.")
}
if (!any(grepl("R/sysdata\\.rda$", contenido))) stop("El paquete no trae el catalogo.")

archivos <- c(tar, "data-raw/transferencia/instalar_siebanxico.R")
zip_destino <- file.path(destino, sprintf("siebanxico_%s_%s.zip", version, commit))
carpeta <- file.path(tmp, "paquete"); dir.create(carpeta)
file.copy(archivos, carpeta)
oldwd <- setwd(carpeta)
utils::zip(zip_destino, list.files(), flags = "-rq")
setwd(oldwd)

message("Listo: ", zip_destino)
message("Version ", version, " (commit ", commit, "). Descargalo en la otra computadora, ",
        "descomprimelo y corre instalar_siebanxico.R.")
