--Author: Martmists
--RETIRE
--MAP
--=== UTILS ===--

local function hex_2(num)
  return string.format("0x%02X", num)
end
local function hex_4(num)
  return string.format("0x%04X", num)
end
local function hex_8(num)
  return string.format("0x%08X", num)
end
local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end
local function unpack (t, i)
  i = i or 1
  if t[i] ~= nil then
    return t[i], unpack(t, i + 1)
  end
end

--=== STRUCT HANDLERS ===--

local function struct_pairs(t)
  local currentIndex = 0
  local function iter(t)
    currentIndex = currentIndex + 1
    local key = t[currentIndex]
    if key then return key, t[key] end
  end
  return iter, t
end

local function createStruct(t)
  local currentIndex = 1
  local metaTable = {}
    
  function metaTable:__newindex(key,value)
    rawset(self, key, value)
    rawset(self, currentIndex, key)
    currentIndex = currentIndex + 1
  end

  function metaTable:__call(addr)
    local obj = {
      __name = t.__name,
      __addr = addr
    }

    local meta = {}
    local type = self

    function meta:__tostring()
      local s = t.__name.."("
      local addComma = false
      for k, v in struct_pairs(type) do
        if (addComma) then
          s = s .. ", "
        else
          addComma = true
        end
        s = s .. k .. "=" .. tostring(obj[k])
      end
      return s .. ")"
    end
    setmetatable(obj, meta)

    local ptr = addr

    local function get_value(size)
      local o
      if (size == 1) then
        o = memory.read_u8(ptr)
      elseif (size == 2) then
        o = memory.read_u16_le(ptr)
      elseif (size == 4) then
        o = memory.read_u32_le(ptr)
      elseif (size.is_ptr) then
        o = size.struct(memory.read_u32_le(ptr))
        size = 4
      elseif (size.is_arr) then
        o = {}
        for x=1,size.length,1 do
          o:insert(x, get_value(size.data))
        end
      end
      ptr = ptr + size
      return o
    end

    for attr, size in struct_pairs(type) do
      obj[attr] = get_value(size)
    end

    return obj
  end

  return setmetatable(t or {}, metaTable)
end

local function ptr(struct)
  return {is_ptr = true, struct = struct}
end

local function arr(data, length)
  return {is_arr = true, length = length, data = data}
end

local Context = {}
function Context:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self

  if (_G["__void_form_id"] ~= nil) then
    forms.destroy(_G["__void_form_id"])
  end

  -- _G["__void_form_id"] = forms.newform()
  -- _G["__void_picture_id"] = forms.pictureBox(_G["__void_form_id"])

  return o
end
local debug = setmetatable({}, {
  __index = function(self, f)
    return setmetatable({}, {
      __call = function(t, ...)
        return forms[f](_G["__void_picture_id"], unpack(arg, 2))
      end
    })
  end
})

--=== SCREEN UTILITIES ===--

function Context:drawGameLine(x1, y1, x2, y2, color)
  local cx = 128
  local cy = 88

  local relx1 = x1 - self.cameraPos.x - 0x1000
  local relx2 = x2 - self.cameraPos.x - 0x1000
  local rely1 = y1 - self.cameraPos.y + 0x9000
  local rely2 = y2 - self.cameraPos.y + 0x9000

  local function apply(x, y)
    if self.matrix_size ~= 1 then
      local nx = x/4096 * 9 / 8
      local ny = y/4096 * 7 / 8
      local nzx = y/4096/-1024 + 0.004 * self.camera.y_tilt
      local nzy = y/4096/-1024/0.8 + 0.0036 * self.camera.y_tilt
      local v = 1.35
      return nx/nzx * v, ny/nzy * v
    else
      local nx = x/4096
      local ny = y/4096*0.78
      return nx, ny
    end
  end

  local tx1, ty1 = apply(relx1, rely1)
  local tx2, ty2 = apply(relx2, rely2)

  local startx = cx + tx1
  local starty = cy + ty1
  local endx = cx + tx2
  local endy = cy + ty2

  if (endy == starty and (starty > 191 or starty < 0)) then return end

  if (starty < 0) then
    local dydx = (endx - startx) / (endy - starty)
    startx = startx + round(dydx* -(starty - 0))
    starty = 0
  end

  if (endy > 191) then
    local dydx = (endx - startx) / (endy - starty)
    endx = startx + round(dydx * endy)
    endy = 191
  end

  gui.drawLine(startx, starty,
               endx, endy, color)
end

