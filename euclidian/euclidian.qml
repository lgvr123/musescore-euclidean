import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.3
import Qt.labs.settings 1.0
import MuseScore 3.0

import "notehelper.js" as NoteHelper
import "selectionhelper.js" as SelHelper

/**********************************************
/*  1.0.0: Initial version
 
 // TODO: résoudre le cas où des notes dépasse la barre de mesure
 // EN COURS: ryhtme libre
 
/**********************************************/
MuseScore {
    menuPath: "Plugins." + qsTr("Euclidian Rhythm")
    version: "1.0.0"
    requiresScore: true
    description: qsTr("Create an euclidian rhythm")
    pluginType: "dialog"

    id: mainWindow

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            mainWindow.title = qsTr("Euclidian Rhythm");
            mainWindow.thumbnailName = "logoTemplater.png";
            // mainWindow.categoryCode = "batch-processing";
        }
    }
    
    property var clipboard: [];
    property var selection: [];
    
    property var theScore
    property var positionInScore

    onRun: {
        // check MuseScore version
        if (mscoreMajorVersion < 3) {
            mainWindow.visible = false
                versionError.open()
        }
        
        theScore=curScore;
        
        // Retrieving the starting position in score
        if (theScore && theScore.selection != null && theScore.selection.elements.length > 0) {
            var element = theScore.selection.elements[0];
            var track = element.track;
            while (element && element.type !== Element.SEGMENT) {
                element = element.parent
            }
            if (element) { 
                positionInScore = {
                    tick: element.tick,
                    track: track,
                    source: "selection"
                };
            }
        }

        if (!positionInScore && theScore) {
            var cursor = theScore.newCursor();
            cursor.rewind(Cursor.SELECTION_START);
            if (cursor.segment) {// something is selected
                positionInScore = {
                    tick: cursor.tick,
                    track: cursor.track,
                    source: "cursor"
                }; 
            }
        }

      if (!positionInScore) {
                positionInScore = {
                    tick: 0,
                    track: 0,
                    source: "default"
                }; 
           
        }        
        console.log(JSON.stringify(positionInScore));

        // Retrieving the notes that could be used for the rhythm
        selection = retrieveSelection();
        clipboard = retrieveClipboard(); 

        // Setting the options based on what was found in the earlier steps
        useFirst.checked = true;
        useOffbeatRest.checked= true
        if (clipboard.length > 0) {
            useClipboard.checked = true;
            if (clipboard.length > 1)
                cycleNotes.checked = true;
        } else if (selection.length > 0) {
            useSelection.checked = true;
            if (selection.length > 1)
                cycleNotes.checked = true;
        } else {
            useAdhoc.checked=true;
        }
        
 
    }

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
	        for(var octave=0;octave<7;octave++) {
	            for (var n = 0; n < NoteHelper.pitchnotes.length; n++) {
	                var name = NoteHelper.pitchnotes[n];
	                var accidental = ((n > 0) && (name === NoteHelper.pitchnotes[n - 1])) ? "SHARP" : "NONE";
	                name = name + octave;
	                var note = NoteHelper.buildPitchedNote(name, accidental);
	                note.name = NoteHelper.pitchToName(note.pitch, note.tpc2).fullname;
                    note.extname={name: note.name}; // tweak for aligning on enrichNote convention
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
            durationmult.append({text: qsTr("1x"), mult: 1});
            durationmult.append({text: qsTr("2x"), mult: 2});
            durationmult.append({text: qsTr("3x"), mult: 3});
            durationmult.append({text: qsTr("4x"), mult: 4});
	    }

	}
	// UI
    ColumnLayout {
        id: mainRow
        spacing: 2
        anchors.margins: 0

        GridLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.margins: 20
            Layout.fillWidth: true
            Layout.fillHeight: true

            columnSpacing: 5
            rowSpacing: 5
            columns: 3

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


            StackLayout {
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                Layout.margins: 20
                Layout.rowSpan: 4
                
                Layout.minimumHeight: visual.size
                Layout.minimumWidth: visual.size
                
                currentIndex: 0 
                
                // Euclidian rhythm canvas
                Canvas {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    Layout.fillWidth: true

                    property int size: 150
                    property int thickness: 20

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

                // Free rhythm
                Grid {
                    columns: 8
                    spacing: 0
                    Repeater {
                        model: patternSize.text

                        BeatCheckBox {
                            text: (index+1)
                        }

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

        RowLayout {
            TempoUnitBox {
                id: unit
                sizeMult: 1
            }
            ComboBox {
                model: durationmult
                id: mult
                textRole: "text"
            }
        }

        Label {
            text: qsTr("Source") + ":"
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
        }

        GroupBox {
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
                    enabled: selection.length>0
                    ButtonGroup.group: source
                }
                
                RadioButton {
                    id: useClipboard
                    text: qsTr("Use clipboard : %1").arg(chordToText(clipboard))
                    enabled: clipboard.length>0
                    ButtonGroup.group: source
                }
                
                Row {
                    RadioButton {
                        id: useAdhoc
                        text: qsTr("Use :")
                        enabled: true
                        ButtonGroup.group: source
                    }
                    
                    ComboBox {
                        id: adhocNote
                        model: allnotes
                        textRole: "name"
                        enabled: useAdhoc.checked
                    }
                    
                    
                }
                
            }
        }

        Label {
            text: qsTr("Use") + ":"
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.topMargin: (gpbeat.label)?gpbeat.label.height:0
        }

        GroupBox {
            title: qsTr("Beat")
            id: gpbeat
            Layout.columnSpan: 1
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            ColumnLayout {
                RadioButton {
                    id: useFirst
                    text: qsTr("First note: %1").arg(notesToText(nnotes(1)))
                    enabled: (clipboard.length > 0 && useClipboard.checked) || (selection.length > 0 && useSelection.checked) || useAdhoc.checked
                }
                RadioButton {
                    id: cycleNotes
                    text: qsTr("Cycle accross selection")
                    enabled: (clipboard.length > 1 && useClipboard.checked) || (selection.length > 1 && useSelection.checked)
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
                    enabled: true
                    ButtonGroup.group: off
                }
                
                RadioButton {
                    id: useOffbeatSecond
                    text: qsTr("Second: %1").arg(notesToText(nnotes(2)))
                    enabled: (useFirst.checked) && ((clipboard.length > 1 && useClipboard.checked) || (selection.length > 1 && useSelection.checked))
                    ButtonGroup.group: off
                }
                
                Row {
                    RadioButton {
                        id: useOffbeatAdhoc
                        text: qsTr("Use :")
                        enabled: true
                        ButtonGroup.group: off
                    }
                    
                    ComboBox {
                        model: allnotes
                        textRole: "name"
                        id: offbeatNote
                        enabled: useOffbeatAdhoc.checked
                    }
                }
                
            }
        }


        /*Label {
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            text: qsTr("Where") + ":"
        }

        GroupBox {
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
            Layout.columnSpan: 2
            ColumnLayout {
                RadioButton {
                    id: atCursor
                    text: qsTr("At cursor")
                }
                RadioButton {
                    id: atMeasure
                    text: qsTr("From measure start")
                }
            }
            }*/
        } // GridLayout

        // Button bar
        DialogButtonBox {
            Layout.fillWidth: true
            spacing: 5
            alignment: Qt.AlignRight
            background.opacity: 0 // hide default white background

            standardButtons: DialogButtonBox.Cancel

            Button {
                id: ok
                enabled: (patternBeats.text !== "") && (patternSize.text !== "")
                text: qsTr("Create")
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
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
                text: "some status"
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
        category: "EuclidianRhythmPlugin"
        property alias nbbeats: patternBeats.text
        property alias size: patternSize.text
        property alias duration: duration.text
        property alias unit: unit.unitDuration
        property alias mult: mult.currentIndex
    }

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
        var tmp=newScore("tmp", "flute", 10);
        var cursor=tmp.newCursor();
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
        var lastStaff= tmp.ntracks;
        tmp.selection.selectRange(firstTick, lastTick, firstStaff, lastStaff);
        
        // retrieving only the chord elements
        var chords=extractSelection(tmp.selection.elements);
        
        // closing the tmp score
        cmd("undo");
        closeScore(tmp);
        
        return chords;
    }
    
    function extractSelection(elements) {
        // Retrieving everything
        var all=copySelection(elements);
        
        // retrieving only the chord elements
        var chords=all.filter(function(e) { return e._element.type === Element.CHORD; });
        
        for(var i=0;i<chords.length;i++) {
            for(var j=0; j<chords[i].notes.length; j++) {
                NoteHelper.enrichNote(chords[i].notes[j]);
                console.log(i+"/"+j+": "+JSON.stringify(chords[i].notes[j].extname));
            }
        }
        
        return chords;
        
    }

	/**
	* Copy segment by segment, track by track, the CHORDREST found a this segment.
	* Includes the annotations at this segment, as well as the notes and their properties
	*/
    function copySelection(chords) {
        logThis("Copying " + chords.length + " elements canidates");
        var targets = [];
        loopelements:
        for (var i = 0; i < chords.length; i++) {
            var chord = chords[i];

            if (chord.type === Element.NOTE) {
                logThis("!! note element in the selection. Using its parent's chord instead");
                chord = chord.parent;

                for (var c = 0; c < targets.length; c++) {
                    // 28/2/2023: Missing note 
                    // if ((targets[c].tick === chord.parent.tick) && (targets[c].track === chord.track)) {
                    if ((targets[c].tick === chord.parent.tick) && (targets[c].track === chord.track) && (targets[c].type === Element.CHORD)) {
						logThis("dropping this note, because we have already added its parent's chord in the selection");
                        continue loopelements;
					}
                }
            }

            logThis("Copying " + i + ": " + chord.userName() + " - " + (chord.duration ? chord.duration.str : "null") + ", notes: " + (chord.notes ? chord.notes.length : 0));
            var target = {
				"_element": chord,
				"tick": chord.parent.tick,
				"track": chord.track,
                "duration": (chord.duration?{
                    "numerator": chord.duration.numerator,
                    "denominator": chord.duration.denominator,
                }:null),
                "lyrics": chord.lyrics,
                "graceNotes": chord.graceNotes,
				"notes": undefined,
				"annotations": [],
				"_username": chord.userName(),
				"userName": function() { return this._username;} //must be "chords[i]"
            };

            // If CHORD, then remember the notes. Otherwise treat as a rest
            if (chord.type === Element.CHORD) {
                // target.notes = chord.notes; // 26/2/23 chord.notes n'est pas une Array donc c'est un peu chiant
                target.notes = [];
                for(var n=0; n<chord.notes.length;n++) {
                target.notes.push(chord.notes[n]);
                }
            };

			// Searching for harmonies & other annotations
			var seg=chord;
			while(seg && seg.type!==Element.SEGMENT) {
				seg=seg.parent
			}
			
			if(seg!==null) {
				var annotations = seg.annotations;
				//console.log(annotations.length + " annotations");
				if (annotations && (annotations.length > 0)) {
					var filtered=[];
					// annotations=annotations.filter(function(e) {
						// return (e.type === Element.HARMONY) && (e.track===chord.track);
					// });
					for(var h=0;h<annotations.length;h++) {
						var e=annotations[h];
						if (/*(e.type === Element.HARMONY) &&*/ (e.track===chord.track)) 
							filtered.push(e);
					}
					annotations=filtered;
					target.annotations=annotations;
				} else annotations=[]; // DEBUG
				logThis("--Annotations: " + annotations.length + ((annotations.length > 0) ? (" (\"" + annotations[0].text + "\")") : ""));
			}
			// Done
            targets.push(target);
            // logThis("--Lyrics: " + target.lyrics.length + ((target.lyrics.length > 0) ? (" (\"" + target.lyrics[0].text + "\")") : ""));
        }

        logThis("Ending was a copy of " + targets.length + " elements");

        return targets;

    }
    
    function logThis(text) { console.log(text); }

    function chordToText(chords) {
        if (!chords || chords.length===0) return "--";
        return chords.map(function (e) { return notesToText(e.notes)}).join(", ");
    }

    function notesToText(notes) {
        if (!notes || notes.length===0) return "--";
            return notes.map(function (n) {
                var acc = "";
                if(n.accidentalName) {
                switch (n.accidentalName) {
                case "FLAT":
                    acc = "\u266D";
                    break;
                case "NATURAL":
                    acc = "\u266E";
                    break;
                case "SHARP":
                    acc = "\u266F";
                    break;
                case "FLAT2":
                    acc = "\u266D\u266D";
                    break;
                case "SHARP2":
                case "SHARP_SHARP":
                    acc = "\u266F\u266F";
                    break;
                case "NATURAL_FLAT":
                    acc = "\u266E\u266D";
                    break;
                case "NATURAL_SHARP":
                    acc = "\u266E\u266F";
                    break;
                case "NONE":
                    acc = "";
                    break;
                default:
                    acc = "(\u2026)"; // "(...)"
                    break;

                }
                }
                return n.extname.name + acc
            }).join("/");
    }

    // returns the nth note of the selection
    // index 1 -> x
    function nnotes(n) {
        if (useSelection.checked && selection.length>=n) {
            return selection[n-1].notes;
        }
        else if (useClipboard.checked && clipboard.length>=n) {
            return clipboard[n-1].notes;
        }
        else if (useAdhoc.checked && adhocNote.currentIndex>=0) {
            return [allnotes.get(adhocNote.currentIndex)];
        
        } else return null;
    }
    // work
    function work() {

        // ~~ notes to use
        var chords=[];
        if (useSelection.checked && selection.length>0) {
            chords=selection;
        }
        else if (useClipboard.checked && clipboard.length>0) {
            chords=clipboard;
        }
        else if (useAdhoc.checked && adhocNote.currentIndex>=0) {
            var chord={
                notes: [allnotes.get(adhocNote.currentIndex)]
            };
            chords.push(chord);
        }
        
        if (chords.length===0) {
            console.warn("No selection");
            return;
        }
        
        if (useFirst.checked) chords=chords.slice(0,1);
        
        chords=chords.map(function(target) {
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

        // ~~ beats to be filled
        var beats = [];

        for (var n = 0; n < duration.text; n++) {
            for (var i = 0; i < patternSize.text; i++) {
                beats.push(isBeat(i));
            }
        }

        console.log("Pushing " + beats.length + " beats from "+chords.length+" notes ");


        var fduration = fraction(unit.unitFractionNum, unit.unitFractionDenum);


        // ~~ looping thru beats
        var score = theScore; 
        var cursor = score.newCursor();
        cursor.rewindToTick(positionInScore.tick);
        cursor.track=positionInScore.track;
        cursor.filter = Segment.ChordRest;
        console.log("* tick at start " + cursor.tick);
        console.log("* track at start " + cursor.track);


        var defMult=durationmult.get(mult.currentIndex).mult;
        var lastMult=1;
        var step=-1;

        score.startCmd();
        for (var i = 0; i < beats.length; i++) {

            var play = beats[i];
            console.log("---- " + i + " ----");
            
            // ~~ bypass beats included in previous duration multiplication
            if(lastMult>1) {
                console.log("=> In duration multiplication");
                lastMult--;
                if (play) console.warn("Conflicting duration multiplication at i="+i);
                continue;
            }

            console.log((play ? "=> NOTE" : "=> REST"));

            // ~~ move to next and removing what's there (to start from a clean segment)
            var success = (i === 0) ? true : cursor.next();
            
            if (!success) {
                console.error("failed to move to the next position at i="+i);
                break;
            }

            removeElement(cursor.element); // replace whatever we have by a rest

            var note = cursor.element;

            if (!note) {
                console.error("could not find an element at cursor at i="+i);
                break;
            }

            var cur_time = cursor.segment.tick;

            // ~~ push the notes and rests
            if (play) {
                // == On-beat: Note ==
                
                step=step+1;
                
                var idx=step%chords.length;
                
                // ~~ duration, including multiplication
                lastMult=1;
                for(var j=(i+1);j<(i+defMult)&&(j<beats.length);j++) {
                    if(beats[j]) {
                        break;
                    }
                    lastMult++;
                }
                
                var realDuration=fraction(unit.unitFractionNum*lastMult, unit.unitFractionDenum);

                console.log("adding note ("+idx+") at " + cur_time + " of " + realDuration.str);
                console.log("- on a " + note.userName());
                
                // ~~ push the chord
                var target = chords[idx];
                console.log("- rest to chord");
                note = NoteHelper.restToChord(note, target, realDuration); // !! ne fonctionne que si "note" est un "REST"

            } else if (useOffbeatAdhoc.checked && offbeatNote.currentIndex>=0) {
                // == Off-beat: Note ==
                console.log("adding an OFF-BEAT note at " + cur_time + " of " + fduration.str);
                console.log("- on a " + note.userName());
                var notes= [allnotes.get(offbeatNote.currentIndex)];
                console.log("- rest to chord");
                console.log(JSON.stringify(notes));
                note = NoteHelper.restToChord(note, notes, fduration); // !! ne fonctionne que si "note" est un "REST"
            } else {
                // == Off-beat: Rest ==
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