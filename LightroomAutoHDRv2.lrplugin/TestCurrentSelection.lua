local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local function main()
    local catalog = LrApplication.activeCatalog()
    local selected = catalog:getTargetPhotos() or {}
    if #selected < 2 then
        LrDialogs.message(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text001=Automatic Bracketed HDR v2',
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text002=Select exactly one bracketed set in Library Grid view (for example, 3 photos).',
            'info'
        )
        return
    end

    local message = string.format(
        LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text003=%d photos selected.^n^nThis test does not change the selection, group photos, or create a collection. It sends Ctrl+Shift+H once to the foreground Lightroom window.^n^nFirst confirm that pressing Ctrl+Shift+H manually works for this set.',
        #selected
    )
    if LrDialogs.confirm(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text004=Automatic Bracketed HDR v2.1.2 test', message, LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text005=Send once', LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text006=Cancel') ~= 'ok' then
        return
    end

    local helper = LrPathUtils.child(_PLUGIN.path, 'AutoHDRInput.exe')
    LrTasks.sleep(0.4)
    -- On this Lightroom build LrTasks.execute treats a quoted command plus
    -- arguments as one executable path and fails before starting the process.
    -- The plug-in path contains no spaces, so execute the helper path directly.
    local exitCode = LrTasks.execute(helper)

    if exitCode == 0 then
        LrDialogs.message(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text007=HDR shortcut sent',
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text008=The helper confirmed Lightroom was in the foreground and sent Ctrl+Shift+H once.^n^nCheck for an HDR task in Lightroom. Details were written to AutoHDRInput.log.',
            'info'
        )
    else
        LrDialogs.message(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text009=HDR shortcut test failed',
            string.format(
                LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text010=The helper returned code %d.^n^n20=Lightroom not found; 22=Lightroom is not in the foreground; 23=Windows SendInput failed; 1=other error.^nSee AutoHDRInput.log for details.',
                exitCode
            ),
            'critical'
        )
    end
end

LrTasks.startAsyncTask(main)
