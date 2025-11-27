#Requires AutoHotkey v2.0

#Include ../Log.ahk
#Include ../appenders/FileAppender.ahk
#Include ../appenders/WindowsEventLogAppender.ahk


; Super simple test / demo script for Log.ahk with FileAppender

OnError((thrown, mode) => Log.LogMessage(mode == "ExitApp" ? Log.Level.FATAL : Log.Level.ERROR, thrown))

Log.Configure(Log.Level.INFO)
    .ToLogger(Log.Logger("FileLogs")
        .WithAppender(FileAppender("test.log"))
        .WithAppender(ConsoleAppender())
    )
    .ToLogger(Log.Logger("WindowsEventLogs", Log.Level.ERROR)
        .WithAppender(WindowsEventLogAppender())
    )

Log.Info("This is an info message.")
Log.Trace("This is a trace message and should not appear.")
Log.Debug("This is a debug message and should not appear.")
Log.Info(() => "This is an info message generated at " . FormatTime(A_Now))
Log.Fatal(Error("Something went terribly wrong!", , "Additional context about the error."))
Log.Info("The fatal message wasn't actually fatal, so this message appears.")
Log.Warn((*) => "We're about to cause some errors for testing")

val := 1 / 0            ; This will trigger an error and be logged
NumPut("int", 42, -1)   ; Fatal error