---
name: kiji-reglas
description: Reglas fijas de Kiji Player sobre claves, privacidad y publicación. Usar antes de cualquier commit, push, release, captura o prueba, y siempre que se toquen archivos de firma, datos del usuario o contenido público (README, notas, capturas).
---

# Reglas de Kiji Player

Estas reglas no se negocian. Si una tarea choca con alguna, detenerse y preguntar.

## Claves y firma
- No abrir, leer, copiar ni mover la carpeta `kiji-keys`.
- Nunca commitear claves ni secretos: `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `.env*`,
  cookies, tokens de cuentas ni `google-services.json` ajenos. Antes de cada commit, revisar
  `git status` y `git diff --cached --stat`.
- Kiji se firma siempre con la MISMA clave (certificado `CN=Kiji Player`). Nunca generar ni usar
  otra: cambiarla obliga a desinstalar y se pierden los datos de quien la usa.

## Publicación
- Kiji Dev (`io.github.kijiplayer.kiji.dev`) nunca se publica: ni en releases, ni en tiendas, ni
  como adjunto.
- No subir versión, crear etiquetas ni publicar releases sin la aprobación explícita del mantenedor.

## Privacidad
- Kiji no recopila datos personales: sin telemetría, sin analíticas, sin servidores propios. Nada
  sale del dispositivo sin que la persona lo pida.
- Nada personal en lo público (repo, commits, notas, issues, capturas): ni nombres, ni país, ni
  correos, ni datos del equipo de nadie.

## Contenido en capturas y pruebas
- Sin letras, portadas ni canciones reales en capturas, tests, reportes o notas. Usar datos
  inventados (por ejemplo, "Glass Harbor — The Velvet Tides") o de dominio público.
- Antes de compartir una captura, comprobar que no se vea nada de otras apps (notificaciones,
  barra de estado) ni contenido real.
