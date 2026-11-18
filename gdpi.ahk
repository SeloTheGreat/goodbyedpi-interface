#Requires AutoHotkey v2.0

#SingleInstance
Persistent

; Constants

ERR_InvalidStateFile := 100

WindowHeight := 360
WindowWidth := 300

Application := A_ScriptDir "\x86_64\goodbyedpi.exe"

DataDirectory := A_ScriptDir "\data"
StateFile := DataDirectory "\.state"
GoodbyeDPIHelpMessageFile := DataDirectory "\goodbyedpi-help-msg.txt"
PresetsFile := DataDirectory "\presets.list"
BlacklistFile := DataDirectory "\blacklist.list"

; Variables

GdpiPID := 0
State := {
	args: "",
	blacklist: true,
}
PresetsList := Array()
MatchingPresetIndex := 0
HasChangedConfiguration := false
TrayHasTerminateGDPIButton := false

; State structure:
; args -> custom argument string user inputs (string)
; blacklist -> whether the blacklist is enabled or not (1 or 0)
Loop read, StateFile {
	arr := StrSplit(A_LoopReadLine, "$")
	if (arr.Length != 2) {
		ExitApp(ERR_InvalidStateFile)
	}
	State.%arr[1]% := arr[2]
}
; Fill presets list
Loop read, PresetsFile {
	PresetsList.Push(A_LoopReadLine)
	if (A_LoopReadLine == State.args) {
		MatchingPresetIndex := PresetsList.Length
	}
}

OnExit(ExitFunc)

; Tray handle

TraySetIcon(Application, , true)

A_TrayMenu.Delete()

A_TrayMenu.Add("&Exit", (*) => ExitApp())
A_TrayMenu.Add()
A_TrayMenu.Add("Dash&board", ShowConfigGui)
A_TrayMenu.Default := "Dash&board"

; Config Gui

ConfigGui := Gui("-Resize -MaximizeBox", "GDPI Dashboard")
_InnerWindowWidth := WindowWidth - ConfigGui.MarginX * 2

ConfigGui_AddSeperator() {
	ConfigGui.AddText("w" _InnerWindowWidth " h2 0x10 xm y+" ConfigGui.MarginY)
}

ConfigGui.SetFont('s9', "Segoe UI")
ConfigGui.MarginY := 5

CTRL_ShowGdpiHelpMsg := ConfigGui.AddButton("vShowGdpiHelpMsg h25", "GoodbyeDPI CLI help ↳")
CTRL_ShowGdpiRepo := ConfigGui.AddButton("vShowGdpiRepo h25 x+15", "GoodbyeDPI Repo ↳")
ConfigGui_AddSeperator()
ConfigGui.AddText(, "Executable path:")
CTRL_ExecPath := ConfigGui.AddEdit("vExecPath ReadOnly yp-3 x+5 w150 r1 -Wrap", Application)
CTRL_ExecPathChange := ConfigGui.AddButton("vExecPathChange yp-1 x+1 Center", "✎")
ConfigGui_AddSeperator()
ConfigGui.AddText(, "CLI Arguments:")
CTRL_ArgumentString := ConfigGui.AddComboBox(
	"vArgumentString  yp-3 x+5 w190 r7 Choose" (MatchingPresetIndex != 0 ? MatchingPresetIndex : 1),
	PresetsList
)
CTRL_ArgumentString.Text := State.args
CTRL_MatchingPresetIndex := ConfigGui.AddText("vMatchingPresetIndex w140 xm y+" ConfigGui.MarginY,
	"Current preset: " (MatchingPresetIndex != 0 ? MatchingPresetIndex : "NONE")
)
CTRL_EditPresetsFile := ConfigGui.AddButton("vEditPresetsFile h25 yp-4 xm+142", "Edit Presets File ↳")
CTRL_ReloadPresets := ConfigGui.AddButton("vReloadPresets h25 yp xm+250", "⟳")
ConfigGui.AddText("w" _InnerWindowWidth " cGray xm y+" ConfigGui.MarginY,
	"Note that you have to press [⟳] once you're done editing the list for changes to register."
)
ConfigGui_AddSeperator()
CTRL_BlacklistEnabled := ConfigGui.AddCheckBox("vBlacklistEnabled Checked" State.blacklist, "Blacklist enabled")
CTRL_EditBlacklistFile := ConfigGui.AddButton("vEditBlacklistFile h25 yp-4 xm+162", "Edit Blacklist File ↳")
ConfigGui.AddText("w" _InnerWindowWidth " cGray xm y+" ConfigGui.MarginY,
	"The blacklist, contrary to it's name; includes a list of domains that will be managed by GoodbyeDPI. It behaves as an include list."
)
ConfigGui_AddSeperator()
CTRL_SaveState := ConfigGui.AddButton("vSaveState w" _InnerWindowWidth, "Save configuration to file")
CTRL_StartGdpi := ConfigGui.AddButton("vStartGdpi w" _InnerWindowWidth / 2 - 5, "Start GoodbyeDPI")
CTRL_KillGdpi := ConfigGui.AddButton("vKillGdpi x+5 w" _InnerWindowWidth / 2, "Kill GoodbyeDPI")
CTRL_GdpiIsRunning := ConfigGui.AddText("vGdpiIsRunning xm r1 w" _InnerWindowWidth, "GoodbyeDPI is: Not Running.")

