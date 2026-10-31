return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.local.lightroom.autohdr.v2',
    LrPluginName = LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text001=Automatic Bracketed HDR v2',

    VERSION = { major = 2, minor = 1, revision = 2, build = 7 },

    LrLibraryMenuItems = {
        {
            title = LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text011=[v2] Detect and merge bracketed HDR DNGs...',
            file = 'AutoHDRBatch.lua',
            enabledWhen = 'photosSelected',
        },
        {
            title = LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text012=[v2] Test HDR shortcut on current selection...',
            file = 'TestCurrentSelection.lua',
            enabledWhen = 'photosSelected',
        },
    },
}