function Context:drawGameQuad(x1, y1, x2, y2, color, fill)
  local cx = 128
  local cy = 88

  local relx1 = x1 - self.cameraPos.x - 0x1000
  local relx2 = x2 - self.cameraPos.x - 0x1000
  local rely1 = y1 - self.cameraPos.y + 0x9000
  local rely2 = y2 - self.cameraPos.y + 0x9000

  local function apply(x, y)
    if self.camera.y_tilt ~= 0 then
      local nx = x/4096 * 9 / 8
      local ny = y/4096 * 7 / 8
      local nzx = y/4096/-1024 + 0.004 * self.camera.y_tilt
      local nzy = y/4096/-1024/0.8 + 0.0036 * self.camera.y_tilt
      local v = 1.35
      return nx/nzx * v, ny/nzy * v
    else
      local nx = x/4096
      local ny = y/4096*0.78
      return nx, ny
    end
  end

  local tx1, ty1 = apply(relx1, rely1)
  local tx2, ty2 = apply(relx2, rely2)

  local startx = cx + tx1
  local starty = cy + ty1
  local endx = cx + tx2
  local endy = cy + ty2

  if (endy == starty and (starty > 191 or starty < 0)) then return end

  if (starty < 0) then
    local dydx = (endx - startx) / (endy - starty)
    startx = startx + round(dydx* -(starty - 0))
    starty = 0
  end

  if (endy > 191) then
    local dydx = (endx - startx) / (endy - starty)
    endx = startx + round(dydx * endy)
    endy = 191
  end

  gui.drawPolygon({{startx, starty}, {startx, endy}, {endx, endy}, {endx, starty}}, color, fill)
end

--=== STRUCTS ===--

local locationStruct = createStruct {
  __name = "LocationData"
}
locationStruct.x = 4
locationStruct.z = 4
locationStruct.y = 4
locationStruct.map_x = 4
locationStruct.map_z = 4
locationStruct.map_y = 4

local cameraStruct = createStruct {
  __name = "CamData"
}
cameraStruct.h_pan = 4
cameraStruct.zoom = 4
cameraStruct.y_tilt = 4
cameraStruct.h_pan_2 = 4
cameraStruct.v_pan_up = 4
cameraStruct.v_pan_down = 4
cameraStruct.rotation = 4

local cameraPosStruct = createStruct {
  __name = "CamPosData"
}
cameraPosStruct.x = 4
cameraPosStruct.z = 4
cameraPosStruct.y = 4

--=== INIT FUNCTIONS ===--

function Context:initSettings()
  self.settings = {
    gridView = true,
    loadLineView = true,

    cheatWTW = true,
    cheatRepel = true
  }
end

function Context:loadBase()
  local version = memory.read_u32_le(0x023FFE0C)
  if version == 0 then
      version = memory.read_u32_le(0x027FFE0C)
  end
  self.version = version

  local id = bit.band(version, 0xFF)
  local lang = bit.band(bit.rshift(version, 24), 0xFF)
  self.id = id
  self.lang = lang

  if id == 0x41 then
    self.game = "DP"
  elseif id == 0x49 then
    self.game = "HGSS"
  elseif id == 0x43 then
    self.game = "Pt"
  end

  local base_addr = 0
  if id == 0x41 then                                 -- Pokemon D/P
    if lang == 0x44 then base_addr = 0x02107100         -- DE
    elseif lang == 0x45 then base_addr = 0x02106FC0     -- US / EU
    elseif lang == 0x46 then base_addr = 0x02107140     -- FR
    elseif lang == 0x49 then base_addr = 0x021070A0     -- IT
    elseif lang == 0x4B then base_addr = 0x021045C0     -- KS
    elseif lang == 0x53 then base_addr = 0x02107160     -- ES
    elseif lang == 0x4A then
      if memory.read_u16_le(0x23FFE2C) == 0xB8 then base_addr = 0x211F988 --Pokemon DP Debug
      else base_addr = 0x02108818                       -- JP
      end
    end

  elseif id == 0x43 then                             -- Pokemon Pt
    if lang == 0x44 then base_addr = 0x02101EE0         -- DE
    elseif lang == 0x45 then base_addr = 0x02101D40     -- US / EU
    elseif lang == 0x46 then base_addr = 0x02101F20     -- FR
    elseif lang == 0x49 then base_addr = 0x02101EA0     -- IT
    elseif lang == 0x4A then base_addr = 0x02101140     -- JP
    elseif lang == 0x4B then base_addr = 0x02102C40     -- KS
    elseif lang == 0x53 then base_addr = 0x02101F40     -- ES
    end

  elseif id == 0x49 then                             -- Pokemon HG/SS CFe0
    if lang == 0x44 then base_addr = 0x02111860         -- DE
    elseif lang == 0x45 then base_addr = 0x02111880     -- US / EU
    elseif lang == 0x46 then base_addr = 0x021118A0     -- FR
    elseif lang == 0x49 then base_addr = 0x02111820     -- IT
    elseif lang == 0x4A then base_addr = 0x02110DC0     -- JP
    elseif lang == 0x4B then base_addr = 0x02112280     -- KS
    elseif lang == 0x53 then base_addr = 0x021118C0     -- ES
    end
  end
  self.base_addr = base_addr
  self.base = memory.read_u32_le(base_addr)
