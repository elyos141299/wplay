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
// Tampilan diperbarui 22 Nov 2026 ("paket lengkap" atas permintaan
// user): tema navy gelap kalem + aksen steel, logo wPlay digambar
// Canvas (segitiga play + gelombang cast, sama seperti ikon exe),
// layar tunggu berisi langkah koneksi bernomor, dan bar kontrol
// bawah bergaya custom (tombol + slider). Logika koneksi TIDAK
// berubah dari versi sebelumnya.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.freedesktop.gstreamer.Qt6GLVideoItem

ApplicationWindow {
    id: root

    width: 900
    height: 600
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: qsTr("wPlay")
    color: "#0a0f1a"

    // Palet tema wPlay (navy kalem + steel)
    readonly property color accent: "#7fb2e0"
    readonly property color panel: "#141f31"
    readonly property color panelBorder: "#22344d"
    readonly property color textDim: "#9db2c8"

    property bool serverRunning: false
    property bool clientConnected: false
    property string clientDeviceName: ""
    property string clientModel: ""
    property string parsedModel: ""
    property int rotationTurns: 0

    function setMasterVolume(volume) {
        AirplayImp.set_master_volume(Math.max(0, Math.min(100, volume)) / 100)
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

    GstGLQt6VideoItem {
        id: video
        anchors.fill: parent
        objectName: "videoItem"
        transformOrigin: Item.Center
        rotation: root.rotationTurns * 90
    }

    // Latar legam di belakang layar tunggu: menutupi frame video
    // terakhir yang tertinggal di GstGLQt6VideoItem setelah koneksi
    // diputus (tanpa ini, layar tunggu menimpa sisa gambar iPhone
    // seperti hantu — terlihat di tes user 23 Nov 2026).
    Rectangle {
        anchors.fill: parent
        color: root.color
        visible: !root.clientConnected
    }

    // Layar tunggu, tampil selama belum ada iPhone yang tersambung.
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14
        visible: !root.clientConnected

        // Logo wPlay: ubin navy + segitiga play + gelombang cast,
        // digambar Canvas (sama seperti ikon wplay.exe).
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
                    // gelombang cast (steel)
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
                    // segitiga play (putih)
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

    // Bar atas (permintaan user 23 Nov 2026): kontrol pindah dari
    // bar bawah ke strip atas sepenuh lebar jendela, isi rata kiri —
    // titik status + nama perangkat, Rotate, Volume. Tombol tidak
    // bisa tinggal di dalam title bar Windows bawaan, jadi strip ini
    // duduk persis di bawahnya. Tampil setelah iPhone tersambung.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: hudLayout.implicitHeight + 16
        color: "#e00d1622"
        border.color: "#2a3c55"
        border.width: 1
        visible: root.clientConnected

        RowLayout {
            id: hudLayout
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: "#3ddc84"
            }

            Label {
                text: root.parsedModel !== "" ? root.parsedModel : root.clientDeviceName
                color: "white"
                font.pixelSize: 13
            }

            Button {
                id: rotateBtn
                text: qsTr("Rotate")
                onClicked: root.rotationTurns += 1

                contentItem: Text {
                    text: rotateBtn.text
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 6
                    bottomPadding: 6
                }
                background: Rectangle {
                    radius: 8
                    color: rotateBtn.down ? "#33517a" : (rotateBtn.hovered ? "#2a4568" : "#1d3049")
                    border.color: "#33506f"
                    border.width: 1
                }
            }

            Label {
                text: qsTr("Volume")
                color: "white"
                font.pixelSize: 13
            }

            Slider {
                id: volumeSlider
                Layout.preferredWidth: 124
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
                    width: 16
                    height: 16
                    radius: 8
                    color: volumeSlider.pressed ? "#dbe9f7" : "white"
                    border.color: root.accent
                    border.width: 2
                }
            }
        }
    }
}
