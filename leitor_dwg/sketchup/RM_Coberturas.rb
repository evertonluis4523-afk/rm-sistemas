# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module RM_Estruturas
  module Coberturas
    unless file_loaded?(__FILE__)
      extension = SketchupExtension.new('RM Coberturas', 'RM_Coberturas/main')
      extension.description = 'Exporta faces 3D de coberturas e fechamentos para o sistema RM Estruturas.'
      extension.version = '1.2.6'
      extension.creator = 'RM Estruturas Pré-Fabricadas'
      extension.copyright = '2026 RM Estruturas'
      Sketchup.register_extension(extension, true)
      file_loaded(__FILE__)
    end
  end
end
