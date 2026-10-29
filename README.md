# Del prototipo a producción

Laboratorio para practicar lo que pasa **después** de que una app funciona en tu
máquina: llevarla a un entorno de producción seguro, observable y recuperable.

La app es mínima a propósito (un contador de visitas en PostgreSQL). Lo que
importa es todo lo que la rodea.

## Arquitectura

```
Navegador ──HTTPS──▶ Caddy (proxy) ──▶ App Node.js ──▶ PostgreSQL
                       │                                   │
                cabeceras de seguridad              backups diarios
                certificado TLS                     verificados con restore
```

| Pieza | Qué demuestra |
|---|---|
| `app/Dockerfile` | Imagen chica, sin root, con healthcheck |
| `compose.yaml` | Servicios con dependencias por salud, reinicio automático, volúmenes persistentes |
| `Caddyfile` | HTTPS, compresión y cabeceras de seguridad |
| `scripts/backup.sh` | Backups comprimidos, chequeados y con retención |
| `scripts/verificar-backup.sh` | Restore de prueba: un backup sin probar no es un backup |
| `.github/workflows/ci.yml` | El stack completo se levanta y se prueba en cada push |
| Timer de systemd | Backup diario automático |

## Comandos

```bash
docker compose up -d --build     # levantar todo
docker compose ps                # ver estado y salud
docker compose logs -f app       # ver logs de la app
./scripts/backup.sh              # backup manual
./scripts/verificar-backup.sh    # probar el último backup
docker compose down              # bajar (los datos quedan en los volúmenes)
```

La app queda en `https://localhost:8443` (certificado propio del laboratorio).

## Pasarlo a un VPS real

1. Copiar el proyecto al servidor y crear el `.env` con una contraseña nueva.
2. En `Caddyfile`, cambiar `https://localhost:...` por tu dominio y borrar `tls internal`.
3. En `compose.yaml`, cambiar el puerto del proxy por `"80:80"` y `"443:443"`.
4. `docker compose up -d --build` y listo: Caddy saca el certificado de Let's Encrypt solo.
