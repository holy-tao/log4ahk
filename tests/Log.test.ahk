#Requires AutoHotkey v2.0

#Include ../Log.ahk
#Include ../appenders/FileAppender.ahk

; Super simple test / demo script for Log.ahk with FileAppender

OnError((thrown, mode) => Log.LogMessage(mode == "ExitApp" ? Log.Level.FATAL : Log.Level.ERROR, thrown))

Log
    .To(FileAppender("test.log"))
    .To(ConsoleAppender())

Log.Trace("This is a trace message and should not appear.")
Log.Debug("This is a debug message and should not appear.")
Log.Info("This is an info message.")
Log.Info(() => "This is an info message generated at " . FormatTime(A_Now))
Log.Fatal(Error("Something went terribly wrong!", , "Additional context about the error."))
Log.Info("The fatal message wasn't actually fatal, so this message appears.")

val := 1 / 0            ; This will trigger an error and be logged
NumPut("int", 42, -1)   ; Fatal error