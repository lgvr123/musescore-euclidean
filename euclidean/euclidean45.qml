import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
//import QtQuick.Dialogs 1.2
import QtQuick.Window 2.3
//import Qt.labs.settings 1.0
import MuseScore 3.0

import "notehelper.js" as NoteHelper
import "selectionhelper.js" as SelHelper

/**********************************************
/*  1.0.0 Beta1: Initial version
/*  1.0.0 Beta2: Correct selection retrieval on selection change
/*  1.1.0 : reverse pattern
/*  1.1.0 : start note sequence at any place
/*  1.1.0 : Write and load from debug
/*  1.1.1 : New "Repeat" fill mode
/*  1.2.0 : Allow the use the fill mode in freeRhythm
/*  1.2.0 : Bug: the pattern does not start at the correct position when a ChordRest is not defined at the same position on the track 0
/*  1.2.0 : Bug: The pattern summary was always written on the first staff.
/*  1.2.0 : CR: Allow ascii symbols for alterations in the pattern summaries (noteHelper 2.0.3)
/*  1.2.0 : CR: Option to stop the pattern when pattern summary is encountered
/*  1.2.0 : Compatibility mode with MU4.5

TODO: fenêtre modale ? 


Issues : 
* matching of accidentals in the UseAsRest: a E# is matched with a F, a Gb is matched with a F#
* in the UseAsRest a B#4 is matched with a C4 isntead of a C5, so on actave lower

/**********************************************/
MuseScore {
    menuPath: "Plugins." + qsTr("Euclidean Rhythm")
    version: "1.2.0"
    requiresScore: true
    description: qsTr("Create an euclidean rhythm. MU4.5 version")
    pluginType: "dialog"

    id: mainWindow
    //4.4 title: "Euclidean Rhythm"
    //4.4 thumbnailName: "logo.png"
    
    Component.onCompleted : {
        if (mscoreMajorVersion >= 4 && mscoreMajorVersion<=3) {
            mainWindow.title = qsTr("Euclidean Rhythm");
            mainWindow.thumbnailName = "logo.png";
            // mainWindow.categoryCode = "batch-processing";
        }
    }

    property var clipboard: [];
    property var selection: [];

    property var theScore
    /**
    tick: selection's tick or 0 if no selection found,
    track: selection's track or 0 if no selection found,
    source: selection|cursor|default "default" means "no selection found"
    measure: selection's measure number or 0 if no selection found,
    measureTick: tick for the selection's measure begin
    summary: element of type STAFF_TEXT containing a summary that could be reused. null if not found.
     */
    property var positionInScore
    property var summary: ""

    onRun: {
        // check MuseScore version
        if (mscoreMajorVersion < 3) {
            mainWindow.visible = false
                versionError.open()
        }

        // Store the current score (because the clipboard analyse mechanism could change the `curScore` definition
        theScore = curScore;

        // Reconstruct the stored free rhythm pattern
        var pArr = settings.freePattern;
        console.log("pArr: " + (pArr ? JSON.stringify(pArr) : "undefined"));
        console.log("is array ? " + Array.isArray(pArr));
        console.log("Size %1 vs. pattern %2".arg(pArr ? pArr.length : 0).arg(freePattern.count));
        if (pArr && Array.isArray(pArr)) {
            for (var i = 0; i < Math.min(pArr.length, freePattern.count); i++) {
                freePattern.itemAt(i).checked = (pArr[i] === 1);
            }
        }

        // Retrieving the starting position in score
        positionInScore = retrieveCurrentPosition(); // assigning to "positionInScore" all properties at once

        // Retrieving the notes that could be used for the rhythm
        selection = retrieveSelection();
        clipboard = retrieveClipboard();

        // Setting the default options based on what was found in the earlier steps
        useFirst.checked = true;
        useOffbeatRest.checked = true;
        if (clipboard.length > 0) {
            useClipboard.checked = true;
            if (clipboard.length > 1)
                cycleNotes.checked = true;
        } else if (selection.length > 0) {
            useSelection.checked = true;
            if (selection.length > 1)
                cycleNotes.checked = true;
        } else {
            useAdhoc.checked = true;
        }

        atCursor.checked = true;

        // Default value, if nothing from settings
        if (!euclideanRhythm.checked && !freeRhythm.checked) {
            euclideanRhythm.checked = true;
        }

        if (!mult.currentIndex || mult.currentIndex <= 0) {
            mult.currentIndex = 0;
        }

    }

    onScoreStateChanged: {
        if (state.selectionChanged) {
            console.log("!! Score's selection changed");
            if (ongoing) {
                console.log("  But busy");
                return;
            }

            // Retrieving the notes that could be used for the rhythm
            selection = retrieveSelection();
            console.log("New selection is : " + ((selection.length > 0) ? selection[0].notes[0] : "--"));

            // Retrieving the starting position in score
            positionInScore = retrieveCurrentPosition(); // assigning to "positionInScore" all properties at once

        }
    }
    
    onSelectionChanged: {
        console.log("°° Selection object changed");
        if (selection.length === 0 && useSelection.checked) {
            useSelection.checked = false;
            if (clipboard.length > 0) {
                useClipboard.checked = true;
            } else {
                useAdhoc.checked = true;
            }
        } else if (selection.length>1 && useSelection.checked) {
            cycleNotes.checked=true;
            startSequenceAt.value=1;
        }
        
    }

    onPositionInScoreChanged: {
        // txtStatus.text = qsTr("At measure : %1").arg(pis ? pis.measure : qsTr("invalid"));

        if (theScore && positionInScore) {
            var instru = "?";

            for (var i = 0; i < theScore.parts.length; i++) {
                var p = theScore.parts[i];
                if (p.startTrack <= positionInScore.track && p.endTrack > positionInScore.track) {
                    instru = p.longName;
                    break;
                }
            }

            var measure = positionInScore.measure;
            if ((positionInScore.track % 4) > 0)
                measure += "/" + ((positionInScore.track % 4) + 1);

            txtStatus.text = qsTr("At : %1, measure %2").arg(instru).arg(measure);

            // summary=(positionInScore.summary?positionInScore.summary:"");

        } else {
            txtStatus.text = qsTr("At : invalid");
            // summary="";
        }

        //console.log("Summary : "+(positionInScore && positionInScore.summary?positionInScore.summary.text:""));

    }

    property var ongoing: false

    // Compute dimension based on content
    width: mainRow.implicitWidth + extraLeft + extraRight
    height: mainRow.implicitHeight + extraTop + extraBottom

    property int extraMargin: mainRow.anchors.margins ? mainRow.anchors.margins : 0
    property int extraTop: mainRow.anchors.topMargin ? mainRow.anchors.topMargin : extraMargin
    property int extraBottom: mainRow.anchors.bottomMargin ? mainRow.anchors.bottomMargin : extraMargin
    property int extraLeft: mainRow.anchors.leftMargin ? mainRow.anchors.leftMargin : extraMargin
    property int extraRight: mainRow.anchors.rightMargin ? mainRow.anchors.rightMargin : extraMargin

    ListModel {
        id: allnotes

        Component.onCompleted: {
            var notes = [];
            for (var octave = 0; octave < 7; octave++) {
                for (var n = 0; n < NoteHelper.pitchnotes.length; n++) {
                    var name = NoteHelper.pitchnotes[n];
                    var accidental = ((n > 0) && (name === NoteHelper.pitchnotes[n - 1])) ? "SHARP" : "NONE";
                    name = name + octave;
                    var note = NoteHelper.buildPitchedNote(name, accidental);
                    // for presentation in the ComboBox
                    note.name=note.extname.fullname;
                    notes.push(note);
                }
            }
            notes = notes.sort(function (a, b) {
                return b.pitch - a.pitch
            });

            for (var i = 0; i < notes.length; i++) {
                allnotes.append(notes[i]);
            }

        }

    }
    ListModel {
        id: durationmult

        Component.onCompleted: {
            durationmult.append({
                text: qsTr("1"),
                mult: 1
            });
            durationmult.append({
                text: qsTr("2"),
                mult: 2
            });
            durationmult.append({
                text: qsTr("3"),
                mult: 3
            });
            durationmult.append({
                text: qsTr("4"),
                mult: 4
            });
            durationmult.append({
                text: qsTr("fill"),
                mult: -1
            });
            durationmult.append({
                text: qsTr("repeat"),
                mult: -2
            });
        }

    }
    // UI
    ColumnLayout {
        id: mainRow
        spacing: 2
        anchors.margins: 0

        GridLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.topMargin: 20
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            columnSpacing: 5
            rowSpacing: 5
            columns: 3

            RowLayout {
                Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                Layout.rowSpan: 3
                Layout.column: 2
                Layout.row: 1
                // Free rhythm
                // Use a transparent Item that will remain visible and hence laidout to avoid a re-layout of the rhythm circle
                // every time we switch back and forth between Euclidean and Free modes
                Item {
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    //Layout.minimumWidth: freeRhythmInfo.width
                    Layout.minimumWidth: 24 * 8
                    Layout.fillHeight: true
                    // color: "yellow"
                    ColumnLayout {
                        visible: freeRhythm.checked
                        id: freeRhythmInfo

                        ScrollView {
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            Layout.maximumHeight: visual.height - freeRhythmInfo.spacing - resetFreeGrid.height
                            Layout.preferredWidth: freeGrid.width + ScrollBar.horizontal.witdh + ScrollBar.leftPadding
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            clip: true
                            Grid {
                                id: freeGrid
                                width: BeatCheckBox.height * maxColumns
                                property var maxColumns: 8
                                columns: maxColumns
                                spacing: 0
                                Repeater {
                                    model: patternSize.value
                                    id: freePattern

                                    BeatCheckBox {
                                        text: (index + 1)
                                        onToggled: refresh()
                                    }

                                }

                            }

                        }
                        ImageButton {
                            Layout.alignment: Qt.AlignTop | Qt.AlignRight
                            id: resetFreeGrid
                            imageSource: "cancel.svg"
                            ToolTip.text: qsTr("Reset")
                            onClicked: {
                                for (var i = 0; i < freePattern.count; i++) {
                                    freePattern.itemAt(i).checked = false;
                                }
                            }
                        }
                        Item {
                            // filler
                            Layout.fillHeight: true
                        }

                    }

                }
                // Rhythm circle
                Canvas {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    // Layout.margins: 20
                    Layout.leftMargin: 20

                    property int size: 200
                    property int thickness: 20

                    width: size
                    height: size

                    id: visual

                    onPaint: {
                        var c = patternSize.value;
                        var delta = Math.PI * 2 / c;

                        var ctx = getContext("2d");

                        ctx.clearRect(0, 0, size, size);

                        var summary = getMergedPattern();
                        for (var index = 0; index < summary.length; index++) {
                            var element = summary[index];
                            var start = (3 * Math.PI / 2) + delta * element.index;
                            var end = (3 * Math.PI / 2) + delta * (element.index + element.dur) - (Math.min(2 * (2 * Math.PI / 360), delta * 0.5));

                            ctx.beginPath();
                            ctx.arc(visual.size / 2, visual.size / 2, (visual.size - visual.thickness) / 2, start, end, false);
                            ctx.lineWidth = visual.thickness
                                ctx.strokeStyle = (element.action ? (element.repeat ? sysActivePalette.shadow : sysActivePalette.text) : sysActivePalette.mid)
                                ctx.stroke()
                        }

                    }

                }

            }
            Label {
                text: qsTr("Type") + ":"
                Layout.alignment: Qt.AlignLeft
                Layout.column: 0
                Layout.row: 0
            }

            RowLayout {
                Layout.alignment: Qt.AlignLeft
                Layout.columnSpan: 2
                Layout.column: 1
                Layout.row: 0

                ButtonGroup {
                    id: rhythmType
                }

                RadioButton {
                    id: euclideanRhythm
                    text: qsTr("Euclidean Rhythm")
                    ButtonGroup.group: rhythmType
                    onToggled: refresh()

                }

                RadioButton {
                    id: freeRhythm
                    text: qsTr("Free Rhythm")
                    ButtonGroup.group: rhythmType
                    onToggled: refresh()
                }

            }

            Label {
                text: qsTr("Pattern") + ":"
                Layout.column: 0
                Layout.row: 1
            }

            RowLayout {
                Layout.column: 1
                Layout.row: 1
                TextField {
                    Layout.preferredWidth: 40
                    id: patternBeats
                    text: "1"
                    selectByMouse: true
                    onTextChanged: refresh()

                    enabled: euclideanRhythm.checked

                    validator: IntValidator {
                        bottom: 1;
                        top: patternSize.value
                    }
                }
                Label {
                    text: "/"
                    color: euclideanRhythm.checked ? sysActivePalette.text : sysActivePalette.mid
                }
                TextField {
                    Layout.preferredWidth: 40
                    readonly property int value: {
                        var val = parseInt(patternSize.text);
                        if (isNaN(val) || (val < 1))
                            val = 1;
                        return val;
                    }
                    id: patternSize
                    text: "16"
                    selectByMouse: true
                    onDisplayTextChanged: refresh()
                    validator: IntValidator {
                        bottom: 1;
                        top: 999;
                    }
                }

                TempoUnitBox {
                    id: unit
                    sizeMult: 1
                }

                CheckBox {
                    id: invert
                    text: qsTr("Invert")
                    checked: false
                    onToggled: refresh()
                    enabled: euclideanRhythm.checked
                }

            }

            Label {
                Layout.column: 0
                Layout.row: 2
                text: qsTr("Start at step") + ":"
                color: euclideanRhythm.checked ? sysActivePalette.text : sysActivePalette.mid
            }
            SpinBox {
                Layout.column: 1
                Layout.row: 2
                id: startAt
                enabled: euclideanRhythm.checked

                from: (patternSize.value * (-1))
                value: 0
                to: (patternSize.value - 1)
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
                Layout.column: 0
                Layout.row: 3
                text: qsTr("Note duration") + ":"
            }

            RowLayout {
                Layout.column: 1
                Layout.row: 3
                CompatibleComboBox {
                    model: durationmult
                    id: mult
                    textRole: "text"
                    onActivated: refresh()
                    // enabled: euclideanRhythm.checked
                }
                Label {
                    text: qsTr("unit(s)")
                }

                CheckBox {
                    Layout.column: 1
                    Layout.row: 4
                    id: mergeConsecutive
                    text: qsTr("Merge")
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Merge consecutive notes")
                    checked: false
                    onToggled: refresh()
                }
            }

            Label {
                Layout.column: 0
                Layout.row: 4
                text: qsTr("Repeats") + ":"
            }
            RowLayout {
                Layout.column: 1
                Layout.row: 4
                TextField {
                Layout.preferredWidth: 40
                id: duration
                text: "1"
                selectByMouse: true
            }
                CheckBox {
                    id: stopAtOtherPattern
                    text: qsTr("Stop")
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Stop when another pattern is encountered")
                    checked: false
                }

            }

            RowLayout {
                Layout.column: 2
                Layout.row: 4
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight

                ImageButton {
                    id: loadPattern
                    //enabled: (typeof positionInScore !== undefined) && (typeof positionInScore.summary !== undefined)
                    enabled: ((typeof positionInScore !== "undefined") && (positionInScore!==null))?(typeof positionInScore.summary === "object"):false
                    imageHeight: 25
                    imageSource: "upload.svg"
                    ToolTip.text: qsTr("Load from log")
                    onClicked: loadFromLog()
                }

                CheckBox {
                    id: addSummary
                    text: qsTr("log pattern")
                }

            }

            Rectangle {
                Layout.column: 0
                Layout.row: 5
                Layout.columnSpan: 3
                Layout.fillWidth: true
                Layout.topMargin: 15
                Layout.bottomMargin: 15

                color: sysActivePalette.button
                height: 2
            }

            Label {
                Layout.column: 0
                Layout.row: 6
                text: qsTr("Source") + ":"
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            }

            GroupBox {
                Layout.column: 1
                Layout.row: 6
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                Layout.columnSpan: 2

                ColumnLayout {

                    anchors.fill: parent

                    ButtonGroup {
                        id: source
                    }

                    RadioButton {
                        id: useSelection
                        text: qsTr("Use selection : %1").arg(chordToText(selection))
                        enabled: selection.length > 0
                        ButtonGroup.group: source
                        contentItem: Label {
                            // On doit faire tout ce bazar (de "contentItem") juste pour faire un "ElideRight"
                            elide: Text.ElideRight
                            text: useSelection.text
                            verticalAlignment: Text.AlignVCenter
                            opacity: enabled ? 1.0 : 0.3
                            leftPadding: useSelection.indicator.width + useSelection.spacing
                        }
                        Layout.maximumWidth: 350
                    }

                    /*RadioButton {
                        id: useClipboard
                        text: qsTr("Use clipboard : %1").arg(chordToText(clipboard))
                        enabled: clipboard.length > 0
                        ButtonGroup.group: source
                        contentItem: Label {
                            // On doit faire tout ce bazar (de "contentItem") juste pour faire un "ElideRight"
                            elide: Text.ElideRight
                            text: useClipboard.text
                            verticalAlignment: Text.AlignVCenter
                            opacity: enabled ? 1.0 : 0.3
                            leftPadding: useClipboard.indicator.width + useClipboard.spacing
                        }
                        Layout.maximumWidth: 350
                    }*/

                    Row {
                        RadioButton {
                            id: useAdhoc
                            text: qsTr("Use :")
                            enabled: true
                            ButtonGroup.group: source
                        }

                        CompatibleComboBox {
                            id: adhocNote
                            model: allnotes
                            textRole: "name"
                            enabled: useAdhoc.checked
                        }

                    }

                }
            }

            Label {
                Layout.column: 0
                Layout.row: 7
                text: qsTr("Use") + ":"
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                Layout.topMargin: (gpbeat.label) ? gpbeat.label.height : 0
            }

            RowLayout {
                Layout.column: 1
                Layout.row: 7
                Layout.columnSpan: 2
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft

                GroupBox {
                    title: qsTr("Beat")
                    id: gpbeat
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                    ColumnLayout {
                        ButtonGroup {
                            id: on
                        }
                        RadioButton {
                            id: useFirst
                            text: qsTr("First note: %1").arg(notesToText(nnotes(1)))
                            enabled: /*(clipboard.length > 0 && useClipboard.checked) ||*/ (selection.length > 0 && useSelection.checked) || useAdhoc.checked
                            ButtonGroup.group: on
                        }
                        Row {
                            RadioButton {
                                id: cycleNotes
                                text: qsTr("Cycle accross selection from")
                                enabled: /*(clipboard.length > 1 && useClipboard.checked) ||*/ (selection.length > 1 && useSelection.checked)
                                ButtonGroup.group: on
                            }
                            SpinBox {
                                id: startSequenceAt
                                enabled: cycleNotes.checked && cycleNotes.enabled

                                from: 1
                                value: 1
                                to: /*useClipboard.checked ? clipboard.length :*/ selection.length
                                stepSize: 1

                                validator: IntValidator {
                                    bottom: startSequenceAt.from
                                    top: startSequenceAt.to
                                }

                                textFromValue: function (value, locale) {
                                    var note = nnotes(value);
                                    return (note ? notesToText(note) : value);
                                }

                            }
                        }
                    }
                }

                GroupBox {
                    title: qsTr("Off-Beat")
                    Layout.alignment: Qt.AlignTop | Qt.AlignLeft

                    ColumnLayout {

                        anchors.fill: parent

                        ButtonGroup {
                            id: off
                        }

                        RadioButton {
                            id: useOffbeatRest
                            text: qsTr("Rest")
                            enabled: freeRhythm.checked || ((durationmult.count > mult.currentIndex && mult.currentIndex >= 0) ? (durationmult.get(mult.currentIndex).mult >= 0) : true)
                            ButtonGroup.group: off
                        }

                        RadioButton {
                            id: useOffbeatSecond
                            text: qsTr("Second: %1").arg(notesToText(nnotes(2)))
                            enabled: useOffbeatRest.enabled && (useFirst.checked) && (/*(clipboard.length > 1 && useClipboard.checked) ||*/(selection.length > 1 && useSelection.checked))
                            ButtonGroup.group: off
                        }

                        Row {
                            RadioButton {
                                id: useOffbeatAdhoc
                                text: qsTr("Use :")
                                enabled: useOffbeatRest.enabled
                                ButtonGroup.group: off
                            }

                            CompatibleComboBox {
                                model: allnotes
                                textRole: "name"
                                id: offbeatNote
                                enabled: useOffbeatAdhoc.checked && useOffbeatAdhoc.enabled
                            }
                        }

                    }
                }

            }
            Label {
                Layout.column: 0
                Layout.row: 8
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                text: qsTr("Where") + ":"
            }

            GroupBox {
                Layout.column: 1
                Layout.row: 8
                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                Layout.columnSpan: 2
                ButtonGroup {
                    id: where
                }
                ColumnLayout {
                    RadioButton {
                        id: atCursor
                        text: qsTr("At cursor")
                        enabled: positionInScore ? (positionInScore.tick !== positionInScore.measureTick) : false
                        ButtonGroup.group: where
                    }
                    RadioButton {
                        id: atMeasure
                        text: qsTr("From measure start")
                        enabled: positionInScore ? (positionInScore.tick !== positionInScore.measureTick) : false
                        ButtonGroup.group: where
                    }
                }
            }
        } // GridLayout

        // Button bar
        DialogButtonBox {
            Layout.fillWidth: true
            Layout.margins: 0
            spacing: 5
            alignment: Qt.AlignRight
            background.opacity: 0 // hide default white background

            // standardButtons: DialogButtonBox.Cancel


            CompatibleButton {
                id: ok
                enabled: (patternBeats.text !== "") && (patternSize.text !== "")
                text: qsTr("Create")
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }

            CompatibleButton {
                id: cancel
                text: qsTr("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }

            onAccepted: {
                work();
            }

            onRejected: mainWindow.parent.Window.window.close();

        } // DialogButtonBox


        // Status bar
        RowLayout {
            Layout.fillWidth: true
            Layout.columnSpan: 2
            Layout.preferredHeight: txtStatus.height
            Layout.margins: 5
            spacing: 5

            Text {
                id: txtStatus
                text: ""
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.fillWidth: true
            }
        } // status bar

    } // ColumnLayout

    // Plugin settings
    Settings {
        id: settings
        category: "EuclideanRhythmPlugin"
        property alias nbbeats: patternBeats.text
        property alias size: patternSize.text
        property alias duration: duration.text
        property alias unit: unit.unitDuration
        property alias mult: mult.currentIndex
        property alias euclideanRhythm: euclideanRhythm.checked
        property alias invert: invert.checked
        property alias freeRhythm: freeRhythm.checked
        property alias altNote: adhocNote.currentIndex
        property alias altOffNote: offbeatNote.currentIndex
        property alias addSummary: addSummary.checked
        property var freePattern
    }

    // Signal onClosing sur la fenêtre parent
    /*Connections {
        target: mainWindow.parent.Window.window
        onClosing: {
            console.log("Saving free pattern to stettings");
            var pArr = [];
            for (var i = 0; i < patternSize.value; i++) {
                pArr.push(freePattern.itemAt(i).checked ? 1 : 0);
            }
            settings.freePattern = pArr;
        }
    }*/ // 4.5

    // Palette for nice color management
    SystemPalette {
        id: sysActivePalette;
        colorGroup: SystemPalette.Active
    }
    SystemPalette {
        id: sysDisabledPalette;
        colorGroup: SystemPalette.Disabled
    }

    // Version mismatch dialog
    MessageDialog {
        id: versionError
        visible: false
        title: qsTr("Unsupported MuseScore Version")
        text: qsTr("This plugin requires MuseScore 3.6later.")
        onAccepted: {
            mainWindow.parent.Window.window.close();
        }
    }

    MessageDialog {
        id: errorDialog
        //icon: StandardIcon.Warning //4.5
        //standardButtons: StandardButton.Ok
        title: qsTr('Warning')
        text: ""
    }

    // The core Euclidean rhythm function
    function isBeat(n) {

        var m = n + startAt.value;

        var coef = patternBeats.text / patternSize.value;

        var curr = Math.floor(m * coef);
        var prev = Math.floor((m - 1) * coef);

        return (!invert.checked) ? (prev < curr) : (prev >= curr);

    }

    function getPattern() {
        var beats = [];

        if (euclideanRhythm.checked) {
            for (var n = 0; n < duration.text; n++) {
                for (var i = 0; i < patternSize.value; i++) {
                    beats.push(isBeat(i));
                }
            }
        } else {
            for (var n = 0; n < duration.text; n++) {
                for (var i = 0; i < patternSize.value; i++) {
                    beats.push(freePattern.itemAt(i).checked);
                }
            }
        }
        return beats;
    }

    function getMergedPattern() {
        var beats = getPattern();
        var summary = [];
        var defMult = (mult.currentIndex >= 0) ? durationmult.get(mult.currentIndex).mult : 1;
        // var defMult = (freeRhythm.checked? 1:(mult.currentIndex >= 0) ? durationmult.get(mult.currentIndex).mult : 1);
        // defMult==-2, = repeat => no multiplier, defMult==-1 = fill the off-beats with the on-beats => infinite multiplier
        var useMult = (defMult > 0) ? defMult : ( (defMult===-2)?1:999); 
        for (var i = 0; i < beats.length; i++) {
            var play = beats[i];
            var action = {
                index: i,
                action: play,
                repeat: false,
                dur: 1
            };
            if (play) {
                var from = i;
                for (var j = (from + 1); j < (from + useMult) && (j < beats.length); j++) { 
                    if (beats[j]) {
                        break;
                    }
                    action.dur++;
                    i++;
                }
            } else if (defMult===-2) {
                action.action=true;
                action.repeat=true;
            }
            summary.push(action);
        }
        // 2) merge
        if (mergeConsecutive.checked) {
            var i = 0;
            while (i < (summary.length - 1)) {
                if (summary[i].action === summary[i + 1].action) {
                    summary[i].dur += summary[i + 1].dur;
                    summary.splice(i + 1, 1); // remove element at (i+1)
                } else
                    i++;
            }
        }

        
        return summary;

    }

    function refresh() {
        visual.requestPaint();
    }

    function retrieveCurrentPosition() {
        var pis;
        var segment;
        if (theScore && theScore.selection != null && theScore.selection.elements.length > 0) {
            var element = theScore.selection.elements[0];
            var track = element.track;
            while (element && element.type !== Element.SEGMENT) {
                element = element.parent
            }
            if (element) {
                segment = element;
                pis = {
                    tick: element.tick,
                    track: track,
                    source: "selection",
                    measure: -1,
                    measureTick: -1
                };
            }
        }

        if (!pis && theScore) {
            var cursor = theScore.newCursor();
            cursor.rewind(Cursor.SELECTION_START);
            if (cursor.segment) { // something is selected
                segment = cursor.segment;
                pis = {
                    tick: cursor.tick,
                    track: cursor.track,
                    source: "cursor",
                    measure: -1,
                    measureTick: -1
                };
            }
        }

        if (!pis) {
            pis = {
                tick: 0,
                track: 0,
                source: "default",
                measure: 0,
                measureTick: 0,
                summary: null
            };

        } else {
            // analysing the summary
            pis.summary = segment ? findSummaryText(segment, pis.track) : null;
            //console.log("pis.summary: " + (pis.summary?pis.summary.userName():"not found"));

            // searching the initial position's measure
            var measure = theScore.firstMeasure;
            var nbMeasure = 1 + measure.noOffset;
            while (measure && measure.lastSegment.tick <= pis.tick) {
                //console.log("* %4) %1: [%2,%3]".arg(pis.tick).arg(measure.firstSegment.tick).arg(measure.lastSegment.tick).arg(nbMeasure));
                measure = measure.nextMeasure;
                if (measure)
                    nbMeasure = nbMeasure + 1 + measure.noOffset;
            }

            //if (measure) console.log("* %4) %1: [%2,%3]".arg(pis.tick).arg(measure.firstSegment.tick).arg(measure.lastSegment.tick).arg(nbMeasure));

            pis.measure = nbMeasure;

            pis.measureTick = 0;
            if (measure) {
                var first = measure.firstSegment;
                //console.log("- segment : %1 (%2)".arg(first?first.segmentType:"--").arg(first?first.userName():"--"));
                while (first && first.segmentType != 512) {
                    first = first.nextInMeasure;
                    //console.log("- segment : %1 (%2)".arg(first?first.segmentType:"--").arg(first?first.userName():"--"));
                }

                if (first)
                    pis.measureTick = first.tick;
                console.log(">>>" + pis.measureTick);

            }

            console.log("L'élément est dans la mesure %1.".arg(nbMeasure));
        }
        // console.log(JSON.stringify(pis));

        return pis;
    }

    function retrieveSelection() {
        // // retrieving only the chord elements
        // var chords=extractSelection(theScore.selection.elements);
        // return chords;

        var chords = SelHelper.getChordsFromCursor(theScore);

        if (chords && (chords.length > 0)) {
            console.log("CHORDS FOUND FROM CURSOR");
        } else {
            chords = SelHelper.getChordsFromSelection(theScore);
            if (chords && (chords.length > 0)) {
                console.log("CHORDS FOUND FROM SELECTION");
            }
        }

        if (chords && (chords.length > 0)) {
            return extractSelection(chords);
        } else {
            return [];
        }
    }

function retrieveClipboard() {
	return [];
}

    /*function retrieveClipboard() {
        var tmp = newScore("tmp", "flute", 10);
        var cursor = tmp.newCursor();
        // paste the clipboard
        cursor.rewind(0);
        tmp.selection.select(cursor.element);
        tmp.startCmd();
        cmd("paste");
        tmp.endCmd();

        // retrieve what has been pasted
        cursor.rewind(0);
        var firstTick = cursor.tick;
        var firstStaff = cursor.track;
        var lastTick = tmp.lastSegment.tick + 1;
        var lastStaff = tmp.ntracks;
        tmp.selection.selectRange(firstTick, lastTick, firstStaff, lastStaff);

        // retrieving only the chord elements
        var chords = extractSelection(tmp.selection.elements);

        // closing the tmp score
        cmd("undo");
        closeScore(tmp);

        return chords;
    }*/

    function extractSelection(elements) {
        // Retrieving everything
        var all = SelHelper.copySelection(elements);

        // retrieving only the chord elements
        var chords = all.filter(function (e) {
            return e._element.type === Element.CHORD;
        });

        for (var i = 0; i < chords.length; i++) {
            for (var j = 0; j < chords[i].notes.length; j++) {
                NoteHelper.enrichNote(chords[i].notes[j]);
                console.log(i + "/" + j + ": " + JSON.stringify(chords[i].notes[j].extname));
            }
        }

        return chords;

    }

    function logThis(text) {
        console.log(text);
    }

    function chordToText(chords) {
        if (!chords || chords.length === 0)
            return "--";
        // console.log(JSON.stringify(chords));  // crash
        return chords.map(function (e) {
            return notesToText(e.notes)
        }).join(", ");
    }

    function notesToText(notes) {

        if (!notes || notes.length === 0)
            return "--";
        return notes.map(function (n) {
            // Ceci est l'inverse de NotHelper.pitchToName
            var label=n.extname.fullname;
            // console.log("> "+label +" <");
            return label;
        }).join("/");
    }

    // returns the nth note of the selection
    // index 1 -> x
    function nnotes(n) {
        if (useSelection.checked && selection.length >= n) {
            return selection[n - 1].notes;
        /*else if (useClipboard.checked && clipboard.length >= n) {
            return clipboard[n - 1].notes;*/
        } else if (useAdhoc.checked && adhocNote.currentIndex >= 0 && n === 1) { // No 2nd note in the adhoc mode
            return [allnotes.get(adhocNote.currentIndex)];

        } else
            return null;
    }

    // work
    function getNotes() {
        var allchords = [];
        var chords;
        if (useSelection.checked && selection.length > 0) {
            allchords = selection;
        /*else if (useClipboard.checked && clipboard.length > 0) {
            allchords = clipboard;*/
        } else if (useAdhoc.checked && adhocNote.currentIndex >= 0) {
            var chord = {
                notes: [allnotes.get(adhocNote.currentIndex)]
            };
            allchords.push(chord);
        }

        if (allchords.length === 0) {
            console.warn("No chords");
            errorDialog.text = qsTr("Cannot process with an empty note selection");
            errorDialog.open();
            return;
        }

        if (!positionInScore || !theScore) {
            console.warn("Invalid score position");
            errorDialog.text = qsTr("Invalid score position");
            errorDialog.open();
            return;
        }

        if (useFirst.checked)
            chords = allchords.slice(0, 1); // "slice" pour garder une array;
        else {
            // making the returned notes starting from the startAtSequence value
            var sa=startSequenceAt.value - 1; // value ranges from [1,length] while `slice` requires [0,length-1]
            chords = allchords.slice(sa).concat(allchords.slice(0,sa));
        }

        // ~~ off-beat chord to be filled
        var offBeatChords = [];
        if (useOffbeatAdhoc.checked && offbeatNote.currentIndex >= 0) {
            offBeatChords.push({
                "notes": [allnotes.get(offbeatNote.currentIndex)]
            });
        } else if (useOffbeatSecond.checked && allchords.length >= 2) {
            offBeatChords.push(allchords[1]); // "slice" pour garder une array;
        }

        return {
            "on": chords,
            "off": offBeatChords
        };

    }

    function work() {

        // ~~ notes to use
        var what = getNotes();
        // var chords = what.on;
        var chords = what.on.map(function (target) {
            var pitches = [];
            for (var j = 0; j < target.notes.length; j++) {
                var n = {
                    "pitch": target.notes[j].pitch,
                    "tpc1": target.notes[j].tpc1,
                    "tpc2": target.notes[j].tpc2
                };
                pitches.push(n);
            }
            return pitches;
        });

        // var offBeatChords = what.off;
        var offBeatChords = what.off.map(function (target) {
            var pitches = [];
            for (var j = 0; j < target.notes.length; j++) {
                var n = {
                    "pitch": target.notes[j].pitch,
                    "tpc1": target.notes[j].tpc1,
                    "tpc2": target.notes[j].tpc2
                };
                pitches.push(n);
            }
            return pitches;
        });

        var offBeatChord = (offBeatChords.length > 0) ? offBeatChords[0] : undefined;

        // ~~ beats to be filled
        var beats = getPattern();
        var merged = getMergedPattern();

        var nb = beats.filter(function (b) {
            return b
        }).length;
        if (nb === 0) {
            console.warn("Empty pattern");
            errorDialog.text = qsTr("Cannot process with an empty pattern");
            errorDialog.open();
            return;
        }

        console.log("Pushing " + beats.length + " beats from " + chords.length + " notes ");
        console.log("Unit: %1, %2 = %3/%4".arg(unit.unitText).arg(unit.unitDuration).arg(unit.unitFractionNum).arg(unit.unitFractionDenum));
        console.log("Fraction: %1".arg(fraction(unit.unitFractionNum, unit.unitFractionDenum).str));

        // ~~ looping thru beats
        var score = theScore;
        var cursor = score.newCursor();
        var tick;
        if ((positionInScore.tick === positionInScore.measureTick) || (atCursor.checked))
            tick = positionInScore.tick;
        else
            tick = positionInScore.measureTick;

        cursor.track = positionInScore.track;
        cursor.filter = Segment.ChordRest;
        cursor.rewindToTick(tick);
        console.log("* tick at start " + cursor.tick);
        console.log("* track at start " + cursor.track);

        var step = -1;
        // var step = startSequenceAt.value - 2; // start at 1 means start at index 0


        ongoing = true;
        score.startCmd(); //-DEBUG
        for (var i = 0; i < merged.length; i++) {
            var item = merged[i];
            var play = item.action;
            var realDuration = fraction(unit.unitFractionNum * item.dur, unit.unitFractionDenum);

            console.log("---- " + i + " ----");
            console.log("using: "+JSON.stringify(item));

            console.log((play ? "=> ON" : "=> OFF"));

            // ~~ move to next and removing what's there (to start from a clean segment)
            var success = (i === 0) ? true : cursor.next();

            if (!success) {
                console.error("failed to move to the next position at i=" + i);
                break;
            }

            if (stopAtOtherPattern.checked && i>0) {
                var localSummary=findSummaryText(cursor.segment, cursor.track);
                if (localSummary) {
                    console.log("Other pattern found at iteration "+i+" at tick "+tick);
                    break;
                }
            }

            removeElement(cursor.element); // replace whatever we have by a rest

            var chordRest = cursor.element;
            var cur_time = cursor.segment.tick;

            if (!chordRest) {
                console.error("could not find an element at cursor at i=" + i);
                break;
            }


            // ~~ push the notes and rests
            // score.startCmd(); //+DEBUG

            if (play) {
                // == On-beat: Note ==
                if (step<0 || !item.repeat) 
                step = step + 1;

                var idx = step % chords.length;
                var target = chords[idx];

                console.log("adding note (" + idx + ") at " + cur_time + " of " + realDuration.str);

                // ~~ push the chord
                chordRest = NoteHelper.restToChord(chordRest, target, realDuration); // !! ne fonctionne que si "chordRest" est un "REST"

            } else if (offBeatChord) {
                // == Off-beat: Note ==
                var target = offBeatChord;
                console.log("adding an OFF-BEAT note at " + cur_time + " of " + realDuration.str);

                // ~~ push the chord
                chordRest = NoteHelper.restToChord(chordRest, target, realDuration); // !! ne fonctionne que si "chordRest" est un "REST"

            } else {
                // == Off-beat: Rest ==
                cursor.setDuration(realDuration.numerator, realDuration.denominator);
                console.log("adding rest at " + cur_time + " of " + realDuration.str);
                cursor.addRest();
                cursor.rewindToTick(cur_time);
                chordRest = cursor.element;

                var remaining = durationTo64(realDuration) - durationTo64(chordRest.duration);
                console.log("- expected: %1, actual: %2, remaining: %3".arg(durationTo64(realDuration)).arg(durationTo64(chordRest.duration)).arg(remaining));

                var success = true;
                while (success && remaining > 0) {
                    var durG = fraction(remaining, 64).str;
                    success = cursor.next();
                    if (!success) {
                        console.warn("Unable to move to the next element while searching for the remaining %1 duration".arg(durG));
                        break;
                    }
                    var element = cursor.element;
                    if (element.type != Element.REST) {
                        console.warn("Could not find a valid Element.REST element while searching for the remaining %1 duration (found %2)".arg(durG).arg(element.userName()));
                        break;
                    }
                    chordRest = element;
                    cur_time = cursor.tick;
                    remaining = remaining - durationTo64(chordRest.duration);
                    console.log("- expected: %1, last: %2, remaining: %3".arg(durationTo64(realDuration)).arg(durationTo64(chordRest.duration)).arg(remaining));
                }

            }

            cursor.rewindToTick(chordRest.parent.tick);

            // score.endCmd(); //+DEBUG

        }

        var summaryText=addSummary.checked?buildSummary():undefined;
        addSummaryText(summaryText, tick);

        score.endCmd(); //-DEBUG
        ongoing = false;

    }

    function durationTo64(duration) {
        return 64 * duration.numerator / duration.denominator;
    }

    function selectCursor(cursor) {
        var el = cursor.element;
        //logThis(el.duration.numerator + "--"+el.duration.denominator);
        if (el == null) {
            return false;
        } else if (el.type === Element.CHORD) {
            for (var i = 0; i < el.notes.length; i++) {
                var note = el.notes[i];
                cursor.score.selection.select(note, (i !== 0)); //addToSelection for i > 0
            }
        } else if (el.type !== Element.REST)
            return false;
        else
            cursor.score.selection.select(el);

    }

    function loadFromLog() {
        // parseSummary("[3/8:2:0.5:fill:A4,B5,D5:D6/E6,B8:2]");
        //parseSummary("[3/8:2:0.5:1:A4:B5:1]");
        //parseSummary("[(14)/8:-4;0.5:2:XX,A4,YY:--:2]");
        // if (positionInScore && positionInScore.summary)
        if (positionInScore && positionInScore.summary)
            parseSummary(positionInScore.summary.text);
    }

    function parseSummary(summary) {
        var s = summary.slice(1, -1);
        console.log(s);
        var _instr = s.split(":");
        var _pat,
        pattSize,
        pattBeats;
        // the pattern
        try {
            _pat = _instr[0].split("/");
            pattSize = parseInt(_pat[1]);
            pattBeats = _pat[0];
            patternSize.text = pattSize;
        } catch (error) {
            console.error("parseSummary: " + error);
            return;
        }

        var pattInvert = false;
        if (pattBeats[0] === "(") {
            // free rhythm
            freeRhythm.checked = true;
            try {
                pattBeats = parseInt(pattBeats.slice(1, -1)).toString(2);
                console.log(Array(pattSize).join("0"));
                pattBeats = (Array(pattSize).join("0") + pattBeats).slice(-pattSize);
                console.log(pattBeats);
                for (var i = 0; i < pattSize; i++) {
                    console.log(">" + pattBeats[i]);
                    freePattern.itemAt(i).checked = pattBeats[i] !== "0";
                }
            } catch (error) {
                console.warn("parseSummary: free rhythm: " + error);
            }

        } else {
            // euclidean rhythm
            euclideanRhythm.checked = true;
            try {
                pattBeats = parseInt(pattBeats);
                if (pattBeats < 0)
                    pattInvert = true;
                pattBeats = Math.abs(pattBeats);
                patternBeats.text = pattBeats;
            } catch (error) {
                console.warn("parseSummary: euclidean rhythm: " + error);
            }
        }

        invert.checked = pattInvert;

        // start At
        try {
            var sa = parseInt(_instr[1]);
            if (sa>=1) sa--; // log range is ...,-1,1,2,..., while value range is ...,-1,0,1,...
            startAt.value = sa; 
        } catch (error) {
            console.warn("parseSummary: startAt: " + error);
        }

        // unit duration
        try {
            unit.unitDuration = parseFloat(_instr[2]);
        } catch (error) {
            console.warn("parseSummary: duration unit: " + error);
        }

        // multiplier
        try {
            var m = _instr[3];
            for (var i = 0; i < durationmult.count; i++) {
                if (durationmult.get(i)[mult.textRole] === m) {
                    mult.currentIndex = i;
                    break;
                }
            }
        } catch (error) {
            console.warn("parseSummary: multiplier: " + error);
        }

        // note on
        var chords = summaryToChords(_instr[4]);
        if (chords.length > 0) {
            useSelection.checked = true;
            console.log("¨¨Changing selection while parsing the summary");
            selection = chords;
        }

        // note off
        chords = summaryToChords(_instr[5]);
        if (chords.length > 0) {
            useOffbeatAdhoc.checked = true;
            for (var j = 0; j < allnotes.count; j++) {
                var off = chords[0].notes[0];
                var a = allnotes.get(j);
                // if (a === off) {
                if (a.pitch === off.pitch) {
                    offbeatNote.currentIndex = j;
                    return;
                }
            }
        } else {
            useOffbeatRest.checked = true;
        }

        // duration
        try {
            duration.text = _instr[6];
        } catch (error) {
            console.warn("parseSummary: duration: " + error);
        }

        // refresh the rhythm wheel
        refresh();
    }

    function summaryToChords(summary) {
        // try {
        if (!summary || summary === "--") {
            return [];
        }
        
        console.log("parsing chord summary: "+summary);

        var chords = summary.split(",").map(function (e) {
            return e.trim();
        });
        chords = chords.map(function (c) {
            var notes = c.split("/").map(function (e) {
                return e.trim();
            })
                // .accidentalName, .extname.name,
                notes = notes.map(function (n) {
                // for (var j = 0; j < allnotes.count; j++) {
                    // var a = allnotes.get(j);
                    // console.log("comparing "+a.extname.fullname+" with "+n);
                    // if (a.extname.fullname === n)
                        // return a;
                // }
                var a=NoteHelper.buildPitchedNote(n);
                console.log(JSON.stringify(a));

                // for presentation in the ComboBox
                a.name=a.extname.fullname;
                
                return a;
            });

            notes = notes.filter(function (n) {
                return typeof n !== "undefined";
            });

            return {
                "notes": notes
            };

        });

        chords = chords.filter(function (c) {
            return c.notes.length > 0;
        });

        return chords;

        // } catch (error) {}

    }

    function buildSummary() {
        var summary = [];
        var pat = "";
        if (euclideanRhythm.checked) {
            pat = patternBeats.text * (!invert.checked ? 1 : -1);
        } else {
            var beats = "";
            for (var i = 0; i < patternSize.value; i++) {
                beats += (freePattern.itemAt(i).checked) ? "1" : "0";
            }
            //var num = BigInt('0b' + beats);
            pat = "(" + parseInt(beats, 2).toString() + ")";
            // pat.toString(2); // back to "110"
            console.log(pat);
        }
        summary.push(pat + "/" + patternSize.value);
        summary.push((startAt.value>=0)?startAt.value+1:startAt.value);
        summary.push(unit.unitDuration);
        summary.push(mult.model.get(mult.currentIndex)[mult.textRole]);

        var what = getNotes();
        // console.log(JSON.stringify(what)); // crash

        summary.push(chordToText(what.on));
        summary.push(chordToText(what.off));

        summary.push(duration.text);

        return "[" + summary.join(":") + "]";
    }

    function addSummaryText(sumText, tick) {
        console.log("addSummaryText : "+(sumText?sumText:"undefined")+" - "+tick+"/"+positionInScore.track);
        console.log(tick+" -- "+parseInt(tick) + " -- "+!(parseInt(tick)>=0));
        console.log(typeof positionInScore);
        if (typeof positionInScore === "undefined")
            return;
        if (!(parseInt(tick)>=0))
            return;
        
        
        var staffText = positionInScore.summary;
        console.log("Reusing :"+(staffText?staffText.userName():"--"));
        console.log("Reusing :"+(typeof staffText));


        // If no fingering found, create a new one
        if (sumText && (!staffText)) {
            var f = newElement(Element.STAFF_TEXT);
            f.text = sumText;
            var cur = theScore.newCursor();
            cur.track = positionInScore.track;
            cur.rewindToTick(tick);
            cur.add(f);
            console.log("new text added at "+cur.tick+"/"+cur.track);
            positionInScore.summary=f;
        } else if (sumText && (staffText)) {
            staffText.text = sumText;
            console.log("Exsiting text modified");
        } else if (!sumText && (staffText)) {
            staffText.remove();
            console.log("Exsiting text removed");
            positionInScore.summary=null;
        }

    }

    function findSummaryText(segment, eTrack) {
        var anns = segment.annotations;
        var staffText;
        var eStaff=eTrack?(eTrack/4)| 0:0 ; // = trunc
        for (var ai = 0; ai < anns.length; ++ai) {
            console.log("  analysing " + anns[ai].text);
            console.log("  comparing with " + ("[" + anns[ai].text.slice(1, -1) + "]"));
		    console.log("  track " + anns[ai].track);
            
            // Rem: les STAFF_TEXT sont toujours la voix 1 => comparer les tracks ensemble ne fonctionnent pas
            // => on calcule un staffId
            var aStaff = (anns[ai].track/4) | 0; // = trunc

		    console.log("  staff " + aStaff);

            if ((anns[ai].type === Element.STAFF_TEXT)
                && (anns[ai].text === ("[" + anns[ai].text.slice(1, -1) + "]"))
                && (aStaff === eStaff)
             ) {
                // Found our reference
                console.log("    found");
                staffText = anns[ai];
                break;
            }
        }

        return staffText;
        
    }

} // MuseScore