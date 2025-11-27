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
     * @param {Array} iconSet An array of {@link https://www.autohotkey.com/docs/v2/lib/GuiControls.htm#SB_SetIcon icon paths or handles} 
     *          to use for the different log levels (default: [])
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
        this._statusBar.SetText(event.Message, this._partIndex)

        if(this._iconSet.Has(event.Level)) {
            this._statusBar.SetIcon(this._iconSet[event.Level], this._partIndex)
        }
    }
}