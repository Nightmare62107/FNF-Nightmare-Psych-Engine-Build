-- ===============================
-- CONFIG
-- ===============================

local replacementNoteType = 'Orange Bones Note'
local replaceChance = 0.05

-- ===============================
-- TOGGLE (LINE 7)
-- ===============================

local orangeBonesNoteRandomEnabled = false

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

    if lines[7] == "orangebonesnoterandom: true" then
        orangeBonesNoteRandomEnabled = true
    end
end

-- ===============================
-- LOGIC
-- ===============================

function onCreatePost()
    loadToggle()
	--debugPrint("Orange Bones enabled = " .. tostring(orangeBonesNoteRandomEnabled))
    if not orangeBonesNoteRandomEnabled then return end

    math.randomseed(os.time())
    local notesLength = getProperty('unspawnNotes.length')

    for i = 0, notesLength - 1 do
        local noteType = getPropertyFromGroup('unspawnNotes', i, 'noteType')
        local isSustain = getPropertyFromGroup('unspawnNotes', i, 'isSustainNote')
        local mustPress = getPropertyFromGroup('unspawnNotes', i, 'mustPress')

        if mustPress and noteType == '' and not isSustain then
            if math.random() < replaceChance then
                setPropertyFromGroup('unspawnNotes', i, 'noteType', replacementNoteType)

                local curTime = getPropertyFromGroup('unspawnNotes', i, 'strumTime')
                local data = getPropertyFromGroup('unspawnNotes', i, 'noteData')

                for j = i + 1, notesLength - 1 do
                    local nextTime = getPropertyFromGroup('unspawnNotes', j, 'strumTime')
                    local nextData = getPropertyFromGroup('unspawnNotes', j, 'noteData')
                    local nextPress = getPropertyFromGroup('unspawnNotes', j, 'mustPress')
                    local nextSustain = getPropertyFromGroup('unspawnNotes', j, 'isSustainNote')

                    if nextTime - curTime > 500 then break end
                    if nextPress and nextSustain and nextData == data then
                        setPropertyFromGroup('unspawnNotes', j, 'noteType', replacementNoteType)
                    end
                end
            end
        end
    end
end
