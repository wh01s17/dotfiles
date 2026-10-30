# Acciones de los módulos: estado y errores

Los controles deben crear sus directorios antes de guardar estado y devolver
un error si la escritura o la acción solicitada falla. Una notificación, una
consulta posterior o un IPC opcional no deben convertir ese error en éxito.
Los archivos y directorios locales que bloquean la escritura se conservan.

La revisión incluye los paneles propios y los comandos del runtime que usan
los módulos y sus accesos de menú:

| Área | Resultado |
| --- | --- |
| Monitor: External, Mirror y tapa | Los toggles se crean en un HOME vacío; las escrituras fallidas no anuncian éxito. Se mantiene la protección de la única pantalla activa. |
| Modos, escala y tamaño de texto | Los errores al persistir se propagan; una ruta de destino que es un directorio no se trata como un archivo guardado. El panel muestra un aviso si la acción falla. |
| Layouts de workspace y toggles de Hyprland | Se comprueban creación, copia, escritura y aplicación antes de confirmar el cambio. |
| Touchpad y touchscreen | No se muestra el OSD de éxito si falla el directorio, la escritura o `hyprctl`. |
| Barra, screensaver, suspensión y captura de fallos | Los wrappers conservan el error del toggle en vez de ocultarlo con una notificación o un IPC posterior. |
| Stay Awake | No imprime el estado solicitado si no pudo guardarlo. |
| Audio y micrófono | Las operaciones de volumen, mute y salida/entrada predeterminada propagan errores del backend; el OSD de éxito no aparece tras un fallo. Mover streams que desaparecen sigue siendo opcional. |
| Bluetooth | Pair/connect/disconnect/forget no ocultan el fallo de la operación final; un fallo al desbloquear la radio se propaga. |
| Nightlight | Devuelve error si la temperatura pedida no se alcanza tras los reintentos. |
| Energía y clima | Los directorios de preferencias se crean y sus errores se propagan; el panel de energía avisa si la acción falla. |
| Aplicaciones predeterminadas | Terminal y editor crean sus rutas; editor, terminal y agente no anuncian ni lanzan una preferencia que no se pudo guardar. |
| Portapapeles | No emite una entrada de imagen si el archivo no se guardó. Los errores de guardado del historial quedan en el registro. |
| Reloj, metrónomo y ajustes de barra | Usan la persistencia compartida del shell; sus errores de guardado ahora quedan en el registro. No escriben directorios de estado propios. |
| Notificaciones/DND | El comando conserva el error del IPC y los errores al guardar preferencias quedan en el registro. |
| Red/Wi-Fi/DNS | Los setters ya comprobaban los errores del backend; el panel solo confirma DNS/banda cuando el comando termina correctamente. |
| Git, CTF, Pomodoro y dispositivos montados | Sus scripts ya crean sus directorios y usan `set -euo pipefail`; no se encontró el mismo éxito falso al guardar estado. |

Pruebas: `installer/tests/test_monitor_actions.py`,
`installer/tests/test_module_actions.py` y `tests/monitor-external.js`.
Se ejecutan con carpetas personales temporales y sustitutos de los servicios;
no cambian pantallas, audio, radio, energía ni archivos reales del usuario.
La prueba de integridad del instalador sigue comprobando disco y cifrado.
