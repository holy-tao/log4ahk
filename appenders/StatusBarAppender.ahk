#Requires AutoHotkey v2.0

/**
 * An appender that writes log event messages to a GUI status bar
 * @see https://www.autohotkey.com/docs/v2/lib/GuiControls.htm#StatusBar
 */
class StatusBarAppender {

    /**
     * Initializes a new StatusBarAppender
     * @param {Gui.StatusBar} statusBar The status bar to write to
     * @param {Integer} partIndex The {@link https://www.autohotkey.com/docs/v2/lib/GuiControls.htm#StatusBar part} 
     *          of the status bar to write to (default: 1)
     * @param {Array} iconSet An array of {@link https://www.autohotkey.com/docs/v2/lib/GuiControls.htm#SB_SetIcon icon handles} 
     *          to use for the different log levels. Use a handle of 0 (NULL) to indicate that events for a
     *          given level should not use an icon (default: [])
     */
    __New(statusBar, partIndex := 1, iconSet := []) {
        if(!(statusBar is Gui.StatusBar)) {
            throw TypeError("Expected a Gui.StatusBar object, but got a(n) " . Type(statusBar), , statusBar)
        }
        this._statusBar := statusBar
        this._partIndex := partIndex
        this._iconSet := iconSet
    }
    
    /**
     * Appends a log event to the status bar
     * @param {Log.Event} event the event to append
     */
    Call(event){
        this._statusBar.SetText(event.Payload, this._partIndex)

        if(this._iconSet.Has(event.Level)) {
            SendMessage(0x040F, this._partIndex - 1, this._iconSet[event.Level], this._statusBar)
        }
    }
}