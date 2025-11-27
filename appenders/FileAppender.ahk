#Requires AutoHotkey v2.0

/** 
 * A FileAppender writes log events to a file with configurable formatting and buffering
 */
class FileAppender {

    /**
     * The pattern used to format log messages
     * @type {String} 
     */
    Pattern := "{Timestamp}.{MSec} [{Level}] {Message}"

    /**
     * The format used to format timestamps
     * @type {String}
     * @see https://www.autohotkey.com/docs/v2/lib/FormatTime.htm
     */
    TimeFormat := "yyyy-MM-dd HH:mm:ss"

    /**
     * @param {String} filePath The path to the log file
     * @param {Number} bufferLength The number of logs to buffer before flushing to disk (default: 10)
     */
    __New(fileOrPath, bufferLength := 10) {
        this._buffer := bufferLength

        if(fileOrPath is String) {
            this._file := FileOpen(fileOrPath, "rw", "UTF-8")
        }
        else if(fileOrPath is File) {
            this._file := fileOrPath
        }
        else {
            throw TypeError("Expected a File object or a filepath string, but got a(n) " . Type(fileOrPath), , fileOrPath)
        }

        ; Imperfect, but __Delete is not guaranteed to fire if the script crashes
        ; or hits the end of the Auto-Execute thread
        this._OnExit := (*) => this.__Delete()
        OnExit(this._OnExit)
    }

    /**
     * Sets the pattern and/or time format for this appender
     * @param {String} pattern The pattern to use for formatting log messages
     * @param {String} timeFormat The format to use for formatting timestamps
     * @returns {FileAppender} this appender for chaining
     */
    WithPattern(pattern?, timeFormat?) {
        if(IsSet(pattern))
            this.Pattern := pattern
        if(IsSet(timeFormat))
            this.TimeFormat := timeFormat
        return this
    }

    /**
     * Formats a log event according to the appender's pattern
     * @param {Log.Event} event the event to format
     * @returns {String} the formatted log message
     */
    _Format(event){
        formattedTime := FormatTime( event.Timestamp, this.TimeFormat)
        message := StrReplace(this.Pattern, "{Timestamp}", formattedTime)
        message := StrReplace(message, "{MSec}", event.MSec)
        message := StrReplace(message, "{Level}", Log.Level[event.Level])
        message := StrReplace(message, "{Message}", event.Payload)

        ; Indent new lines for better readability
        message := StrReplace(message, "`n", "`n`t")
        message := Trim(message, "`n`t`r ")

        return message
    }

    /**
     * Flushes the file buffer to disk
     */
    Flush() {
        ; File objects have no Flush() method, but accessing the handle forces a flush
        ; https://www.autohotkey.com/docs/v2/lib/File.htm#Handle
        _ := this._file.Handle
    }

    /**
     * Logs an event to the file
     * @param {Log.Event} event The event to log
     */
    Call(event) {
        message := this._Format(event)
        this._file.WriteLine(message)

        this._buffer -= 1
        if(this._buffer <= 0 || event.Level >= Log.Level.ERROR) {
            this.Flush()
            this._buffer := 10
        }
    }

    __Delete() {
        this.Flush()
        this._file.Close()
        OnExit(this._OnExit, 0)
    }
}

/**
 * A ConsoleAppender is a special kind of `FileAppender` that writes log events to 
 * stdout and stderr with no buffering. Log events with level `ERROR` and above are
 * written to stderr; all others are written to stdout.
 * 
 * Note that because stdout and stderr are separate streams, log events may appear
 * out of order if both error and non-error events are logged in quick succession.
 */
class ConsoleAppender extends FileAppender {

    _stdout := FileOpen("*", "w", "UTF-8")
    _stderr := FileOpen("**", "w", "UTF-8")

    __New(){
        ; Don't call parent constructor since we don't want a "real" file
    }

    /**
     * Logs an event to the file
     * @param {Log.Event} event The event to log
     */
    Call(event) {
        if(event.Level >= Log.Level.ERROR){
            this._stderr.WriteLine(this._Format(event))
        }
        else{
            this._stdout.WriteLine(this._Format(event))
        }

        this.Flush()
    }

    Flush() {
        _ := this._stdout.Handle
        _ := this._stderr.Handle
    }

    __Delete() {
        this.Flush()
        this._stdout.Close()
        this._stderr.Close()
    }
}