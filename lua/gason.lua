local ffi = require "ffi"

local C = ffi.C

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
  local self = {super = ffi.C.new_JsonAllocator()}
  ffi.gc(self.super, C.delete_JsonAllocator)
  return setmetatable(self, ja)
end

local jn = {}
jn.__index = jn

local function jsonNode(jv)
  local self = {super = C.to_node(jv.super)}
  --ffi.gc(self.super, C.free)
  return setmetatable(self, jn)
end

local jv = {}
jv.__index = jv

local function jsonValue(json_node)
  local self = {}
  if json_node then
    self.super = C.node_value(json_node.super)
  else
    self.super = C.new_JsonValue()
  end
  ffi.gc(self.super, C.delete_JsonValue)
  return setmetatable(self, jv)
end

function jn.value(self)
  return jsonValue(self) 
end

function jn.key(self)
  return ffi.string(C.node_key(self.super))
end

function jn.next(self)
  local node_next = C.node_next(self.super) 

  if node_next == nil then return nil end
  self = {super = node_next}
  --ffi.gc(self.super, C.free)
  return setmetatable(self, jn)
end


function jv.get_tag(self)
  return JsonTag[C.get_tag(self.super)]
end

function jv.to_number(self)
  return C.to_number(self.super)
end

function jv.to_string(self)
  return ffi.string(C.to_string(self.super))
end

function jv.to_node(self)
  return jsonNode(self)
end

function jv.json_parse(self, allocator, source)
  local endptr = ffi.new("char *")
  local source_char = ffi.new("char["..#source.."]", source)
  return C.json_parse(source_char, endptr, self.super, allocator.super)
end

local function decode(source)
  local jallocator = jsonAllocator()
  local jvalue = jsonValue()

  -- TODO: handle statuses
  local status = jvalue:json_parse(jallocator, source)
  if status ~= 0 then return print("parse error") end
  return json_decode(jvalue)
end

return { decode = decode }