CTRL_ShowGdpiRepo.OnEvent("Click", (*) => Run("https://github.com/ValdikSS/goodbyeDPI"))
CTRL_ShowGdpiHelpMsg.OnEvent("Click", (*) => Run("notepad.exe " GoodbyeDPIHelpMessageFile))
CTRL_EditBlacklistFile.OnEvent("Click", (*) => Run("notepad.exe " BlacklistFile))
CTRL_EditPresetsFile.OnEvent("Click", (*) => Run("notepad.exe " PresetsFile))

CTRL_ExecPathChange.OnEvent("Click", (*) => MsgBox("Not implemented!", "Oops! :("))
CTRL_ArgumentString.OnEvent("Change", OnArgumentStringChanged)
CTRL_ReloadPresets.OnEvent("Click", ReloadPresetsList)
CTRL_BlacklistEnabled.OnEvent("Click", ToggleBlacklistEnabled)

CTRL_SaveState.OnEvent("Click", SaveConfigurationToFiles)
CTRL_StartGdpi.OnEvent("Click", StartGdpiProcess)
CTRL_KillGdpi.OnEvent("Click", FinishGdpiProcess)

; App handle

Set_HasChangedConfiguration(set) {
	global HasChangedConfiguration

	HasChangedConfiguration := set
	if (set) {
		ConfigGui.Title := "GDPI Dashboard*"
	} else {
		ConfigGui.Title := "GDPI Dashboard"
	}
}

ShowConfigGui(*) {
	ConfigGui.Show("Restore Center w" WindowWidth " h" WindowHeight)
}

ToggleBlacklistEnabled(*) {
	State.blacklist := !State.blacklist
	Set_HasChangedConfiguration(true)
}

OnArgumentStringChanged(*) {
	global PresetsList
	global MatchingPresetIndex

	if (State.args == CTRL_ArgumentString.Text) {
		return
	}

	State.args := CTRL_ArgumentString.Text
	Set_HasChangedConfiguration(true)

	MatchingPresetIndex := 0
	Loop PresetsList.Length {
		if (State.args == PresetsList[A_Index]) {
			MatchingPresetIndex := A_Index
		}
	}

	if (MatchingPresetIndex != 0) {
		CTRL_MatchingPresetIndex.Text := "Current preset: " MatchingPresetIndex
	} else {
		CTRL_MatchingPresetIndex.Text := "No preset"
	}
}

ReloadPresetsList(*) {
	global PresetsList

	PresetsList := []
	Loop read, PresetsFile {
		PresetsList.Push(A_LoopReadLine)
	}

	CTRL_ArgumentString.Delete()
	CTRL_ArgumentString.Add(PresetsList)
	CTRL_ArgumentString.Text := State.args

	OnArgumentStringChanged()
}

SaveConfigurationToFiles(*) {
	StateFileContent := ""
	for key, value in State.OwnProps() {
		StateFileContent := StateFileContent key "$" value "`n"
	}
	o_StateFile := FileOpen(StateFile, "w")
	o_StateFile.Write(StateFileContent)
	o_StateFile.Close()

	Set_HasChangedConfiguration(false)
}

BuildGdpiExecCommand() {
	BlacklistSuffix := ""
	if (State.blacklist) {
		BlacklistSuffix := ' --blacklist "' BlacklistFile '"'
	}

	return Application " " State.args BlacklistSuffix
}

StartGdpiProcess(*) {
	global GdpiPID
	global HasChangedConfiguration
	global TrayHasTerminateGDPIButton

	if (HasChangedConfiguration) {
		SaveConfigurationToFiles()
	}

	if (ProcessExist(GdpiPID)) {
		ProcessClose(GdpiPID)
	}

	try {
		Run(BuildGdpiExecCommand(), , "Hide", &NewPID)
		GdpiPID := NewPID
	} catch {
		return
	}

	A_TrayMenu.Add("&Kill goodbyedpi.exe", FinishGdpiProcess)
	TrayHasTerminateGDPIButton := true

	CTRL_GdpiIsRunning.Text := "GoodbyeDPI is: Running!"
}

FinishGdpiProcess(*) {
	global GdpiPID
	global TrayHasTerminateGDPIButton

	if (ProcessExist(GdpiPID)) {
		ProcessClose(GdpiPID)
	}
	GdpiPID := 0

	if (TrayHasTerminateGDPIButton) {
		A_TrayMenu.Delete("&Kill goodbyedpi.exe")
		TrayHasTerminateGDPIButton := false
	}
	CTRL_GdpiIsRunning.Text := "GoodbyeDPI is: Not Running."
}

; Application Start

if (A_Args.Length > 0 && A_Args[1] = "run") {
	StartGdpiProcess()
} else {
	ShowConfigGui()
}

; Exit label

ExitFunc(ExitReason, ExitCode) {
	FinishGdpiProcess()
	if (ExitCode == ERR_InvalidStateFile) {
		MsgBox("ERR_CODE(" ERR_InvalidStateFile ") - State file has been incorrectly formmatted.", "Error")
	}
}
