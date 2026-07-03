fx_version 'cerulean'
game 'gta5'

author 'DaveDev'
description "DaveDev's Immersive Flashlite - standalone flashlight"
version '1.0.0'

shared_scripts {
  'config.lua'
}

client_scripts {
  'client/modules/core.lua',
  'client/modules/state.lua',
  'client/modules/controls.lua',
  'client/modules/audio.lua',
  'client/modules/entities.lua',
  'client/modules/beam.lua',
  'client/modules/animation.lua',
  'client/modules/corona.lua',
  'client/modules/remote.lua',
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

escrow_ignore {
  'config.lua',
  'client/modules/*.lua',
  'README.md'
}
