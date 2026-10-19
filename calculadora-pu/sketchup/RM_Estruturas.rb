require 'sketchup'
require 'extensions'

module RM_Estruturas
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(
      'RM Estruturas — Controle de PU',
      'RM_Estruturas/menu.rb'
    )
    ext.description = 'Scripts de exportação para o sistema de controle de aplicação de PU.' \
                      ' RM Estruturas Pré-Fabricadas.'
    ext.version     = '1.1.0'
    ext.copyright   = 'RM Estruturas Pré-Fabricadas'
    ext.creator     = 'RM Estruturas'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
