logFile = "oreIdent.log"
logH = fs.open(logFile, "w")

function log(str)
     logH.write("["..os.day().." "..
      textutils.formatTime(os.time())..
      "] ")
     logH.write(str)
     logH.write("\n")
     logH.flush()
end

function lprint(str)
     log(str)
     print(str)
end

function lerror(e)
     log("Error: "..tostring(e))
     error(e)
end

log("Started script")

local tArgs = { ... }
if #tArgs ~= 2 then
     lerror("Usage: oreIdent <length> <height>")
end
length = tonumber(tArgs[1])
height = tonumber(tArgs[2])

log("Using length "..length)

local f = fs.open("oreData","r")
oreData = "a"
--print(f.readAll())
if f ~= nil then
     oreData = textutils.unserialise(f.readAll())
else
     oreData = {["minecraft:gravel"]="minecraft:gravel"}
end
--print(textutils.serialise(oreData))

orePos = {}
ignore = {["minecraft:stone"] = true,
          ["minecraft:flowing_lava"] = true,
          ["minecraft:water"] = true,
          ["minecraft:flowing_water"] = true}
local freePos = 2
local x = 0
local y = 0
local bedrock = false

dirInfo = {
 f = {x=1, y=0, next="u"},
 u = {x=0, y=1, next="b"},
 b = {x=-1,y=0, next="d"},
 d = {x=0, y=-1,next="f"} }

local function halfTurn()
     turtle.turnLeft()
     turtle.turnLeft()
end

local function turn(dir)
  if dir == "l" then
    turtle.turnLeft()
  elseif dir == "r" then
    turtle.turnRight()
  else
    lerror("turn: Unkown direction "..tostring(dir))
  end
end

local function place(dir)
     if dir == "f" then
          return turtle.place()
     elseif dir == "u" then
          return turtle.placeUp()
     elseif dir == "d" then
          return turtle.placeDown()
     else
          error("Place: Unknown direction: "..dir)
     end
end

local function inspect(dir)
     if dir == "f" then
          return turtle.inspect()
     elseif dir == "u" then
          return turtle.inspectUp()
     elseif dir == "d" then
          return turtle.inspectDown()
     elseif dir == "b" then
          halfTurn()
          a,b = turtle.inspect()
          halfTurn()
          return a,b
     else
          error("Inspect: Unknown direction")
     end
end

local function attack(dir)
     if dir == "f" then
          return turtle.attack()
     elseif dir == "u" then
          return turtle.attackUp()
     elseif dir == "d" then
          return turtle.attackDown()
     else
          lerror("attack: Unknown direction: "..dir)
     end
end

local function dig(dir)
     if dir == "f" then
          return turtle.dig()
     elseif dir == "u" then
          return turtle.digUp()
     elseif dir == "d" then
          return turtle.digDown()
     elseif dir == "b" then
          halfTurn()
          ok, reason = turtle.dig()
          halfTurn()
          return ok, reason
     else
          lerror("Unknown direction")
     end
end

movements = {
 f=turtle.forward,
 u=turtle.up,
 b=turtle.back,
 d=turtle.down}

function go2(dir)
     return movements[dir]()
end

local function go(dir)
     if dir == "f" then
          return turtle.forward()
     elseif dir == "u" then
          return turtle.up()
     elseif dir == "d" then
          return turtle.down()
     elseif dir == "b" then
          return turtle.back()
     else
          lerror("Unknown direction")
     end
end

local function saveOreData()
     local str = textutils.serialise(oreData)
     local f = fs.open("oreData", "w")
     f.write(str)
     f.close()
end

local function unload()
     lprint("Unloading...")
     dig("u")
     go("u")
     dig("u")
     turtle.select(1)
     place("d")
     turtle.select(2)
     place("u")
     for i=3,14 do
          turtle.select(i)
          local item = turtle.getItemDetail()
          if item and item.name == "minecraft:cobblestone" then
               turtle.dropUp()
          else
               turtle.dropDown()
          end
     end
     turtle.select(1)
     dig("d")
     turtle.select(2)
     dig("u")
     go("d")
     freePos = 3
     orePos = {} 
end

local function refuel()
     local fl = turtle.getFuelLevel()
     if fl < 1000 then
          lprint("Low fuel level, refueling...")
          turtle.select(16)
          turtle.refuel(2)
          lprint("Charcoal left: "..turtle.getItemCount())
     end
end

