// Prueba de carga para demostrar el HorizontalPodAutoscaler (HA-05).
// Requiere estar conectado a la VPN y tener docs/hosts.txt en el archivo hosts.
//   k6 run loadtest/k6-carga.js
// En otra terminal, mirar el escalado:
//   kubectl get hpa -n kubelab -w
import http from "k6/http";
import { check, sleep } from "k6";

const API = __ENV.API || "http://api.grupo7.lab";
const WEB = __ENV.WEB || "http://app.grupo7.lab";

export const options = {
  stages: [
    { duration: "30s", target: 20 },  // calentamiento
    { duration: "3m", target: 60 },   // carga sostenida: aquí debe subir de 2 a más réplicas
    { duration: "30s", target: 0 },   // fin
  ],
  thresholds: {
    http_req_failed: ["rate<0.02"],      // menos de 2 % de errores
    http_req_duration: ["p(95)<1500"],   // 95 % de respuestas en menos de 1,5 s
  },
};

export default function () {
  const lista = http.get(`${API}/productos`);
  check(lista, { "API lista productos (200)": (r) => r.status === 200 });

  const salud = http.get(`${API}/health`);
  check(salud, { "API /health (200)": (r) => r.status === 200 });

  const web = http.get(`${WEB}/`);
  check(web, { "web responde (200)": (r) => r.status === 200 });

  sleep(0.2);
}
