local LrApplication = import 'LrApplication'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

local PLUGIN_VERSION = '1.1.0'
local COLLECTION_SET_NAME = '合并原片清理助手'
local LOG_PATH = LrPathUtils.child(_PLUGIN.path, 'MergeCleanup.log')
local AUTO_HDR_FOLDER = LrPathUtils.child(
    LrPathUtils.parent(_PLUGIN.path),
    'LightroomAutoHDRv2.lrplugin'
)
local AUTO_HDR_MANIFEST = LrPathUtils.child(AUTO_HDR_FOLDER, 'AutoHDR-v2-last-run.tsv')
local AUTO_HDR_LOG = LrPathUtils.child(AUTO_HDR_FOLDER, 'AutoHDR-v2.log')

local logger = LrLogger('LightroomMergeCleanup')
logger:enable('logfile')
local traceId = os.date('%Y%m%dT%H%M%S') .. '-' .. tostring(math.floor((LrDate.currentTime() % 1) * 1000))
local runStarted = LrDate.currentTime()

local function cleanLogValue(value)
    return tostring(value == nil and '' or value):gsub('[\r\n\t]', ' ')
end

local function logEvent(level, node, status, fields)
    local parts = {
        os.date('%Y-%m-%dT%H:%M:%S'),
        'level=' .. cleanLogValue(level),
        'traceId=' .. cleanLogValue(traceId),
        'node=' .. cleanLogValue(node),
        'status=' .. cleanLogValue(status),
    }
    if fields then
        local keys = {}
        for key in pairs(fields) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = cleanLogValue(key) .. '=' .. cleanLogValue(fields[key])
        end
    end
    local line = table.concat(parts, '\t')
    logger:trace(line)
    local file = io.open(LOG_PATH, 'a')
    if file then
        file:write(line, '\n')
        file:close()
    end
end

local function durationMs(started)
    return math.floor((LrDate.currentTime() - started) * 1000 + 0.5)
end

local function filenameOf(photo)
    local path = photo:getRawMetadata('path') or ''
    return LrPathUtils.leafName(path) or path
end

local function pathOf(photo)
    return photo:getRawMetadata('path') or ''
end

local function normalizePath(path)
    local normalized = tostring(path or ''):gsub('/', '\\')
    return string.lower(normalized)
end

local function stemOf(photo)
    local name = filenameOf(photo)
    return LrPathUtils.removeExtension(name) or name
end

local function isLikelyMerged(photo)
    if photo:getRawMetadata('isVirtualCopy') or photo:getRawMetadata('isVideo') then
        return false
    end

    local name = string.upper(filenameOf(photo))
    local ext = string.upper(LrPathUtils.extension(name) or '')
    if ext ~= 'DNG' and ext ~= 'TIF' and ext ~= 'TIFF' and ext ~= 'PSD' then
        return false
    end

    local stem = string.upper(LrPathUtils.removeExtension(name) or name)
    return stem:find('%-HDR') ~= nil
        or stem:find('_HDR') ~= nil
        or stem:find('%-PANO') ~= nil
        or stem:find('_PANO') ~= nil
        or stem:find('%-PANORAMA') ~= nil
        or stem:find('_PANORAMA') ~= nil
        or stem:find('%-MERGE') ~= nil
        or stem:find('_MERGE') ~= nil
end

local function isSourcePhoto(photo)
    if photo:getRawMetadata('isVirtualCopy') or photo:getRawMetadata('isVideo')
        or isLikelyMerged(photo)
    then
        return false
    end
    local format = string.upper(photo:getRawMetadata('fileFormat') or '')
    return format == 'RAW' or format == 'DNG'
end

local function mergedRoot(photo)
    local stem = string.upper(stemOf(photo))
    local cut = nil
    for _, marker in ipairs({ '-HDR', '_HDR', '-PANO', '_PANO', '-PANORAMA', '_PANORAMA', '-MERGE', '_MERGE' }) do
        local position = stem:find(marker, 1, true)
        if position and (not cut or position < cut) then cut = position end
    end
    return cut and stem:sub(1, cut - 1) or stem
