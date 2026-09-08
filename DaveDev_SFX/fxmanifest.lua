fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DaveDev'
description 'DaveDev SFX - shared sound player for DaveDev resources (source-available)'
version '2.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/sounds/*.ogg',
    'html/sounds/*.mp3',
    'html/sounds/*.wav',
}

server_exports {
    'PlayWithinDistance',
    'PlayAtCoords',
    'PlayOnSource',
    'PlayOnAll',
    'IsCompatActive',
}

client_exports {
    'PlayLocal',
}

escrow_ignore {
    'config.lua',
    'client/*.lua',
    'server/*.lua',
    'html/*',
    'html/sounds/*',
    'README.md',
    'LICENSE.md',
}
