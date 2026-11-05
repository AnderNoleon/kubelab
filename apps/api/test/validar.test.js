const { test } = require("node:test");
const assert = require("node:assert/strict");
const { validarProducto, resolverRuta } = require("../src/validar");

test("acepta un producto válido y limpia el nombre", () => {
  const r = validarProducto({ nombre: "  Laptop ", cantidad: 3, precio: 7500.456 });
  assert.equal(r.ok, true);
  assert.deepEqual(r.valor, { nombre: "Laptop", cantidad: 3, precio: 7500.46 });
});

test("rechaza nombre vacío, cantidad negativa y precio inválido", () => {
  const r = validarProducto({ nombre: "", cantidad: -1, precio: "caro" });
  assert.equal(r.ok, false);
  assert.equal(r.errores.length, 3);
});

test("rechaza cantidad con decimales", () => {
  assert.equal(validarProducto({ nombre: "Mouse", cantidad: 1.5, precio: 10 }).ok, false);
});

test("rechaza cuerpos que no son objetos", () => {
  for (const cuerpo of [null, [], "texto", 5]) assert.equal(validarProducto(cuerpo).ok, false);
});

test("normaliza rutas con id para las métricas", () => {
  assert.deepEqual(resolverRuta("/productos/15"), { ruta: "/productos/:id", id: 15 });
  assert.deepEqual(resolverRuta("/productos/"), { ruta: "/productos", id: null });
  assert.equal(Number.isNaN(resolverRuta("/productos/abc").id), true);
  assert.deepEqual(resolverRuta("/health"), { ruta: "/health", id: null });
});
