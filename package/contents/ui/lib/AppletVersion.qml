import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 6.0 as PlasmaCore
import org.kde.plasma.plasmoid 6.0

Item {
	implicitWidth: label.implicitWidth
	implicitHeight: label.implicitHeight

	property string version: "?"
	property string metadataFilepath: plasmoid.file("", "../metadata.desktop")

	PlasmaCore.DataSource {
		id: executable
		engine: "executable"
		connectedSources: []
		onNewData: {
			var exitCode = data["exit code"]
			var exitStatus = data["exit status"]
			var stdout = data["stdout"]
			var stderr = data["stderr"]
			exited(exitCode, exitStatus, stdout, stderr)
			disconnectSource(sourceName) // cmd finished
		}
		function exec(cmd) {
			connectSource(cmd)
		}
		signal exited(int exitCode, int exitStatus, string stdout, string stderr)
	}

	Connections {
		target: executable
		onExited: {
			version = stdout.replace('\n', ' ').trim()
		}
	}

	Label {
		id: label
		text: i18n("<b>Version:</b> %1", version)
	}

	Component.onCompleted: {
		var cmd = 'kreadconfig5 --file "' + metadataFilepath + '" --group "Desktop Entry" --key "X-KDE-PluginInfo-Version"'
		executable.exec(cmd)
	}

}
