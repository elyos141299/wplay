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
// - 23 Nov 2026 (feedback user dari tes frameless): tombol Rotate
//   DIHAPUS; area drag jendela dipersempit ke ruang kosong title
//   bar saja. Fitur ukuran jendela mengikuti rasio mirror sempat
//   ditambahkan lalu DIBATALKAN user di hari yang sama. Kontrol
//   Volume juga akhirnya DIHAPUS atas permintaan user (masih
//   bermasalah) — title bar kini hanya berisi nama perangkat.
// - 23 Nov 2026 (permintaan user): layar tunggu DIHIDUPKAN —
//   cincin sinyal memancar dari logo (sonar kalem), logo bernapas
//   halus, titik-titik tunggu berjalan, fade-in saat layar tampil.
//   Tema navy/steel tetap; logika koneksi & ukuran jendela tetap.
// - 23 Nov 2026 (permintaan user): POP-UP DONASI SociaBuzz —
//   kartu modal tampil satu kali pada peluncuran pertama
//   (persistensi Settings), berisi NOTE + ajakan traktir kopi +
//   kode QR, plus tombol hati permanen di title bar untuk
//   membukanya lagi kapan pun. Teks Indonesia di kartu ini
//   dikunci user persis seperti tertulis (tanpa qsTr). Kode QR
//   digambar via Canvas dari data modul gambar aslinya — pola
//   yang sama dengan logo (aplikasi tidak punya aset gambar;
//   semua grafis digambar Canvas).
// - 23 Nov 2026 (permintaan user): LABEL VERSI di layar tunggu +
//   PERIKSA PEMBARUAN semi-otomatis — aplikasi mengecek rilis
//   terbaru di GitHub Releases (diam total selama repo masih
//   privat atau jaringan gagal), dialog menawarkan unduh
//   installer baru; pemasangan tetap manual oleh user
//   (upgrade di tempat via AppId installer yang sama).

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtCore
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

    // Tautan donasi SociaBuzz (pop-up donasi + tombol hati).
    readonly property string donationUrl: "https://sociabuzz.com/oroboo/tribe"

    // Versi aplikasi. WAJIB selalu sama dengan #define AppVersion
    // di installer/wplay.iss — keduanya diubah bersamaan tiap rilis.
    readonly property string appVersion: "0.1.3"

    // Periksa Pembaruan: endpoint rilis terbaru di GitHub. Selama
    // repo masih privat, API ini menjawab 404 untuk permintaan
    // tanpa login dan fitur pembaruan diam total (disengaja);
    // fitur hidup sendiri begitu repo publik + Release pertama
    // diterbitkan — tanpa perlu build ulang.
    readonly property string latestReleaseApi: "https://api.github.com/repos/elyos141299/wplay/releases/latest"
    readonly property string releasesPageUrl: "https://github.com/elyos141299/wplay/releases"

    // Persistensi pop-up donasi (QtCore Settings -> QSettings):
    // donationSeen    = pop-up sudah diselesaikan user (klik donasi,
    //                   atau tutup dengan centang aktif).
    // donationRemind  = pop-up boleh tampil otomatis sekali lagi
    //                   pada peluncuran berikutnya (user melepas
    //                   centang "Jangan tampilkan lagi").
    Settings {
        id: appSettings
        property bool donationSeen: false
        property bool donationRemind: true
        // Tag rilis yang pernah ditolak user lewat "Nanti Saja" di
        // dialog pembaruan — cek otomatis tidak menampilkannya lagi.
        property string updateDismissedTag: ""
    }

    function openDonationPopup() {
        donationOverlay.openPopup()
    }

    // ---------------------------------------------------------------
    // Periksa Pembaruan (semi-otomatis). Cek otomatis berjalan
    // sekali beberapa detik setelah start dan DIAM TOTAL pada
    // kegagalan apa pun (offline, timeout, HTTP 404 selama repo
    // privat, JSON tak valid) — tidak ada pesan error, tidak ada
    // dialog. Cek manual (tombol di layar tunggu) memakai jalur
    // yang sama tetapi memberi umpan balik teks sesaat.
    // ---------------------------------------------------------------

    // Dialog otomatis tampil maksimal sekali per sesi.
    property bool updateAutoShown: false
    // Data rilis yang menunggu keputusan user di dialog:
    // { tag, notes, downloadUrl } — null bila belum ada.
    property var pendingUpdate: null

    // Bandingkan dua versi secara numerik per komponen, sehingga
    // "0.1.10" lebih baru dari "0.1.9" (perbandingan string biasa
    // akan salah di sini). Hasil: 1 bila a > b, -1 bila a < b,
    // 0 bila sama. Komponen yang hilang dianggap 0.
    function compareVersions(a, b) {
        const pa = String(a).split(".")
        const pb = String(b).split(".")
        const n = Math.max(pa.length, pb.length)
        for (let i = 0; i < n; i++) {
            const na = i < pa.length ? parseInt(pa[i], 10) : 0
            const nb = i < pb.length ? parseInt(pb[i], 10) : 0
            const va = isNaN(na) ? 0 : na
            const vb = isNaN(nb) ? 0 : nb
            if (va !== vb)
                return va > vb ? 1 : -1
        }
        return 0
    }

    function checkForUpdates(manual) {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", root.latestReleaseApi)
        xhr.setRequestHeader("Accept", "application/vnd.github+json")
        xhr.setRequestHeader("User-Agent", "wPlay/" + root.appVersion)
        xhr.timeout = 10000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                root.handleUpdateResponse(xhr, manual)
        }
        xhr.ontimeout = function() {
            if (manual)
                root.showUpdateStatus("Tidak bisa memeriksa saat ini")
        }
        xhr.send()
    }

    function handleUpdateResponse(xhr, manual) {
        if (xhr.status !== 200) {
            // 404 selama repo privat / belum ada Release, atau
            // gangguan jaringan: otomatis diam; manual memberi tahu.
            if (manual)
                root.showUpdateStatus("Tidak bisa memeriksa saat ini")
            return
        }
        let rel
        try {
            rel = JSON.parse(xhr.responseText)
        } catch (e) {
            if (manual)
                root.showUpdateStatus("Tidak bisa memeriksa saat ini")
            return
        }
        // tag_name berbentuk "v0.2.0" — buang awalan "v".
        const tag = String(rel.tag_name || "").replace(/^v/, "")
        if (tag === "" || root.compareVersions(tag, root.appVersion) <= 0) {
            if (manual)
                root.showUpdateStatus("Sudah versi terbaru ✓")
            return
        }
        // Ada versi lebih baru. Utamakan aset .exe (installer);
        // bila tidak ada, pakai halaman rilisnya.
        let downloadUrl = rel.html_url || root.releasesPageUrl
        const assets = rel.assets || []
        for (let i = 0; i < assets.length; i++) {
            const name = String(assets[i].name || "")
            if (name.toLowerCase().endsWith(".exe") && assets[i].browser_download_url) {
                downloadUrl = assets[i].browser_download_url
                break
            }
        }
        root.pendingUpdate = {
            "tag": tag,
            "notes": String(rel.body || ""),
            "downloadUrl": downloadUrl
        }
        if (!manual) {
            // Anti-nag cek otomatis: sekali per sesi, tidak untuk
            // tag yang pernah ditolak, dan tidak menumpuk pop-up
            // donasi yang sedang terbuka.
            if (root.updateAutoShown || donationOverlay.shown)
                return
            if (appSettings.updateDismissedTag === tag)
                return
            root.updateAutoShown = true
        }
        updateOverlay.openPopup()
    }

    // Umpan balik sesaat di sebelah label versi (cek manual saja).
    function showUpdateStatus(text) {
        updateStatusLabel.text = text
        updateStatusLabel.visible = true
        updateStatusTimer.restart()
    }

    // CATATAN: fitur ukuran jendela mengikuti rasio mirror pernah
    // dicoba 23 Nov 2026 lalu DIBATALKAN user di hari yang sama
    // ("balikan ke awal... tidak usah mengikuti mirror") — jendela
    // berukuran tetap seperti semula, user mengatur sendiri.

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

    Component.onCompleted: {
        initTimer.start()
        donationTimer.start()
        updateCheckTimer.start()
    }

    onClosing: AirplayImp.cleanup()

    Connections {
        target: AirplayImp

        function onConnection_change(connected) {
            root.clientConnected = connected
            if (!connected) {
                root.clientDeviceName = ""
                root.clientModel = ""
                root.parsedModel = ""
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

    // Pop-up donasi tampil otomatis hanya pada peluncuran pertama
    // (atau sekali lagi bila user melepas centang terakhir kali).
    Timer {
        id: donationTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (!appSettings.donationSeen && appSettings.donationRemind)
                root.openDonationPopup()
        }
    }

    // Cek pembaruan otomatis: sekali, beberapa detik setelah
    // aplikasi start (pola timer yang sama dengan pop-up donasi).
    Timer {
        id: updateCheckTimer
        interval: 3500
        repeat: false
        onTriggered: root.checkForUpdates(false)
    }

    // Menyembunyikan teks status periksa pembaruan setelah sesaat.
    Timer {
        id: updateStatusTimer
        interval: 4000
        repeat: false
        onTriggered: updateStatusLabel.visible = false
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

            // CATATAN: area drag jendela hanya tinggal di ruang
            // kosong (spacer) title bar — lihat di bawah — bukan
            // menutupi seluruh bar, supaya tidak merebut interaksi
            // dari kontrol apa pun di bar ini.
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

                // Ruang kosong = area drag jendela (satu-satunya).
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    MouseArea {
                        anchors.fill: parent
                        onPressed: root.startSystemMove()
                        onDoubleClicked: root.toggleMaximized()
                    }
                }

                // Tombol donasi permanen: membuka lagi kartu donasi.
                Button {
                    id: donateBtn
                    text: "❤"
                    onClicked: root.openDonationPopup()

                    ToolTip.visible: donateBtn.hovered
                    ToolTip.text: "Dukung wPlay"
                    ToolTip.delay: 600

                    contentItem: Text {
                        text: donateBtn.text
                        color: "#e08a76"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitWidth: 42
                        implicitHeight: 30
                        radius: 6
                        color: donateBtn.hovered ? "#22344d" : "transparent"
                    }
                }

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
                id: waitingColumn
                anchors.centerIn: parent
                spacing: 14
                visible: !root.clientConnected
                opacity: 0

                NumberAnimation {
                    id: entranceAnim
                    target: waitingColumn
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 650
                    easing.type: Easing.OutCubic
                }

                onVisibleChanged: if (visible) entranceAnim.start()
                Component.onCompleted: if (visible) entranceAnim.start()

                // Logo wPlay besar + cincin sinyal beranimasi
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 104
                    height: 104

                    // Cincin sonar: memancar dari logo lalu memudar,
                    // bergantian — kesan "sedang mencari sinyal".
                    Repeater {
                        model: 3

                        Rectangle {
                            id: ring
                            anchors.centerIn: parent
                            width: 108
                            height: 108
                            radius: width / 2
                            color: "transparent"
                            border.color: root.accent
                            border.width: 1.5
                            opacity: 0

                            SequentialAnimation {
                                running: !root.clientConnected
                                loops: Animation.Infinite

                                PauseAnimation { duration: index * 900 }
                                ParallelAnimation {
                                    NumberAnimation { target: ring; property: "scale"; from: 0.72; to: 1.8; duration: 2700; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: ring; property: "opacity"; from: 0.45; to: 0; duration: 2700; easing.type: Easing.OutCubic }
                                }
                                PauseAnimation { duration: (2 - index) * 900 }
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 104
                        height: 104
                        radius: 26

                        // Napas halus logo.
                        SequentialAnimation on scale {
                            running: !root.clientConnected
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 1.045; duration: 2100; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.045; to: 1.0; duration: 2100; easing.type: Easing.InOutSine }
                        }
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

                    Label {
                        id: waitDots
                        text: ""
                        color: root.textDim
                        font.pixelSize: 15
                        visible: root.serverRunning && !root.clientConnected

                        Timer {
                            interval: 450
                            repeat: true
                            running: waitDots.visible
                            onTriggered: waitDots.text = waitDots.text.length >= 3 ? "" : waitDots.text + "."
                        }
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

            // Label versi + tombol periksa pembaruan: sudut bawah
            // layar tunggu saja — tidak pernah tampil di atas video
            // saat mirroring (visible terikat !clientConnected).
            RowLayout {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 14
                spacing: 10
                visible: !root.clientConnected

                Label {
                    text: "wPlay v" + root.appVersion
                    color: root.textDim
                    font.pixelSize: 11
                }

                Button {
                    id: updateCheckBtn
                    text: "Periksa Pembaruan"
                    onClicked: root.checkForUpdates(true)

                    contentItem: Text {
                        text: updateCheckBtn.text
                        color: updateCheckBtn.hovered ? root.accent : root.textDim
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        implicitHeight: 20
                        color: "transparent"
                    }
                }

                // Umpan balik sesaat untuk cek manual ("Sudah versi
                // terbaru ✓" / "Tidak bisa memeriksa saat ini").
                Label {
                    id: updateStatusLabel
                    visible: false
                    color: root.accent
                    font.pixelSize: 11
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

    // ---------------------------------------------------------------
    // Dialog pembaruan: gaya visual sama persis dengan kartu
    // donasi (overlay redup, kartu navy radius 16, tombol primer
    // baja + ghost). Ditempatkan SEBELUM overlay donasi di pohon
    // objek, jadi bila keduanya bersamaan, kartu donasi selalu
    // berada di atas. Klik pada latar tidak menutup dialog.
    // ---------------------------------------------------------------
    Item {
        id: updateOverlay
        anchors.fill: parent
        visible: opacity > 0
        opacity: shown ? 1 : 0

        property bool shown: false

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        function openPopup() {
            shown = true
        }

        function downloadUpdate() {
            if (root.pendingUpdate)
                Qt.openUrlExternally(root.pendingUpdate.downloadUrl)
            shown = false
        }

        function dismissUpdate() {
            // Anti-nag: tag ini tidak ditawarkan lagi oleh cek
            // otomatis (cek manual tetap boleh menampilkannya).
            if (root.pendingUpdate)
                appSettings.updateDismissedTag = root.pendingUpdate.tag
            shown = false
        }

        // Latar gelap; menelan semua klik di luar kartu.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.58

            MouseArea {
                anchors.fill: parent
            }
        }

        // Bayangan halus di bawah kartu.
        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 7
            width: updateCard.width
            height: updateCard.height
            radius: 16
            color: "#59000000"
        }

        Rectangle {
            id: updateCard
            anchors.centerIn: parent
            width: Math.min(456, parent.width - 28)
            height: Math.min(updateColumn.implicitHeight + 40, parent.height - 28)
            radius: 16
            color: "#111e30"
            border.color: root.panelBorder
            border.width: 1
            scale: updateOverlay.shown ? 1 : 0.965

            Behavior on scale {
                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: updateColumn
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                Label {
                    Layout.fillWidth: true
                    text: root.pendingUpdate ? "Versi " + root.pendingUpdate.tag + " Tersedia" : ""
                    color: "white"
                    font.pixelSize: 17
                    font.bold: true
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                }

                Label {
                    Layout.fillWidth: true
                    text: root.pendingUpdate ? "wPlay " + root.pendingUpdate.tag + " sudah rilis (kamu memakai v" + root.appVersion + ")." : ""
                    color: "#d5dee9"
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.45
                }

                // Catatan rilis dari GitHub (teks polos, dipotong
                // wajar bila panjang). Sembunyi bila kosong.
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (!root.pendingUpdate)
                            return ""
                        const notes = root.pendingUpdate.notes.trim()
                        return notes.length > 400 ? notes.substring(0, 400) + "…" : notes
                    }
                    color: root.textDim
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    lineHeight: 1.45
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: updateNowBtn
                        Layout.fillWidth: true
                        text: "Unduh Pembaruan"
                        onClicked: updateOverlay.downloadUpdate()

                        contentItem: Text {
                            text: updateNowBtn.text
                            color: "white"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 40
                            radius: 8
                            color: updateNowBtn.pressed ? "#1d4066" : (updateNowBtn.hovered ? "#2f6db3" : "#26588f")
                        }
                    }

                    Button {
                        id: updateLaterBtn
                        Layout.fillWidth: true
                        text: "Nanti Saja"
                        onClicked: updateOverlay.dismissUpdate()

                        contentItem: Text {
                            text: updateLaterBtn.text
                            color: "#d5dee9"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 40
                            radius: 8
                            color: updateLaterBtn.hovered ? "#1a2a42" : "transparent"
                            border.color: root.panelBorder
                            border.width: 1
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------
    // Pop-up donasi SociaBuzz: overlay modal di atas seluruh jendela
    // (termasuk title bar). Tampil otomatis satu kali pada
    // peluncuran pertama; sesudah itu hanya dibuka manual lewat
    // tombol hati di title bar. Klik pada latar TIDAK menutup
    // kartu — hanya tombol di dalam kartu yang menutupnya.
    // ---------------------------------------------------------------
    Item {
        id: donationOverlay
        anchors.fill: parent
        visible: opacity > 0
        opacity: shown ? 1 : 0

        property bool shown: false

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        function openPopup() {
            // Centang selalu mulai aktif: bawaan = jangan tampil lagi.
            dontShowCheck.checked = true
            shown = true
        }

        function finishWithDonation() {
            appSettings.donationSeen = true
            appSettings.donationRemind = false
            Qt.openUrlExternally(root.donationUrl)
            shown = false
        }

        function finishLater() {
            if (dontShowCheck.checked) {
                appSettings.donationSeen = true
                appSettings.donationRemind = false
            } else {
                // Centang dilepas: boleh tampil satu kali lagi pada
                // peluncuran berikutnya.
                appSettings.donationRemind = true
            }
            shown = false
        }

        // Latar gelap; menelan semua klik di luar kartu.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.58

            MouseArea {
                anchors.fill: parent
            }
        }

        // Bayangan halus di bawah kartu.
        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 7
            width: donationCard.width
            height: donationCard.height
            radius: 16
            color: "#59000000"
        }

        Rectangle {
            id: donationCard
            anchors.centerIn: parent
            width: Math.min(456, parent.width - 28)
            height: Math.min(cardColumn.implicitHeight + 40, parent.height - 28)
            radius: 16
            color: "#111e30"
            border.color: root.panelBorder
            border.width: 1
            scale: donationOverlay.shown ? 1 : 0.965

            Behavior on scale {
                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
            }

            // Logo mini wPlay di sudut kanan atas kartu (pola Canvas
            // yang sama persis dengan logo mini title bar).
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 14
                width: 30
                height: 30
                radius: 8
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
                        const cx = 20, cy = 9.5
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
                        ctx.moveTo(10, 10)
                        ctx.lineTo(10, 20.5)
                        ctx.lineTo(18.5, 15.25)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
            }

            // Isi kartu bisa digeser hanya pada jendela kecil, saat
            // seluruh isi tidak muat sekaligus. Batang gulir tidak
            // pernah ditampilkan (AlwaysOff): pada ukuran bawaan
            // seluruh isi muat tanpa gulir, dan di jendela kecil
            // cukup digeser dengan seret/roda tetikus — batang gulir
            // bawaan yang tebal dan terang merusak tampilan kartu.
            Flickable {
                id: cardFlick
                anchors.fill: parent
                anchors.margins: 20
                contentWidth: width
                contentHeight: cardColumn.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

                ColumnLayout {
                    id: cardColumn
                    width: cardFlick.width
                    spacing: 8

                    // 1) NOTE — sengaja paling atas (permintaan user).
                    Label {
                        Layout.fillWidth: true
                        Layout.rightMargin: 44
                        text: "NOTE: Pesan ini cuma muncul satu kali — luangkan 10 detik buat baca ya 🙏"
                        color: "#cd6753"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }

                    // 2) Hook.
                    Label {
                        Layout.fillWidth: true
                        text: "Senang rasanya bisa nemenin stream kamu."
                        color: "white"
                        font.pixelSize: 19
                        font.bold: true
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                    }

                    // 3) Isi.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            Layout.fillWidth: true
                            text: "wPlay dibuat dengan satu niat sederhana: bikin streamer iPhone bisa live dari PC tanpa ribet — dan tanpa biaya. Nggak ada iklan, nggak ada langganan."
                            color: "#d5dee9"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.45
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Kalau selama ini wPlay terasa ngebantu, dan kamu pengen ikut jaga aplikasi ini tetap hidup dan berkembang, kamu bisa traktir secangkir kopi lewat SociaBuzz."
                            color: "#d5dee9"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.45
                        }

                        Label {
                            Layout.fillWidth: true
                            text: "Sukarela, semampunya. Terima kasih banyak sudah jadi bagian dari perjalanan ini. 🙏"
                            color: "#d5dee9"
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            lineHeight: 1.45
                        }
                    }

                    // 4) Kode QR di atas kartu putih (zona tenang).
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: qrCanvas.width + 18
                        implicitHeight: qrCanvas.height + 18
                        radius: 10
                        color: "white"

                        Canvas {
                            id: qrCanvas
                            anchors.centerIn: parent
                            width: Math.min(168, Math.max(120, root.height - 488))
                            height: width

                            // Data modul kode QR persis dari gambar
                            // qr-sociabuzz-oroboo.png (29 x 29 modul;
                            // isinya tautan root.donationUrl).
                            property var modules: [
                                "11111110011001110010001111111",
                                "10000010111000010100101000001",
                                "10111010111100101001101011101",
                                "10111010100000111101101011101",
                                "10111010010011110001001011101",
                                "10000010001011100110101000001",
                                "11111110101010101010101111111",
                                "00000000111111000010100000000",
                                "10000010100010110101011001110",
                                "00111101110000101111000110110",
                                "11111011100110011100110110000",
                                "00010100001000101001110001000",
                                "10100111000101111000101100001",
                                "00101100101001111011101110011",
                                "11001111000011110110110101100",
                                "01110000011101111011100010101",
                                "00010110110100110100000001100",
                                "11001001100100011111111110111",
                                "11010110000101110001101001001",
                                "10011101010010100001110100000",
                                "10111110000110000101111110111",
                                "00000000100101010110100011000",
                                "11111110010111110101101011100",
                                "10000010000111010000100010001",
                                "10111010010001010011111111011",
                                "10111010010001011110110001101",
                                "10111010010110010100101111110",
                                "10000010011000100001000101101",
                                "11111110100110111101011011100"
                            ]

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.fillStyle = "#0e1a2b"
                                // Kisi 33 x 33: 29 modul + zona tenang
                                // 2 modul di tiap sisi (sama seperti
                                // bingkai putih gambar aslinya).
                                const cell = width / (modules.length + 4)
                                for (let y = 0; y < modules.length; y++) {
                                    const row = modules[y]
                                    for (let x = 0; x < row.length; x++) {
                                        if (row.charAt(x) === "1")
                                            ctx.fillRect(Math.floor((x + 2) * cell), Math.floor((y + 2) * cell), Math.ceil(cell), Math.ceil(cell))
                                    }
                                }
                            }

                            onWidthChanged: requestPaint()
                        }
                    }

                    // 5) Keterangan di bawah QR.
                    Label {
                        Layout.fillWidth: true
                        text: "Scan pakai kamera HP, atau klik tombol di bawah"
                        color: root.textDim
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    // 6) Baris tombol.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Button {
                            id: donateNowBtn
                            Layout.fillWidth: true
                            text: "Traktir Kopi ☕"
                            onClicked: donationOverlay.finishWithDonation()

                            contentItem: Text {
                                text: donateNowBtn.text
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitHeight: 40
                                radius: 8
                                color: donateNowBtn.pressed ? "#1d4066" : (donateNowBtn.hovered ? "#2f6db3" : "#26588f")
                            }
                        }

                        Button {
                            id: laterBtn
                            Layout.fillWidth: true
                            text: "Nanti Saja"
                            onClicked: donationOverlay.finishLater()

                            contentItem: Text {
                                text: laterBtn.text
                                color: "#d5dee9"
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitHeight: 40
                                radius: 8
                                color: laterBtn.hovered ? "#1a2a42" : "transparent"
                                border.color: root.panelBorder
                                border.width: 1
                            }
                        }
                    }

                    // 7) Centang jangan tampilkan lagi.
                    CheckBox {
                        id: dontShowCheck
                        Layout.alignment: Qt.AlignHCenter
                        text: "Jangan tampilkan lagi"
                        checked: true
                        spacing: 7
                        leftPadding: 0
                        rightPadding: 0

                        contentItem: Text {
                            text: dontShowCheck.text
                            color: root.textDim
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: dontShowCheck.indicator.width + dontShowCheck.spacing
                        }

                        indicator: Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            x: dontShowCheck.leftPadding
                            y: (dontShowCheck.height - height) / 2
                            radius: 4
                            color: "transparent"
                            border.color: "#3a5878"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: root.accent
                                font.pixelSize: 11
                                font.bold: true
                                visible: dontShowCheck.checked
                            }
                        }
                    }
                }
            }
        }
    }
}
