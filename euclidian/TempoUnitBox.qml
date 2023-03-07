import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

/**
 * Exposes 2 values:
 * - unitDuration: the base duration selected (4 for a whole, 1 for a quarter, ...)
 * - unitText: a representation with Symbols of the selected duration
 * - unitFractionNum: the numerator of the fraction to use for durations
 * - unitFractionDenum: the denumerator of the fraction to use for durations
 * 1.0.0 Version initiale tirée de TapTempo
 */

RowLayout {
    // id
    id: control

    // layout
    spacing: 5

    // control
    property var sizeMult: 1.5

    property var buttonColor: "#21be2b"
    property var buttonDownColor: "#17a81a"

    // returned values
    property var unitDuration
    readonly property var unitText: (lstMult.currentIndex>=0)?multipliers.get(lstMult.currentIndex).sym:undefined
    readonly property var unitFractionNum: (lstMult.currentIndex>=0)?multipliers.get(lstMult.currentIndex).fnum:undefined
    readonly property var unitFractionDenum: (lstMult.currentIndex>=0)?multipliers.get(lstMult.currentIndex).fdenum:undefined

    // inner data
    ListModel {
        id: multipliers
        ListElement 
        //mult is a tempo-multiplier compared to a crotchet
        {
            text: '\uECA2';
            mult: 4;
            sym: '<sym>metNoteWhole</sym>';
            fnum: 1;
            fdenum: 1
        } // 1/1
        ListElement 
        {
            text: '\uECA3 \uECB7';
            mult: 3;
            sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym>';
            fnum: 3;
            fdenum: 4
        } // 1/2.
        ListElement 
        {
            text: '\uECA3';
            mult: 2;
            sym: '<sym>metNoteHalfUp</sym>';
            fnum: 1;
            fdenum: 2
        } // 1/2
        ListElement 
        {
            text: '\uECA5 \uECB7 \uECB7';
            mult: 1.75;
            sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>';
            fnum: 7;
            fdenum: 16
        } // 1/4..
        ListElement 
        {
            text: '\uECA5 \uECB7';
            mult: 1.5;
            sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym>';
            fnum: 3;
            fdenum: 8
        } // 1/4.
        ListElement 
        {
            text: '\uECA5';
            mult: 1;
            sym: '<sym>metNoteQuarterUp</sym>';
            fnum: 1;
            fdenum: 4
        } // 1/4
        ListElement 
        {
            text: '\uECA7 \uECB7 \uECB7';
            mult: 0.875;
            sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>';
            fnum: 7;
            fdenum: 32
        } // 1/8..
        ListElement 
        {
            text: '\uECA7 \uECB7';
            mult: 0.75;
            sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym>';
            fnum: 3;
            fdenum: 16
        } // 1/8.
        ListElement 
        {
            text: '\uECA7';
            mult: 0.5;
            sym: '<sym>metNote8thUp</sym>';
            fnum: 1;
            fdenum: 8
        } // 1/8
        ListElement 
        {
            text: '\uECA9 \uECB7 \uECB7';
            mult: 0.4375;
            sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>';
            fnum: 7;
            fdenum: 64
        } //1/16..
        ListElement 
        {
            text: '\uECA9 \uECB7';
            mult: 0.375;
            sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym>';
            fnum: 3;
            fdenum: 32
        } //1/16.
        ListElement 
        {
            text: '\uECA9';
            mult: 0.25;
            sym: '<sym>metNote16thUp</sym>';
            fnum: 1;
            fdenum: 16
        } //1/16
    }

    // Components
    ComboBox {
        id: lstMult
        model: multipliers

        textRole: "text"

        property var comboValue: "mult"

        onActivated: {
            console.log("Activated with model = %1".arg(JSON.stringify(model)));
            unitDuration = model.get(lstMult.currentIndex)[comboValue];
            console.log("Ending up with unitDuration = %1".arg(JSON.stringify(unitDuration)));
        }

        Binding on currentIndex {
            value: indexForUnitDuration()
        }
        
        Component.onCompleted: {
            // to be done this way too for the very first call
            var ci=indexForUnitDuration();
            if(ci<=0) ci=6; // chercher l'index telque mult=1
            lstMult.currentIndex = ci;
        }

        implicitHeight: 40 * sizeMult
        implicitWidth: 90

        font.family: 'MScore Text'
        font.pointSize: 10 * sizeMult

        delegate: ItemDelegate {
            contentItem: Text {
                // text: modelData[lstMult.textRole] // "modelData" fonctionne pour un modèle qui est une Array, "model" pour un modèle qui est un ListModel
                text: model[lstMult.textRole]
                verticalAlignment: Text.AlignVCenter
                font: lstMult.font
            }
            highlighted: multipliers.highlightedIndex === index

        }
        
    }
    
    function indexForUnitDuration() {
        if (!unitDuration) return -1;
        for( var i = 0; i < multipliers.rowCount(); i++ ) {
            if (multipliers.get(i).mult===unitDuration) return i;
        }
        unitDuration=undefined;
        return -1;
    }
}