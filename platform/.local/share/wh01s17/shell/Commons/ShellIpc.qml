import QtQuick
import Quickshell.Io

// Omarchy 4.5 names its IPC handlers ShellIpc so the shell can also answer
// them over its own socket. This runtime has no such socket, so ShellIpc is a
// plain IpcHandler: `wh01s17-shell`/qs ipc reach it as before.
IpcHandler {
}
