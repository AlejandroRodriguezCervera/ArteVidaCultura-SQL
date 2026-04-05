# ArteVidaCultura — Base de Datos Relacional en MySQL

Proyecto académico desarrollado para el **Máster en Big Data, Data Science e 
Inteligencia Artificial** de la **Universidad Complutense de Madrid**.

## Descripción

Diseño e implementación completa de una base de datos relacional para la gestión 
de una empresa de eventos culturales ficticia llamada **ArteVida Cultural**.

El proyecto cubre todo el ciclo de desarrollo de una base de datos:
desde el modelo Entidad-Relación hasta la implementación en SQL con consultas 
de distinto nivel de complejidad.

## Contenido del proyecto

- **Modelo Entidad-Relación** — diseño conceptual con entidades, relaciones y cardinalidades
- **Diseño lógico** — traducción del modelo ER al modelo relacional
- **DDL** — creación de tablas, claves primarias, claves foráneas y restricciones de dominio
- **Triggers** — control del aforo, validación de valoraciones y restricciones de participación
- **Inserción de datos** — datos de prueba para 100 personas, 25 artistas, 20 eventos y 15 ubicaciones
- **Vistas** — vista resumen de eventos utilizada en consultas posteriores
- **Consultas SQL** — 10 consultas de distinto nivel de complejidad:
  subconsultas, funciones ventana, agregaciones y joins múltiples

## Estructura de la base de datos

| Tabla       | Descripción                                      |
|-------------|--------------------------------------------------|
| `persona`   | Datos personales de artistas y asistentes        |
| `telefono`  | Teléfonos de contacto (atributo multivalorado)   |
| `artista`   | Especialización de persona con datos artísticos  |
| `actividad` | Tipos de actividades culturales                  |
| `ubicacion` | Espacios con aforo y precio de alquiler          |
| `evento`    | Eventos con fecha, hora, precio y ubicación      |
| `asiste`    | Relación persona-evento con valoración           |
| `participa` | Relación artista-evento con pago                 |

## Tecnologías

- **MySQL / MySQL Workbench**
- **LaTeX** — para la memoria del proyecto

## Autor

**Alejandro Rodríguez Cervera**  
Máster en Big Data, Data Science e Inteligencia Artificial  
Universidad Complutense de Madrid — Curso 2026-27
