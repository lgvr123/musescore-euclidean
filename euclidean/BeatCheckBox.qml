import QtQuick 2.9
import QtQuick.Controls 2.2

CheckBox {
    id: control
    leftPadding : 0
    rightPadding : 0
    anchors.margins: 0
    width: 24
    height: 24


    indicator: Rectangle {
        id: box
        anchors.centerIn: control
        anchors.fill: parent
        border.color: sysActivePalette.window
        color: (control.checked ? sysActivePalette.text : sysActivePalette.mid)
        
        // Text {
            // anchors.centerIn: parent
            // anchors.fill: parent
            // text: control.text
            // color: (control.checked ? sysActivePalette.light : sysActivePalette.text)
        // }
    }

    contentItem: Text {
        width: 0
        text: ""
        leftPadding: 0
    }
    
    SystemPalette {
        id: sysActivePalette;
        colorGroup: SystemPalette.Active
    }

}