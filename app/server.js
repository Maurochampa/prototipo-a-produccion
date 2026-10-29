'use strict';
// App mínima "estilo prototipo": un contador de visitas guardado en PostgreSQL.
// Lo importante del laboratorio no es la app, sino todo lo que la rodea.
const http = require('node:http');
const { Pool } = require('pg');

const PORT = Number(process.env.PORT) || 3000;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 5 });

async function iniciarBase(intentos = 15) {
  for (let i = 1; i <= intentos; i++) {
    try {
      await pool.query(`CREATE TABLE IF NOT EXISTS visitas (
        id     SERIAL PRIMARY KEY,
        creada TIMESTAMPTZ NOT NULL DEFAULT now()
      )`);
      return;
    } catch (err) {
      console.error(`Base no disponible (intento ${i}/${intentos}): ${err.message}`);
      await new Promise((r) => setTimeout(r, 2000));
    }
  }
  throw new Error('No se pudo conectar a la base de datos');
}

function responder(res, estado, cuerpo) {
  res.writeHead(estado, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(cuerpo));
}

const server = http.createServer(async (req, res) => {
  const ruta = (req.url || '/').split('?')[0];
  try {
    if (req.method === 'GET' && ruta === '/health') {
      await pool.query('SELECT 1');
      return responder(res, 200, { estado: 'ok', base: 'ok' });
    }
    if (req.method === 'GET' && ruta === '/') {
      await pool.query('INSERT INTO visitas DEFAULT VALUES');
      const { rows } = await pool.query('SELECT count(*)::int AS total FROM visitas');
      return responder(res, 200, { mensaje: 'Hola desde producción', visitas: rows[0].total });
    }
    return responder(res, 404, { error: 'No encontrado' });
  } catch (err) {
    console.error(err.message);
    return responder(res, 503, { estado: 'error', detalle: 'base de datos no disponible' });
  }
});

// Apagado prolijo: Docker manda SIGTERM antes de matar el contenedor
function apagar(senal) {
  console.log(`Recibí ${senal}, cerrando conexiones...`);
  server.close(() => pool.end().finally(() => process.exit(0)));
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', () => apagar('SIGTERM'));
process.on('SIGINT', () => apagar('SIGINT'));

iniciarBase()
  .then(() => server.listen(PORT, () => console.log(`Escuchando en el puerto ${PORT}`)))
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
