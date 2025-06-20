import QtQuick 2.9
import QtQuick.Controls 2.2

// v1.1.0: including textRole
// v1.1.1: bugfix on textRole
// v1.1.2: disabled color

ComboBox {
    id: control

    model: []
	
	textRole: "text"
    
    implicitWidth: 80

    delegate: ItemDelegate { // requiert QuickControls 2.2
        width: control.width
        contentItem: Text {
            // text:  modelData[textRole]
            text:  model[textRole]
            anchors.verticalCenter: parent.verticalCenter
            color: (mscoreMajorVersion >= 4)? ui.theme.fontPrimaryColor : sysActivePalette.text
            opacity: (control.enabled)?1:0.6
        }
        highlighted: control.highlightedIndex === index
    }

    contentItem: Text {

        text: control.displayText
        anchors.verticalCenter: parent.verticalCenter
        color: (mscoreMajorVersion >= 4)? ui.theme.fontPrimaryColor : sysActivePalette.text
        opacity: (control.enabled)?1:0.6
        
        leftPadding: 10
        rightPadding: 10 //+ control.indicator.width + control.spacing
        topPadding: 5
        bottomPadding: 5
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Canvas {
        x: control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 8
        height: 5
        contextType: "2d"

        onPaint: {
            context.reset();
            context.moveTo(0, 0);
            context.lineTo(width, 0);
            context.lineTo(width / 2, height);
            context.closePath();
            context.fillStyle = (mscoreMajorVersion >= 4)? ui.theme.fontPrimaryColor : sysActivePalette.text;
            context.fill();
        }
    } 
    
    SystemPalette { id: sysActivePalette; colorGroup: SystemPalette.Active }
}