set LUA_PROTO_DIR=../npl_mod/ProtocolBuff/samples/
for %%i in (%LUA_PROTO_DIR%*.proto) do (  
echo %%i
protoc.exe -I=%LUA_PROTO_DIR% --plugin=protoc-gen-lua="protoc-gen-lua.bat" --lua_out=%LUA_PROTO_DIR% %LUA_PROTO_DIR%%%i
)
pause