// SPDX-FileCopyrightText: 2025-2026 Uncore <https://github.com/uncor3>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// wPlay: jendela AirPlay polos. Ini penyederhanaan besar dari
// src/ui/tools/Airplay.qml iDescriptor v0.6.1 (±520 baris):
// dibuang — video tutorial, Theme/Settings/DeviceContext iDescriptor,
// StateView, dialog info koneksi, zoom/tampilan HUD ala FluentUI.
// dipertahankan — GstGLQt6VideoItem (qml6glsink) sebagai layar video,
// putar 90°, slider volume, status koneksi + nama perangkat.
// Semua teks memakai qsTr, sesuai aturan project upstream.

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
    color: "#111111"

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

    // Layar tunggu, tampil selama belum ada iPhone yang tersambung.
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12
        visible: !root.clientConnected

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("wPlay")
            color: "white"
            font.pixelSize: 32
            font.bold: true
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: root.serverRunning && !root.clientConnected
        }

        Label {
            id: statusLabel
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Starting AirPlay Server...")
            color: "white"
            font.pixelSize: 16
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 480
            text: qsTr("Open Control Center on your iPhone, choose Screen Mirroring, then select wPlay.")
            color: "#bbbbbb"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Bar bawah, tampil setelah iPhone tersambung.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.margins: 18
        width: Math.min(parent.width - 36, hudLayout.implicitWidth + 24)
        height: hudLayout.implicitHeight + 20
        radius: 10
        color: "#cc222222"
        visible: root.clientConnected

        RowLayout {
            id: hudLayout
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Label {
                text: root.parsedModel !== "" ? root.parsedModel : root.clientDeviceName
                color: "white"
                font.pixelSize: 13
            }

            Button {
                text: qsTr("Rotate")
                onClicked: root.rotationTurns += 1
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
            }
        }
    }
}