-- Get position for an item type
local function getPos(name)
     -- TODO: Also check for old items
     local pos = orePos[name]
     --while pos == nil or pos > 15 do
          if pos == nil then
               turtle.select(1)
               while turtle.getItemCount()>0 and pos ~= 16 do
                    pos = freePos
                    freePos = pos+1
                    orePos[name] = pos
                    turtle.select(pos)
                    -- Save updated array
               end
               lprint("New pos: "..tostring(pos)..
                     " for the ore "..name)
          else
               turtle.select(pos)
               if turtle.getItemSpace() == 0 then
                    orePos[name] = nil
                    return getPos(name)
               end
          end
         
         return pos
    end
    
    --TODO; Handle lava
    local function tryGo(dir)
         refuel()
         local isBlock, data = inspect(dir)
         if isBlock and (data.name == "minecraft:lava"
            or data.name == "minecraft:flowing_lava" and data.metadata == 0) then
          lprint("Drinking lava...")
          turtle.select(15)
          ok, reason = place(dir)
          if not ok then
               lprint("Failed to gather lava, because: "..reason)
          end
          ok, reason = turtle.refuel()
          if not ok then
               lprint("Failed to drink lava, because "..reason)
          end
          fuelLevel = turtle.getFuelLevel()
          lprint("Fuel level; "..fuelLevel)
     elseif isBlock then
          local name = data.name
          local val = oreData[name]
          
          -- Hit bedrock
          if name == "minecraft:bedrock" then
               bedrock = true
               lprint("Found bedrock: "..name)
               return "bedrock"
          end
          
          if val ~= nil and val ~= name
             and not ignore[name] then
           lprint("Skipping ore: "..name.."->"..val)
           return false, name, val
      end
      
      pos = getPos(name)
      if pos == 16 then
           unload(dir)
           pos = getPos(name)
      end
      
      ok, reason = dig(dir)
      if not ok and not ignore[name] then
           lprint("Failed to dig "..dir.." "..name..
           " which becomes "..tostring(val)..
           ", because: "..reason)
           oreData[name] = "unbreakable"
           saveOreData()
           return false, name, "unbreakable"
      end
      
      if val == nil then 
           newData = turtle.getItemDetail()
           if newData == nil then
                val = "No item"
           else
                val = newData.name
           end
           oreData[name] = val
           lprint("Found new block: "..name
                 .."="..val.."@"..pos)
           saveOreData()
      end
      -- print("Found "..name.."@"..pos)
 end
 
 if not go(dir) then
      if inspect(dir) then
           return tryGo(dir)
      end
      while attack(dir) do
           sleep(0.5)
      end
      sleep(1)
      ok, reason = go(dir)
      if not ok then
           lprint("Failed to go, because: "..tostring(reason))
           return false
      end
 end
 return true, name, val
end

local function pathFind(dir)
     local di = dirInfo[dir]
     while not tryGo(dir) do
          pathFind(di["next"])
     end
      x = x + di["x"]
      y = y + di["y"]
end 

local function newLayer()
     --while not turtle.detectUp() do
         -- go("u")
     --end
     lprint("New layer from "..x.."x"..y)
     y = 1
     y0 = height
     while y < y0 do
          pathFind("u")
          while x < 0 do
               pathFind("f")
          end
     end
     if dx > 0 then
         lprint("Turning right")
         turtle.turnRight()
     else
         lprint("Turning left")
         turtle.turnLeft()
     end
     dig("f")
     go("f")
     if dx > 0 then
          turtle.turnLeft()
     else
          turtle.turnRight()
     end
end

y0 = 0
y = 0
x = 0
dx = 1
while true do
    while not bedrock do
      while x < length do
           pathFind("f")
           
           if y~=y0 then          
             lprint("Going back from "..x.."x"..(y-y0))
           end
           while y > y0 do
                pathFind("d")
           end
      end
      lprint("Done with layer "..y0.." is at "..x.."x"..y)
      pathFind("d")
      y0 = y0 - 1
      
      turtle.turnLeft()
      turtle.turnLeft()
      dx = -dx
      x = length - x
      if dx>0 then
           lprint("Next dir is right")
      else
           lprint("Next dir is left")
      end
    end
    newLayer()
    bedrock = false
end

-- Todo: Move to where it updates
-- Also add persitance for movement
-- TODO: Refuel automatiaclly
-- TODO: Handle mobs
-- TODO: Place torches
str = textutils.serialise(oreData)
--print(str)
local f=fs.open("oreData","w")
f.write(str)
f.close()
--print(textutils.serialise(orePos))
