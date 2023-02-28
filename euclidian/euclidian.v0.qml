import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.2
import Qt.labs.settings 1.0
import QtQml 2.8
import MuseScore 3.0

import "notehelper.js" as NoteHelper

/**********************************************
/*  1.0.0: Initial version
 * TODO:  Ne pas mettre la séquence en position 0, track 1
 * TODO:  définier la note à mettre

/**********************************************/
MuseScore {
    menuPath: "Plugins." + qsTr("Euclidian Rhythm")
    version: "1.0.0"
    requiresScore: false // true
    description: qsTr("Create an euclidian rhythm")
    pluginType: "dialog"

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            mainWindow.title = qsTr("Euclidian Rhythm");
            mainWindow.thumbnailName = "logoTemplater.png";
            // mainWindow.categoryCode = "batch-processing";
        }
    }

    MessageDialog {
        id: versionError
        visible: false
        title: qsTr("Unsupported MuseScore Version")
        text: qsTr("This plugin does not work with MuseScore 4.0.")
        onAccepted: {
            mainWindow.parent.Window.window.close();
        }
    }

    onRun: {
        // check MuseScore version
        if (mscoreMajorVersion < 3 || mscoreMajorVersion > 3) { // we should really never get here, but fail at the imports above already
            mainWindow.visible = false
                versionError.open()
        }

    }

    id: mainWindow

    // `width` and `height` allegedly are not valid property names, works regardless and seems needed?!
    width: mainRow.childrenRect.width + mainRow.anchors.margins * 2
    height: mainRow.childrenRect.height + mainRow.anchors.margins * 2

    GridLayout {
        id: mainRow
        rowSpacing: 2
        columnSpacing: 2
        anchors.margins: 20

        columns: 2

        GridLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.margins: 20

            columnSpacing: 5
            rowSpacing: 5
            columns: 2

            Label {
                text: qsTr("Rhythm") + ":"
            }

            RowLayout {
                TextField {
                    Layout.preferredWidth: 40
                    id: patternBeats
                    text: "1"
                    selectByMouse: true
                    onTextChanged: refresh()

                    validator: IntValidator {
                        bottom: 1;
                        top: parseInt(patternSize.text)
                    }
                }
                Label {
                    text: "/"
                }
                TextField {
                    Layout.preferredWidth: 40
                    id: patternSize
                    text: "32"
                    selectByMouse: true
                    onDisplayTextChanged: refresh()
                    validator: IntValidator {
                        bottom: 1;
                        top: 999;
                    }
                }

            }

            Label {
                text: qsTr("Start at step") + ":"
            }
            SpinBox {
                id: startAt
                from: (parseInt(patternSize.text) * (-1))
                value: 0
                to: (parseInt(patternSize.text) - 1)
                stepSize: 1

                validator: IntValidator {
                    bottom: startAt.from
                    top: startAt.to
                }

                textFromValue: function (value, locale) {
                    return Number((value < 0) ? value : value + 1); // On bypasse 0: -2, -1, 1, 2
                }

                valueFromText: function (text, locale) {
                    var n = Number.fromLocaleString(locale, text);
                    return (n <= 0) ? n : n - 1; // On bypasse 0: -2, -1, 1, 2
                }

                onValueModified: refresh()
            }
            Label {
                text: qsTr("Duration") + ":"
            }
            TextField {
                Layout.preferredWidth: 40
                id: duration
                text: "1"
                selectByMouse: true
            }
            Label {
                text: qsTr("Unit") + ":"
            }

            TempoUnitBox {
                id: unit
                sizeMult: 1
            }

        } // GroupLayout

        Canvas {
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            Layout.margins: 20

            property int size: 150
            property int thickness: 20

            //color: "yellow"

            width: size
            height: size

            id: visual

            onPaint: {
                var c = parseInt(patternSize.text);
                var delta = Math.PI * 2 / c;

                var ctx = getContext("2d");

                ctx.clearRect(0, 0, size, size);

                for (var index = 0; index < c; index++) {

                    var start = (3 * Math.PI / 2) + delta * index;
                    var end = (3 * Math.PI / 2) + delta * (index + 1) - (Math.min(2 * (2 * Math.PI / 360), delta * 0.5));

                    ctx.beginPath();
                    ctx.arc(visual.size / 2, visual.size / 2, (visual.size - visual.thickness) / 2, start, end, false);
                    ctx.lineWidth = visual.thickness
                        ctx.strokeStyle = (isBeat(index) ? sysActivePalette.text : sysActivePalette.mid)
                        ctx.stroke()
                }

            }

        }
        Item {
            Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.rightMargin: 10
            Layout.leftMargin: 10
            Layout.topMargin: 5
            Layout.preferredHeight: btnrow.implicitHeight
            RowLayout {
                id: btnrow
                spacing: 5
                anchors.fill: parent
                Item { // spacer
                    id: spacer
                    implicitHeight: 10
                    Layout.fillWidth: true
                }

                Button {
                    id: ok
                    enabled: (patternBeats.text !== "") && (patternSize.text !== "")
                    text: qsTr("Create")
                    onClicked: {
                        work();

                    } // onClicked
                } // ok
                Button {
                    id: cancel
                    text: /*qsTr("Cancel")*/ qsTranslate("QPlatformTheme", "Close")
                    onClicked: {
                        mainWindow.parent.Window.window.close();
                    }
                } // Cancel
            } // RowLayout
        } // Item
    } // ColumnLayout

    // Plugin settings
    Settings {
        id: settings
        category: "EuclidianRhythmPlugin"
        property alias nbbeats: patternBeats.text
        property alias size: patternSize.text
        property alias duration: duration.text
        property alias unit: unit.unitDuration
    }

    SystemPalette {
        id: sysActivePalette;
        colorGroup: SystemPalette.Active
    }

    function isBeat(n) {

        var m = n + startAt.value;

        var coef = patternBeats.text / patternSize.text;

        var curr = Math.floor(m * coef);
        var prev = Math.floor((m - 1) * coef);

        return (prev < curr);

    }

    function refresh() {
        visual.requestPaint();
    }

    // work
    function work() {

        var what = [];

        for (var n = 0; n < duration.text; n++) {
            for (var i = 0; i < patternSize.text; i++) {
                what.push(isBeat(i));
            }
        }

        console.log("Pushing " + what.length + " elements");

        var score = curScore;
        score.startCmd();

        var fduration = fraction(unit.unitFractionNum, unit.unitFractionDenum);

        var debugNextMeasure = true;

        var cursor = score.newCursor();
        cursor.rewind(Cursor.SELECTION_START);
        console.log("=> "+cursor.track);
        
        cursor.filter = Segment.ChordRest;

        for (var i = 0; i < what.length; i++) {

            var play = what[i];

            console.log("---- " + i + " ----");
            console.log((play ? "=> NOTE" : "=> REST"));

            var success = (i === 0) ? true : cursor.next();

            removeElement(cursor.element); // replace whatever we have by a rest

            var note = cursor.element;
            var cur_time = cursor.segment.tick;

            if (play) {
                // Note

                console.log("adding note at " + cur_time + " of " + fduration.str);
                console.log("- " + note.userName());
                var target = [];
                target.push({
                    "pitch": 60,
                    "concertPitch": false,
                    "sharp_mode": false
                });
                target.push({
                    "pitch": 64,
                    "concertPitch": false,
                    "sharp_mode": false
                });
                console.log("- rest to chord");
                note = NoteHelper.restToChord(note, target, fduration); // !! ne fonctionne que si "note" est un "REST"

            } else {
                // Rest
                cursor.setDuration(fduration.numerator, fduration.denominator);
                console.log("adding rest at " + cur_time + " of " + fduration.str);
                cursor.addRest();
            }
            cursor.rewindToTick(cur_time);
            note = cursor.element;

        }
        score.endCmd();

    }

} // MuseScore