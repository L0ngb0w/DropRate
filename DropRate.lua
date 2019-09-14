local DropRate_DEBUG = false;
local DropRate_UNIQUE_UNIT_TIMEOUT = 60*60;

local DropRate_DEFAULT_SETTINGS = {
    per_zone = true,
    minimum_quality = 1
};

local DropRate_Color = {};

DropRate_DebugPrint = function(...)
    if DropRate_DEBUG then
        print(...)
    end
end

DropRate_PrintUnits = function(indentation, units)
    for name,unit in pairs(units) do
        local unit_count = unit['count'];

        print(indentation..'"'..name..'" looted '..unit_count..' times');

        for name,item in pairs(unit['items']) do
            local item_count = item['count'];
            local quantity = item['quantity'];
            local rate = (item_count / unit_count) * 100;

            print(indentation..'  "'..name..'" dropped '..item_count..' times: '..rate..'%');
        end
    end
end

DropRate_PrintUnitTable = function()
    if DropRate_UnitTable == nil then
        print('DropRate: Unit table not initialized');
        return;
    end

    if next(DropRate_UnitTable) == nil then
        print('No looting have been observed');
        return;
    end

    if DropRate_Settings['per_zone'] then
        for zone,units in pairs(DropRate_UnitTable) do
            print('In "'..zone..'"');
            DropRate_PrintUnits('  ', units);
        end
    else
        DropRate_PrintUnits('', DropRate_UnitTable);
    end
end

DropRate_RegisterItem = function(item, quantity, quality)
    if item == nil then
        item = {
            count = 0,
            quantity = 0,
            quality = quality
        };
    end

    item['count'] = item['count'] + 1;
    item['quantity'] = item['quantity'] + quantity;

    return item;
end

DropRate_RegisterItems = function(items)
    if items == nil then
        items = {}
    end

    for i = 1, GetNumLootItems() do
        if LootSlotHasItem(i) then
            local texture, item, quantity, currencyID, quality, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i);

            -- Detect coins and skip them
            local result = string.find(item, '^%d+');
            if not result then
                items[item] = DropRate_RegisterItem(items[item], quantity, quality)
            else
                DropRate_DebugPrint('Item "'..item..'" appears to be coins');
            end
        end
    end

    return items;
end

DropRate_RegisterUnit = function(unit)
    if unit == nil then
        unit = {
            count = 0
        }
    end

    unit['count'] = unit['count'] + 1
    unit['items'] = DropRate_RegisterItems(unit['items']);

    return unit;
end

DropRate_RegisterZone = function(zone, target)
    if zone == nil then
        zone = {}
    end

    zone[target] = DropRate_RegisterUnit(zone[target]);

    return zone;
end

DropRate_OnLootOpened = function(self, event, ...)
    DropRate_DebugPrint('DropRate_OnLootOpened');

    if DropRate_UnitTable == nil then
        print('DropRate: Unit table not initialized');
        return;
    end

    if not UnitIsDead('target') then
        DropRate_DebugPrint('Targeted unit does not appear to be dead!');
        return
    end

    local guid = UnitGUID('target');
    if guid == nil then
        print('DropRate: Could not get unit GUID');
        return;
    end

    if DropRate_UniqueUnitTable[guid] == nil then
        DropRate_UniqueUnitTable[guid] = time();
    else
        DropRate_DebugPrint('Unit already registered');
        return;
    end

    local target = UnitName('target');

    if DropRate_Settings['per_zone'] then
        local zone = GetRealZoneText();
        DropRate_UnitTable[zone] = DropRate_RegisterZone(DropRate_UnitTable[zone], target);
    else
        DropRate_UnitTable[target] = DropRate_RegisterUnit(DropRate_UnitTable[target]);
    end
end

DropRate_HookLootFrame = function()
    DropRate_DebugPrint('Hooking LootFrame');
    local loot_frame = getglobal('LootFrame');
    if loot_frame then
        local old_script = loot_frame:GetScript('OnEvent');
        if old_script then
            loot_frame:HookScript('OnEvent', function(...)
                local self, event = ...
                if event == 'LOOT_OPENED' then
                    DropRate_OnLootOpened(...)
                end

                old_script(...);
            end);
        else
            print('DropRate: No LootFrame:OnEvent script found');
        end
    else
        print('DropRate: No LootFrame found')
    end
end

DropRate_QueryUnitTable = function(unit)
    if DropRate_Settings['per_zone'] then
        local name = GetRealZoneText();
        local zone = DropRate_UnitTable[name];

        if zone then
            return zone[unit];
        end

        return nil
    end

    return DropRate_UnitTable[unit];
