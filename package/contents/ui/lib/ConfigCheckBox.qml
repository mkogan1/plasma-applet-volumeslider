import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import org.kde.plasma.core  6.0 as PlasmaCore
import org.kde.plasma.components  6.0 as PlasmaComponents

import ".."

CheckBox {
	id: configCheckBox

	property string configKey: ''
	checked: plasmoid.configuration[configKey]
	onClicked: plasmoid.configuration[configKey] = !plasmoid.configuration[configKey]
}
