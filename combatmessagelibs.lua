local function GetShortFlags(entityIndex)
    local fullFlags = AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(entityIndex);
    return bit.band(fullFlags, 0xFF);
end

function IsMonster(entityIndex)
    if (GetShortFlags(entityIndex) == 0x10) then
        return true
    end
  return false
end

function GetIndexFromId(serverId)
    local index = bit.band(serverId, 0x7FF);
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    if (entMgr:GetServerId(index) == serverId) then
        return index;
    end
    for i = 1,2303 do
        if entMgr:GetServerId(i) == serverId then
            return i;
        end
    end
    return 0;
end

local bitData;
local bitOffset;
local function UnpackBits(length)
    local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
    bitOffset = bitOffset + length;
    return value;
end

function ParseActionPacket(e)
    local actionPacket = T{};
    bitData = e.data_raw;
    bitOffset = 40;
    actionPacket.UserId = UnpackBits(32);
    actionPacket.UserIndex = GetIndexFromId(actionPacket.UserId);
    local targetCount = UnpackBits(6);
    --Unknown 4 bits
    bitOffset = bitOffset + 4;
    actionPacket.Type = UnpackBits(4);
    actionPacket.Id = UnpackBits(32);
    --Unknown 32 bits
    bitOffset = bitOffset + 32;

    actionPacket.Targets = T{};
    for i = 1,targetCount do
        local target = T{};
        target.Id = UnpackBits(32);
        local actionCount = UnpackBits(4);
        target.Actions = T{};
        for j = 1,actionCount do
            local action = {};
            action.Reaction = UnpackBits(5);
            action.Animation = UnpackBits(12);
            action.SpecialEffect = UnpackBits(7);
            action.Knockback = UnpackBits(3);
            action.Param = UnpackBits(17);
            action.Message = UnpackBits(10);
            action.Flags = UnpackBits(31);

            local hasAdditionalEffect = (UnpackBits(1) == 1);
            if hasAdditionalEffect then
                local additionalEffect = {};
                additionalEffect.Damage = UnpackBits(10);
                additionalEffect.Param = UnpackBits(17);
                additionalEffect.Message = UnpackBits(10);
                action.AdditionalEffect = additionalEffect;
            end

            local hasSpikesEffect = (UnpackBits(1) == 1);
            if hasSpikesEffect then
                local spikesEffect = {};
                spikesEffect.Damage = UnpackBits(10);
                spikesEffect.Param = UnpackBits(14);
                spikesEffect.Message = UnpackBits(10);
                action.SpikesEffect = spikesEffect;
            end

            target.Actions:append(action);
        end
        actionPacket.Targets:append(target);
    end
    
    return actionPacket;
end

function GetEvent(e)
    local eventId, eventParams, eventType;
    if (e.id == 0x32) or (e.id == 0x33) then
        eventId = struct.unpack('H', e.data, 0x0C + 1);
        eventType = 'Start'
        if (e.id == 0x33) then        
            eventParams = T{};
            for i = 1,8 do
                eventParams[i] = struct.unpack('L', e.data, 0x4C + (i * 4) + 1);
            end
        end
    elseif (e.id == 0x34) then
        eventId = struct.unpack('H', e.data, 0x2C + 1);
        eventType = 'Start'
        eventParams = T{};
        for i = 1,8 do
            eventParams[i] = struct.unpack('L', e.data, 0x04 + (i * 4) + 1);
        end
    elseif (e.id == 0x00A) and (struct.unpack('H', e.data, 0x64 + 1) ~= 0) then
        eventId = struct.unpack('H', e.data, 0x64 + 1);
        eventType = 'Start'
    elseif (e.id == 0x5C) then -- Event update
        eventId = 0
        eventType = 'Update'
        eventParams = T{};
        for i = 1,8 do
            eventParams[i] = struct.unpack('I', e.data, (0x04 * i) + 1);
        end
    elseif (e.id == 0x2A) then -- Zone text msgID
        eventId = bit.band(struct.unpack('H', e.data, 0x1A + 1), 0x7FFF);
        eventType = 'MsgID'
        eventParams = T{};
        for i = 1,4 do
            eventParams[i] = struct.unpack('L', e.data, (i * 4) + 0x04 + 0x01);
        end
    end
    return eventId, eventParams, eventType;
end