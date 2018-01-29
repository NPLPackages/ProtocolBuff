local string = string
local math = math
local print = print
local getmetatable = getmetatable
local table = table
local ipairs = ipairs

local descriptor = NPL.load("./descriptor.lua")
 
--module "text_format"
local text_format = NPL.export();

function text_format.format(buffer)
    local len = string.len( buffer )	
    for i = 1, len, 16 do		
        local text = ""	
        for j = i, math.min( i + 16 - 1, len ) do	
            text = string.format( "%s  %02x", text, string.byte( buffer, j ) )			
        end			
        print( text )	
    end
end

local FieldDescriptor = descriptor.FieldDescriptor

text_format.msg_format_indent = function(write, msg, indent)
    for field, value in msg:ListFields() do
        local print_field = function(field_value)
            local name = field.name
            write(string.rep(" ", indent))
            if field.type == FieldDescriptor.TYPE_MESSAGE then
                local extensions = getmetatable(msg)._extensions_by_name
                if extensions[field.full_name] then
                    write("[" .. name .. "] {\n")
                else
                    write(name .. " {\n")
                end
                text_format.msg_format_indent(write, field_value, indent + 4)
                write(string.rep(" ", indent))
                write("}\n")
            elseif field.type == FieldDescriptor.TYPE_ENUM then
                local v, found = nil
                for _, v in ipairs(field.enum_type.values) do
                    if v.number == field_value then
                        found = v.namea
                        break
                    end
                end
                write(string.format("%s: %s (%s)\n", name, field_value,
                    found or "invalid"))
            else
                write(string.format("%s: %s\n", name, field_value))
            end
        end
        if field.label == FieldDescriptor.LABEL_REPEATED then
            for _, k in ipairs(value) do
                print_field(k)
            end
        else
            print_field(value)
        end
    end
end

function text_format.msg_format(msg)
    local out = {}
    local write = function(value)
        out[#out + 1] = value
    end
    text_format.msg_format_indent(write, msg, 0)
    return table.concat(out)
end

