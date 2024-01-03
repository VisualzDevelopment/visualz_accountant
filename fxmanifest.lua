fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Visualz Development <https://visualz.dk>'
description 'Accountant Job'
version '1.0'

shared_script { "@es_extended/imports.lua", "@ox_lib/init.lua", "config.lua" }
client_scripts { "client/client.lua" }
server_scripts { "@oxmysql/lib/MySQL.lua", "server/server.lua", "server/logs.lua" }

escrow_ignore { "server/logs.lua" }