end

function Context:loadDPPointers()
  self.npc_ptr = self.base + 0x248F0
  self.map_ptr = self.base + 0x144C
  self.cam_ptr = self.base + 0xBE9E4
  self.cam_pos_ptr = 0x021CEF70
  self.npc_ptr = self.base + 0x248F0
  self.void_data_ptr = self.base + 0x22AD9
  self.repel_num_ptr = self.base + 0x75F4
  self.wtw_ptr = 0x02056C06

  local coord_addr = self.base + 0x248D4
  local coord_ptr = memory.read_u32_le(coord_addr)
  if coord_ptr ~= (coord_addr + 0x140) then
    coord_ptr = memory.read_u32_le(coord_ptr + 0xC)
    self.battletower = true
  else
    self.battletower = false
  end
  self.position_ptr = coord_ptr + 0x84
end

function Context:loadPtPointers()
  self.npc_ptr = self.base + 0x23738
  self.map_ptr = self.base + 0x1294
  self.cam_ptr = self.base + 0xBEA30
  self.cam_pos_ptr = 0x021CEF70 --TODO: Align for Pt
  self.npc_ptr = self.base + 0x23738
  local coord_addr = self.base + 0x2371C
  local coord_ptr = memory.read_u32_le(coord_addr)
  if coord_ptr ~= (coord_addr + 0x140) then
    coord_ptr = memory.read_u32_le(coord_ptr + 0xC)
    self.battletower = true
  else
    self.battletower = false
  end
  self.position_ptr = coord_ptr + 0x84
end

function Context:loadHGSSPointers()
  -- TODO
end

function Context:loadPointers()
  self["load"..self.game.."Pointers"](self)
end

--=== TICK FUNCTIONS ===--

function Context:loadData()
  self.position = locationStruct(self.position_ptr)
  self.camera = cameraStruct(self.cam_ptr)
  self.cameraPos = cameraPosStruct(self.cam_pos_ptr)
  self.matrix_size = memory.read_u8(self.void_data_ptr)
  self.void_data = 0 -- +1x -> x/16 bytes further
                     -- +1y -> y/16 * map_width
  self.map_id = memory.read_u32_le(self.map_ptr)
end

function Context:displayGrid()
  local startX = bit.band(self.cameraPos.x, 0xFFFF0000) - 0xA * 65536
  local startY = bit.band(self.cameraPos.y, 0xFFFF0000) - 0xA * 65536
  local endX = bit.band(self.cameraPos.x, 0xFFFF0000) + 0xA * 65536
  local endY = bit.band(self.cameraPos.y, 0xFFFF0000) + 0xA * 65536

  local color = "blue"

  for x = startX, endX, 0x00010000 do
    if self.settings.loadLineView and (x / 65536) % 32 == 16 then color = "red" else color = "blue" end
    self:drawGameLine(x, startY, x, endY, color)
  end

  for y = startY, endY, 0x00010000 do
    if self.settings.loadLineView and (y / 65536) % 32 == 16 then color = "red" else color = "blue" end
    self:drawGameLine(startX, y, endX, y, color)
  end
end

function Context:displayData()
  if self.settings.gridView then
    self:displayGrid()
  end

  gui.drawText(0, 0, "Base: " .. hex_8(self.base))
  gui.drawText(0, 10, "Position[" .. tostring(self.map_id) .. "]: " .. tostring(self.position.x) .. ", " .. tostring(self.position.y))
  --self:drawGameQuad(self.position.map_x-0x8000, self.position.map_y-0x7000,
  --                  self.position.map_x+0x7000, self.position.map_y+0x7000, nil, "white")
  gui.drawText(0, 20, "NPC: " .. hex_8(self.npc_ptr))
end

function Context:writeRepel()
  if self.settings.cheatRepel then
    memory.write_u8(self.repel_num_ptr, 0xF)
  end
end

function Context:writeWTW()
  if self.settings.cheatWTW then
    memory.write_u16_le(self.wtw_ptr, 0x1000)
  else
    memory.write_u16_le(self.wtw_ptr, 0x1C20)
  end
end

function Context:handleKeys()

end

--=== INIT & TICK FUNCS ===--

function Context:init()
  self:initSettings()
  self:loadBase()
  self:loadPointers()
end

function Context:tick()
  self:handleKeys()
  self:writeRepel()
  self:writeWTW()
  self:loadData()
  self:displayData()
end

--=== MAIN ===--

-- All this script does is read data and draw to the screen --

event.unregisterbyname("void_start")
event.unregisterbyname("void_end")
local ctx = Context:new()
event.onframestart(function() ctx:init() end, "void_start")
event.onframeend(function() ctx:tick() end, "void_end")

