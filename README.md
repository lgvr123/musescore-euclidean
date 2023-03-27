
# Euclidean Rhythm Generator plugin for MuseScore 3.x and 4.x
The *Euclidean Rhythm Generator* will help you create euclidean (or free rhythm) patterns.

(More info on Euclidean Rhythm is this [video](https://www.youtube.com/watch?v=8G8qko7NZdE) (french) or on [wikipedia](https://en.wikipedia.org/wiki/Euclidean_rhythm)).

<p align="center"><img src="/euclidean/logo.png" Alt="logo" width="300" /></p>

[![](https://markdown-videos.deta.dev/youtube/ekAY6hZApsQ)](https://youtu.be/ekAY6hZApsQ)


## Usage
### 1. Pattern definition
The pattern can be of two types: _Euclidean Rhythm_ or _Free Rhythm_. Both have most parameters in common. For both you must defined a pattern length. For _Euclidean Rhythm_ you must define how many steps will be played and spread over the pattern length, while for _Free Rhythm_ you must indicate manually which steps have to be played.

<p align="center"><img src="https://github.com/lgvr123/musescore-euclidean/raw/master/demo/euclidean-demo.png" Alt="logo" width="50%" /></p>

#### Parameters:

1. **Pattern**: number of steps to spread over the pattern length / pattern length / step duration.<br/>
E.g. : 9/16 ♪ will lead to 9 ♪ being spread over a 16 ♪ duration.
<p align="center"><img src="/demo/9-16.png"/></p>

2. **Start at step**: where to start in the pattern. By default, the pattern is stared at its 1st step, but you can decide wherever you want in the pattern<br/>
E.g. : In previous example, starting at step 3 will lead to
<p align="center"><img src="/demo/9-16x2.png"/></p>

3. **Note duration**: by default the _note_ duration is the same as the _step_ duration. However, when possible (i.e. when the notes are followed by rests) you can decide to have the notes longer than the steps.<br/>
There is a special "fill" mode, where each note is expanded in the all rests that are following the note.<br/>
E.g. : In a 5/16 pattern
<p align="center"><img src="/demo/7-16-fill.png"/></p>

4. **Merge consecutive notes**: in this mode, if several consecutive steps are played, they will replaced by a single note spanning over these consecutive steps.<br/>
E.g. : In first example, merging the consecutive steps will lead to
<p align="center"><img src="/demo/9-16-merge.png"/></p>

### 2. What to play
You can parametrize what to play on the "on-beats" (i.e. the "played" steps) and the "off-beats" (i.e. the "non-played" beats).

#### Source
The plugin can use 3 sources for defining the notes to play:
1. the selection in the score
2. the clipboard (what you copied through CTRL/CMD+C)
3. the manual indication of the note to play

#### On-beats
A note must always be selected for the On-beat.

If the selection contains more than one note (see "source"), you can decide to only the **First Note** or to **Cycle across (the) selection**.

#### Off-beats
For the Off-beats, the default is using a **Rest**. All the previous examples have been produced using rests.

If the selection contains more than **two** notes (see "source") and if you are only using the first one for the "on-beat" you can decide to use the **Second (one)** as off-beat.

A third option is to use a manually indicated note as off-beat.

E.g. The following pattern has been built using a 9/16 pattern, with selection containing B4, C5, D5, E5, and and an off-beat note A4:
<p align="center"><img src="/demo/9-16-multiple.png"/></p>


### 3. Where to write the pattern
The pattern will be written in your score at the cursor position.

However, if your cursor is not placed at a measure start, you can choose between placing the pattern **At (the) cursor** or **From (the) measure start**  

### Remarks

* The parameter **Repeats** lets you repeat your pattern consecutively

* In the status bar, the plugin indicates the staff/measure/voice where it will write the pattern

* The plugin detects the selection changes in the score and adapts both the selection content available in the **Source/Use Selection** parameters and the location for writing the pattern.<br/>
However the plugin does not detect any change in the clipboard. In order to refresh the **Source/Use Clipboard**, the plugin must be closed and reopened.


## Download and Install ##
Download the [last stable version](https://github.com/lgvr123/musescore-euclidian/releases)
For installation see [Plugins](https://musescore.org/en/handbook/3/plugins).

### Remark
The whole zip content (so the `euclidean\ ` folder) must be unzipped **as such** in your plugin folder. <br/>

## Support of MS4.0
Supported, although the User Interface does not look very nice in this version.

## Sponsorship ##
If you appreciate my plugins, you can support and sponsor their development on the following platforms:
[<img src="/support/Button-Tipeee.png" alt="Support me on Tipee" height="50"/>](https://www.tipeee.com/parkingb) 
[<img src="/support/paypal.jpg" alt="Support me on Paypal" height="55"/>](https://www.paypal.me/LaurentvanRoy) 
[<img src="/support/patreon.png" alt="Support me on Patreon" height="25"/>](https://patreon.com/parkingb)

And also check my **[Zploger application](https://www.parkingb.be/zploger)**, a tool for managing a library of scores, with extended MuseScore support.

## IMPORTANT
NO WARRANTY THE PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW THE AUTHOR WILL BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
