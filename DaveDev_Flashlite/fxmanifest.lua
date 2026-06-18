fx_version 'cerulean'
game 'gta5'

author 'DaveDev'
description "DaveDev's Immersive Flashlite - standalone flashlight"
version '1.0.0'

shared_scripts {
  'config.lua'
}

client_scripts {
  'client/flashlight_cl.lua'
}

server_scripts {
  'server/flashlight_sv.lua'
}

files {
  'stream/flashlight_corona_prop.ytyp',
  'stream/flashlight_corona_prop.ydr'
}

data_file 'DLC_ITYP_REQUEST' 'stream/flashlight_corona_prop.ytyp'
