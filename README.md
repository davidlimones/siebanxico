# siebanxico <img src="https://www.banxico.org.mx/favicon.ico" align="right" height="40"/>

<!-- badges: start -->
[![R-CMD-check](https://github.com/davidlimones/siebanxico/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/davidlimones/siebanxico/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

Cliente en R para consultar series de tiempo del **Sistema de Información Económica (SIE)** del Banco de México mediante su [API REST](https://www.banxico.org.mx/SieAPIRest/service/v1/).

## Características

- Descarga de series individuales o en lote.
- Agrupación automática en bloques de hasta 80 series (límite de la API).
- Pausa configurable entre bloques para no saturar la API.
- Manejo de valores faltantes (`N/A` del SIE → `NA` en R).
- Búsqueda de series por palabra clave vía API.
- Soporte opcional para un catálogo interno con autocompletado de fechas y exploración temática.

## Instalación

```r
# Desde GitHub (requiere el paquete remotes)
remotes::install_github("davidlimones/siebanxico")
```

## Token de la API

Para usar el paquete necesitas un token gratuito del SIE. Puedes tramitarlo en:

👉 <https://www.banxico.org.mx/SieAPIRest/service/v1/token>

Una vez que lo tengas, configúralo al inicio de tu sesión:

```r
library(siebanxico)
set_sie_token("aqui_va_tu_token")
```

Para no escribirlo cada vez, puedes guardarlo en tu `.Renviron`:

```
BANXICO_TOKEN=aqui_va_tu_token
```

y cargarlo automáticamente desde tu `.Rprofile`:

```r
siebanxico::set_sie_token(Sys.getenv("BANXICO_TOKEN"))
```

## Uso básico

### Consultar una serie individual

```r
library(siebanxico)
set_sie_token("tu_token")

# Tipo de cambio FIX (SF43718)
tc <- get_sie_series("SF43718", start = "2020-01-01", end = "2023-12-31")
tc
#> # A tibble: 1,044 × 3
#>    fecha      valor serie
#>    <date>     <dbl> <chr>
#>  1 2020-01-02  18.9 SF43718
#>  2 2020-01-03  18.8 SF43718
#>  ...
```

### Consultar varias series a la vez

```r
series <- c("SF43718",   # Tipo de cambio FIX
            "SF46410",   # TIIE 28 días
            "SF60653")   # Inflación mensual

datos <- get_sie_series_multiple(
  ids   = series,
  start = "2020-01-01",
  pause = 30            # segundos entre bloques (default: 60)
)
```

### Obtener metadatos de una serie

```r
get_sie_metadata("SF43718")
#> # A tibble: 1 × 7
#>   id      titulo                  frecuencia unidad banco   fecha_inicio fecha_fin
#>   <chr>   <chr>                   <chr>      <chr>  <chr>   <date>       <date>
#> 1 SF43718 Tipo de cambio para ... Diaria     Pesos  Banxico 1991-11-11   NA
```

## Funciones del catálogo interno (opcional)

El paquete puede aprovechar un catálogo con metadatos de miles de series del SIE para autocompletar fechas y explorar la estructura temática. Este catálogo **no se distribuye en el repositorio público**; consulta [`data-raw/README.md`](data-raw/README.md) para instrucciones.

Cuando el catálogo está disponible:

```r
# Buscar series por tema
buscar_en_catalogo("inflacion")
buscar_por_sector("mercado de dinero")

# Obtener todas las series de una estructura temática
ids <- estructura_a_series("Tipo de cambio")
datos <- get_sie_series_multiple(ids)

# Ver resumen del catálogo
resumen_catalogo()
```

## Límites de la API

| Concepto                  | Límite               |
|---------------------------|----------------------|
| Series por petición       | hasta 80             |
| Observaciones por serie   | hasta 5,000          |
| Solicitudes simultáneas   | 1 por token          |

La función `get_sie_series_multiple()` maneja automáticamente el límite de 80 series por bloque. Usa el parámetro `pause` (segundos entre bloques) para evitar el error HTTP 429. El valor por defecto es **60 segundos**, suficientemente conservador para uso normal.

```r
# Para consultas grandes, aumenta la pausa si recibes errores 429
get_sie_series_multiple(muchas_ids, pause = 90)
```

## Referencia de funciones

| Función                      | Descripción                                                 |
|------------------------------|-------------------------------------------------------------|
| `set_sie_token()`            | Configura el token de la API                                |
| `get_sie_series()`           | Descarga una serie individual                               |
| `get_sie_series_multiple()`  | Descarga múltiples series con paginación automática         |
| `get_sie_metadata()`         | Metadatos de una serie                                      |
| `parse_sie_response()`       | Parsea el JSON crudo de la API                              |
| `buscar_en_catalogo()`       | Busca en el catálogo interno (requiere catálogo)            |
| `buscar_por_sector()`        | Filtra por sector económico (requiere catálogo)             |
| `estructura_a_series()`      | Claves de series de una estructura (requiere catálogo)      |
| `resumen_catalogo()`         | Resumen del catálogo interno (requiere catálogo)            |

## Recursos

- [Documentación oficial de la API del SIE](https://www.banxico.org.mx/SieAPIRest/service/v1/doc/catalogoSeries)
- [Portal del SIE](https://www.banxico.org.mx/SIE/)
- [Trámite de token](https://www.banxico.org.mx/SieAPIRest/service/v1/token)

## Licencia

MIT © David Limones. Este paquete no tiene afiliación oficial con el Banco de México.
