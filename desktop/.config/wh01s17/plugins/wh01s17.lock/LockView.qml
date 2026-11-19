import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "LockModel.js" as LockModel

// wh01s17 lock screen: the theme's deep negative space with the pixel
// `wh01s17` wordmark, a Departure Mono clock and a terminal-style prompt,
// over the current background pixelated and dimmed.
//
// Same interface and input handling as core.lock's LockView, so Service.qml
// (unchanged from core.lock) drives it exactly as it drives the stock one.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property bool errorState: failureMessage.length > 0
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && !errorState

  // Departure Mono is drawn on an 11px grid: its sizes stay crisp at multiples.
  // Everything scales by a whole factor of the screen height (2 on 4K), so the
  // pixels stay square and sharp on every monitor.
  readonly property int k: Math.max(1, Math.floor(height / 1080))
  readonly property int smallSize: 11 * k
  readonly property int promptSize: 22 * k
  readonly property int dateSize: 22 * k
  readonly property int clockSize: 99 * k
  readonly property int secondsSize: 33 * k
  readonly property int markCell: 6 * k
  readonly property int boxWidth: 528 * k
  readonly property int pad: 18 * k
  readonly property int outlineThickness: Math.max(1, Style.pixelUnit) * k

  readonly property color ink: Colors.lock.text
  readonly property color dim: Colors.lock.placeholder
  readonly property color signal: Colors.accent
  readonly property color fault: Colors.lock.textError
  readonly property var promptBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Colors.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Colors.lock.borderActive, root.outlineThickness, "border-alpha")

  property date now: new Date()
  property bool blinkOn: true
  property int authDots: 0
  property real shakeX: 0
  property int shakeStep: -1

  readonly property string userName: Quickshell.env("USER") || "user"
  readonly property string hostName: String(hostnameFile.text() || "").trim() || "localhost"
  readonly property var mark: LockModel.wordmark("wh01s17")

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor while the monitor
  // modesets, so the wake key's repeat would flood the field. Only holding
  // Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function two(n) {
    return n < 10 ? "0" + n : String(n)
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onFailedAttemptsChanged: if (failedAttempts > 0) { shakeStep = 0; shakeTimer.restart() }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  FileView {
    id: hostnameFile
    path: "/etc/hostname"
    blockLoading: true
    printErrors: false
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // Cursor blink, in whole steps like a terminal.
  Timer {
    interval: 530
    repeat: true
    running: root.visible
    onTriggered: root.blinkOn = !root.blinkOn
  }

  Timer {
    interval: 280
    repeat: true
    running: root.authenticatingPassword
    onRunningChanged: root.authDots = 0
    onTriggered: root.authDots = (root.authDots + 1) % 4
  }

  Timer {
    id: shakeTimer
    interval: 45
    repeat: true
    onTriggered: {
      if (root.shakeStep < 0 || root.shakeStep >= LockModel.SHAKE.length) {
        root.shakeX = 0
        root.shakeStep = -1
        stop()
        return
      }
      root.shakeX = LockModel.SHAKE[root.shakeStep]
      root.shakeStep++
    }
  }

  TextMetrics {
    id: cellMetrics
    font.family: Style.font.family
    font.pixelSize: root.promptSize
    text: "M"
  }

  Rectangle {
    anchors.fill: parent
    color: Colors.background

    // The background loaded at a sixth of the screen and scaled back up
    // without smoothing: the wallpaper turns into big pixels.
    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      smooth: false
      mipmap: false
      sourceSize.width: Math.max(1, Math.round(width / 6))
      sourceSize.height: Math.max(1, Math.round(height / 6))
    }

    Rectangle {
      anchors.fill: parent
      color: Colors.background
      opacity: 0.9
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    Column {
      anchors.centerIn: parent
      spacing: 0

      // ---- Pixel wordmark: letters in the foreground, digits in green.
      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.mark.width * root.markCell
        height: root.mark.height * root.markCell

        Repeater {
          model: root.mark.cells
          Rectangle {
            required property var modelData
            x: modelData.x * root.markCell
            y: modelData.y * root.markCell
            width: root.markCell
            height: root.markCell
            color: modelData.digit ? root.signal : root.ink
          }
        }
      }

      Item { width: 1; height: 44 * root.k }

      // ---- Clock. The colon steps between green and dim every second.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Text {
          id: hours
          textFormat: Text.PlainText
          text: root.two(root.now.getHours())
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: root.clockSize
        }
        Text {
          textFormat: Text.PlainText
          text: ":"
          color: root.now.getSeconds() % 2 === 0 ? root.signal : root.dim
          font.family: Style.font.family
          font.pixelSize: root.clockSize
        }
        Text {
          textFormat: Text.PlainText
          text: root.two(root.now.getMinutes())
          color: root.ink
          font.family: Style.font.family
          font.pixelSize: root.clockSize
        }
        Text {
          id: seconds
          textFormat: Text.PlainText
          anchors.baseline: hours.baseline
          leftPadding: 11 * root.k
          text: root.two(root.now.getSeconds())
          color: root.signal
          font.family: Style.font.family
          font.pixelSize: root.secondsSize
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.locale().toString(root.now, "dddd d MMMM yyyy").toUpperCase()
        color: root.dim
        font.family: Style.font.family
        font.pixelSize: root.dateSize
        font.letterSpacing: 2 * root.k
      }

      Item { width: 1; height: 55 * root.k }

      // ---- Terminal prompt. Pixel mode cuts its corners into steps.
      BorderSurface {
        id: promptBox
        // A Column only stacks; centre it by hand so the shake can offset it.
        x: Math.round((parent.width - width) / 2) + root.shakeX
        width: root.boxWidth
        height: promptColumn.implicitHeight + 2 * root.pad
        color: Colors.lock.background
        borderSpec: root.promptBorderSpec
        radius: Style.cornerRadius
        pixelScale: root.k

        Column {
          id: promptColumn
          anchors.fill: parent
          anchors.margins: root.pad
          spacing: 14 * root.k

          Item {
            width: parent.width
            height: identity.implicitHeight

            Text {
              id: identity
              textFormat: Text.PlainText
              text: root.userName + "@" + root.hostName + " ~ session locked"
              color: root.dim
              font.family: Style.font.family
              font.pixelSize: root.smallSize
              elide: Text.ElideRight
              width: parent.width - status.implicitWidth - 11 * root.k
            }

            Text {
              id: status
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: (root.fingerprintConfigured ? "󰈷  " : "")
                + LockModel.statusTag(root.authenticatingPassword, root.errorState, root.failedAttempts, root.authDots)
              color: root.errorState ? root.fault : (root.authenticatingPassword ? root.signal : root.dim)
              font.family: Style.font.family
              font.pixelSize: root.smallSize
            }
          }

          Row {
            width: parent.width
            spacing: 11 * root.k

            Text {
              id: promptGlyph
              textFormat: Text.PlainText
              text: ">"
              color: root.errorState ? root.fault : root.signal
              font.family: Style.font.family
              font.pixelSize: root.promptSize
            }

            Item {
              width: parent.width - promptGlyph.width - parent.spacing
              height: promptGlyph.height
              clip: true

              TextInput {
                id: passwordInput
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnPress: true
                enabled: root.inputEnabled && !root.authenticatingPassword
                readOnly: root.authenticatingPassword
                echoMode: TextInput.Password
                passwordCharacter: "*"
                passwordMaskDelay: 0
                color: root.ink
                selectionColor: Colors.lock.selection
                selectedTextColor: root.ink
                font.family: Style.font.family
                font.pixelSize: root.promptSize
                cursorVisible: activeFocus && root.showPasswordCursor
                cursorDelegate: Rectangle {
                  width: Math.max(2, Math.round(cellMetrics.advanceWidth))
                  color: root.signal
                  visible: passwordInput.cursorVisible && root.blinkOn
                }

                onTextChanged: {
                  if (!root.syncingPasswordText) root.passwordTextEdited(text)
                  if (text.length > 0) root.wakeRequested()
                  if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
                }

                onAccepted: {
                  var submitted = root.passwordText
                  root.passwordTextEdited("")
                  if (submitted.length > 0) root.submitPassword(submitted)
                }

                Keys.onPressed: function(event) {
                  root.wakeRequested()
                  if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
                    event.accepted = true
                    return
                  }
                  if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                    root.passwordTextEdited("")
                    event.accepted = true
                  }
                }
              }

              // What the empty prompt says: the hint, the check in progress,
              // or why the last try failed. Clear of the block cursor.
              Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.leftMargin: Math.round(cellMetrics.advanceWidth) + 11 * root.k
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: passwordInput.text.length === 0
                text: root.authenticatingPassword ? "checking"
                  : (root.errorState ? root.failureMessage.toLowerCase() : "password")
                color: root.errorState ? root.fault : root.dim
                font.family: Style.font.family
                font.pixelSize: root.promptSize
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 44 * root.k
      textFormat: Text.PlainText
      text: "ENTER UNLOCK  ·  ESC CLEAR" + (root.fingerprintConfigured ? "  ·  TOUCH THE SENSOR" : "")
      color: root.dim
      font.family: Style.font.family
      font.pixelSize: root.smallSize
      font.letterSpacing: root.k
    }
  }
}
