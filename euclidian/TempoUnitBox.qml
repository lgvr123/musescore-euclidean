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
    property var unitDuration: 1
    property var unitText: multipliers[lstMult.currentIndex].sym;
    property var unitFractionNum: multipliers[lstMult.currentIndex].fnum;
    property var unitFractionDenum: multipliers[lstMult.currentIndex].fdenum;

    // inner data
    property var multipliers: [
        //mult is a tempo-multiplier compared to a crotchet
        {
            text: '\uECA2',
            mult: 4,
            sym: '<sym>metNoteWhole</sym>',
            fnum: 1,
            fdenum: 1
        }, // 1/1
        {
            text: '\uECA3 \uECB7',
            mult: 3,
            sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym>',
            fnum: 3,
            fdenum: 4
        }, // 1/2.
        {
            text: '\uECA3',
            mult: 2,
            sym: '<sym>metNoteHalfUp</sym>',
            fnum: 1,
            fdenum: 2
        }, // 1/2
        {
            text: '\uECA5 \uECB7 \uECB7',
            mult: 1.75,
            sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>',
            fnum: 7,
            fdenum: 16
        }, // 1/4..
        {
            text: '\uECA5 \uECB7',
            mult: 1.5,
            sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym>',
            fnum: 3,
            fdenum: 8
        }, // 1/4.
        {
            text: '\uECA5',
            mult: 1,
            sym: '<sym>metNoteQuarterUp</sym>',
            fnum: 1,
            fdenum: 4
        }, // 1/4
        {
            text: '\uECA7 \uECB7 \uECB7',
            mult: 0.875,
            sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>',
            fnum: 7,
            fdenum: 32
        }, // 1/8..
        {
            text: '\uECA7 \uECB7',
            mult: 0.75,
            sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym>',
            fnum: 3,
            fdenum: 16
        }, // 1/8.
        {
            text: '\uECA7',
            mult: 0.5,
            sym: '<sym>metNote8thUp</sym>',
            fnum: 1,
            fdenum: 8
        }, // 1/8
        {
            text: '\uECA9 \uECB7 \uECB7',
            mult: 0.4375,
            sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>',
            fnum: 7,
            fdenum: 64
        }, //1/16..
        {
            text: '\uECA9 \uECB7',
            mult: 0.375,
            sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym>',
            fnum: 3,
            fdenum: 32
        }, //1/16.
        {
            text: '\uECA9',
            mult: 0.25,
            sym: '<sym>metNote16thUp</sym>',
            fnum: 1,
            fdenum: 16
        }, //1/16
    ]

    // Components
    ComboBox {
        id: lstMult
        model: multipliers

        textRole: "text"

        // property var valueRole: "mult"
        property var comboValue: "mult"

        onActivated: {
            unitDuration = model[currentIndex][comboValue];
        }

        Binding on currentIndex {
            value: multipliers.map(function (e) {
                return e[lstMult.comboValue]
            }).indexOf(unitDuration);
        }

        implicitHeight: 40 * sizeMult
        implicitWidth: 90

        font.family: 'MScore Text'
        font.pointSize: 10 * sizeMult

        delegate: ItemDelegate {
            contentItem: Text {
                text: modelData[lstMult.textRole]
                verticalAlignment: Text.AlignVCenter
                font: lstMult.font
            }
            highlighted: multipliers.highlightedIndex === index

        }

    }
}