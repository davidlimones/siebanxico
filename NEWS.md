# siebanxico 0.1.0

* Versión inicial del paquete.
* Funciones para consultar series individuales (`get_sie_series()`) y en lote
  (`get_sie_series_multiple()`) con paginación automática y pausas
  configurables.
* Búsqueda de series en el catálogo interno (`buscar_en_catalogo()`); el SIE no ofrece búsqueda por palabra clave vía API.
* Obtención de metadatos de series (`get_sie_metadata()`).
* Soporte opcional para catálogo interno: `buscar_en_catalogo()`,
  `buscar_por_sector()`, `estructura_a_series()`, `resumen_catalogo()`.
* Manejo correcto de valores `N/A` del SIE (se convierten a `NA` en R).
* Gestión de errores HTTP 429 (límite de solicitudes).
