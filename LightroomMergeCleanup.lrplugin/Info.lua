return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.local.lightroom.mergecleanup',
    LrPluginName = '合并原片清理助手',

    VERSION = { major = 1, minor = 1, revision = 0, build = 2 },

    LrLibraryMenuItems = {
        {
            title = '扫描合并结果与原片（堆栈/AutoHDR）…',
            file = 'ScanMergedStacks.lua',
            enabledWhen = 'photosSelected',
        },
    },
}
