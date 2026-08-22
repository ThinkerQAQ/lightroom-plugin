local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local function main()
    local catalog = LrApplication.activeCatalog()
    local selected = catalog:getTargetPhotos() or {}
    if #selected < 2 then
        LrDialogs.message(
            '自动包围曝光 HDR v2',
            '请在“图库”网格视图中准确选中一组照片（例如 3 张）。',
            'info'
        )
        return
    end

    local message = string.format(
        '当前选中 %d 张照片。\n\n此测试不会重新选择、分组或创建收藏集，只向当前前台的 Lightroom 发送一次 Ctrl+Shift+H。\n\n确认手动按 Ctrl+Shift+H 对这组照片有效后再继续。',
        #selected
    )
    if LrDialogs.confirm('自动包围曝光 HDR v2.1.1 测试', message, '发送一次', '取消') ~= 'ok' then
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
            'v2 测试按键已发送',
            '原生 helper 已确认 Lightroom 是前台窗口，并发送了一次 Ctrl+Shift+H。\n\n请检查 Lightroom 左上角是否出现 HDR 任务。结果已写入 AutoHDRInput.log。',
            'info'
        )
    else
        LrDialogs.message(
            'v2 测试失败',
            string.format(
                '原生 helper 返回代码 %d。\n\n20=找不到 Lightroom；22=Lightroom 不是前台；23=Windows SendInput 失败；1=其他异常。\n详细信息见 AutoHDRInput.log。',
                exitCode
            ),
            'critical'
        )
    end
end

LrTasks.startAsyncTask(main)
