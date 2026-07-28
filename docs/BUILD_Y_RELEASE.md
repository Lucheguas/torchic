# 📦 Cómo exportar y publicar Torchic

Guía para generar la **versión final (release)** del juego y publicarla en GitHub para que la gente la descargue. Cualquiera del equipo debería poder seguir estos pasos.

---

## 0. Requisitos previos (una sola vez)

1. **Godot 4.7.1** (mismo que el proyecto): https://godotengine.org/download/
   - El proyecto usa el renderer *GL Compatibility*, no hace falta configurar nada extra.
2. **Plantillas de exportación** de esa misma versión:
   - Abre Godot → menú **Editor → Manage Export Templates → Download and Install**.
   - Descarga ~700 MB. Sin esto no se puede exportar.
   - Comprueba que la versión de las plantillas coincide **exactamente** con la del editor (`4.7.1.stable`).

> El preset de exportación ya está versionado en el repo (`export_presets.cfg`), así que no hay que configurarlo a mano.

---

## 1. Generar la build final

Hay dos formas. Ambas producen el mismo resultado: **un solo `Torchic.exe`** con todo embebido.

### Opción A — Desde el editor (recomendada si no usas consola)

1. Abre el proyecto (`project.godot`) en Godot.
2. Menú **Project → Export**.
3. Selecciona el preset **"Windows Desktop"** (ya viene configurado).
4. Pulsa **Export Project...**.
5. En la ventana que se abre, **DESMARCA la casilla "Export With Debug"** (abajo). Esto es lo que hace que sea versión final y no debug.
6. Elige dónde guardar (por ejemplo `build/windows/Torchic.exe`) y confirma.

### Opción B — Por consola (más rápida y reproducible)

Desde la carpeta del proyecto, ejecutando el binario de Godot:

```powershell
# Ajusta la ruta a tu ejecutable de Godot
& "RUTA\A\Godot_v4.7.1-stable_win64.exe" --headless `
  --path "." `
  --export-release "Windows Desktop" `
  "build/windows/Torchic.exe"
```

- `--export-release` → genera la versión final (usar `--export-debug` daría la de depuración; **no** la queremos).
- Si la carpeta `build/windows` no existe, créala antes:
  ```powershell
  New-Item -ItemType Directory -Force -Path "build\windows" | Out-Null
  ```

### Cómo saber que salió una build release (no debug)

- Se genera **un único** `Torchic.exe` (~116 MB con el pack embebido).
- **NO** aparece un `Torchic.console.exe` al lado. Si aparece, es build de debug o el "console wrapper" está activado.

---

## 2. Comprimir en ZIP

```powershell
Compress-Archive -Path "build\windows\Torchic.exe" `
  -DestinationPath "build\Torchic-windows.zip" -Force
```

Queda un `Torchic-windows.zip` (~48 MB) listo para subir.

---

## 3. Publicar la Release en GitHub

Esto se hace en la web de GitHub (o con la CLI `gh` si la tienes instalada).

### Desde la web

1. Ve al repo → pestaña lateral **Releases** → **Create a new release** (o **Draft a new release**).
2. **Choose a tag**: escribe uno nuevo, ej. `v0.1.0`, y elige *"Create new tag on publish"*.
3. **Release title**: ej. `Torchic v0.1.0`.
4. Escribe notas de la versión (qué cambió, qué probar).
5. En **Attach binaries**, arrastra el archivo `build\Torchic-windows.zip`.
6. **Publish release**.

### Con la CLI de GitHub (opcional, si tienes `gh`)

```powershell
gh release create v0.1.0 "build\Torchic-windows.zip" `
  --title "Torchic v0.1.0" `
  --notes "Primera versión jugable para testers."
```

El link de descarga del README (`releases/latest`) apunta siempre a la última release publicada, así que se actualiza solo.

---

## 4. Para quien lo descarga

1. Entra a la sección **Releases** del repo (o al link del README).
2. Descarga el `.zip`, descomprímelo y ejecuta `Torchic.exe`.
3. **Aviso de Windows**: como el ejecutable no está firmado, aparecerá *"Windows protegió tu PC"*. Hay que hacer clic en **Más información → Ejecutar de todas formas**. Es normal en juegos independientes.

---

## Notas importantes

- **No subir los binarios al repo.** El `.gitignore` ya ignora `build/` y `*.zip`. Los ejecutables se distribuyen **solo** por Releases, no en el historial de git (mantiene el `clone` liviano).
- **Mantén la versión de Godot y de las plantillas sincronizadas.** Si actualizas Godot, reinstala las plantillas de la nueva versión antes de exportar.
- El preset de exportación clave está en `export_presets.cfg`:
  - `binary_format/embed_pck=true` → un solo `.exe` autocontenido.
  - `debug/export_console_wrapper=0` → sin ventana de consola extra.
