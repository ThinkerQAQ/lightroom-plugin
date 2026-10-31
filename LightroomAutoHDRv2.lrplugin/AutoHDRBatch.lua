local LrApplication = import 'LrApplication'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'

local MAX_GAP_SECONDS = 2.0
local MIN_EV_SPAN = 1.0
local MIN_GROUP_SIZE = 2
local MAX_GROUP_SIZE = 9
local SELECTION_TIMEOUT_SECONDS = 5.0
local DNG_TIMEOUT_SECONDS = 180.0
local POLL_SECONDS = 0.5

local logger = LrLogger('LightroomAutoHDRv2')
logger:enable('logfile')
local logPath = LrPathUtils.child(_PLUGIN.path, 'AutoHDR-v2.log')
local manifestPath = LrPathUtils.child(_PLUGIN.path, 'AutoHDR-v2-last-run.tsv')

local function log(message, ...)
    local text = select('#', ...) > 0 and string.format(message, ...) or tostring(message)
    logger:trace(text)
    local file = io.open(logPath, 'a')
    if file then
        file:write(os.date('%Y-%m-%dT%H:%M:%S'), ' ', text, '\n')
        file:close()
    end
end

local function resetManifest()
    local file = io.open(manifestPath, 'w')
    if not file then
        log('MANIFEST_RESET status=failed path=%s', manifestPath)
        return false
    end
    file:write('# AutoHDR v2 exact DNG-to-source mapping\n')
    file:close()
    log('MANIFEST_RESET status=ok path=%s', manifestPath)
    return true
end

