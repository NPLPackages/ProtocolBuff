# ProtocolBuff
Transports the google protocol buffer in NPL
### protoc-gen-lua
 - https://github.com/sean-lin/protoc-gen-lua
### Setup building environment on windows
- Install [python 2.7.0](https://www.python.org/download/releases/2.7/)
- Install tools/setuptools-0.6c11.win32-py2.7.exe 
- Add system variable path for python.exe
- Add system variable path for protoc.exe
- Download [protobuf-2.4.1](https://github.com/google/protobuf/releases/tag/v2.4.1) and unzip
```
cd protobuf-2.4.1/python
python setup.py install
``` 
### Use cmd to make protocol files
```
buildProto.bat
```
### Test codes
```lua
-- add search path
ParaIO.AddSearchPath("npl_packages/ProtocolBuff/npl_mod/ProtocolBuff");
-- activated pb state
NPL.call("protocol/pb.cpp", {});

local person_pb = NPL.load("samples/person_pb.lua");
local msg = person_pb.Person()
msg.id = 100
msg.name = "foo"
msg.email = "bar"
local pb_data = msg:SerializeToString()

-- Parse Example
local msg = person_pb.Person()
msg:ParseFromString(pb_data)
echo({msg.id, msg.name, msg.email})
```
