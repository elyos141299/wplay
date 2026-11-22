// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: jendela AirPlay. Ini penyederhanaan besar dari
// src/ui/tools/Airplay.qml iDescriptor v0.6.1 (±520 baris):
// dibuang — video tutorial, Theme/Settings/DeviceContext iDescriptor,
// StateView, dialog info koneksi, zoom/tampilan HUD ala FluentUI.
// dipertahankan — GstGLQt6VideoItem (qml6glsink) sebagai layar video,
// putar 90°, slider volume, status koneksi + nama perangkat.
// Semua teks memakai qsTr, sesuai aturan project upstream.
//
// Riwayat tampilan:
// - 22 Nov 2026: tema profesional navy/steel, layar tunggu berlogo,
//   HUD bawah custom.
// - 23 Nov 2026: latar legam di belakang layar tunggu (menutupi
//   frame terakhir yang tertinggal setelah koneksi diputus).
// - 23 Nov 2026 (permintaan user): FRAMELESS + title bar custom.
//   Semua kontrol (nama perangkat, Rotate, Volume) pindah ke dalam
//   title bar navy di kiri; tombol min/max/close custom di kanan;
//   area video 100% bersih tanpa overlay apa pun di atas mirroring.
//   Jendela digeser dengan drag title bar (startSystemMove) dan
//   diubah ukurannya dari tepi (startSystemResize). Logika koneksi
//   TIDAK berubah.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.freedesktop.gstreamer.Qt6GLVideoItem

