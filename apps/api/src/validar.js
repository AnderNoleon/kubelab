// Validación de la entidad "producto". Separada del servidor para poder probarla sin base de datos.

function validarProducto(body) {
  const errores = [];
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, errores: ["el cuerpo debe ser un objeto JSON"] };
  }
  const { nombre, cantidad, precio } = body;

  if (typeof nombre !== "string" || nombre.trim() === "") errores.push("nombre es obligatorio");
  else if (nombre.trim().length > 100) errores.push("nombre admite máximo 100 caracteres");

  if (!Number.isInteger(cantidad) || cantidad < 0) errores.push("cantidad debe ser un entero mayor o igual a 0");

  if (typeof precio !== "number" || !Number.isFinite(precio) || precio < 0) errores.push("precio debe ser un número mayor o igual a 0");

  if (errores.length > 0) return { ok: false, errores };
  return { ok: true, valor: { nombre: nombre.trim(), cantidad, precio: Math.round(precio * 100) / 100 } };
}

// Convierte "/productos/15" en { ruta: "/productos/:id", id: 15 }.
// La ruta normalizada se usa como etiqueta de las métricas (evita una serie por cada id).
function resolverRuta(pathname) {
  const limpio = pathname.replace(/\/+$/, "") || "/";
  const m = limpio.match(/^\/productos\/([^/]+)$/);
  if (m) {
    const id = /^\d+$/.test(m[1]) ? Number(m[1]) : NaN;
    return { ruta: "/productos/:id", id };
  }
  return { ruta: limpio, id: null };
}

module.exports = { validarProducto, resolverRuta };
