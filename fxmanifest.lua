fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'visualzx'
description 'Accountant Job'
version '1.0'

shared_script { "@es_extended/imports.lua", "@ox_lib/init.lua", "config.lua" }
client_scripts { "client.lua" }
server_scripts { "@oxmysql/lib/MySQL.lua", "server.lua", "logs.lua" }