end

DropRate_GetTooltipLines = function(unit)
    local minimum_quality = DropRate_Settings['minimum_quality'];
    local lines = {}

    local unit_count = unit['count'];
    local found = false;
    for name,item in pairs(unit['items']) do
        local quality = item['quality'];
        if not quality then
            quality = 1
        end

        if minimum_quality <= quality then
            local item_count = item['count'];
            local rate = (item_count / unit_count) * 100;
            local percentage = string.format('%.2f', rate)..'%';

            table.insert(lines, {quality = quality, name = name, count = item_count, percentage = percentage});
            found = true;
        end
    end

    if found then
        return lines;
    else
        return nil;
    end
end

DropRate_SortTooltipLines = function(lines)
    table.sort(lines, function(a, b)
        local a_quality = a['quality'];
        local b_quality = b['quality'];
        if a_quality > b_quality then
            return true;
        elseif a_quality < b_quality then
            return false;
        end

        local a_count = a['count'];
        local b_count = b['count'];
        if a_count > b_count then
            return true;
        elseif a_count < b_count then
            return false;
        end

        return a['name'] < b['name'];
    end);
end

DropRate_DebugPrint('In DropRate!');
local DropRate_Frame = CreateFrame('Frame');
DropRate_Frame:RegisterEvent('ADDON_LOADED');

-- Cache item colors
for i = 0, 7 do
    local r, g, b = GetItemQualityColor(i);
    DropRate_Color[i] = {r, g, b};
end

DropRate_Frame:SetScript('OnEvent', function(self, event, arg1, arg2)
    if event == 'ADDON_LOADED' and arg1 == 'DropRate' then
        DropRate_DebugPrint('DropRate loaded');

        if DropRate_Settings == nil then
            DropRate_DebugPrint('Creating persisted table DropRate_Settings');
            DropRate_Settings = DropRate_DEFAULT_SETTINGS;
        end

        if DropRate_UnitTable == nil then
            DropRate_DebugPrint('Creating persisted table DropRate_UnitTable');
            DropRate_UnitTable = {
                version = 1
            };
        else
            -- Check version and upgrade
        end

        if DropRate_UniqueUnitTable == nil then
            DropRate_DebugPrint('Creating persisted table DropRate_UniqueUnitTable');
            DropRate_UniqueUnitTable = {};
        else
            -- Clean up old entries
            local current = time();
            for guid,timestamp in pairs(DropRate_UniqueUnitTable) do
                if current - timestamp >= DropRate_UNIQUE_UNIT_TIMEOUT then
                    DropRate_DebugPrint('purging ' .. guid);
                    DropRate_UniqueUnitTable[guid] = nil;
                end
            end
        end

        -- Hook the LootFrame so we are sure to execute before the player can take loot from it
        DropRate_HookLootFrame();
    end
end)

GameTooltip:HookScript("OnTooltipSetUnit", function(tt)
    local target = tt:GetUnit();
    local unit = DropRate_QueryUnitTable(target)

    if unit then
        local lines = DropRate_GetTooltipLines(unit);

        if lines then
            tt:AddLine('Drops');

            DropRate_SortTooltipLines(lines);
            
            for i, line in ipairs(lines) do
                local color = DropRate_Color[line['quality']];
                tt:AddDoubleLine(line['name'], line['percentage'], color[1], color[2], color[3], 1, 1, 1);
            end
        end
    end

    tt:Show();
end);

SLASH_DropRate_PrintUnitTable1 = "/droprate_print";
function SlashCmdList.DropRate_PrintUnitTable(msg)
    DropRate_PrintUnitTable();
end

SLASH_DropRate_Clear1 = "/droprate_clear";
function SlashCmdList.DropRate_Clear(msg)
    print('DropRate: Clearing tables');
    DropRate_UnitTable = { verson = 1 };
    DropRate_UniqueUnitTable = {};
end

SLASH_DropRate_ResetSettings1 = "/droprate_resetsettings";
function SlashCmdList.DropRate_ResetSettings(msg)
    print('DropRate: Resetting settings');
    DropRate_Settings = DropRate_DEFAULT_SETTINGS;
end

SLASH_DropRate_DebugToggle1 = "/droprate_debugtoggle";
function SlashCmdList.DropRate_DebugToggle(msg)
    print('DropRate: toggling debug print');
    DropRate_DEBUG = not DropRate_DEBUG;
end
