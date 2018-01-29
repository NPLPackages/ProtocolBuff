local string = string
local table = table
local ipairs = ipairs
local assert =assert

--local pb = require "pb"
local wire_format = NPL.load("./wire_format.lua")

--module "encoder"
local encoder = NPL.export();

function _VarintSize(value)
    if value <= 0x7f then return 1 end
    if value <= 0x3fff then return 2 end
    if value <= 0x1fffff then return 3 end
    if value <= 0xfffffff then return 4 end
    return 5 
end
encoder._VarintSize = _VarintSize;

function _SignedVarintSize(value)
    if value < 0 then return 10 end
    if value <= 0x7f then return 1 end
    if value <= 0x3fff then return 2 end
    if value <= 0x1fffff then return 3 end
    if value <= 0xfffffff then return 4 end
    return 5
end
encoder._SignedVarintSize = _SignedVarintSize;

function _TagSize(field_number)
  return _VarintSize(wire_format.PackTag(field_number, 0))
end
encoder._TagSize = _TagSize;

function _SimpleSizer(compute_value_size)
    return function(field_number, is_repeated, is_packed)
        local tag_size = _TagSize(field_number)
        if is_packed then
            local VarintSize = _VarintSize
            return function(value)
                result = 0
                for element in value do
                    result = result + compute_value_size(element)
                end
                return result + VarintSize(result) + tag_size
            end
        elseif is_repeated then
            return function(value)
                result = tag_size * len(value)
                for element in value do
                    result = result + compute_value_size(element)
                end
                return result
            end
        else
            return function (value)
                return tag_size + compute_value_size(value)
            end
        end
    end
end
encoder._SimpleSizer = _SimpleSizer;

function _ModifiedSizer(compute_value_size, modify_value)
    return function (field_number, is_repeated, is_packed)
        local tag_size = _TagSize(field_number)
        if is_packed then
            local VarintSize = _VarintSize
            return function (value)
                result = 0
                for element in value do
                    result = result + compute_value_size(modify_value(element))
                end
                return result + VarintSize(result) + tag_size
            end
        elseif is_repeated then
            return function (value)
                result = tag_size * len(value)
                for element in value do
                    result = result + compute_value_size(modify_value(element))
                end
                return result
            end
        else
            return function (value)
                return tag_size + compute_value_size(modify_value(value))
            end
        end
    end
end
encoder._ModifiedSizer = _ModifiedSizer;

function _FixedSizer(value_size)
    return function (field_number, is_repeated, is_packed)
        local tag_size = _TagSize(field_number)
        if is_packed then
            local VarintSize = _VarintSize
            return function (value)
                local result = len(value) * value_size
                return result + VarintSize(result) + tag_size
            end
        elseif is_repeated then
            local element_size = value_size + tag_size
            return function(value)
                return len(value) * element_size
            end
        else
            local field_size = value_size + tag_size
            return function (value)
                return field_size
            end
        end
    end
end
encoder._FixedSizer = _FixedSizer;

Int32Sizer = _SimpleSizer(_SignedVarintSize)
Int64Sizer = Int32Sizer
EnumSizer = Int32Sizer

UInt32Sizer = _SimpleSizer(_VarintSize)
UInt64Sizer = UInt32Sizer 

SInt32Sizer = _ModifiedSizer(_SignedVarintSize, wire_format.ZigZagEncode32)
SInt64Sizer = SInt32Sizer

Fixed32Sizer = _FixedSizer(4) 
SFixed32Sizer = Fixed32Sizer
FloatSizer = Fixed32Sizer

Fixed64Sizer = _FixedSizer(8) 
SFixed64Sizer = Fixed64Sizer
DoubleSizer = Fixed64Sizer

BoolSizer = _FixedSizer(1)

encoder.Int32Sizer =Int32Sizer;
encoder.Int64Sizer = Int64Sizer;
encoder.EnumSizer = EnumSizer;
encoder.UInt32Sizer = UInt32Sizer;
encoder.UInt64Sizer = UInt64Sizer;
encoder.SInt32Sizer = SInt32Sizer;
encoder.SInt64Sizer = SInt64Sizer;
encoder.Fixed32Sizer = Fixed32Sizer;
encoder.SFixed32Sizer = SFixed32Sizer;
encoder.FloatSizer = FloatSizer;
encoder.Fixed64Sizer = Fixed64Sizer;
encoder.SFixed64Sizer = SFixed64Sizer;
encoder.DoubleSizer = DoubleSizer;
encoder.BoolSizer = BoolSizer;


function StringSizer(field_number, is_repeated, is_packed)
    local tag_size = _TagSize(field_number)
    local VarintSize = _VarintSize
    assert(not is_packed)
    if is_repeated then
        return function(value)
            local result = tag_size * #value
            for _, element in ipairs(value) do
                local l = #element
                result = result + VarintSize(l) + l
            end
            return result
        end
    else
        return function(value)
            local l = #value
            return tag_size + VarintSize(l) + l
        end
    end
