require 'sketchup'

module RM_Estruturas
  def self.marcar_ignorar_pu(valor)
    model = Sketchup.active_model
    itens = model.selection.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    if itens.empty?
      UI.messagebox('Selecione o grupo ou componente do chão e tente novamente.')
      return
    end
    model.start_operation('Alterar leitura de PU', true)
    begin
      itens.each { |e| e.set_attribute('RM_Estruturas_PU', 'ignorar', valor) }
      model.commit_operation
    rescue StandardError => erro
      model.abort_operation
      UI.messagebox("Erro ao alterar leitura: #{erro.message}")
      return
    end
    UI.messagebox(valor ? 'Seleção ignorada no PU. Exporte novamente os JSONs.' : 'Seleção habilitada no PU. Exporte novamente os JSONs.')
  end

  unless file_loaded?(__FILE__)

    SCRIPTS_DIR = File.dirname(__FILE__)

    menu = UI.menu('Extensões').add_submenu('RM Estruturas PU')

    menu.add_item('📊  Exportar Medição PU  (→ Sistema PU)') do
      load File.join(SCRIPTS_DIR, 'RM_ExportarPU.rb')
    end

    menu.add_item('📏  Exportar Linhas PU  (→ Viewer 3D)') do
      load File.join(SCRIPTS_DIR, 'RM_ExportarLinhasPU.rb')
    end

    menu.add_item('Ignorar seleção na leitura de PU (chão)') do
      marcar_ignorar_pu(true)
    end
    menu.add_item('Voltar a ler seleção no PU') do
      marcar_ignorar_pu(false)
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
