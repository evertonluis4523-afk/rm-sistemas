# RM Cenas -- exporta todas as cenas do modelo em PNG, uma imagem por cena,
# para a aba Imagens do sistema de Propostas.
#
# Feita para os problemas que apareceram com as extensões prontas:
#   - tamanho fixo 16:9 saía com as faixas cinza da cena: aqui a imagem
#     sai na proporção da própria cena (ou da tela, se a cena não tem uma);
#   - 4K com suavização saía escura no vídeo integrado: a largura e a
#     suavização são escolhas;
#   - fundo do estilo cinza/azulado: sai transparente, e o sistema põe o
#     branco do papel;
#   - sol cena por cena: dá para usar as sombras de agora em todas;
#   - "Qualidade máxima" (o padrão): o acabamento que testamos para a
#     proposta -- texturas, arestas finas por material, perfil fino, sombras
#     só nas faces (sem a mancha no chão), sol nas faces, sem céu nem chão,
#     oclusão de ambiente quando a versão tem -- igual em todas as cenas,
#     sem mudar o estilo nem as cenas.
# Tudo o que muda para exportar volta como estava no fim, mesmo com erro.
# Teste: propostas_rm/sketchup/testes/exportar_cenas.rb.
require 'sketchup.rb'

module RM_Cenas
  EXTENSION_VERSION = '1.4.1'
  LARGURAS = %w[1920 3000 3840].freeze
  FUNDO_TRANSP = 'Transparente (fica branco no sistema)'.freeze
  FUNDO_ESTILO = 'Como está no estilo'.freeze
  SOMBRA_CENA = 'As de cada cena'.freeze
  SOMBRA_AGORA = 'As de agora em todas as cenas'.freeze
  CENAS_TODAS = 'Todas as cenas'.freeze
  CENAS_ATUAL = 'Só a vista atual (sem trocar de cena)'.freeze
  ESPERA = 1.5
  QUAL_MAX = 'Máxima (para a proposta)'.freeze
  QUAL_MODELO = 'Como está no modelo'.freeze

  # o acabamento da "Qualidade máxima"; chave que a versão do SketchUp não
  # tem (a oclusão de ambiente só existe nas mais novas) fica de fora
  ESTILO_MAX = {
    'RenderMode' => 2, 'Texture' => true,
    'EdgeDisplayMode' => 1, 'EdgeColorMode' => 1, 'DrawSilhouettes' => true, 'SilhouetteWidth' => 1,
    'DrawDepthQue' => false, 'ExtendLines' => false, 'DrawLineEnds' => false, 'JitterEdges' => false, 'DrawBackEdges' => false,
    'DrawHorizon' => false, 'DrawGround' => false, 'DisplayWatermarks' => false, 'MaterialTransparency' => true,
    'AmbientOcclusion' => true
  }.freeze
  SOMBRA_MAX = {
    'DisplayShadows' => true, 'UseSunForAllShading' => true, 'Light' => 80, 'Dark' => 45,
    'DisplayOnAllFaces' => true, 'DisplayOnGroundPlane' => false, 'EdgesCastShadows' => false
  }.freeze

  extend self

  # largura x altura na proporção da cena (câmera com proporção fixa) ou da tela
  def tamanho(view, largura)
    cam = view.camera
    ar = cam.respond_to?(:aspect_ratio) ? cam.aspect_ratio.to_f : 0.0
    ar = view.vpwidth.to_f / view.vpheight.to_f if ar <= 0 && view.vpheight.to_i > 0
    ar = 16.0 / 9.0 if ar <= 0
    [largura.to_i, (largura.to_i / ar).round]
  end

  # "01 - Fachada frontal.png": numerado na ordem das cenas, sem caractere proibido
  def nome_arquivo(indice, total, nome)
    casas = [2, total.to_s.length].max
    limpo = nome.to_s.gsub(%r{[\\/:*?"<>|]}, '_').strip
    limpo = 'Cena' if limpo.empty?
    format("%0#{casas}d - %s.png", indice + 1, limpo)
  end

  # aplica os valores que a versão conhece (chave que ela não tem fica de fora)
  def aplica(opcoes, valores)
    conhecidas = opcoes.respond_to?(:keys) ? opcoes.keys : []
    valores.each do |k, v|
      next unless conhecidas.include?(k)
      begin
        opcoes[k] = v
      rescue StandardError
        nil
      end
    end
  end

  # o retrato de TODAS as opções de agora: trocar de cena reaplica o estilo e
  # o sol guardados nela, e o que estava na tela (mesmo sem salvar na cena)
  # tem de voltar igual no fim
  def retrato(opcoes)
    (opcoes.respond_to?(:keys) ? opcoes.keys : []).each_with_object({}) { |k, h| h[k] = opcoes[k] }
  end

  def copia_camera(c)
    Sketchup::Camera.new(c.eye, c.target, c.up, c.perspective?, c.fov)
  rescue StandardError
    c
  end

  def devolve(opcoes, antes)
    antes.each do |k, v|
      begin
        opcoes[k] = v
      rescue StandardError
        nil
      end
    end
  end

  # roda o bloco depois de "seg" segundos devolvendo o controle ao SketchUp
  # (é nesse tempo que ele termina de desenhar a cena); 0 = já. O relógio é
  # parado antes de rodar: no SketchUp, um aviso aberto dentro do bloco faz
  # o relógio disparar de novo (o aviso do fim se repetia).
  def depois(seg, &b)
    if seg.to_f > 0 && defined?(UI) && UI.respond_to?(:start_timer)
      id = nil
      id = UI.start_timer(seg.to_f, false) do
        UI.stop_timer(id) if id && UI.respond_to?(:stop_timer)
        b.call
      end
    else
      b.call
    end
  end

  def status(txt)
    Sketchup.status_text = txt if Sketchup.respond_to?(:status_text=)
  end

  # Exporta e devolve a lista de arquivos (com espera 0, já completa).
  # espera > 0: depois de trocar de cena, devolve o controle ao SketchUp por
  # esse tempo antes de gravar -- trocar de cena e gravar no mesmo instante
  # pegava a cena ainda sendo desenhada (imagem escura). No fim chama o bloco
  # com (arquivos, erro). Só a vista atual: grava a tela sem trocar de cena.
  def exportar(pasta, largura: 3000, suavizar: true, transparente: true, sombras_agora: false, qualidade_max: false,
               espera: 0, so_atual: false, &fim)
    model = Sketchup.active_model
    view = model.active_view
    pages = model.pages
    opcoes = model.options['PageOptions']
    st = {
      transicao: opcoes['ShowTransition'], cena: pages.selected_page,
      sombras: pages.map { |p| [p, p.use_shadow_info?] },
      estilos: pages.map { |p| [p, p.respond_to?(:use_rendering_options?) ? p.use_rendering_options? : nil] },
      # a cena também guarda o ESTILO (céu, chão, fundo): na qualidade máxima ele não volta
      usa_estilo: pages.map { |p| [p, p.respond_to?(:use_style?) ? p.use_style? : nil] },
      estilo: retrato(model.rendering_options), sol: retrato(model.shadow_info),
      camera: copia_camera(view.camera), feito: false
    }
    gravados = []
    termina = lambda do |erro|
      next if st[:avisou]
      unless st[:feito]
        st[:feito] = true
        st[:estilos].each { |p, v| p.use_rendering_options = v unless v.nil? }
        st[:usa_estilo].each { |p, v| p.use_style = v unless v.nil? }
        st[:sombras].each { |p, v| p.use_shadow_info = v }
        pages.selected_page = st[:cena] if st[:cena] && !so_atual
        opcoes['ShowTransition'] = st[:transicao]
        # a tela volta como estava, mesmo o que não foi salvo na cena
        devolve(model.rendering_options, st[:estilo])
        devolve(model.shadow_info, st[:sol])
        view.camera = st[:camera] if st[:camera]
        model.abort_operation
        status('')
      end
      st[:avisou] = true if fim
      if fim then fim.call(gravados, erro)
      elsif erro then raise erro
      end
    end
    model.start_operation('RM Cenas: exportar', true)
    lista = so_atual ? [] : pages.to_a
    acabamento = lambda do
      next unless qualidade_max
      aplica(model.rendering_options, ESTILO_MAX)
      aplica(model.shadow_info, SOMBRA_MAX)
    end
    passo = lambda do |i|
      begin
        if lista.empty?
          gravados << grava(view, File.join(pasta, nome_arquivo(0, 1, 'Vista atual')), largura, suavizar, transparente)
          next termina.call(nil)
        end
        next termina.call(nil) if i >= lista.size
        p = lista[i]
        status("RM Cenas: #{i + 1} de #{lista.size} -- #{p.name}")
        pages.selected_page = p
        view.camera = p.camera if p.respond_to?(:use_camera?) && p.use_camera?
        acabamento.call   # por garantia: o acabamento de novo, depois de a cena entrar
        view.refresh if view.respond_to?(:refresh)
        depois(espera) do
          begin
            acabamento.call
            view.refresh if view.respond_to?(:refresh)
            gravados << grava(view, File.join(pasta, nome_arquivo(i, lista.size, p.name)), largura, suavizar, transparente)
            passo.call(i + 1)
          rescue StandardError => e
            termina.call(e)
          end
        end
      rescue StandardError => e
        termina.call(e)
      end
    end
    begin
      opcoes['ShowTransition'] = false
      pages.each { |p| p.use_shadow_info = false } if (sombras_agora || qualidade_max) && !so_atual
      if qualidade_max
        unless so_atual
          pages.each do |p|
            p.use_rendering_options = false if p.respond_to?(:use_rendering_options=)
            p.use_style = false if p.respond_to?(:use_style=)
          end
        end
        acabamento.call
      end
    rescue StandardError => e
      return termina.call(e)
    end
    passo.call(0)
    gravados
  end

  # grava pelo MESMO exportador do "Arquivo > Exportar > Gráfico 2D": o
  # view.write_image (o que as extensões prontas usam) saía escuro em alguns
  # computadores, e o Exportar 2D saía certo. O write_image fica de reserva.
  def grava(view, arquivo, largura, suavizar, transparente)
    w, h = tamanho(view, largura)
    ok = begin
      Sketchup.active_model.export(arquivo, show_summary: false, width: w, height: h,
                                            antialias: suavizar ? true : false, transparent: transparente ? true : false)
    rescue StandardError
      false
    end
    unless ok
      view.write_image(filename: arquivo, width: w, height: h, antialias: suavizar ? true : false,
                       transparent: transparente ? true : false)
    end
    arquivo
  end

  def lembra(chave, padrao)
    Sketchup.read_default('RM_Cenas', chave, padrao)
  end

  def dialogo
    model = Sketchup.active_model
    return UI.messagebox('Abra um modelo antes.') unless model
    escolhas = UI.inputbox(
      ['Exportar', 'Qualidade', 'Largura (px)', 'Suavização', 'Fundo', 'Sombras (só em "Como está")'],
      [lembra('cenas', CENAS_TODAS), lembra('qualidade', QUAL_MAX), lembra('largura', '3000'), lembra('suavizar', 'Sim'), lembra('fundo', FUNDO_TRANSP), lembra('sombras', SOMBRA_CENA)],
      [[CENAS_TODAS, CENAS_ATUAL].join('|'), [QUAL_MAX, QUAL_MODELO].join('|'), LARGURAS.join('|'), 'Sim|Não', [FUNDO_TRANSP, FUNDO_ESTILO].join('|'), [SOMBRA_CENA, SOMBRA_AGORA].join('|')],
      'RM Cenas: exportar as cenas'
    )
    return unless escolhas
    cenas, qualidade, largura, suav, fundo, sombras = escolhas
    { 'cenas' => cenas, 'qualidade' => qualidade, 'largura' => largura, 'suavizar' => suav, 'fundo' => fundo, 'sombras' => sombras }.each { |k, v| Sketchup.write_default('RM_Cenas', k, v) }
    inicio = model.path.to_s.empty? ? nil : File.dirname(model.path)
    pasta = UI.select_directory(inicio ? { title: 'Pasta para salvar as imagens', directory: inicio } : { title: 'Pasta para salvar as imagens' })
    return unless pasta
    exportar(pasta, largura: largura.to_i, suavizar: suav == 'Sim', transparente: fundo == FUNDO_TRANSP,
                    sombras_agora: sombras == SOMBRA_AGORA, qualidade_max: qualidade == QUAL_MAX,
                    so_atual: cenas == CENAS_ATUAL, espera: ESPERA) do |arqs, erro|
      if erro
        UI.messagebox("Não consegui exportar: #{erro.message}")
      else
        UI.messagebox("#{arqs.size} #{arqs.size == 1 ? 'imagem salva' : 'imagens salvas'} em:\n#{pasta}\n\n" \
                      "No sistema de Propostas: aba Imagens, \"Trocar imagem\" em cada bloco (ou \"Adicionar imagens\").\n\n" \
                      'Se sair escura: teste "Só a vista atual" e a suavização em "Não", e conte como saiu.')
      end
    end
  rescue StandardError => e
    UI.messagebox("Não consegui exportar: #{e.message}")
  end

  def ajuda
    UI.messagebox(
      "RM Cenas #{EXTENSION_VERSION}\n\n" \
      "Exporta todas as cenas do modelo em PNG, uma imagem por cena, numeradas na ordem das cenas.\n\n" \
      "  - Qualidade máxima (o padrão): texturas, arestas finas, sombras e sol nas faces, sem céu nem chão, igual em todas as cenas. O sol é o da hora de agora (Janela > Sombras): escolha uma hora em que a fachada fica clara.\n" \
      "  - Largura: 3000 px é o bom para o papel A4.\n" \
      "  - Fundo transparente: no sistema de Propostas vira o branco do papel.\n" \
      "  - Sombras \"as de agora em todas\": usa o sol e a hora de agora em todas as cenas, sem mudar as cenas.\n" \
      "  - A imagem sai na proporção da cena, sem as faixas cinza.\n\n" \
      'O modelo e as cenas ficam como estavam.'
    )
  end

  unless file_loaded?(__FILE__)
    menu = begin
      UI.menu('Extensions')
    rescue StandardError
      UI.menu('Plugins')
    end.add_submenu('RM Cenas')
    menu.add_item('Exportar todas as cenas…') { dialogo }
    menu.add_item('Como usar') { ajuda }
    file_loaded(__FILE__)
  end
end
