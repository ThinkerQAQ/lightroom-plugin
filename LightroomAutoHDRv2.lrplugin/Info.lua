return {
    LrSdkVersion = 10.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.local.lightroom.autohdr.v2',
    LrPluginName = '自动包围曝光 HDR v2',

    VERSION = { major = 2, minor = 1, revision = 1, build = 6 },

    LrLibraryMenuItems = {
        {
            title = '[v2] 自动识别并逐组合成 HDR DNG…',
            file = 'AutoHDRBatch.lua',
            enabledWhen = 'photosSelected',
        },
        {
            title = '[v2] 测试合并当前选择一次…',
            file = 'TestCurrentSelection.lua',
            enabledWhen = 'photosSelected',
        },
    },
}