end
encoder.StringSizer = StringSizer;

function BytesSizer(field_number, is_repeated, is_packed)
    local tag_size = _TagSize(field_number)
    local VarintSize = _VarintSize
    assert(not is_packed)
    if is_repeated then
        return function (value)
            local result = tag_size * #value
            for _,element in ipairs(value) do
                local l = #element
                result = result + VarintSize(l) + l
            end
            return result
        end
    else
        return function (value)
            local l = #value
            return tag_size + VarintSize(l) + l
        end
    end
end
encoder.BytesSizer = BytesSizer;

function MessageSizer(field_number, is_repeated, is_packed)
    local tag_size = _TagSize(field_number)
    local VarintSize = _VarintSize
    assert(not is_packed)
    if is_repeated then
        return function(value)
            local result = tag_size * #value
            for _,element in ipairs(value) do
                local l = element:ByteSize()
                result = result + VarintSize(l) + l
            end
            return result
        end
    else
        return function (value)
            local l = value:ByteSize()
            return tag_size + VarintSize(l) + l
        end
    end
end
encoder.MessageSizer = MessageSizer;


-- ====================================================================
--  Encoders!

local _EncodeVarint = pb.varint_encoder
local _EncodeSignedVarint = pb.signed_varint_encoder


function _VarintBytes(value)
    local out = {}
    local write = function(value)
        out[#out + 1 ] = value
    end
    _EncodeSignedVarint(write, value)
    return table.concat(out)
end
encoder._VarintBytes = _VarintBytes;

function TagBytes(field_number, wire_type)
  return _VarintBytes(wire_format.PackTag(field_number, wire_type))
end
encoder.TagBytes = TagBytes;

function _SimpleEncoder(wire_type, encode_value, compute_value_size)
    return function(field_number, is_repeated, is_packed)
        if is_packed then
            local tag_bytes = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
            local EncodeVarint = _EncodeVarint
            return function(write, value)
                write(tag_bytes)
                local size = 0
                for _, element in ipairs(value) do
                    size = size + compute_value_size(element)
                end
                EncodeVarint(write, size)
                for element in value do
                    encode_value(write, element)
                end
            end
        elseif is_repeated then
            local tag_bytes = TagBytes(field_number, wire_type)
            return function(write, value)
                for _, element in ipairs(value) do
                    write(tag_bytes)
                    encode_value(write, element)
                end
            end
        else
            local tag_bytes = TagBytes(field_number, wire_type)
            return function(write, value)
                write(tag_bytes)
                encode_value(write, value)
            end
        end
    end
end
encoder._SimpleEncoder = _SimpleEncoder;

function _ModifiedEncoder(wire_type, encode_value, compute_value_size, modify_value)
    return function (field_number, is_repeated, is_packed)
        if is_packed then
            local tag_bytes = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
            local EncodeVarint = _EncodeVarint
            return function (write, value)
                write(tag_bytes)
                local size = 0
                for _, element in ipairs(value) do
                    size = size + compute_value_size(modify_value(element))
                end
                EncodeVarint(write, size)
                for _, element in ipairs(value) do
                    encode_value(write, modify_value(element))
                end
            end
        elseif is_repeated then
            local tag_bytes = TagBytes(field_number, wire_type)
            return function (write, value)
                for _, element in ipairs(value) do
                    write(tag_bytes)
                    encode_value(write, modify_value(element))
                end
            end
        else
            local tag_bytes = TagBytes(field_number, wire_type)
            return function (write, value)
                write(tag_bytes)
                encode_value(write, modify_value(value))
            end
        end
    end
end
encoder._ModifiedEncoder = _ModifiedEncoder;

function _StructPackEncoder(wire_type, value_size, format)
    return function(field_number, is_repeated, is_packed)
        local struct_pack = pb.struct_pack
        if is_packed then
            local tag_bytes = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
            local EncodeVarint = _EncodeVarint
            return function (write, value)
                write(tag_bytes)
                EncodeVarint(write, #value * value_size)
                for _, element in ipairs(value) do
                    struct_pack(write, format, element)
                end
            end
        elseif is_repeated then
            local tag_bytes = TagBytes(field_number, wire_type)
            return function (write, value)
                for _, element in ipairs(value) do
                    write(tag_bytes)
                    struct_pack(write, format, element)
                end
            end
        else
            local tag_bytes = TagBytes(field_number, wire_type)
            return function (write, value)
                write(tag_bytes)
                struct_pack(write, format, value)
            end
        end

    end
end
encoder._StructPackEncoder = _StructPackEncoder;

Int32Encoder = _SimpleEncoder(wire_format.WIRETYPE_VARINT, _EncodeSignedVarint, _SignedVarintSize)
Int64Encoder = Int32Encoder
EnumEncoder = Int32Encoder

UInt32Encoder = _SimpleEncoder(wire_format.WIRETYPE_VARINT, _EncodeVarint, _VarintSize)
UInt64Encoder = UInt32Encoder

SInt32Encoder = _ModifiedEncoder(
    wire_format.WIRETYPE_VARINT, _EncodeVarint, _VarintSize,
    wire_format.ZigZagEncode32)

SInt64Encoder = _ModifiedEncoder(
    wire_format.WIRETYPE_VARINT, _EncodeVarint, _VarintSize,
    wire_format.ZigZagEncode64)

Fixed32Encoder  = _StructPackEncoder(wire_format.WIRETYPE_FIXED32, 4, string.byte('I'))
Fixed64Encoder  = _StructPackEncoder(wire_format.WIRETYPE_FIXED64, 8, string.byte('Q'))
SFixed32Encoder = _StructPackEncoder(wire_format.WIRETYPE_FIXED32, 4, string.byte('i'))
SFixed64Encoder = _StructPackEncoder(wire_format.WIRETYPE_FIXED64, 8, string.byte('q'))
FloatEncoder    = _StructPackEncoder(wire_format.WIRETYPE_FIXED32, 4, string.byte('f'))
DoubleEncoder   = _StructPackEncoder(wire_format.WIRETYPE_FIXED64, 8, string.byte('d'))

encoder.Int32Encoder = Int32Encoder;
encoder.Int64Encoder = Int64Encoder;
encoder.EnumEncoder = EnumEncoder;
encoder.UInt32Encoder = UInt32Encoder;
encoder.UInt64Encoder = UInt64Encoder;
encoder.SInt32Encoder = SInt32Encoder;
encoder.SInt64Encoder = SInt64Encoder;
encoder.Fixed32Encoder = Fixed32Encoder;
encoder.Fixed64Encoder = Fixed64Encoder;
encoder.SFixed32Encoder = SFixed32Encoder;
encoder.SFixed64Encoder = SFixed64Encoder;
encoder.FloatEncoder = FloatEncoder;
encoder.DoubleEncoder = DoubleEncoder;


function BoolEncoder(field_number, is_repeated, is_packed)
    local false_byte = '\0'
    local true_byte = '\1'
    if is_packed then
        local tag_bytes = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
        local EncodeVarint = _EncodeVarint
        return function (write, value)
            write(tag_bytes)
            EncodeVarint(write, #value)
            for _, element in ipairs(value) do
                if element then
                    write(true_byte)
                else
                    write(false_byte)
                end
            end
        end
    elseif is_repeated then
        local tag_bytes = TagBytes(field_number, wire_format.WIRETYPE_VARINT)
        return function(write, value)
            for _, element in ipairs(value) do
                write(tag_bytes)
                if element then
                    write(true_byte)
                else
                    write(false_byte)
                end
            end
        end
    else
        local tag_bytes = TagBytes(field_number, wire_format.WIRETYPE_VARINT)
        return function (write, value)
            write(tag_bytes)
            if value then
                return write(true_byte)
            end
            return write(false_byte)
        end
    end
end
encoder.BoolEncoder = BoolEncoder;

function StringEncoder(field_number, is_repeated, is_packed)
    local tag = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
    local EncodeVarint = _EncodeVarint
    assert(not is_packed)
    if is_repeated then
        return function (write, value)
            for _, element in ipairs(value) do
--                encoded = element.encode('utf-8')
                write(tag)
                EncodeVarint(write, #element)
                write(element)
            end
        end
    else
        return function (write, value)
--            local encoded = value.encode('utf-8')
            write(tag)
            EncodeVarint(write, #value)
            return write(value)
        end
    end
end
encoder.StringEncoder = StringEncoder;

function BytesEncoder(field_number, is_repeated, is_packed)
    local tag = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
    local EncodeVarint = _EncodeVarint
    assert(not is_packed)
    if is_repeated then
        return function (write, value)
            for _, element in ipairs(value) do
                write(tag)
                EncodeVarint(write, #element)
                write(element)
            end
        end
    else
        return function(write, value)
            write(tag)
            EncodeVarint(write, #value)
            return write(value)
        end
    end
end
encoder.BytesEncoder = BytesEncoder;


function MessageEncoder(field_number, is_repeated, is_packed)
    local tag = TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
    local EncodeVarint = _EncodeVarint
    assert(not is_packed)
    if is_repeated then
        return function(write, value)
            for _, element in ipairs(value) do
                write(tag)
                EncodeVarint(write, element:ByteSize())
                element:_InternalSerialize(write)
            end
        end
    else
        return function (write, value)
            write(tag)
            EncodeVarint(write, value:ByteSize())
            return value:_InternalSerialize(write)
        end
    end
end
encoder.MessageEncoder = MessageEncoder;

