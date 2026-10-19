require 'sketchup'

module RM_Estruturas
  unless file_loaded?(__FILE__)

    SCRIPTS_DIR = File.dirname(__FILE__)

    menu = UI.menu('Extensões').add_submenu('RM Estruturas PU')

    menu.add_item('📊  Exportar Medição PU  (→ Sistema PU)') do
      load File.join(SCRIPTS_DIR, 'RM_ExportarPU.rb')
    end

    menu.add_item('📏  Exportar Linhas PU  (→ Viewer 3D)') do
      load File.join(SCRIPTS_DIR, 'RM_ExportarLinhasPU.rb')
    end

    menu.add_separator

    menu.add_item('ℹ️  Sobre') do
      UI.messagebox(
        "RM Estruturas — Controle de PU\n\n" \
        "Scripts disponíveis:\n" \
        "  • Exportar Medição PU      → gera PU_*.json para o sistema\n" \
        "  • Exportar Linhas PU       → gera *_linhasPU.json para o viewer 3D\n" \
        "    (leva também as peças e a vista atual do SketchUp)\n\n" \
        "Para usar: abra o modelo → Extensões → RM Estruturas PU → escolha a ação.\n\n" \
        "RM Estruturas Pré-Fabricadas · Estrela/RS"
      )
    end

    file_loaded(__FILE__)
  end
end
