-- ===============================
-- CONFIG
-- ===============================

local replacementNoteType = 'Black Onslaught Note'
local replaceChance = 0.05

-- ===============================
-- TOGGLE (LINE 6)
-- ===============================

local blackOnslaughtNoteRandomEnabled = false

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function loadToggle()
    local text = getTextFromFile('scripts/noteRandomToggle.txt')
    if not text then return end

    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, trim(line:lower()))
    end

    if lines[6] == "blackonslaughtnoterandom: true" then
        blackOnslaughtNoteRandomEnabled = true
    end
end

-- ===============================
-- LOGIC
-- ===============================

function onCreatePost()
    loadToggle()
	--debugPrint("Black Onslaught enabled = " .. tostring(blackOnslaughtNoteRandomEnabled))
    if not blackOnslaughtNoteRandomEnabled then return end

    math.randomseed(os.time())
    local notesLength = getProperty('unspawnNotes.length')

    for i = 0, notesLength - 1 do
        local noteType = getPropertyFromGroup('unspawnNotes', i, 'noteType')
        local isSustain = getPropertyFromGroup('unspawnNotes', i, 'isSustainNote')
        local mustPress = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
        local data = getPropertyFromGroup('unspawnNotes', i, 'noteData')
        local time = getPropertyFromGroup('unspawnNotes', i, 'strumTime')

        if mustPress and noteType == '' and not isSustain then
            local hasSustain = false

            for j = i + 1, notesLength - 1 do
                local nextTime = getPropertyFromGroup('unspawnNotes', j, 'strumTime')
                local nextData = getPropertyFromGroup('unspawnNotes', j, 'noteData')
                local nextPress = getPropertyFromGroup('unspawnNotes', j, 'mustPress')
                local nextSustain = getPropertyFromGroup('unspawnNotes', j, 'isSustainNote')

                if nextTime - time > 500 then break end
                if nextPress and nextSustain and nextData == data then
                    hasSustain = true
                    break
                end
            end

            if not hasSustain and math.random() < replaceChance then
                setPropertyFromGroup('unspawnNotes', i, 'noteType', replacementNoteType)
            end
        end
    end
end
