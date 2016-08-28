local ffi = require "ffi"
local gason = ffi.load('./build/libgason.so')

ffi.cdef[[
  typedef struct JsonValue JsonValue;
  typedef struct JsonNode JsonNode;
  typedef struct JsonAllocator JsonAllocator;

  JsonValue* new_JsonValue();
  void delete_JsonValue(JsonValue* jv);
  JsonAllocator* new_JsonAllocator();  
  void delete_JsonAllocator(JsonAllocator* ja);  

  int json_parse(char *source, char *endptr, JsonValue* jv, JsonAllocator* ja);
  int get_tag(JsonValue* jv);
  char *to_string(JsonValue* jv);
  double to_number(JsonValue* jv);
  JsonNode* to_node(JsonValue* jv);

  JsonNode* node_next(JsonNode* jn);
  char *node_key(JsonNode* jn);
  JsonValue* node_value(JsonNode* jn);

  void free(void*);

]]

local JsonTag = {
    [0]  = "JSON_NUMBER",
    [1]  = "JSON_STRING",
    [2]  = "JSON_ARRAY",
    [3]  = "JSON_OBJECT",
    [4]  = "JSON_TRUE",
    [5]  = "JSON_FALSE",
    [15] = "JSON_NULL",
}

local function pp(t)
  local print_r_cache={}
  local ps = ""
  local function to_print(str)
    ps = ps..str.."\n"
  end
  local function sub_print_r(ta, indent)
    if (print_r_cache[tostring(ta)]) then
      to_print(indent.."*"..tostring(ta))
    else
      print_r_cache[tostring(ta)] = true
      if type(ta) == "table" then
        for pos, val in pairs(ta) do
          if type(val) == "table" then
            to_print(indent.."["..pos.."] => "..tostring(ta).." {")
            sub_print_r(val, indent..string.rep(" ", string.len(pos) + 8))
            to_print(indent..string.rep(" ", string.len(pos) + 6).."}")
          elseif type(val) == "string" then
            to_print(indent.."["..pos..'] => "'..val..'"')
          else
            to_print(indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        to_print(indent..tostring(t))
      end
    end
  end
  if type(t) == "table" then
    to_print(tostring(t).." {")
    sub_print_r(t, "  ")
    to_print("}")
  else
    sub_print_r(t, "  ")
  end
  return ps
end

local function json_decode(jv)
  local tag = jv:get_tag()
  if tag == "JSON_NUMBER" then
    return jv:to_number()
  elseif tag == "JSON_STRING" then
    return jv:to_string() 
  elseif tag == "JSON_ARRAY" then
    local a = {}
    local node = jv:to_node()
    table.insert(a, json_decode(node:value()))
    while (node:next()) do
      node = node:next()
      table.insert(a, json_decode(node:value()))
    end
    return a
  elseif tag == "JSON_OBJECT" then
    local o = {}
    local node = jv:to_node()
    o[node:key()] = json_decode(node:value())
    while (node:next()) do
      node = node:next()
      o[node:key()] = json_decode(node:value())
    end
    return o
  elseif tag == "JSON_TRUE" then
    return true
  elseif tag == "JSON_FALSE" then
    return false
  elseif tag == "JSON_NULL" then
    return nil
  end
end

local ja = {}
ja.__index = ja

local function jsonAllocator()
  local self = {super = gason.new_JsonAllocator()}
  ffi.gc(self.super, gason.delete_JsonAllocator)
  return setmetatable(self, ja)
end

local jn = {}
jn.__index = jn

local function jsonNode(jv)
  local self = {super = gason.to_node(jv.super)}
  --ffi.gc(self.super, ffi.C.free)
  return setmetatable(self, jn)
end

local jv = {}
jv.__index = jv

local function jsonValue(json_node)
  local self = {}
  if json_node then
    self.super = gason.node_value(json_node.super)
  else
    self.super = gason.new_JsonValue()
  end
  --ffi.gc(self.super, gason.delete_JsonValue)
  return setmetatable(self, jv)
end

function jn.value(self)
  return jsonValue(self) 
end

function jn.key(self)
  return ffi.string(gason.node_key(self.super))
end

function jn.next(self)
  local node_next = gason.node_next(self.super) 

  if node_next == nil then return nil end
  self = {super = node_next}
  --ffi.gc(self.super, ffi.C.free)
  return setmetatable(self, jn)
end


function jv.get_tag(self)
  return JsonTag[gason.get_tag(self.super)]
end

function jv.to_number(self)
  return gason.to_number(self.super)
end

function jv.to_string(self)
  return ffi.string(gason.to_string(self.super))
end

function jv.to_node(self)
  return jsonNode(self)
end

function jv.json_parse(self, allocator, source)
  local endptr = ffi.new("char *")
  local source_char = ffi.new("char["..#source.."]", source)
  return gason.json_parse(source_char, endptr, self.super, allocator.super)
end

local function decode(source)
  local jallocator = jsonAllocator()
  local jvalue = jsonValue()

  local status = jvalue:json_parse(jallocator, source)
  print("here, status: "..status)
  if status ~= 0 then return print("parse error") end
  return json_decode(jvalue)
end

print(pp(decode('[null,[1,2,{"z": 55, "g": [14,3,2]}]]')))


--local test_json = '["a", "b", [1,2,3]]'
--
--local endptr = ffi.new("char *")
--local source = ffi.new("char[?]", test_json)
--local jsonValue = gason.new_JsonValue()
--local jsonAllocator = gason.new_JsonAllocator()
--
--print('bla')
--local res = gason.json_parse(source, endptr, jsonValue, jsonAllocator)
--print("res: "..res)
--
--local write = io.write
--
--local function print_jsonvalue(jv)
--  local tag = JsonTag[gason.get_tag(jv)]
--  if tag == "JSON_NUMBER" then
--    write(gason.to_number(jv))
--  elseif tag == "JSON_STRING" then
--    write(ffi.string(gason.to_string(jv))) 
--  elseif tag == "JSON_ARRAY" then
--    write('[')
--    local node = gason.to_node(jv)
--    print_jsonvalue(node.value)
--    while (node.next ~= nil) do
--      node = gason.next_node(node.next)
--      print_jsonvalue(node.value)
--    end
--    write(']\n')
--  elseif tag == "JSON_OBJECT" then
--    print('{')
--    local node = gason.to_node(jv)
--    print(ffi.string(node.key)..": ")
--    print_jsonvalue(node.value)
--    while (node.next ~= nil) do
--      node = gason.next_node(node.next)
--      print(ffi.string(node.key)..": ")
--      print_jsonvalue(node.value)
--    end
--    print('}\n')
--  elseif tag == "JSON_TRUE" then
--    print("true")
--  elseif tag == "JSON_FALSE" then
--    print("false")
--  end
--end
--
--print_jsonvalue(jsonValue)

--print("tag: "..JsonTag[gason.get_tag(jsonValue)])
--
--local node1 = gason.to_node(jsonValue)
--
--print("tag1: "..gason.get_tag(node1.value))
--print("value1: "..ffi.string(gason.to_string(node1.value)))
--
--print(node1.next)
--local node2 = gason.next_node(node1.next)
--print("tag2: "..gason.get_tag(node2.value))
--print("value2: "..ffi.string(gason.to_string(node2.value)))
--local bla = node2.next
--
--if bla == nil then print("x") end
--print(bla)

--print("tag: "..JsonTag[gason.get_tag(jsonValue)])
--print("value: "..ffi.string(gason.to_string(jsonValue)))
--print("tag: "..JsonTag[gason.get_tag(jsonValue)])
--print("value: "..ffi.string(gason.to_string(jsonValue)))

--local tag = gason.sum_and_print(jsonValue);
--print(tag)
--local tag = gason.get_tag(jsonValue, jsonAllocator)
--print(tag)