end

local function mergedKind(photo)
    local stem = string.upper(stemOf(photo))
    if stem:find('HDR', 1, true) then
        return 'hdr'
    elseif stem:find('PANO', 1, true) then
        return 'pano'
    end
    return 'merge'
end

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

local function loadTsvManifest()
    if LrFileUtils.exists(AUTO_HDR_MANIFEST) ~= 'file' then return nil end
    local content = LrFileUtils.readFile(AUTO_HDR_MANIFEST)
    local groups = {}
    for line in content:gmatch('[^\r\n]+') do
        local index, dng, source = line:match('^(%d+)\t([^\t]+)\t(.+)$')
        if index and dng and source then
            index = tonumber(index)
            groups[index] = groups[index] or { index = index, dng = dng, sources = {} }
            groups[index].sources[#groups[index].sources + 1] = source
        end
    end
    local result = {}
    for _, group in pairs(groups) do result[#result + 1] = group end
    table.sort(result, function(a, b) return a.index < b.index end)
    return #result > 0 and result or nil
end

local function loadLogManifest()
    if LrFileUtils.exists(AUTO_HDR_LOG) ~= 'file' then return nil end
    local content = LrFileUtils.readFile(AUTO_HDR_LOG)
    local plans = {}
    local completed = {}
    local allGroups = {}

    local function flushRun()
        for index, dng in pairs(completed) do
            if dng and plans[index] and #plans[index].sources >= 2 then
                allGroups[normalizePath(dng)] = {
                    index = index,
                    dng = dng,
                    sources = plans[index].sources,
                }
            end
        end
    end

    for line in content:gmatch('[^\r\n]+') do
        if line:find(' RUN_START ', 1, true) then
            flushRun()
            plans = {}
            completed = {}
        else
            local planIndex = tonumber(line:match('GROUP_PLAN index=(%d+)'))
            if planIndex then
                local folder = line:match(' folder=(.-) items=')
                local items = line:match(' items=(.*)$')
                local sources = {}
                if folder and items then
                    for name in items:gmatch('([^,]+)%(') do
                        sources[#sources + 1] = LrPathUtils.child(folder, trim(name))
                    end
                end
                plans[planIndex] = { index = planIndex, sources = sources }
            end

            local completeIndex = tonumber(line:match('GROUP_COMPLETE index=(%d+)'))
            if completeIndex then
                completed[completeIndex] = line:match(' dng=(.-) elapsed=')
            end
        end
    end
    flushRun()

    local result = {}
    for _, group in pairs(allGroups) do result[#result + 1] = group end
    table.sort(result, function(a, b) return a.dng < b.dng end)
    return #result > 0 and result or nil
end

local function loadAutoHdrManifest()
    local started = LrDate.currentTime()
    local tsvManifest = loadTsvManifest() or {}
    local logManifest = loadLogManifest() or {}
    local merged = {}
    for _, entry in ipairs(logManifest) do
        merged[normalizePath(entry.dng)] = entry
    end
    for _, entry in ipairs(tsvManifest) do
        merged[normalizePath(entry.dng)] = entry
    end
    local manifest = {}
    for _, entry in pairs(merged) do manifest[#manifest + 1] = entry end
    table.sort(manifest, function(a, b) return a.dng < b.dng end)
    local source = #tsvManifest > 0 and (#logManifest > 0 and 'tsv+log' or 'tsv') or 'log'
    logEvent('INFO', 'manifest.load', #manifest > 0 and 'ok' or 'not_found', {
        durationMs = durationMs(started),
        entries = #manifest,
        logEntries = #logManifest,
        source = #manifest > 0 and source or 'none',
        tsvEntries = #tsvManifest,
    })
    return manifest, source
end

local function sourceMetadata(photo)
    local shutter = tonumber(photo:getRawMetadata('shutterSpeed'))
    local aperture = tonumber(photo:getRawMetadata('aperture'))
    local iso = tonumber(photo:getRawMetadata('isoSpeedRating'))
    local captureTime = tonumber(photo:getRawMetadata('dateTimeOriginal'))
        or tonumber(photo:getRawMetadata('dateTime'))
    if not shutter or shutter <= 0 or not aperture or aperture <= 0
        or not iso or iso <= 0 or not captureTime
    then
        return nil
    end
    local dimensions = photo:getRawMetadata('dimensions') or {}
    return {
        photo = photo,
        path = pathOf(photo),
        folder = LrPathUtils.parent(pathOf(photo)),
        stem = string.upper(stemOf(photo)),
        time = captureTime,
        ev = math.log((aperture * aperture) / shutter) / math.log(2)
            - math.log(iso / 100) / math.log(2),
        camera = tostring(photo:getFormattedMetadata('cameraModel') or ''),
        focal = tonumber(photo:getRawMetadata('focalLength')) or 0,
        width = tonumber(dimensions.width) or 0,
        height = tonumber(dimensions.height) or 0,
    }
end

local function compatible(a, b)
    if a.folder ~= b.folder or a.camera ~= b.camera
        or a.width ~= b.width or a.height ~= b.height
    then
        return false
    end
    if a.focal == 0 or b.focal == 0 then return a.focal == b.focal end
    return math.abs(a.focal - b.focal) <= math.max(0.5, a.focal * 0.01)
end

local function evSpan(items)
    local low, high = items[1].ev, items[1].ev
    for index = 2, #items do
        low = math.min(low, items[index].ev)
        high = math.max(high, items[index].ev)
    end
    return high - low
end

local function scan(targetPhotos)
    local candidates = {}
    local candidateIds = {}
    local keepNames = {}
    local keepIds = {}
    local recognizedResults = {}
    local acceptedGroups = 0
    local methodCounts = { stack = 0, manifest = 0, metadata = 0 }
    local skipped = {
        notStacked = 0,
        stackNoResult = 0,
        stackTooFewSources = 0,
        manifestIncomplete = 0,
        metadataNoAnchor = 0,
        metadataUnsafe = 0,
        overlap = 0,
    }

    local function acceptGroup(method, results, sources, evidence)
        for _, source in ipairs(sources) do
            if candidateIds[tostring(source.localIdentifier)] then
                skipped.overlap = skipped.overlap + 1
                logEvent('WARN', 'group.accept', 'rejected_overlap', {
                    evidence = evidence,
                    method = method,
                    source = filenameOf(source),
                })
                return false
            end
        end

        acceptedGroups = acceptedGroups + 1
        methodCounts[method] = methodCounts[method] + 1
        local resultNames = {}
        for _, result in ipairs(results) do
            local id = tostring(result.localIdentifier)
            recognizedResults[id] = true
            resultNames[#resultNames + 1] = filenameOf(result)
            if not keepIds[id] then
                keepIds[id] = true
                keepNames[#keepNames + 1] = filenameOf(result)
            end
        end
        local sourceNames = {}
        for _, source in ipairs(sources) do
            local id = tostring(source.localIdentifier)
            candidateIds[id] = true
            candidates[#candidates + 1] = source
            sourceNames[#sourceNames + 1] = filenameOf(source)
        end
        logEvent('INFO', 'group.accept', 'ok', {
            evidence = evidence,
            method = method,
            results = table.concat(resultNames, ','),
            sourceCount = #sources,
            sources = table.concat(sourceNames, ','),
        })
        return true
    end

    -- Evidence 1: genuine Lightroom folder stacks. The result can occupy any
    -- position; older catalogs do not always put it at stack position 1.
    local seenStacks = {}
    for _, selectedPhoto in ipairs(targetPhotos) do
        if not selectedPhoto:getRawMetadata('isInStackInFolder') then
            skipped.notStacked = skipped.notStacked + 1
        else
            local members = selectedPhoto:getRawMetadata('stackInFolderMembers') or {}
            local memberIds = {}
            for _, member in ipairs(members) do
                memberIds[#memberIds + 1] = tostring(member.localIdentifier)
            end
            table.sort(memberIds)
            local stackId = table.concat(memberIds, ',')
            if stackId ~= '' and not seenStacks[stackId] then
                seenStacks[stackId] = true
                local results = {}
                local sources = {}
                for _, member in ipairs(members) do
                    if isLikelyMerged(member) then
                        results[#results + 1] = member
                    elseif isSourcePhoto(member) then
                        sources[#sources + 1] = member
                    end
                end
                if #results == 0 then
                    skipped.stackNoResult = skipped.stackNoResult + 1
                    logEvent('INFO', 'stack.inspect', 'skip_no_result', {
                        memberCount = #members,
                        stackId = stackId,
                    })
                elseif #sources < 2 then
                    skipped.stackTooFewSources = skipped.stackTooFewSources + 1
                    logEvent('INFO', 'stack.inspect', 'skip_too_few_sources', {
                        resultCount = #results,
                        sourceCount = #sources,
                        stackId = stackId,
                    })
                else
                    acceptGroup('stack', results, sources, 'folderStack=' .. stackId)
                end
            end
        end
    end

    local selectedByPath = {}
    local selectedMerged = {}
    local sourceItems = {}
    for _, photo in ipairs(targetPhotos) do
        local path = pathOf(photo)
        if path ~= '' then selectedByPath[normalizePath(path)] = photo end
        if isLikelyMerged(photo) then
            selectedMerged[#selectedMerged + 1] = photo
        elseif isSourcePhoto(photo) then
            local item = sourceMetadata(photo)
            if item then sourceItems[#sourceItems + 1] = item end
        end
    end

    -- Evidence 2: exact DNG-to-source mapping from AutoHDR. v2.1.0 did not
    -- write a separate manifest, so reconstruct its last run from the log.
    local manifest, manifestSource = loadAutoHdrManifest()
    for _, entry in ipairs(manifest) do
        local result = selectedByPath[normalizePath(entry.dng)]
        if result and not recognizedResults[tostring(result.localIdentifier)] then
            local sources = {}
            local missing = {}
            for _, sourcePath in ipairs(entry.sources) do
                local source = selectedByPath[normalizePath(sourcePath)]
                if source and isSourcePhoto(source) then
                    sources[#sources + 1] = source
                else
                    missing[#missing + 1] = LrPathUtils.leafName(sourcePath) or sourcePath
                end
            end
            if #sources >= 2 and #missing == 0 then
                acceptGroup(
                    'manifest',
                    { result },
                    sources,
                    string.format('%sGroup=%d', manifestSource, entry.index)
                )
            else
                skipped.manifestIncomplete = skipped.manifestIncomplete + 1
                logEvent('WARN', 'manifest.match', 'skip_incomplete_selection', {
                    group = entry.index,
                    matchedSources = #sources,
                    missing = table.concat(missing, ','),
                    result = filenameOf(result),
                })
            end
        end
    end

    -- Evidence 3: conservative fallback for other merges. Lightroom's HDR DNG
    -- basename starts with the first source, and its capture time is at the
    -- last source in the merge interval.
    for _, result in ipairs(selectedMerged) do
        local resultId = tostring(result.localIdentifier)
        if not recognizedResults[resultId] then
            local folder = LrPathUtils.parent(pathOf(result))
            local root = mergedRoot(result)
            local resultTime = tonumber(result:getRawMetadata('dateTimeOriginal'))
                or tonumber(result:getRawMetadata('dateTime'))
            local anchor = nil
            for _, item in ipairs(sourceItems) do
                if item.folder == folder and item.stem == root then
                    anchor = item
                    break
                end
            end

            if not anchor or not resultTime then
                skipped.metadataNoAnchor = skipped.metadataNoAnchor + 1
                logEvent('INFO', 'metadata.match', 'skip_no_anchor', {
                    result = filenameOf(result),
                    resultTime = tostring(resultTime),
                    root = root,
                })
            else
                local items = {}
                for _, item in ipairs(sourceItems) do
                    if item.folder == folder and item.time >= anchor.time - 0.05
                        and item.time <= resultTime + 0.05
                    then
                        items[#items + 1] = item
                    end
                end
                table.sort(items, function(a, b) return a.time < b.time end)

                local safe = #items >= 2 and #items <= 50
                if safe and mergedKind(result) == 'hdr' then
                    safe = #items <= 9 and evSpan(items) >= 1.0
                    for _, item in ipairs(items) do
                        if not compatible(anchor, item) then safe = false end
                    end
                end

                if safe then
                    local sources = {}
                    for _, item in ipairs(items) do sources[#sources + 1] = item.photo end
                    acceptGroup(
                        'metadata',
                        { result },
                        sources,
                        string.format('root=%s,timeRange=%.3f', root, resultTime - anchor.time)
                    )
                else
                    skipped.metadataUnsafe = skipped.metadataUnsafe + 1
                    logEvent('WARN', 'metadata.match', 'skip_unsafe', {
                        itemCount = #items,
                        kind = mergedKind(result),
                        result = filenameOf(result),
                        timeRange = resultTime - anchor.time,
                    })
                end
            end
        end
    end

    return candidates, keepNames, acceptedGroups, skipped, methodCounts
end

local function shortKeepList(names)
    local lines = {}
    local shown = math.min(#names, 8)
    for index = 1, shown do lines[#lines + 1] = '  • ' .. names[index] end
    if #names > shown then
        lines[#lines + 1] = string.format('  …另有 %d 个合成结果', #names - shown)
    end
    return table.concat(lines, '\n')
end

local function selectCandidates(catalog, candidates)
    if #candidates == 0 then return false, 0 end
    local expected = {}
    for _, photo in ipairs(candidates) do
        expected[tostring(photo.localIdentifier)] = true
    end
    catalog:setSelectedPhotos(candidates[1], candidates)
    for _ = 1, 25 do
        LrTasks.sleep(0.2)
        local selected = catalog:getTargetPhotos() or {}
        local matches = #selected == #candidates
        if matches then
            for _, photo in ipairs(selected) do
                if not expected[tostring(photo.localIdentifier)] then
                    matches = false
                end
            end
        end
        if matches then return true, #selected end
    end
    return false, #(catalog:getTargetPhotos() or {})
end

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local selected = catalog:getTargetPhotos() or {}
    logEvent('INFO', 'run', 'start', {
        catalog = catalog:getPath(),
        pluginVersion = PLUGIN_VERSION,
        selected = #selected,
    })

    if #selected == 0 then
        logEvent('WARN', 'run', 'abort_no_selection', { durationMs = durationMs(runStarted) })
        LrDialogs.message('合并原片清理助手', '请先选中合成结果及其原片，或一个/多个真实堆栈。', 'info')
        return
    end

    local scanStarted = LrDate.currentTime()
    local candidates, keepNames, groupCount, skipped, methods = scan(selected)
    logEvent('INFO', 'scan', #candidates > 0 and 'candidates_found' or 'no_candidates', {
        candidateCount = #candidates,
        durationMs = durationMs(scanStarted),
        groupCount = groupCount,
        manifestGroups = methods.manifest,
        metadataGroups = methods.metadata,
        stackGroups = methods.stack,
    })

    if #candidates == 0 then
        local detail = string.format(
            '没有找到可安全处理的原片。\n\n当前选择：%d 张\n其中未建立文件夹堆栈：%d 张\n真实堆栈无合成结果：%d 组\n真实堆栈原片少于 2 张：%d 组\nAutoHDR 记录与当前选择不完整：%d 组\n元数据找不到首张原片：%d 个结果\n元数据闭环不安全：%d 个结果\n\n请同时选中 HDR DNG 和它对应的全部 RAW 原片；批量处理时先 Ctrl+A 全选当前复核收藏集。\n\n日志：%s',
            #selected,
            skipped.notStacked,
            skipped.stackNoResult,
            skipped.stackTooFewSources,
            skipped.manifestIncomplete,
            skipped.metadataNoAnchor,
            skipped.metadataUnsafe,
            LOG_PATH
        )
        logEvent('INFO', 'run', 'done_no_candidates', { durationMs = durationMs(runStarted) })
        LrDialogs.message('扫描完成', detail, 'info')
        return
    end

    local message = string.format(
        '识别到 %d 组、%d 张候选原片。\n\n证据来源：真实堆栈 %d 组；AutoHDR 精确记录 %d 组；元数据兜底 %d 组。\n\n将保留：\n%s\n\n下一步只创建“待删除”收藏集，不会立即删除文件。是否继续？',
        groupCount,
        #candidates,
        methods.stack,
        methods.manifest,
        methods.metadata,
        shortKeepList(keepNames)
    )
    if LrDialogs.confirm('请复核扫描结果', message, '创建待删除收藏集', '取消') ~= 'ok' then
        logEvent('INFO', 'run', 'user_canceled_review', { durationMs = durationMs(runStarted) })
        return
    end

    local timestamp = LrDate.timeToUserFormat(LrDate.currentTime(), '%Y-%m-%d %H%M%S')
    local collectionName = '待删除原片 ' .. timestamp
    local createdCollection
    local writeStarted = LrDate.currentTime()
    logEvent('INFO', 'collection.create', 'start', {
        candidateCount = #candidates,
        collection = collectionName,
    })
    local status, err = catalog:withWriteAccessDo('创建合并原片待删除收藏集', function()
        local collectionSet = catalog:createCollectionSet(COLLECTION_SET_NAME, nil, true)
        createdCollection = catalog:createCollection(collectionName, collectionSet, false)
        createdCollection:addPhotos(candidates)
    end)
    logEvent(status == 'executed' and 'INFO' or 'ERROR', 'collection.create', tostring(status), {
        durationMs = durationMs(writeStarted),
        error = err,
    })

    if status ~= 'executed' then
        logEvent('ERROR', 'run', 'failed_collection', { durationMs = durationMs(runStarted), error = err })
        LrDialogs.message('创建失败', tostring(err or status) .. '\n\n日志：' .. LOG_PATH, 'critical')
        return
    end

    catalog:setActiveSources({ createdCollection })
    LrTasks.sleep(0.5)
    local selectionOk, selectedCount = selectCandidates(catalog, candidates)
    logEvent(selectionOk and 'INFO' or 'WARN', 'selection.prepare_delete', selectionOk and 'ok' or 'mismatch', {
        actual = selectedCount,
        expected = #candidates,
    })
    logEvent('INFO', 'run', 'done', {
        candidates = #candidates,
        durationMs = durationMs(runStarted),
        groups = groupCount,
        selectionOk = selectionOk,
    })

    LrDialogs.message(
        '待删除原片已准备好',
        string.format(
            '已打开“%s”，其中有 %d 张候选原片。%s\n\n请先复核缩略图；确认无误后按：\nCtrl+Alt+Shift+Backspace\n\n注意是 Backspace（退格键），不是 Del/Delete。然后在 Lightroom 确认框中选择“从磁盘删除”，文件会进入 Windows 回收站。\n\n日志：%s',
            collectionName,
            #candidates,
            selectionOk and '\n候选原片已全部选中。' or '\n自动全选未成功，请先按 Ctrl+A。',
            LOG_PATH
        ),
        'warning'
    )
end)
