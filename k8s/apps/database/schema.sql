-- Esquema inicial de KubeLab (APP-07). Lo ejecuta el Job db-init en cada sincronización de Argo CD.
-- Es idempotente: se puede correr muchas veces sin duplicar nada.
-- Variables que pasa el Job:  :ro_user  :ro_pass  (usuario de solo lectura para el docente, desde Doppler)

\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS productos (
  id              SERIAL PRIMARY KEY,
  nombre          VARCHAR(100)   NOT NULL,
  cantidad        INTEGER        NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
  precio          NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (precio >= 0),
  creado_en       TIMESTAMPTZ    NOT NULL DEFAULT now(),
  actualizado_en  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- Datos de ejemplo solo si la tabla está vacía
INSERT INTO productos (nombre, cantidad, precio)
SELECT * FROM (VALUES
  ('Laptop', 5, 7500.00),
  ('Monitor 24 pulgadas', 12, 1400.00),
  ('Teclado mecánico', 20, 450.00),
  ('Mouse inalámbrico', 35, 120.00)
) AS datos(nombre, cantidad, precio)
WHERE NOT EXISTS (SELECT 1 FROM productos);

-- Usuario de solo lectura (ACC-03): se crea si no existe y su clave se sincroniza con Doppler
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'ro_user', :'ro_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'ro_user') \gexec

SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'ro_user', :'ro_pass') \gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'ro_user') \gexec
GRANT USAGE ON SCHEMA public TO :"ro_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"ro_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO :"ro_user";
