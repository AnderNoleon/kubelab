// API de inventario (KubeLab · Grupo 7)
// CRUD de productos sobre PostgreSQL, /health y /metrics para Prometheus.
const http = require("http");
const { Pool } = require("pg");
const client = require("prom-client");
const { validarProducto, resolverRuta } = require("./validar");

const PORT = Number(process.env.PORT || 3000);
const VERSION = process.env.APP_VERSION || "dev";

// DATABASE_URL llega desde Doppler (Secret kubelab-secrets). Nunca se escribe en el repositorio.
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 10 });

// ---------- Métricas ----------
client.collectDefaultMetrics(); // CPU, memoria, event loop del proceso
const peticiones = new client.Counter({
  name: "http_requests_total",
  help: "Peticiones HTTP atendidas por la API",
  labelNames: ["method", "route", "status"],
});
const duracion = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duración de las peticiones HTTP",
  labelNames: ["method", "route"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2],
});

// ---------- Utilidades ----------
function log(datos) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), servicio: "api", version: VERSION, ...datos }));
}

function enviar(res, status, data) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  res.end(status === 204 ? undefined : JSON.stringify(data));
}

function leerCuerpo(req) {
  return new Promise((resolve, reject) => {
    let datos = "";
    req.on("data", (c) => {
      datos += c;
      if (datos.length > 1e5) reject(Object.assign(new Error("cuerpo demasiado grande"), { status: 413 }));
    });
    req.on("end", () => {
      try {
        resolve(datos ? JSON.parse(datos) : null);
      } catch {
        reject(Object.assign(new Error("JSON inválido"), { status: 400 }));
      }
    });
    req.on("error", reject);
  });
}

const COLUMNAS = "id, nombre, cantidad, precio::float AS precio, creado_en, actualizado_en";

// ---------- Rutas ----------
async function manejar(req, res, ruta, id) {
  const m = req.method;

  if (m === "OPTIONS") return enviar(res, 204);

  if (ruta === "/health" && m === "GET") {
    // Liveness: el proceso responde. No depende de la base para no reiniciar pods por una caída de la base.
    return enviar(res, 200, { status: "ok", version: VERSION });
  }

  if (ruta === "/ready" && m === "GET") {
    // Readiness: solo recibe tráfico si llega a la base de datos.
    await pool.query("SELECT 1");
    return enviar(res, 200, { status: "ready" });
  }

  if (ruta === "/metrics" && m === "GET") {
    res.writeHead(200, { "Content-Type": client.register.contentType });
    return res.end(await client.register.metrics());
  }

  if (ruta === "/productos") {
    if (m === "GET") {
      const { rows } = await pool.query(`SELECT ${COLUMNAS} FROM productos ORDER BY id`);
      return enviar(res, 200, rows);
    }
    if (m === "POST") {
      const v = validarProducto(await leerCuerpo(req));
      if (!v.ok) return enviar(res, 400, { errores: v.errores });
      const { nombre, cantidad, precio } = v.valor;
      const { rows } = await pool.query(
        `INSERT INTO productos (nombre, cantidad, precio) VALUES ($1, $2, $3) RETURNING ${COLUMNAS}`,
        [nombre, cantidad, precio]
      );
      return enviar(res, 201, rows[0]);
    }
  }

  if (ruta === "/productos/:id") {
    if (!Number.isInteger(id)) return enviar(res, 400, { error: "id inválido" });
    if (m === "GET") {
      const { rows } = await pool.query(`SELECT ${COLUMNAS} FROM productos WHERE id = $1`, [id]);
      return rows[0] ? enviar(res, 200, rows[0]) : enviar(res, 404, { error: "producto no encontrado" });
    }
    if (m === "PUT") {
      const v = validarProducto(await leerCuerpo(req));
      if (!v.ok) return enviar(res, 400, { errores: v.errores });
      const { nombre, cantidad, precio } = v.valor;
      const { rows } = await pool.query(
        `UPDATE productos SET nombre = $1, cantidad = $2, precio = $3, actualizado_en = now()
         WHERE id = $4 RETURNING ${COLUMNAS}`,
        [nombre, cantidad, precio, id]
      );
      return rows[0] ? enviar(res, 200, rows[0]) : enviar(res, 404, { error: "producto no encontrado" });
    }
    if (m === "DELETE") {
      const { rowCount } = await pool.query("DELETE FROM productos WHERE id = $1", [id]);
      return rowCount ? enviar(res, 204) : enviar(res, 404, { error: "producto no encontrado" });
    }
  }

  return enviar(res, 404, { error: "ruta no encontrada" });
}

const server = http.createServer(async (req, res) => {
  const { ruta, id } = resolverRuta(new URL(req.url, "http://x").pathname);
  const fin = duracion.startTimer({ method: req.method, route: ruta });
  try {
    await manejar(req, res, ruta, id);
  } catch (e) {
    const status = e.status || 500;
    if (status === 500) log({ nivel: "error", ruta, error: e.message });
    if (!res.headersSent) enviar(res, status === 500 && ruta === "/ready" ? 503 : status, { error: e.message });
  } finally {
    fin();
    peticiones.inc({ method: req.method, route: ruta, status: res.statusCode });
    if (!["/health", "/ready", "/metrics"].includes(ruta)) {
      log({ metodo: req.method, ruta, status: res.statusCode });
    }
  }
});

server.listen(PORT, () => log({ mensaje: `API escuchando en el puerto ${PORT}` }));

// Apagado ordenado: Kubernetes envía SIGTERM al eliminar un pod o durante un RollingUpdate.
function apagar(senal) {
  log({ mensaje: `recibido ${senal}, cerrando conexiones` });
  server.close(() => pool.end().finally(() => process.exit(0)));
  setTimeout(() => process.exit(0), 10000).unref();
}
process.on("SIGTERM", () => apagar("SIGTERM"));
process.on("SIGINT", () => apagar("SIGINT"));
