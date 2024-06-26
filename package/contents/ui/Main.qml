import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 6.0
import org.kde.plasma.core 6.0 as PlasmaCore
import org.kde.plasma.components 6.0 as PlasmaComponents

import org.kde.kquickcontrolsaddons 6.0 as KAddons

import org.kde.plasma.private.volume 1.0 as PlasmaVolume

import "./code/Utils.js" as Utils
import "./code/PulseObjectCommands.js" as PulseObjectCommands

Item {
	id: main

	QtObject {
		id: config
		property bool showVisualFeedback: false
		property string volumeSliderUrl: plasmoid.file("images", "volumeslider-default.svg")
		property int intervalBeforeResetingVolumeBoost: 5000
	}

	PlasmaVolume.SinkModel {
		id: sinkModel
		property var selectedSink: defaultSink
	}

	PlasmaVolume.VolumeFeedback {
		id: feedback
	}

	function playFeedback(sinkIndex) {
		if (!plasmoid.configuration.volumeChangeFeedback) {
			return
		}
		if (sinkIndex == undefined) {
			sinkIndex = sinkModel.selectedSink.index
		}
		feedback.play(sinkIndex)
	}

	Plasmoid.preferredRepresentation: plasmoid.configuration.showInPopup ? Plasmoid.compactRepresentation : Plasmoid.fullRepresentation

	Plasmoid.compactRepresentation: PlasmaComponents.Label {
		property var pulseObject: sinkModel.selectedSink
		property int volumePercentage: Math.round(pulseObject.volume / 65536 * 100)
		text: i18n("%1%", volumePercentage)

		MouseArea {
			id: mouseArea
			anchors.fill: parent
			acceptedButtons: Qt.LeftButton | Qt.MiddleButton
			hoverEnabled: true

			property bool wasExpanded: false
			onPressed: wasExpanded = plasmoid.expanded
			onClicked: plasmoid.expanded = !wasExpanded

			onWheel: {
				var wheelDelta = wheel.angleDelta.y || wheel.angleDelta.x

				// Magic number 120 for common "one click"
				// See: http://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
				while (wheelDelta >= 120) {
					wheelDelta -= 120
					PulseObjectCommands.increaseVolume(sinkModel.selectedSink)
				}
				while (wheelDelta <= -120) {
					wheelDelta += 120
					PulseObjectCommands.decreaseVolume(sinkModel.selectedSink)
				}
			}
		}
	}

	Plasmoid.fullRepresentation: Item {
		Layout.preferredWidth: plasmoid.configuration.width * units.devicePixelRatio
		Layout.preferredHeight: plasmoid.configuration.height * units.devicePixelRatio

		VerticalVolumeSlider {
			id: slider

			anchors.fill: parent
			property var pulseObject: sinkModel.selectedSink

			readonly property int volume: pulseObject.volume
			property bool ignoreValueChange: true
			property bool isVolumeBoosted: false

			Timer {
				id: volumeBoostDoneTimer
				interval: config.intervalBeforeResetingVolumeBoost
				onTriggered: slider.isVolumeBoosted = false

				function check() {
					if (slider.isVolumeBoosted && slider.pulseObject.volume <= 66000) {
						volumeBoostDoneTimer.restart()
					}
				}
			}

			minimumValue: 0
			maximumValue: slider.isVolumeBoosted ? 98304 : 65536
			showPercentageLabel: false
			orientation: Qt.Horizontal


			stepSize: maximumValue / maxPercentage
			visible: pulseObject.hasVolume
			enabled: typeof pulseObject.volumeWritable === 'undefined' || pulseObject.volumeWritable

			opacity: {
				return enabled && pulseObject.muted ? 0.5 : 1
			}

			onVolumeChanged: {
				var oldIgnoreValueChange = ignoreValueChange
				if (!slider.isVolumeBoosted && pulseObject.volume > 66000) {
					slider.isVolumeBoosted = true
				}
				value = pulseObject.volume
				ignoreValueChange = oldIgnoreValueChange
				volumeBoostDoneTimer.check()
			}

			onValueChanged: {
				if (!ignoreValueChange) {
					PulseObjectCommands.setVolume(pulseObject, value)

					if (!pressed) {
						updateTimer.restart()
					}
				}
			}

			property bool playFeedbackOnUpdate: false
			onPressedChanged: {
				if (pressed) {
					playFeedbackOnUpdate = true
				} else {
					// Make sure to sync the volume once the button was
					// released.
					// Otherwise it might be that the slider is at v10
					// whereas PA rejected the volume change and is
					// still at v15 (e.g.).
					updateTimer.restart()
				}
				volumeBoostDoneTimer.check()
			}

			Timer {
				id: updateTimer
				interval: 200
				onTriggered: {
					slider.value = slider.pulseObject.volume

					// Done dragging, play feedback
					if (slider.playFeedbackOnUpdate) {
						main.playFeedback(slider.pulseObject.index)
					}

					if (!slider.pressed) {
						slider.playFeedbackOnUpdate = false
					}
				}
			}

			// Block wheel events
			KAddons.MouseEventListener {
				anchors.fill: parent
				acceptedButtons: Qt.MidButton

				property int wheelDelta: 0
				onWheelMoved: {
					wheelDelta += wheel.delta
				
					// Magic number 120 for common "one click"
					// See: http://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
					while (wheelDelta >= 120) {
						wheelDelta -= 120
						PulseObjectCommands.increaseVolume(slider.pulseObject)
					}
					while (wheelDelta <= -120) {
						wheelDelta += 120
						PulseObjectCommands.decreaseVolume(slider.pulseObject)
					}
				}
			}

			Component.onCompleted: {
				ignoreValueChange = false
				slider.isVolumeBoosted = pulseObject.volume > 66000 // 100% is 65863.68, not 65536... Bleh. Just trigger at a round number.
			}
		}

		PlasmaCore.ToolTipArea {
			anchors.fill: parent
			mainText: main.Plasmoid.toolTipMainText
			subText: main.Plasmoid.toolTipSubText
		}
	}

	property string displayName: i18nd("plasma_applet_org.kde.plasma.volume", "Audio Volume")
	property string speakerIcon: Utils.iconNameForStream(sinkModel.selectedSink)
	Plasmoid.icon: {
		// if (mpris2Source.hasPlayer && mpris2Source.albumArt) {
		// 	return mpris2Source.albumArt
		// } else {
			return speakerIcon
		// }
	}
	Plasmoid.toolTipMainText: {
		// if (mpris2Source.hasPlayer && mpris2Source.track) {
		// 	return mpris2Source.track
		// } else {
			return displayName
		// }
	}
	Plasmoid.toolTipSubText: {
		var lines = []
		// if (mpris2Source.hasPlayer && mpris2Source.artist) {
		// 	if (mpris2Source.isPaused) {
		// 		lines.push(mpris2Source.artist ? i18ndc("plasma_applet_org.kde.plasma.mediacontroller", "Artist of the song", "by %1 (paused)", mpris2Source.artist) : i18nd("plasma_applet_org.kde.plasma.mediacontroller", "Paused"))
		// 	} else if (mpris2Source.artist) {
		// 		lines.push(i18ndc("plasma_applet_org.kde.plasma.mediacontroller", "Artist of the song", "by %1", mpris2Source.artist))
		// 	}
		// }
		if (sinkModel.selectedSink) {
			var sinkVolumePercent = Math.round(PulseObjectCommands.volumePercent(sinkModel.selectedSink.volume))
			lines.push(i18nd("plasma_applet_org.kde.plasma.volume", "Volume at %1%", sinkVolumePercent))
			lines.push(sinkModel.selectedSink.description)
		}
		return lines.join('\n')
	}

	Component.onCompleted: {
		
		// plasmoid.action('configure').trigger() // Uncomment to open the config window on load.
	}
}