local function appendManifest(index, dngPath, group)
    local file = io.open(manifestPath, 'a')
    if not file then
        log('MANIFEST_APPEND status=failed index=%d dng=%s', index, dngPath)
        return false
    end
    for _, item in ipairs(group) do
        file:write(tostring(index), '\t', dngPath, '\t', item.path, '\n')
    end
    file:close()
    log('MANIFEST_APPEND status=ok index=%d dng=%s sources=%d', index, dngPath, #group)
    return true
end

local function log2(value)
    return math.log(value) / math.log(2)
end

local function filenameOf(photo)
    local path = photo:getRawMetadata('path') or ''
    return LrPathUtils.leafName(path) or path
end

local function isRawSource(photo)
    if photo:getRawMetadata('isVirtualCopy') or photo:getRawMetadata('isVideo') then
        return false
    end
    local format = string.upper(photo:getRawMetadata('fileFormat') or '')
    if format ~= 'RAW' and format ~= 'DNG' then
        return false
    end
    local name = string.upper(filenameOf(photo))
    return not name:find('%-HDR')
        and not name:find('_HDR')
        and not name:find('%-PANO')
        and not name:find('_PANO')
        and not name:find('%-PANORAMA')
        and not name:find('_PANORAMA')
end

local function metadataFor(photo)
    local path = photo:getRawMetadata('path') or ''
    local shutter = tonumber(photo:getRawMetadata('shutterSpeed'))
    local aperture = tonumber(photo:getRawMetadata('aperture'))
    local iso = tonumber(photo:getRawMetadata('isoSpeedRating'))
    local captureTime = tonumber(photo:getRawMetadata('dateTimeOriginal'))
        or tonumber(photo:getRawMetadata('dateTime'))
    if path == '' or not shutter or shutter <= 0 or not aperture or aperture <= 0
        or not iso or iso <= 0 or not captureTime
    then
        return nil
    end

    local dimensions = photo:getRawMetadata('dimensions') or {}
    local camera = photo:getFormattedMetadata('cameraModel') or ''
    local focal = tonumber(photo:getRawMetadata('focalLength')) or 0
    local ev = log2((aperture * aperture) / shutter) - log2(iso / 100)

    return {
        photo = photo,
        path = path,
        folder = LrPathUtils.parent(path),
        name = LrPathUtils.leafName(path) or path,
        time = captureTime,
        ev = ev,
        camera = tostring(camera),
        focal = focal,
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
    if a.focal == 0 or b.focal == 0 then
        return a.focal == b.focal
    end
    return math.abs(a.focal - b.focal) <= math.max(0.5, a.focal * 0.01)
end

local function evSpan(items)
    local low, high = items[1].ev, items[1].ev
    for i = 2, #items do
        low = math.min(low, items[i].ev)
        high = math.max(high, items[i].ev)
    end
    return high - low
end

local function hasDistinctExposures(items)
    for i = 2, #items do
        if math.abs(items[i].ev - items[1].ev) >= 0.45 then
            return true
        end
    end
    return false
end

local function isValidGroup(items)
    return #items >= MIN_GROUP_SIZE
        and #items <= MAX_GROUP_SIZE
        and hasDistinctExposures(items)
        and evSpan(items) >= MIN_EV_SPAN
end

local function appendValid(groups, items)
    if isValidGroup(items) then
        groups[#groups + 1] = items
    end
end

local function splitRun(groups, run)
    if #run <= MAX_GROUP_SIZE then
        appendValid(groups, run)
        return
    end

    local current = {}
    for _, item in ipairs(run) do
        local repeatsStart = #current >= MIN_GROUP_SIZE
            and math.abs(item.ev - current[1].ev) <= 0.35
            and isValidGroup(current)
        if repeatsStart then
            appendValid(groups, current)
            current = {}
        end
        current[#current + 1] = item
    end
    appendValid(groups, current)
end

local function detectGroups(photos)
    local items = {}
    local skippedMetadata = 0
    local skippedNotRaw = 0
    for _, photo in ipairs(photos) do
        if isRawSource(photo) then
            local item = metadataFor(photo)
            if item then
                items[#items + 1] = item
            else
                skippedMetadata = skippedMetadata + 1
            end
        else
            skippedNotRaw = skippedNotRaw + 1
        end
    end

    table.sort(items, function(a, b)
        if a.time == b.time then
            return a.name < b.name
        end
        return a.time < b.time
    end)

    local groups = {}
    local run = {}
    for _, item in ipairs(items) do
        local previous = run[#run]
        local shouldBreak = previous and (
            item.time - previous.time > MAX_GAP_SECONDS
            or item.time < previous.time
            or not compatible(previous, item)
        )
        if shouldBreak then
            splitRun(groups, run)
            run = {}
        end
        run[#run + 1] = item
    end
    if #run > 0 then
        splitRun(groups, run)
    end

    return groups, skippedMetadata, skippedNotRaw
end

local function groupSummary(groups)
    local lines = {}
    local photoCount = 0
    local shown = math.min(#groups, 10)
    for _, group in ipairs(groups) do
        photoCount = photoCount + #group
    end
    for i = 1, shown do
        local group = groups[i]
        lines[#lines + 1] = string.format(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text013=%d. %d photos, %.1f EV: %s ... %s',
            i,
            #group,
            evSpan(group),
            group[1].name,
            group[#group].name
        )
    end
    if #groups > shown then
        lines[#lines + 1] = string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text014=...and %d more groups', #groups - shown)
    end
    return photoCount, table.concat(lines, '\n')
end

local function groupDetails(group)
    local parts = {}
    for _, item in ipairs(group) do
        parts[#parts + 1] = string.format('%s(EV=%.3f,t=%.3f)', item.name, item.ev, item.time)
    end
    return table.concat(parts, ', ')
end

local function selectionMatches(catalog, group)
    local selected = catalog:getTargetPhotos() or {}
    if #selected ~= #group then
        return false
    end
    local expected = {}
    for _, item in ipairs(group) do
        expected[tostring(item.photo.localIdentifier)] = true
    end
    for _, photo in ipairs(selected) do
        if not expected[tostring(photo.localIdentifier)] then
            return false
        end
    end
    return true
end

local function selectionNames(catalog)
    local names = {}
    for _, photo in ipairs(catalog:getTargetPhotos() or {}) do
        names[#names + 1] = filenameOf(photo)
    end
    return table.concat(names, ', ')
end

local function selectGroupAndWait(catalog, group)
    if selectionMatches(catalog, group) then
        return true
    end

    local photos = {}
    for _, item in ipairs(group) do
        photos[#photos + 1] = item.photo
    end
    catalog:setSelectedPhotos(group[1].photo, photos)

    local started = LrDate.currentTime()
    while LrDate.currentTime() - started < SELECTION_TIMEOUT_SECONDS do
        LrTasks.sleep(0.2)
        if selectionMatches(catalog, group) then
            return true
        end
    end
    return false
end

local function dngSnapshot(folder)
    local result = {}
    local count = 0
    for path in LrFileUtils.files(folder) do
        if string.lower(path):match('%.dng$') then
            result[string.lower(path)] = true
            count = count + 1
        end
    end
    return result, count
end

local function findNewDng(folder, before)
    local found = nil
    for path in LrFileUtils.files(folder) do
        if not found and string.lower(path):match('%.dng$')
            and not before[string.lower(path)]
        then
            found = path
        end
    end
    return found
end

local function waitForNewDng(folder, before, progress, index, total)
    local started = LrDate.currentTime()
    while LrDate.currentTime() - started < DNG_TIMEOUT_SECONDS do
        if progress:isCanceled() then
            return nil, 'canceled', LrDate.currentTime() - started
        end
        local elapsed = LrDate.currentTime() - started
        progress:setCaption(string.format(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text015=Group %d/%d: waiting for DNG (%.0f s)',
            index,
            total,
            elapsed
        ))
        local path = findNewDng(folder, before)
        if path then
            return path, nil, elapsed
        end
        LrTasks.sleep(POLL_SECONDS)
    end
    return nil, 'timeout', LrDate.currentTime() - started
end

local function helperExitReason(exitCode)
    if exitCode == 20 then
        return LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text016=Lightroom process not found'
    elseif exitCode == 22 then
        return LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text017=Lightroom is not the foreground window'
    elseif exitCode == 23 then
        return LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text018=Windows SendInput did not send the full shortcut'
    end
    return LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text019=Windows helper encountered another error'
end

local function main()
    local catalog = LrApplication.activeCatalog()
    local selected = catalog:getTargetPhotos() or {}
    log('RUN_START plugin=2.1.2 selected=%d catalog=%s', #selected, tostring(catalog:getPath()))

    if #selected < 2 then
        log('RUN_ABORT reason=too_few_selected')
        LrDialogs.message(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text020=Automatic Bracketed HDR v2.1.2', LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text021=Select at least two RAW/DNG photos to scan.', 'info')
        return
    end

    local groups, skippedMetadata, skippedNotRaw = detectGroups(selected)
    log(
        'DETECT_DONE groups=%d skippedMetadata=%d skippedNotRaw=%d',
        #groups,
        skippedMetadata,
        skippedNotRaw
    )
    for index, group in ipairs(groups) do
        log(
            'GROUP_PLAN index=%d count=%d spanEV=%.3f folder=%s items=%s',
            index,
            #group,
            evSpan(group),
            tostring(group[1].folder),
            groupDetails(group)
        )
    end

    if #groups == 0 then
        log('RUN_ABORT reason=no_groups')
        LrDialogs.message(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text022=No bracketed groups found',
            string.format(
                LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text023=Requirements: same folder, camera, focal length, and dimensions; at most %.1f seconds between adjacent shots; at least %.1f EV exposure span; %d-%d photos per group.^n^nIncomplete metadata: %d; non-source RAW/DNG: %d.^n^nLog: %s',
                MAX_GAP_SECONDS,
                MIN_EV_SPAN,
                MIN_GROUP_SIZE,
                MAX_GROUP_SIZE,
                skippedMetadata,
                skippedNotRaw,
                logPath
            ),
            'info'
        )
        return
    end

    local photoCount, summary = groupSummary(groups)
    local confirmation = string.format(
        LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text024=Found %d groups containing %d source photos:^n^n%s^n^nFor each group: select photos -> Ctrl+Shift+H -> wait for a new DNG. Maximum wait: %.0f seconds per group.^n^nFinish other Lightroom import, export, and HDR tasks first. Keep Lightroom in the foreground and do not use the keyboard or mouse while this runs. Source photos are not deleted.',
        #groups,
        photoCount,
        summary,
        DNG_TIMEOUT_SECONDS
    )
    if LrDialogs.confirm(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text025=Detect and merge bracketed HDR DNGs v2.1.2', confirmation, LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text026=Start merge', LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text006=Cancel') ~= 'ok' then
        log('RUN_ABORT reason=user_canceled_confirmation')
        return
    end

    resetManifest()
    LrTasks.sleep(0.5)
    local helper = LrPathUtils.child(_PLUGIN.path, 'AutoHDRInput.exe')
    local progress = LrProgressScope({ title = LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text020=Automatic Bracketed HDR v2.1.2' })
    progress:setCancelable(true)
    local submitted = 0
    local completed = 0
    local failure = nil

    for index, group in ipairs(groups) do
        if progress:isCanceled() then
            failure = LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text027=Canceled by user'
            log('RUN_STOP index=%d reason=user_canceled_before_group', index)
            break
        end

        progress:setPortionComplete(index - 1, #groups)
        progress:setCaption(string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text028=Group %d/%d: selecting %s', index, #groups, group[1].name))
        log('GROUP_START index=%d count=%d first=%s last=%s', index, #group, group[1].name, group[#group].name)

        if not selectGroupAndWait(catalog, group) then
            failure = string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text029=Could not select photos for group %d', index)
            log('GROUP_FAIL index=%d stage=selection actual=%s', index, selectionNames(catalog))
            break
        end
        log('GROUP_SELECTION_OK index=%d selected=%s', index, selectionNames(catalog))

        local before, baselineCount = dngSnapshot(group[1].folder)
        log('GROUP_DNG_BASELINE index=%d folder=%s count=%d', index, group[1].folder, baselineCount)
        progress:setCaption(string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text030=Group %d/%d: submitting Lightroom HDR', index, #groups))

        LrTasks.sleep(0.3)
        local helperStarted = LrDate.currentTime()
        local exitCode = LrTasks.execute(helper)
        local helperElapsed = LrDate.currentTime() - helperStarted
        log('GROUP_HELPER_DONE index=%d exitCode=%s elapsed=%.3f', index, tostring(exitCode), helperElapsed)
        if exitCode ~= 0 then
            failure = string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text031=Group %d helper returned %s: %s', index, tostring(exitCode), helperExitReason(exitCode))
            log('GROUP_FAIL index=%d stage=helper exitCode=%s reason=%s', index, tostring(exitCode), helperExitReason(exitCode))
            break
        end
        submitted = submitted + 1

        local dngPath, waitError, waitElapsed = waitForNewDng(group[1].folder, before, progress, index, #groups)
        if not dngPath then
            if waitError == 'canceled' then
                failure = string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text032=Canceled while waiting for group %d DNG', index)
            else
                failure = string.format(LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text033=Group %d DNG wait exceeded %.0f seconds', index, waitElapsed)
            end
            log('GROUP_FAIL index=%d stage=wait_dng reason=%s elapsed=%.3f', index, tostring(waitError), waitElapsed)
            break
        end

        completed = completed + 1
        appendManifest(index, dngPath, group)
        log('GROUP_COMPLETE index=%d dng=%s elapsed=%.3f', index, dngPath, waitElapsed)
        progress:setPortionComplete(index, #groups)
        LrTasks.sleep(0.8)
    end

    progress:done()
    log(
        'RUN_DONE detected=%d submitted=%d completed=%d failure=%s',
        #groups,
        submitted,
        completed,
        tostring(failure)
    )

    if completed == #groups then
        LrDialogs.message(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text034=HDR batch complete',
            string.format(
                LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text035=Completed %d/%d groups and detected their new DNG files on disk.^n^nSource photos were not deleted.^nLog: %s',
                completed,
                #groups,
                logPath
            ),
            'info'
        )
    else
        LrDialogs.message(
            LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text036=HDR batch stopped',
            string.format(
                LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text037=%s^n^nSubmitted %d/%d groups; detected new DNGs for %d/%d groups. No further groups were submitted.^n^nCheck the logs:^n%s^n%s',
                tostring(failure or LOC '$$$/ThinkerQAQ/LightroomAutoHDRv2/Text038=Unknown reason'),
                submitted,
                #groups,
                completed,
                #groups,
                logPath,
                LrPathUtils.child(_PLUGIN.path, 'AutoHDRInput.log')
            ),
            'critical'
        )
    end
end

LrTasks.startAsyncTask(main)