ApplicationWindow {
    id: root

    width: 900
    height: 644
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: qsTr("wPlay")
    color: "#0a0f1a"
    flags: Qt.Window | Qt.FramelessWindowHint

    // Palet tema wPlay (navy kalem + steel)
    readonly property color accent: "#7fb2e0"
    readonly property color panel: "#141f31"
    readonly property color panelBorder: "#22344d"
    readonly property color textDim: "#9db2c8"
    readonly property color titleBarColor: "#0d1622"

    property bool serverRunning: false
    property bool clientConnected: false
    property string clientDeviceName: ""
    property string clientModel: ""
    property string parsedModel: ""
    property int rotationTurns: 0

    function setMasterVolume(volume) {
        AirplayImp.set_master_volume(Math.max(0, Math.min(100, volume)) / 100)
    }

    function toggleMaximized() {
        if (root.visibility === Window.Maximized)
            root.showNormal()
        else
            root.showMaximized()
    }

    function startAirPlay() {
        // Di upstream, load_gst_gl() dipanggil dari Toolbox.qml sebelum
        // jendela AirPlay dibuka; di wPlay dipanggil di sini.
        const glLoaded = AirplayImp.load_gst_gl()
        if (!glLoaded) {
            statusLabel.text = qsTr("Failed to load the GStreamer video plugin (qml6glsink).")
            return
        }
        if (AirplayImp.init(video)) {
            root.serverRunning = true
            statusLabel.text = qsTr("Waiting for device connection")
        } else {
            statusLabel.text = qsTr("Failed to start AirPlay.")
        }
    }

    Component.onCompleted: initTimer.start()

    onClosing: AirplayImp.cleanup()

    Connections {
        target: AirplayImp

        function onConnection_change(connected) {
            root.clientConnected = connected
            if (!connected) {
                root.clientDeviceName = ""
                root.clientModel = ""
                root.parsedModel = ""
                root.rotationTurns = 0
                statusLabel.text = qsTr("Waiting for device connection")
            }
        }

        function onConnectionDetailsChanged(name, model, parsed_model, device_id) {
            root.clientDeviceName = name
            root.clientModel = model
            root.parsedModel = parsed_model
        }
    }

    Timer {
        id: initTimer
        interval: 450
        repeat: false
        onTriggered: root.startAirPlay()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------------
        // Title bar custom (navy): logo + nama app + kontrol koneksi
        // di kiri; tombol jendela di kanan. Drag area di lapisan bawah.
        // ---------------------------------------------------------------
        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: root.titleBarColor

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.panelBorder
            }

            MouseArea {
                anchors.fill: parent
                onPressed: root.startSystemMove()
                onDoubleClicked: root.toggleMaximized()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 10

                // Logo mini wPlay
                Rectangle {
                    width: 26
                    height: 26
                    radius: 7
                    border.color: "#2c4a6b"
                    border.width: 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f47" }
                        GradientStop { position: 1.0; color: "#0b1322" }
                    }

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#7fb2e0"
                            ctx.lineWidth = 1.6
                            ctx.lineCap = "round"
                            const cx = 17.5, cy = 8
                            for (const r of [3, 5.5, 8]) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -1.0, 0.55)
                                ctx.stroke()
                            }
                            ctx.fillStyle = "#7fb2e0"
                            ctx.beginPath()
                            ctx.arc(cx, cy, 1.3, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.fillStyle = "#f5f8fc"
                            ctx.beginPath()
                            ctx.moveTo(8.5, 8.5)
                            ctx.lineTo(8.5, 18)
                            ctx.lineTo(16.5, 13.25)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                Label {
                    text: qsTr("wPlay")
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                }

                // Kontrol koneksi (hanya saat tersambung)
                Rectangle {
                    width: 1
                    height: 20
                    color: "#2a3c55"
                    visible: root.clientConnected
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: "#3ddc84"
                    visible: root.clientConnected
                }

                Label {
                    text: root.parsedModel !== "" ? root.parsedModel : root.clientDeviceName
                    color: "white"
                    font.pixelSize: 13
                    visible: root.clientConnected
                }

                Button {
                    id: rotateBtn
                    text: qsTr("Rotate")
                    visible: root.clientConnected
                    onClicked: root.rotationTurns += 1

                    contentItem: Text {
                        text: rotateBtn.text
                        color: "white"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: 4
                        bottomPadding: 4
                    }
                    background: Rectangle {
                        radius: 7
                        color: rotateBtn.down ? "#33517a" : (rotateBtn.hovered ? "#2a4568" : "#1d3049")
                        border.color: "#33506f"
                        border.width: 1
                    }
                }

                Label {
                    text: qsTr("Volume")
                    color: "white"
                    font.pixelSize: 12
                    visible: root.clientConnected
                }

                Slider {
                    id: volumeSlider
                    Layout.preferredWidth: 110
                    visible: root.clientConnected
                    from: 0
                    to: 100
                    value: 100
                    stepSize: 1
                    onMoved: root.setMasterVolume(value)

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: volumeSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#2a3c55"

                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: root.accent
                        }
                    }
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: volumeSlider.pressed ? "#dbe9f7" : "white"
                        border.color: root.accent
                        border.width: 2
                    }
                }

                Item { Layout.fillWidth: true }

                // Tombol jendela custom
                Button {
                    id: minBtn
                    text: "–"
                    onClicked: root.showMinimized()

                    contentItem: Text {
                        text: minBtn.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 42
                        implicitHeight: 30
                        radius: 6
                        color: minBtn.hovered ? "#22344d" : "transparent"
                    }
                }

                Button {
                    id: maxBtn
                    text: root.visibility === Window.Maximized ? "❐" : "□"
                    onClicked: root.toggleMaximized()

                    contentItem: Text {
                        text: maxBtn.text
                        color: "white"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 42
                        implicitHeight: 30
                        radius: 6
                        color: maxBtn.hovered ? "#22344d" : "transparent"
                    }
                }

                Button {
                    id: closeBtn
                    text: "✕"
                    onClicked: root.close()

                    contentItem: Text {
                        text: closeBtn.text
                        color: "white"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 42
                        implicitHeight: 30
                        radius: 6
                        color: closeBtn.hovered ? "#c42b1c" : "transparent"
                    }
                }
            }
        }

        // ---------------------------------------------------------------
        // Area konten: video + layar tunggu. Tanpa overlay kontrol —
        // mirroring tampil bersih sepenuh area ini.
        // ---------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GstGLQt6VideoItem {
                id: video
                anchors.fill: parent
                objectName: "videoItem"
                transformOrigin: Item.Center
                rotation: root.rotationTurns * 90
            }

            // Latar legam di belakang layar tunggu: menutupi frame
            // video terakhir yang tertinggal setelah koneksi diputus.
            Rectangle {
                anchors.fill: parent
                color: root.color
                visible: !root.clientConnected
            }

            // Layar tunggu, tampil selama belum ada iPhone tersambung.
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14
                visible: !root.clientConnected

                // Logo wPlay besar
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 104
                    height: 104
                    radius: 26
                    border.color: "#2c4a6b"
                    border.width: 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1a2f47" }
                        GradientStop { position: 1.0; color: "#0b1322" }
                    }

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#7fb2e0"
                            ctx.lineWidth = 5
                            ctx.lineCap = "round"
                            const cx = 70, cy = 33
                            for (const r of [10, 19, 28]) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -1.0, 0.55)
                                ctx.stroke()
                            }
                            ctx.fillStyle = "#7fb2e0"
                            ctx.beginPath()
                            ctx.arc(cx, cy, 4, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.fillStyle = "#f5f8fc"
                            ctx.beginPath()
                            ctx.moveTo(36, 34)
                            ctx.lineTo(36, 72)
                            ctx.lineTo(68, 53)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("wPlay")
                    color: "white"
                    font.pixelSize: 34
                    font.bold: true
                    font.letterSpacing: 1
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("AIRPLAY RECEIVER")
                    color: root.accent
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 3
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    BusyIndicator {
                        running: root.serverRunning && !root.clientConnected
                        implicitWidth: 22
                        implicitHeight: 22
                    }

                    Label {
                        id: statusLabel
                        text: qsTr("Starting AirPlay Server...")
                        color: "white"
                        font.pixelSize: 15
                    }
                }

                // Kartu langkah koneksi
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    implicitWidth: stepsLayout.implicitWidth + 36
                    implicitHeight: stepsLayout.implicitHeight + 28
                    radius: 14
                    color: root.panel
                    border.color: root.panelBorder
                    border.width: 1

                    ColumnLayout {
                        id: stepsLayout
                        anchors.centerIn: parent
                        spacing: 10

                        Repeater {
                            model: [
                                qsTr("Connect your iPhone and this PC to the same Wi-Fi"),
                                qsTr("Open Control Center, then tap Screen Mirroring"),
                                qsTr("Select “wPlay” from the list")
                            ]

                            RowLayout {
                                spacing: 10

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: "#24466b"

                                    Label {
                                        anchors.centerIn: parent
                                        text: index + 1
                                        color: "white"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                Label {
                                    text: modelData
                                    color: "#d5dee9"
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    text: qsTr("Tip: in OBS, add this window with Window Capture.")
                    color: root.textDim
                    font.pixelSize: 12
                }
            }
        }
    }

    // Gagang ubah ukuran di tepi jendela (pengganti bingkai Windows
    // yang hilang karena frameless). Memakai startSystemResize agar
    // perilaku snap Windows tetap jalan.
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        cursorShape: Qt.SizeHorCursor
        onPressed: root.startSystemResize(Qt.LeftEdge)
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 5
        cursorShape: Qt.SizeHorCursor
        onPressed: root.startSystemResize(Qt.RightEdge)
    }
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 5
        cursorShape: Qt.SizeVerCursor
        onPressed: root.startSystemResize(Qt.BottomEdge)
    }
    MouseArea {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: 10
        height: 10
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.startSystemResize(Qt.LeftEdge | Qt.BottomEdge)
    }
    MouseArea {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 10
        height: 10
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
    }
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        width: 6
        height: 6
        cursorShape: Qt.SizeFDiagCursor
        onPressed: root.startSystemResize(Qt.LeftEdge | Qt.TopEdge)
    }
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        width: 6
        height: 6
        cursorShape: Qt.SizeBDiagCursor
        onPressed: root.startSystemResize(Qt.RightEdge | Qt.TopEdge)
    }
}
