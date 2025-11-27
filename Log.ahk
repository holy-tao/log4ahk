/** 
 * log4ahk's primary entry point
*/
class Log {
    /**
     * Enum of valid log levels
     */
    class Level {
        static ALL => 0
        static TRACE => 1
        static DEBUG => 2
        static INFO => 3
        static WARN => 4
        static ERROR => 5
        static FATAL => 6
        static OFF => 7

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
        }
    }

    /**
     * A Logger is the beginning of a logging pipeline and has its own log level, set of
     * filters, and set of appenders.
     */
    class Logger {
        
        _Filters := []
        _Appenders := []

        /**
         * Initializes a new Logger.
         * @param {String} name the name of the logger. Must be unique among all registered
         *          loggers (default: A_ScriptName) 
         * @param {Integer} level the logger's level. If lower than the global log level, can
         *          be used to filter logs (default: Log.Level.ALL)
         */
        __New(name := A_ScriptName, level := Log.Level.ALL){
            this.Name := name
            this.CurrentLevel := level

            return this
        }

        /**
         * Registers a new Appender
         * @param {Func(Log.Event) => void} appender Callable object that writes an event somewhere
         * @returns {Log} the Log class for chaining
         */
        WithAppender(appender){
            if(!HasMethod(appender, , 1)){
                throw TypeError("Appender must be a callable object that takes a Log.Event as parameter")
            }

            this._Appenders.Push(appender)
            return this
        }

        /**
         * Adds a filter to the log pipeline
         * @param {Func(Log.Event) => boolean} filter Callable object that takes an event and returns a boolean
         */
        Filter(filter){
            if(!HasMethod(filter, , 1)){
                throw TypeError("Filter must be a callable object that takes a Log.Event as parameter and returns a boolean")
            }

            this._Filters.Push(filter)
            return this
        }

        Call(event){
            if(event.level < this.CurrentLevel)
                return

            event.Target := this.Name
            for(filter in this._Filters){
                if(!filter.Call(event))
                    return
            }

            for(appender in this._Appenders){
                appender.Call(event)
            }
        }
    }

    /**
     * The current logging level
     */
    static CurrentLevel := Log.Level.INFO

    static _Filters := []
    static Loggers := Map()

    /**
     * Configures global settings and does any required initialization (nothing for now)
     * @param {Integer?} level Log level to set - leave blank to read from AHK_LOG_LEVEL environment
     *          variable
     */
    static Configure(level?){
        levelNum := Log.Level.OFF

        if(!IsSet(level)){
            if((envVar := EnvGet("AHK_LOG_LEVEL")) != "") {
                levelNum := IsInteger(envVar) ? Integer(envVar) : Log.Level.%StrUpper(envVar)%
            }
        }
        else{
            levelNum := level
        }

        if(levelNum < Log.Level.ALL || levelNum > Log.Level.OFF){
            throw ValueError("Log level out of range", , levelNum)
        }
        Log.CurrentLevel := levelNum

        return Log
    }

    /**
     * Registers a new logger
     * @param {Log.Logger} logger logger to register 
     */
    static ToLogger(logger) {
        if(Log.Loggers.Has(logger.Name)){
            throw ValueError("Logger with name " . logger.Name " is already registered")
        }

        this.Loggers[logger.Name] := logger
        return Log
    }

    /**
     * Adds a global filter to the log pipeline
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

        for(name, logger in Log.Loggers){
            logger.Call(evt)
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
