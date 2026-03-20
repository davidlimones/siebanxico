# utils.R — Funciones internas de utilidad

# Operador "valor por defecto": devuelve y si x es NULL o de longitud 0
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
