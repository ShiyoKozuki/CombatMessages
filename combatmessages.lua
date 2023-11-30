addon.name      = 'Combat messages';
addon.author    = 'Shiyo';
addon.version   = '1.0.0.0';
addon.desc      = 'Shows messages related to the enemies combat state.';
addon.link      = 'https://github.com/ShiyoKozuki';

require('common');
require ('combatmessagelibs')
local fonts = require('fonts');
local settings = require('settings');
local textDuration = 0
local monsterIndex
local tpId
local tpString
local monsterId
local monsterName
local spellId
local tpName

local windowWidth = AshitaCore:GetConfigurationManager():GetFloat('boot', 'ffxi.registry', '0001', 1024);
local windowHeight = AshitaCore:GetConfigurationManager():GetFloat('boot', 'ffxi.registry', '0002', 768);

local default_settings = T{
	font = T{
        visible = true,
        font_family = 'Arial',
        font_height = 18,
        color = 0xFFFFFFFF,
        position_x = 785,
        position_y = 470,
		background = T{
            visible = true,
            color = 0x80000000,
		}
    }
};

local function CheckString(string)
    if (string ~= nil) then
        textDuration = os.time() + 5 -- Only display text for 5 seconds
    end
end

local cmsg = T{
	settings = settings.load(default_settings)
};

local UpdateSettings = function(settings)
    cmsg.settings = settings;
    if (cmsg.font ~= nil) then
        cmsg.font:apply(cmsg.settings.font)
    end
end


ashita.events.register('load', 'load_cb', function ()
    cmsg.font = fonts.new(cmsg.settings.font);
    settings.register('settings', 'settingchange', UpdateSettings);
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    local myTarget = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
    -- Packet: Action
    if (e.id == 0x028) then
        local actionPacket = ParseActionPacket(e);
        if (actionPacket.Type == 7) and IsMonster(actionPacket.UserIndex) and (myTarget == actionPacket.UserIndex) then -- Mobskill Start
            local actionMessage = actionPacket.Targets[1].Actions[1].Message
            monsterId = struct.unpack('L', e.data, 0x05 + 0x01);
            monsterIndex = bit.band(monsterId, 0x7FF);
            tpId = ashita.bits.unpack_be(e.data:totable(), 0, 213, 17);
            textDuration = 0
            spellString = nil
            if (tpId < 256) then
                tpName = AshitaCore:GetResourceManager():GetAbilityById(tpId)
                tpString = ' readies ' .. tpName.Name[1]
            else
                local tempName = AshitaCore:GetResourceManager():GetString('monsters.abilities', tpId - 256);
                if (tempName ~= nil) then
                    tpName = tempName;
                    tpString = ' readies ' .. tpName
                end
            end
            monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
            CheckString(tpString)
            if (actionMessage == 0) then -- Mob Skill interrupted
                -- print('Enemy mob ability interrupted!!');
                monsterId = struct.unpack('L', e.data, 0x05 + 0x01);
                monsterIndex = bit.band(monsterId, 0x7FF);
                tpId = 0
                tpString = '\'s TP move interrupted!!!'
                monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
                CheckString(tpString)
            end
        end
        if (actionPacket.Type == 8) and IsMonster(actionPacket.UserIndex) and (myTarget == actionPacket.UserIndex) then  -- Magic start
            local actionMessage = actionPacket.Targets[1].Actions[1].Message
            monsterId = struct.unpack('L', e.data, 0x05 + 0x01);
            monsterIndex = bit.band(monsterId, 0x7FF);
            spellId = actionPacket.Targets[1].Actions[1].Param
            textDuration = 0
            tpString = nil
            local spellResource = AshitaCore:GetResourceManager():GetSpellById(spellId);
            if spellResource then
                -- print(string.format('Enemy started casting %s.', spellResource.Name[1]));
                if (spellResource.Name[1] ~= nil) then
                    spellString = ' casting ' .. spellResource.Name[1]
                end
                monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
                -- print(string.format('monsterName: %s', monsterName));
                CheckString(spellString)
            end
            if (actionMessage == 0) then -- Magic Interrupted
                -- print('Enemy spell interrupted!!');
                spellString = '\'s spell interrupted!!!'
                monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
                CheckString(spellString)
           end
        end
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()

    local fontObject = cmsg.font;
    if (fontObject.position_x > windowWidth) then
      fontObject.position_x = 0;
    end
    if (fontObject.position_y > windowHeight) then
      fontObject.position_y = 0;
    end
    if (fontObject.position_x ~= cmsg.settings.font.position_x) or (fontObject.position_y ~= cmsg.settings.font.position_y) then
        cmsg.settings.font.position_x = fontObject.position_x;
        cmsg.settings.font.position_y = fontObject.position_y;
        settings.save()
    end

    if (os.time() > textDuration ) then
        -- Hide text, reset variables to nil
        cmsg.font.visible = false;
        monsterIndex = nil
        tpId = nil
        tpString = nil
        monsterName = nil
        spellId = nil
        return;
    end
	if monsterName then
        if tpString and (tpId ~= nil) then
            cmsg.font.text = ('%s%s'):fmt(monsterName, tpString);
            cmsg.font.visible = true;
        elseif monsterName and (spellId ~= nil) then
            cmsg.font.text = ('%s%s'):fmt(monsterName, spellString);
            cmsg.font.visible = true;
        else
            cmsg.font.visible = false;
            return;
        end
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    if (cmsg.font ~= nil) then
        cmsg.font:destroy();
    end
    settings.save();
end);

