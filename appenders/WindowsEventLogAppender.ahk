#Requires AutoHotkey v2.0

#Include <AhkWin32Projection\Windows\Win32\System\EventLog\Apis>
#Include <AhkWin32Projection\Windows\Win32\System\EventLog\REPORT_EVENT_TYPE>

/**
 * An appender that writes log event messages to the Windows Event Log. This appender requires
 * the following types from AhkWin32Projection to be available in a library directory under
 * Lib/AhkWin32Projection/:
 * - Windows.Win32.System.EventLog.Apis
 * - Windows.Win32.System.EventLog.REPORT_EVENT_TYPE
 * 
 * It also requires write access to the Windows registry the first time you run it.
 * 
 * @see https://github.com/holy-tao/AhkWin32Projection/tree/main/Windows/Win32/System/EventLog
 * @see https://learn.microsoft.com/en-us/windows/win32/etw/tracing-events
 */
class WindowsEventLogAppender {

    /**
     * Initializes a new WindowsEventLogAppender
     * @param {String} eventSourceName Name of the event source to register with Windows (default: A_ScriptName)
     *          Avoid changing this too often; as a registry key needs to be written every time it's modified 
     */
    __New(eventSourceName := A_ScriptName){
        this._RegisterEventSource(eventSourceName)

        this._hEvtLog := EventLog.RegisterEventSourceW(0, eventSourceName)

        this._OnExit := (*) => this.__Delete()
        OnExit(this._OnExit)
    }

    /**
     * Logs an event to the Windows Event Log
     * @param {Log.Event} event event to log 
     */
    Call(event){
        ; Create a single-element "array" of strings
        lpStrBuf := Buffer(StrPut(event.payload, "UTF-16"), 0)
        StrPut(event.payload, lpStrBuf, ,"UTF-16")
        arrBuf := Buffer(A_PtrSize, 0)
        NumPut("ptr", lpStrBuf.Ptr, arrBuf)

        try{
            EventLog.ReportEventW(
                this._hEvtLog, 
                this._LogLevelToEventType(event.level), 
                0,
                event.level,
                0, 
                1, 
                0, 
                arrBuf, 
                0)
        }
        catch OSError as err {
            ; Something internal to ReportEventW can throw a 203 and ReportEventW doesn't reset LastError
            ; Anyways, we can safely ignore it
            ; https://github.com/holy-tao/AhkWin32Projection/issues/88
            if(err.Number != 203){
                throw err
            }
        }
    }

    /**
     * Maps log4ahk log levels onto Windows Event Log log types 
     * @param {Integer} logLevel Level to map 
     */
    _LogLevelToEventType(logLevel){
        switch(logLevel){
            case Log.Level.FATAL:
                return REPORT_EVENT_TYPE.EVENTLOG_ERROR_TYPE
            case Log.Level.ERROR:
                return REPORT_EVENT_TYPE.EVENTLOG_ERROR_TYPE
            case Log.Level.WARN:
                return REPORT_EVENT_TYPE.EVENTLOG_WARNING_TYPE
            default:
                return REPORT_EVENT_TYPE.EVENTLOG_INFORMATION_TYPE
        }
    }

    /**
     * Registers this script as an event source if it isn't already. Registering as
     * an event source requires admin priveleges to write to the registry. The script
     * uses eventcreate.exe as a proxy; otherwise the message file would need to be 
     * embedded in a binary and the script would need to be compiled.
     * 
     * @see https://learn.microsoft.com/en-us/windows/win32/eventlog/message-files
     * 
     * @param {String} evtSourceName name of the event source to register 
     */
    _RegisterEventSource(evtSourceName){
        static APP_KEY := "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\EventLog\Application"
        static EVT_SRC_KEY := APP_KEY . "\" . evtSourceName

        try existing := RegRead(EVT_SRC_KEY, "", "")
        if(IsSet(existing) || existing != ""){
            ; Registry key already exists
            return
        }

        RegCreateKey(EVT_SRC_KEY)
        RegWrite("C:\Windows\System32\eventcreate.exe", "REG_SZ", EVT_SRC_KEY, "EventMessageFile")
        RegWrite(7, "REG_DWORD", EVT_SRC_KEY, "TypesSupported")
    }

    /**
     * Cleans up the logger, unregisters it if it's still registerede
     */
    __Delete(){
        OnExit(this._OnExit, 0)
        if(this._hEvtLog != 0) {
            EventLog.DeregisterEventSource(this._hEvtLog)
        }
    }
}