class Log {
    /**
     * Enum of valid log levels
     */
    class Level {
        static OFF => 0
        static TRACE => 1
        static DEBUG => 2
        static INFO => 3
        static WARN => 4
        static ERROR => 5
        static FATAL => 6

        static __Item[levelNum] {
            get{
                for(levelName, num in this.OwnProps()){
                    if(num == levelNum)
                        return levelName
                    }
                throw ValueError("Not a log level number", , levelNum)
            } 
        }
    }

    /**
     * A log event with payload evaluated
     */
    class Event {
        __New(level, payload) {
            this.Level := level
            this.Payload := payload

            this.Timestamp := A_Now
            this.MSec := A_MSec
            this.Target := Log.target
        }
    }

    /**
     * The current logging level
     */
    static CurrentLevel := Log.Level.INFO

    /**
     * The name of the logging target (usually the script name) - useful
     * if sending logs to an aggregator
     */
    static Target := A_ScriptName

    static _Filters := []
    static _Appenders := []

    static __New(){
        this.DeleteProp("__New") ; static class

        envVar := EnvGet("AHK_LOG_LEVEL")
        if(envVar != ""){
            if(IsInteger(envVar)){
                levelNum := Integer(envVar)
                if(levelNum < Log.Level.OFF || levelNum > Log.Level.FATAL){
                    throw ValueError("Environment variable AHK_LOG_LEVEL is out of range", , levelNum)
                }
                Log.CurrentLevel := levelNum
            }
            else {
                levelStr := StrUpper(envVar)
                Log.CurrentLevel := Log.Level.%levelStr%
            }
        }
    }

    /**
     * Registers a new Appender
     * @param {Func(Log.Event) => void} appender Callable object that writes an event somewhere
     * @returns {Log} the Log class for chaining
     */
    static To(appender){
        if(!HasMethod(appender, , 1)){
            throw TypeError("Appender must be a callable object that takes a Log.Event as parameter")
        }

        Log._Appenders.Push(appender)
        return Log
    }

    /**
     * Adds a filter to the log pipeline
     * @param {Func(Log.Event) => boolean} filter Callable object that takes an event and returns a boolean
     */
    static Filter(filter){
        if(!HasMethod(filter, , 1)){
            throw TypeError("Filter must be a callable object that takes a Log.Event as parameter and returns a boolean")
        }

        Log._Filters.Push(filter)
        return Log
    }

    /**
     * Logs a message at the given level
     * 
     * @param {Number} level the log level
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static LogMessage(level, payload){
        if(level < Log.CurrentLevel)
            return

        evt := Log.Event(level, Log._EvaluatePayload(payload))

        for(filter in Log._Filters){
            if(!filter.Call(evt))
                return
        }

        for(appender in Log._Appenders){
            appender.Call(evt)
        }
    }

    /**
     * Converts the payload to a string, calling it if it's callable
     * 
     * @param {String | Object | Func() => String | Object} payload the payload to evaluate
     * @returns {String} the evaluated payload
     */
    static _EvaluatePayload(payload) {
        if(payload is Error){
            return Log._FormatErrorMessage(payload)
        }
        else if(HasMethod(payload, , 0)){
            return Log._EvaluatePayload(payload.Call())
        }
        else if(HasMethod(payload, "ToString", 0)){
            return String(payload)
        }
        
        return String(payload)
    }

    /**
     * Formats an Error object into a loggable string
     * @param {Error} err the Error to format
     * @returns {String} the formatted error message 
     */
    static _FormatErrorMessage(err){
        message := Format("{1}: {2}", Type(err), err.Message)
        if(err.extra != ""){
            message .= Format(" (Specifically: {1})", err.extra)
        }
        message .= "`n"
        message .= err.Stack

        return message
    }

;@region Logging Aliases
    /**
     * Logs a TRACE level message
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static Trace(payload){
        Log.LogMessage(Log.Level.TRACE, payload)
    }

    /**
     * Logs a DEBUG level message
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static Debug(payload){
        Log.LogMessage(Log.Level.DEBUG, payload)
    }

    /**
     * Logs an INFO level message
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static Info(payload){
        Log.LogMessage(Log.Level.INFO, payload)
    }

    /**
     * Logs a WARN level message
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static Warn(payload){
        Log.LogMessage(Log.Level.WARN, payload)
    }

    /**
     * Logs an ERROR level message
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static Error(payload){
        Log.LogMessage(Log.Level.ERROR, payload)
    }

    /**
     * Logs a FATAL level message
     * @param {String | Object | Func() => String | Object} payload the payload to log
     */
    static Fatal(payload){
        Log.LogMessage(Log.Level.FATAL, payload)
    }
;@endregion Logging Aliases
}
