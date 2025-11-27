#Requires AutoHotkey v2.0

/**
 * A filter that limits log events with the same message to a specified interval
 */
class ThrottleFilter {

    /**
     * A map of messages to timestamps of their last logged time
     * @type {Map<String, Integer>}
     */
    _lastLogged := Map()

    /**
     * @param {Number} interval The minimum interval (in milliseconds) between log events
     */
    __New(interval) {
        this._interval := interval
        this._lastLogged := 0
    }

    /**
     * Determines whether a log event should be logged based on the frequency filter
     * @param {Log.Event} event the event to evaluate
     * @returns {Boolean} true if the event should be logged, false otherwise
     */
    Call(event) {
        currentTime := A_TickCount
        lastTime := this._lastLogged.Has(event.Message) ? this._lastLogged[event.Message] : 0

        if((currentTime - lastTime) >= this._interval) {
            this._lastLogged[event.Level] := currentTime
            return true
        }

        return false
    }
}