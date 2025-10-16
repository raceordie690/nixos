import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import SddmComponents 2.0
import Qt.labs.folderlistmodel 2.15

Rectangle {
    id: container
    
    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    
    property int sessionIndex: typeof session !== "undefined" ? session.index : 0
    
    Connections {
        target: sddm
        
        function onLoginSucceeded() {
            errorMessage.color = "steelblue"
            errorMessage.text = textConstants.loginSucceeded
        }
        
        function onLoginFailed() {
            password.text = ""
            errorMessage.color = "red"
            errorMessage.text = textConstants.loginFailed
        }
        
        function onInformationMessage(message) {
            errorMessage.color = "steelblue"
            errorMessage.text = message
        }
    }
    
    // Background with random wallpaper
    Rectangle {
        id: backgroundContainer
        anchors.fill: parent
        color: "#1e1e2e"
        
        // Folder model to get wallpapers
        FolderListModel {
            id: wallpaperModel
            folder: "file:///usr/share/sddm-wallpapers"
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp"]
            showDirs: false
            
            property int currentRandomIndex: -1
            
            Component.onCompleted: {
                console.log("Wallpaper model loaded, count:", count)
                selectRandomWallpaper()
            }
            
            onCountChanged: {
                if (count > 0) {
                    selectRandomWallpaper()
                }
            }
            
            function selectRandomWallpaper() {
                if (count > 0) {
                    // Generate a truly random index using current time
                    var seed = new Date().getTime()
                    var randomIndex = Math.floor((seed % count))
                    currentRandomIndex = randomIndex
                    console.log("Selected wallpaper index:", randomIndex, "of", count)
                    backgroundImage.source = get(randomIndex, "fileURL")
                } else {
                    console.log("No wallpapers found, using fallback")
                    backgroundImage.source = "file:///usr/share/sddm-wallpapers/default.jpg"
                }
            }
        }
        
        Image {
            id: backgroundImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: "file:///usr/share/sddm-wallpapers/default.jpg" // fallback
            asynchronous: true
            smooth: true
            
            onStatusChanged: {
                if (status === Image.Error) {
                    console.log("Failed to load wallpaper, trying fallback")
                    source = "file:///usr/share/sddm-wallpapers/default.jpg"
                }
            }
        }
        
        // Proper blur effect using QtGraphicalEffects
        FastBlur {
            id: backgroundBlur
            anchors.fill: backgroundImage
            source: backgroundImage
            radius: 64
            cached: true
            
            // Dark overlay for better readability
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.4
            }
        }
        
        // Force wallpaper refresh on visibility change
        Timer {
            id: refreshTimer
            interval: 500
            running: false
            repeat: false
            onTriggered: {
                if (wallpaperModel.count > 0) {
                    wallpaperModel.selectRandomWallpaper()
                }
            }
        }
        
        Component.onCompleted: {
            refreshTimer.start()
        }
    }
    
    // Clock
    Rectangle {
        id: clockContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 40
        width: 200
        height: 80
        color: "#313244"
        opacity: 0.8
        radius: 10
        
        Column {
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                id: timeText
                color: "#cdd6f4"
                font.pointSize: 24
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
                
                function updateTime() {
                    text = new Date().toLocaleTimeString(Qt.locale(), "hh:mm")
                }
            }
            
            Text {
                id: dateText
                color: "#cdd6f4"
                font.pointSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
                
                function updateDate() {
                    text = new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                }
            }
        }
        
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                timeText.updateTime()
                dateText.updateDate()
            }
        }
        
        Component.onCompleted: {
            timeText.updateTime()
            dateText.updateDate()
        }
    }
    
    // Main login area
    Rectangle {
        id: mainContainer
        anchors.centerIn: parent
        width: 400
        height: 500
        color: "#313244"
        opacity: 0.9
        radius: 15
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 60
            
            // User avatar
            Rectangle {
                id: userPictureBackground
                width: 120
                height: 120
                radius: 60
                color: "#45475a"
                anchors.horizontalCenter: parent.horizontalCenter
                
                    Rectangle {
                        id: userPictureClip
                        width: parent.width - 4
                        height: parent.height - 4
                        anchors.centerIn: parent
                        radius: width / 2
                        color: "#45475a"
                        clip: true
                        
                        Image {
                            id: userPicture
                            anchors.fill: parent
                            source: typeof userModel !== "undefined" && userModel.lastUser !== "" ? "file:///var/lib/AccountsService/icons/" + userModel.lastUser : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                        }                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "transparent"
                        border.color: "#cdd6f4"
                        border.width: 2
                    }
                }
                
                // Fallback icon if no user picture
                Text {
                    anchors.centerIn: parent
                    text: "👤"
                    font.pointSize: 40
                    color: "#cdd6f4"
                    visible: userPicture.status !== Image.Ready
                }
            }
            
            // Username field
            Rectangle {
                width: parent.width
                height: 50
                color: "#45475a"
                radius: 8
                border.color: userNameInput.activeFocus ? "#89b4fa" : "transparent"
                border.width: 2
                
                TextInput {
                    id: userNameInput
                    anchors.fill: parent
                    anchors.margins: 15
                    font.pointSize: 14
                    color: "#cdd6f4"
                    selectByMouse: true
                    selectionColor: "#89b4fa"
                    verticalAlignment: TextInput.AlignVCenter
                    
                    Text {
                        anchors.fill: parent
                        text: typeof textConstants !== "undefined" ? textConstants.userName : "Username"
                        color: "#6c7086"
                        verticalAlignment: Text.AlignVCenter
                        visible: userNameInput.text.length === 0 && !userNameInput.activeFocus
                    }
                    
                    KeyNavigation.backtab: layoutBox
                    KeyNavigation.tab: password
                    
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(userNameInput.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }
            
            // Password field
            Rectangle {
                width: parent.width
                height: 50
                color: "#45475a"
                radius: 8
                border.color: password.activeFocus ? "#89b4fa" : "transparent"
                border.width: 2
                
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: 15
                    font.pointSize: 14
                    color: "#cdd6f4"
                    selectByMouse: true
                    selectionColor: "#89b4fa"
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    
                    Text {
                        anchors.fill: parent
                        text: typeof textConstants !== "undefined" ? textConstants.password : "Password"
                        color: "#6c7086"
                        verticalAlignment: Text.AlignVCenter
                        visible: password.text.length === 0 && !password.activeFocus
                    }
                    
                    KeyNavigation.backtab: userNameInput
                    KeyNavigation.tab: loginButton
                    
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(userNameInput.text, password.text, sessionIndex)
                            event.accepted = true
                        }
                    }
                }
            }
            
            // Login button
            Rectangle {
                id: loginButton
                width: parent.width
                height: 50
                color: loginButtonArea.pressed ? "#74c7ec" : "#89b4fa"
                radius: 8
                
                Text {
                    anchors.centerIn: parent
                    text: typeof textConstants !== "undefined" ? textConstants.login : "Login"
                    color: "#1e1e2e"
                    font.pointSize: 14
                    font.bold: true
                }
                
                MouseArea {
                    id: loginButtonArea
                    anchors.fill: parent
                    onClicked: sddm.login(userNameInput.text, password.text, sessionIndex)
                }
                
                KeyNavigation.backtab: password
                KeyNavigation.tab: sessionButton
                
                Keys.onPressed: {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        sddm.login(userNameInput.text, password.text, sessionIndex)
                        event.accepted = true
                    }
                }
            }
            
            // Error message
            Text {
                id: errorMessage
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: "#f38ba8"
                font.pointSize: 10
                wrapMode: Text.Wrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    
    // Bottom panel with session and power options
    Rectangle {
        id: bottomPanel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60
        color: "#313244"
        opacity: 0.8
        
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            spacing: 20
            
            // Session selection
            Rectangle {
                id: sessionButton
                width: 120
                height: 40
                color: "#45475a"
                radius: 6
                
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🖥️"
                        font.pointSize: 16
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: typeof session !== "undefined" ? session.lastSession : "Hyprland"
                        color: "#cdd6f4"
                        font.pointSize: 12
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (sessionModel.count > 1) {
                            sessionIndex = (sessionIndex + 1) % sessionModel.count
                        }
                    }
                }
                
                KeyNavigation.backtab: loginButton
                KeyNavigation.tab: layoutBox
            }
            
            // Keyboard layout
            Rectangle {
                id: layoutBox
                width: 100
                height: 40
                color: "#45475a"
                radius: 6
                
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌨️"
                        font.pointSize: 16
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: typeof keyboard !== "undefined" && keyboard.layouts && keyboard.layouts[keyboard.currentLayout] ? keyboard.layouts[keyboard.currentLayout].shortName : "US"
                        color: "#cdd6f4"
                        font.pointSize: 12
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.numberOfLayouts
                }
                
                KeyNavigation.backtab: sessionButton
                KeyNavigation.tab: userNameInput
            }
        }
        
        // Power options
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            spacing: 15
            
            // Suspend
            Rectangle {
                width: 40
                height: 40
                color: suspendArea.pressed ? "#6c7086" : "#45475a"
                radius: 6
                visible: sddm.canSuspend
                
                Text {
                    anchors.centerIn: parent
                    text: "🌙"
                    font.pointSize: 16
                }
                
                MouseArea {
                    id: suspendArea
                    anchors.fill: parent
                    onClicked: sddm.suspend()
                }
            }
            
            // Reboot
            Rectangle {
                width: 40
                height: 40
                color: rebootArea.pressed ? "#6c7086" : "#45475a"
                radius: 6
                visible: sddm.canReboot
                
                Text {
                    anchors.centerIn: parent
                    text: "🔄"
                    font.pointSize: 16
                }
                
                MouseArea {
                    id: rebootArea
                    anchors.fill: parent
                    onClicked: sddm.reboot()
                }
            }
            
            // Shutdown
            Rectangle {
                width: 40
                height: 40
                color: shutdownArea.pressed ? "#6c7086" : "#45475a"
                radius: 6
                visible: sddm.canPowerOff
                
                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    font.pointSize: 16
                }
                
                MouseArea {
                    id: shutdownArea
                    anchors.fill: parent
                    onClicked: sddm.powerOff()
                }
            }
        }
    }
    
    Component.onCompleted: {
        if (userNameInput.text === "") {
            userNameInput.focus = true
        } else {
            password.focus = true
        }
    }
}