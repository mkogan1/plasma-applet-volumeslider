import QtQuick 2.15
import org.kde.plasma.configuration 6.0

ConfigModel {
	ConfigCategory {
		name: i18nd("plasma_applet_org.kde.plasma.volume", "General")
		icon: "plasma"
		source: "config/ConfigGeneral.qml"
	}
}
