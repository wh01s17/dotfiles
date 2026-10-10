# Pomodoro

[`pomodoro.sh`](../desktop/.config/omarchy/bar/scripts/pomodoro.sh) conserva cuatro sistemas:

| Sistema | Trabajo | Descanso | Descanso largo |
| --- | ---: | ---: | ---: |
| Equilibrado | 40 min | 10 min | 20 min cada 4 sesiones |
| Clásico | 25 min | 5 min | 15 min cada 4 sesiones |
| Enfoque profundo | 50 min | 10 min | 20 min cada 4 sesiones |
| Ultradiano | 90 min | 20 min | 30 min cada 2 sesiones |

Controles:

- clic izquierdo: abrir el panel Pomodoro;
- clic central: saltar fase;
- clic derecho: elegir sistema;
- scroll: ajustar ±1 minuto.

El panel permite iniciar/pausar, saltar, reiniciar y elegir sistema. Las mismas
acciones están disponibles desde terminal:

```bash
~/.config/omarchy/bar/scripts/pomodoro.sh toggle
~/.config/omarchy/bar/scripts/pomodoro.sh reset
~/.config/omarchy/bar/scripts/pomodoro.sh skip
~/.config/omarchy/bar/scripts/pomodoro.sh preset balanced
```

Los identificadores de preset son `balanced`, `classic`, `deep` y
`ultradian`. `POMODORO_PRESET` define el predeterminado y
`POMODORO_STATE_DIR` permite mover el estado. Los ajustes manuales están
limitados al rango de 1 minuto a 4 horas.

Durante una fase de enfoque activa, el script usa el servicio de notificaciones de Omarchy para activar DND. El estado vive en `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/bar/pomodoro`.
