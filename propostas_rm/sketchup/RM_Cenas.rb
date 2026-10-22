require 'sketchup.rb'
require 'extensions.rb'

# RM Cenas: exporta todas as cenas do modelo em PNG, uma imagem por cena,
# para a aba Imagens do sistema de Propostas. RM Estruturas Pré-Fabricadas.
module RM_Cenas
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('RM Cenas', File.join(__dir__, 'RM_Cenas', 'main.rb'))
    extension.description = 'Exporta todas as cenas em PNG (uma imagem por cena) para as imagens da proposta.'
    extension.version = '1.4.1'
    extension.creator = 'RM Estruturas'
    extension.copyright = 'RM Estruturas Pré-Fabricadas'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
