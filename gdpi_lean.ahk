#Requires AutoHotkey v2.0

#SingleInstance
Persistent

Application := A_ScriptDir "\x86_64\goodbyedpi.exe"

StateFile := A_ScriptDir "\data\.state"
BlacklistFile := A_ScriptDir "\data\blacklist.list"

GdpiPID := 0

A_TrayMenu.Delete()

A_TrayMenu.Add("&Exit", (*) => ExitApp())

OnExit(ExitFunc)

global GdpiPID

if (ProcessExist(GdpiPID)) {
	ProcessClose(GdpiPID)
}

HasBlacklist := false
StateArgs := ""
Loop read, StateFile {
	arr := StrSplit(A_LoopReadLine, "$")
	if (arr[1] == "args") {
		StateArgs := arr[2]
	} else if (arr[1] == "blacklist") {
		HasBlacklist := arr[2] == "1"
	}
}

BlacklistSuffix := ""
if (HasBlacklist) {
	BlacklistSuffix := ' --blacklist "' BlacklistFile '"'
}

Run(Application " " StateArgs BlacklistSuffix, , "Hide", &NewPID)
GdpiPID := NewPID

FinishGdpiProcess(*) {
	global GdpiPID

	if (ProcessExist(GdpiPID)) {
		ProcessClose(GdpiPID)
	}
	GdpiPID := 0
}

ExitFunc(ExitReason, ExitCode) {
	FinishGdpiProcess()
}
