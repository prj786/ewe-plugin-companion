import QtQuick
import qs
import ".."

// Messages — the conversation: every turn kept (the last 40), oldest at the
// top. It lives in the notch's scrolling part, so a long history scrolls
// while the line you type in stays put (Chat.qml); a new answer scrolls
// itself into view (Drop.qml).
//
// A command's answer carries Undo when there is a way back. A shell command
// the companion proposes (the AI's, a knowledge topic's, or your own
// `$ command`) shows exactly as it will run, with Run and In terminal;
// nothing runs without that click, and a risky one says why in warning ink
// with a danger-styled Run.
Column {
    id: ch
    spacing: Theme.spaceS
    readonly property var chat: CompanionState.chat || {}

    // ── the conversation ──
    Repeater {
        model: CompanionState.messages
        Item {
            id: msg
            required property var modelData
            readonly property bool mine: modelData.who === "you"
            // the button under an answer from what the companion knows
            // ("Open Settings"), else Undo after a command
            readonly property var action: !msg.mine && msg.modelData.action ? msg.modelData.action : null
            // a shell command it proposes: shown exactly, run only on a click
            readonly property var confirm: !msg.mine && msg.modelData.confirm ? msg.modelData.confirm : null
            readonly property bool sent: !!msg.modelData.sent
            readonly property string output: !msg.mine && msg.modelData.output ? msg.modelData.output : ""
            readonly property int headH: Math.max(body.implicitHeight, undo.visible ? undo.height : 0)
            width: ch.width
            height: msg.headH + (extras.visible ? extras.implicitHeight + Theme.spaceXs : 0)
            TextBody {
                id: body
                width: Math.min(implicitWidth, ch.width - (undo.visible ? undo.width + Theme.spaceS : 0))
                anchors.right: msg.mine ? parent.right : undefined
                text: msg.modelData.text
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                horizontalAlignment: msg.mine ? Text.AlignRight : Text.AlignLeft
                color: msg.mine ? Theme.textSecondary : msg.modelData.kind === "error" ? Theme.danger
                     : msg.modelData.kind === "info" ? Theme.textMuted : Theme.textPrimary
            }
            QsButton {
                id: undo
                visible: !msg.mine && !!msg.modelData.undo
                anchors.right: parent.right
                anchors.verticalCenter: body.verticalCenter
                label: "Undo"
                variant: "ghost"
                onGo: CompanionState.undo(msg.modelData.undo)
            }
            Column {
                id: extras
                y: msg.headH + Theme.spaceXs
                width: parent.width
                spacing: Theme.spaceXs
                visible: msg.action !== null || msg.confirm !== null || msg.output !== ""

                // what a command printed, or the command on offer
                Rectangle {
                    visible: msg.output !== "" || msg.confirm !== null
                    width: parent.width
                    height: code.implicitHeight + 2 * Theme.spaceS
                    radius: Theme.radiusPrimary
                    color: Theme.surfaceSunken
                    Text {
                        id: code
                        x: Theme.spaceS; y: Theme.spaceS
                        width: parent.width - 2 * Theme.spaceS
                        text: msg.confirm ? "$ " + msg.confirm.command : msg.output
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 12
                        elide: Text.ElideRight
                        color: Theme.textPrimary
                        font.family: Theme.type.mono.family
                        font.pixelSize: Theme.type.mono.size
                        font.weight: Theme.type.mono.weight
                    }
                }
                TextCaption {
                    visible: !!(msg.confirm && msg.confirm.reason) && !msg.sent
                    width: parent.width
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    color: Theme.warning
                    text: msg.confirm && msg.confirm.reason ? msg.confirm.reason : ""
                }
                Row {
                    spacing: Theme.spaceXs
                    visible: (msg.confirm !== null && !msg.sent) || msg.action !== null
                    // Run here, or In terminal; a command that needs a
                    // password or a person only gets the terminal
                    QsButton {
                        visible: msg.confirm !== null && !msg.sent && !msg.confirm.terminal
                        label: "Run"
                        variant: msg.confirm && msg.confirm.risk === "danger" ? "danger" : "primary"
                        onGo: CompanionState.runProposal(msg.modelData.id, msg.confirm.token, "run")
                    }
                    QsButton {
                        visible: msg.confirm !== null && !msg.sent
                        label: msg.confirm && msg.confirm.terminal ? "Run in terminal" : "In terminal"
                        variant: !msg.confirm || !msg.confirm.terminal ? "ghost"
                               : msg.confirm.risk === "danger" ? "danger" : "primary"
                        onGo: CompanionState.runProposal(msg.modelData.id, msg.confirm.token, "terminal")
                    }
                    QsButton {
                        visible: msg.action !== null
                        label: msg.action ? msg.action.label : ""
                        variant: "secondary"
                        onGo: CompanionState.run(msg.action.command, msg.action.args)
                    }
                }
            }
        }
    }
    Row {
        visible: CompanionState.thinking
        spacing: Theme.spaceS
        Spinner { size: Theme.iconSm; anchors.verticalCenter: parent.verticalCenter }
        TextCaption { text: ch.chat.label ? ch.chat.label + " is thinking" : "Working on it"; anchors.verticalCenter: parent.verticalCenter }
    }

}
