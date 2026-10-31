return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.local.lightroom.mergecleanup',
    LrPluginName = LOC '$$$/ThinkerQAQ/LightroomMergeCleanup/Text016=Merged Source Cleanup',

    VERSION = { major = 1, minor = 1, revision = 1, build = 3 },

    LrLibraryMenuItems = {
        {
            title = LOC '$$$/ThinkerQAQ/LightroomMergeCleanup/Text017=Scan merges and source photos (stacks/AutoHDR)...',
            file = 'ScanMergedStacks.lua',
            enabledWhen = 'photosSelected',
        },
    },
}
