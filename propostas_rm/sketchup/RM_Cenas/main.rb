# RM Cenas -- exporta todas as cenas do modelo em PNG, uma imagem por cena,
# para a aba Imagens do sistema de Propostas.
#
# Feita para os problemas que apareceram com as extensões prontas:
#   - tamanho fixo 16:9 saía com as faixas cinza da cena: aqui a imagem
#     sai na proporção da própria cena (ou da tela, se a cena não tem uma);
#   - 4K com suavização saía escura no vídeo integrado: a largura e a
#     suavização são escolhas;
#   - fundo do estilo cinza/azulado: sai branco como o papel (o fundo
#     transparente fica como opção: em alguns computadores ele escurecia);
#   - sol cena por cena: dá para usar as sombras de agora em todas;
#   - "Qualidade máxima" (o padrão): o acabamento que testamos para a
#     proposta -- texturas, arestas finas por material, perfil fino, sombras
#     só nas faces (sem a mancha no chão), sol nas faces, sem céu nem chão,
#     oclusão de ambiente quando a versão tem -- igual em todas as cenas,
#     sem mudar o estilo nem as cenas.
#   - imagem com 1/4 do brilho (o branco saía 64, mesmo sem suavizar) só
#     quando gravada maior que a tela, na placa integrada; o Exportar 2D, no
#     tamanho da tela, saía certo. A extensão mede a 1ª imagem e, se saiu
#     escura, tenta sem suavizar e depois no tamanho da tela, e segue com a
#     primeira forma que sair clara;
#   - imagem escura só pela extensão: o "Diagnóstico" grava a vista atual de
#     várias formas (e um .txt com o que estava ligado) para achar a causa.
# Tudo o que muda para exportar volta como estava no fim, mesmo com erro.
# Teste: propostas_rm/sketchup/testes/exportar_cenas.rb.
require 'sketchup.rb'

module RM_Cenas
  EXTENSION_VERSION = '1.6.0'
  LARGURAS = %w[1920 3000 3840].freeze
  FUNDO_BRANCO = 'Branco (como o papel)'.freeze
  FUNDO_TRANSP = 'Transparente'.freeze
  FUNDO_ESTILO = 'Como está no estilo'.freeze
  SOMBRA_CENA = 'As de cada cena'.freeze
  SOMBRA_AGORA = 'As de agora em todas as cenas'.freeze
  CENAS_TODAS = 'Todas as cenas'.freeze
  CENAS_ATUAL = 'Só a vista atual (sem trocar de cena)'.freeze
  CENAS_DIAG = 'Diagnóstico: a vista atual de várias formas'.freeze
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

  # o Diagnóstico: a vista atual gravada de cada forma, uma diferença por vez
  # [nome, por onde grava, largura (:tela = a da tela), suavizar, transparente, ajuste]
  # Nomes SEM acento: no Windows, nome com acento numa pasta com acento
  # (C:/Users/Usuário) podia parar tudo antes da primeira imagem.
  DIAG = [
    ['D1 - opcoes do Exportar 2D', :dialogo, nil, nil, nil, {}],
    ['D2 - tamanho da tela, sem suavizar', :exportador, :tela, false, false, {}],
    ['D3 - 3000, sem suavizar', :exportador, 3000, false, false, {}],
    ['D4 - 3000, suavizado', :exportador, 3000, true, false, {}],
    ['D5 - 3000, suavizado, fundo transparente', :exportador, 3000, true, true, {}],
    ['D6 - 3000, suavizado, sem oclusao de ambiente', :exportador, 3000, true, false, { 'AmbientOcclusion' => false }],
    ['D7 - 3000, suavizado, pelo write_image', :write_image, 3000, true, false, {}],
    ['D8 - qualidade maxima, fundo branco, 3000, suavizado', :exportador, 3000, true, false, :max]
  ].freeze
  DIAG_TXT = 'D0 - diagnostico.txt'.freeze
  # o que vai no .txt do Diagnóstico (nada do cliente: nem o nome do arquivo)
  DIAG_ESTILO = %w[RenderMode Texture AmbientOcclusion DrawHorizon DrawGround BackgroundColor SkyColor GroundColor
                   EdgeDisplayMode DrawSilhouettes MaterialTransparency].freeze
  DIAG_SOL = %w[DisplayShadows UseSunForAllShading ShadowTime Light Dark DisplayOnAllFaces DisplayOnGroundPlane].freeze

  extend self

  def branco
    Sketchup::Color.new(255, 255, 255)
  end

  # largura x altura na proporção da cena (câmera com proporção fixa) ou da tela
  def tamanho(view, largura)
    [largura.to_i, (largura.to_i / proporcao(view)).round]
  end

  def proporcao(view)
    cam = view.camera
    ar = cam.respond_to?(:aspect_ratio) ? cam.aspect_ratio.to_f : 0.0
    ar = view.vpwidth.to_f / view.vpheight.to_f if ar <= 0 && view.vpheight.to_i > 0
    ar <= 0 ? 16.0 / 9.0 : ar
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
               espera: 0, so_atual: false, fundo_branco: false, &fim)
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
    @forma = nil
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
      aplica(model.rendering_options, 'BackgroundColor' => branco) if fundo_branco
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
      end
      acabamento.call
    rescue StandardError => e
      return termina.call(e)
    end
    passo.call(0)
    gravados
  end

  # grava pelo MESMO exportador do "Arquivo > Exportar > Gráfico 2D": o
  # view.write_image (o que as extensões prontas usam) saía escuro em alguns
  # computadores, e o Exportar 2D saía certo. O write_image fica de reserva.
  #
  # Na placa integrada, a imagem maior que a tela saía com 1/4 do brilho (o
  # branco virava 64), com ou sem suavizar. A 1ª imagem é medida; se saiu
  # escura, tenta as outras formas, em ordem, e segue com a primeira que sair
  # clara. Se nenhuma sair, fica :nada (e o aviso manda rodar o Diagnóstico).
  def grava(view, arquivo, largura, suavizar, transparente)
    forma = @forma
    if forma.nil?
      grava_forma(view, arquivo, largura, suavizar, transparente, :escolhida)
      return arquivo unless escura?(arquivo)
      tentativas = suavizar ? %i[sem_suavizar tela tela_sem_suavizar] : %i[tela]
      @forma = :nada
      tentativas.each do |t|
        grava_forma(view, arquivo, largura, suavizar, transparente, t)
        next if escura?(arquivo)
        @forma = t
        break
      end
      return arquivo
    end
    grava_forma(view, arquivo, largura, suavizar, transparente, forma == :nada ? :escolhida : forma)
  end

  # nil (gravou como escolhido), :sem_suavizar, :tela, :tela_sem_suavizar ou :nada
  def forma_usada
    @forma
  end

  def grava_forma(view, arquivo, largura, suavizar, transparente, forma)
    w, h = forma.to_s.start_with?('tela') ? tamanho_tela(view) : tamanho(view, largura)
    aa = suavizar && !%i[sem_suavizar tela_sem_suavizar].include?(forma)
    grava_wh(view, arquivo, w, h, aa, transparente)
  end

  # o maior tamanho na proporção da cena que cabe na tela (como o Exportar 2D
  # com "Usar tamanho da vista")
  def tamanho_tela(view)
    ar = proporcao(view)
    w = view.vpwidth.to_i
    h = view.vpheight.to_i
    w / ar <= h ? [w, (w / ar).round] : [[(h * ar).round, w].min, h]
  end

  # o ponto mais claro da imagem (0 a 255), olhando uma grade de 15 x 15
  # pontos; nil quando não dá para ler (SketchUp antigo, arquivo não gravou)
  def brilho_max(arquivo)
    return nil unless defined?(Sketchup::ImageRep) && File.exist?(arquivo.to_s)
    rep = Sketchup::ImageRep.new
    rep.load_file(arquivo)
    maior = nil
    (1..15).each do |a|
      (1..15).each do |b|
        c = rep.color_at_uv(a / 16.0, b / 16.0)
        next if c.respond_to?(:alpha) && c.alpha && c.alpha.to_i.zero?   # transparente: não conta
        maior = [maior || 0, c.red.to_i, c.green.to_i, c.blue.to_i].max
      end
    end
    maior
  rescue StandardError
    nil
  end

  # com 1/4 do brilho, nem o ponto mais claro passa de ~64 (o branco)
  def escura?(arquivo)
    b = brilho_max(arquivo)
    !b.nil? && b <= 72
  end

  def grava_wh(view, arquivo, w, h, suavizar, transparente)
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

  # grava a vista atual de cada forma do DIAG, sem trocar de cena, e escreve o
  # "D0 - diagnostico.txt" ANTES da primeira imagem e de novo a cada passo (com
  # o tempo e o erro de cada uma): se algo parar no meio, o relatório fica.
  # Se a pasta escolhida não aceitar, o relatório vai para a pasta do usuário.
  # Devolve [linhas do resultado, onde ficou o relatório]. O estilo e o sol
  # voltam como estavam.
  def diagnostico(pasta)
    model = Sketchup.active_model
    view = model.active_view
    ro = model.rendering_options
    si = model.shadow_info
    estilo = retrato(ro)
    sol = retrato(si)
    linhas = []
    cabeca = ["RM Cenas #{EXTENSION_VERSION}#{Sketchup.respond_to?(:version) ? " - SketchUp #{Sketchup.version}" : ''}",
              "Tela: #{view.vpwidth} x #{view.vpheight}",
              'Estilo: ' + DIAG_ESTILO.select { |k| estilo.key?(k) }.map { |k| "#{k}=#{estilo[k]}" }.join('; '),
              'Sol: ' + DIAG_SOL.select { |k| sol.key?(k) }.map { |k| "#{k}=#{sol[k]}" }.join('; '), '']
    relatorio = nil
    escreve = lambda do
      texto = (linhas + [''] + cabeca).map { |l| l.to_s.dup.force_encoding('UTF-8').scrub('?') }.join("\r\n")
      [pasta, File.join(Dir.home, 'Desktop'), Dir.home].each do |dir|
        begin
          alvo = File.join(dir.to_s, DIAG_TXT)
          File.open(alvo, 'wb') { |f| f.write(texto) }
          relatorio = alvo
          break
        rescue StandardError, SystemCallError
          next
        end
      end
    end
    escreve.call
    model.start_operation('RM Cenas: diagnóstico', true)
    begin
      DIAG.each_with_index do |(nome, via, larg, suav, transp, ajuste), n|
        status("RM Cenas: diagnóstico #{n + 1} de #{DIAG.size} (pode levar alguns minutos)")
        inicio = Time.now
        w = h = nil
        resultado = begin
          devolve(ro, estilo)
          devolve(si, sol)
          if ajuste == :max
            aplica(ro, ESTILO_MAX)
            aplica(si, SOMBRA_MAX)
            aplica(ro, 'BackgroundColor' => branco)
          else
            aplica(ro, ajuste)
          end
          view.refresh if view.respond_to?(:refresh)
          arquivo = File.join(pasta, "#{nome}.png")
          w, h = larg == :tela ? [view.vpwidth, view.vpheight] : tamanho(view, larg || 0)
          ok = case via
               when :dialogo then model.export(arquivo, false)
               when :write_image then view.write_image(filename: arquivo, width: w, height: h, antialias: suav, transparent: transp)
               else model.export(arquivo, show_summary: false, width: w, height: h, antialias: suav, transparent: transp)
               end
          b = ok ? brilho_max(arquivo) : nil
          (ok ? 'gravou' : 'o SketchUp recusou') + (b ? ", ponto mais claro #{b} de 255#{b <= 72 ? ' (ESCURA)' : ''}" : '')
        rescue StandardError => e
          "erro: #{e.class}: #{e.message}"
        end
        linhas << "#{nome}: #{resultado}#{larg ? " (#{w} x #{h})" : ''} em #{(Time.now - inicio).round(1)} s"
        escreve.call
      end
    rescue StandardError => e
      linhas << "parou: #{e.class}: #{e.message} #{Array(e.backtrace).first(3).join(' | ')}"
      escreve.call
    ensure
      devolve(ro, estilo)
      devolve(si, sol)
      model.abort_operation
      view.refresh if view.respond_to?(:refresh)
      status('')
    end
    [linhas, relatorio]
  end

  def lembra(chave, padrao)
    Sketchup.read_default('RM_Cenas', chave, padrao)
  end

  def dialogo
    model = Sketchup.active_model
    return UI.messagebox('Abra um modelo antes.') unless model
    escolhas = UI.inputbox(
      ['Exportar', 'Qualidade', 'Largura (px)', 'Suavização', 'Fundo', 'Sombras (só em "Como está")'],
      [lembra('cenas', CENAS_TODAS), lembra('qualidade', QUAL_MAX), lembra('largura', '3000'), lembra('suavizar', 'Sim'), lembra('fundo2', FUNDO_BRANCO), lembra('sombras', SOMBRA_CENA)],
      [[CENAS_TODAS, CENAS_ATUAL, CENAS_DIAG].join('|'), [QUAL_MAX, QUAL_MODELO].join('|'), LARGURAS.join('|'), 'Sim|Não', [FUNDO_BRANCO, FUNDO_TRANSP, FUNDO_ESTILO].join('|'), [SOMBRA_CENA, SOMBRA_AGORA].join('|')],
      'RM Cenas: exportar as cenas'
    )
    return unless escolhas
    cenas, qualidade, largura, suav, fundo, sombras = escolhas
    { 'cenas' => cenas, 'qualidade' => qualidade, 'largura' => largura, 'suavizar' => suav, 'fundo2' => fundo, 'sombras' => sombras }.each { |k, v| Sketchup.write_default('RM_Cenas', k, v) }
    inicio = model.path.to_s.empty? ? nil : File.dirname(model.path)
    pasta = UI.select_directory(inicio ? { title: 'Pasta para salvar as imagens', directory: inicio } : { title: 'Pasta para salvar as imagens' })
    return unless pasta
    if cenas == CENAS_DIAG
      linhas, relatorio = diagnostico(pasta)
      return UI.messagebox("RM Cenas #{EXTENSION_VERSION}: diagnóstico pronto.\n\n#{linhas.join("\n")}\n\n" \
                           "Relatório: #{relatorio || 'não consegui gravar (copie esta mensagem)'}\n\n" \
                           'Abra as imagens D1 a D8 e conte quais saíram escuras (ou mande a pasta com o relatório).')
    end
    exportar(pasta, largura: largura.to_i, suavizar: suav == 'Sim', transparente: fundo == FUNDO_TRANSP, fundo_branco: fundo == FUNDO_BRANCO,
                    sombras_agora: sombras == SOMBRA_AGORA, qualidade_max: qualidade == QUAL_MAX,
                    so_atual: cenas == CENAS_ATUAL, espera: ESPERA) do |arqs, erro|
      if erro
        UI.messagebox("Não consegui exportar: #{erro.message}")
      else
        aviso = case forma_usada
                when :sem_suavizar
                  Sketchup.write_default('RM_Cenas', 'suavizar', 'Não')
                  "A suavização saía escura neste computador: gravei sem suavizar (da próxima vez já vem \"Não\").\n\n"
                when :tela, :tela_sem_suavizar
                  w, = tamanho_tela(model.active_view)
                  "Neste computador, a imagem maior que a tela saía escura: gravei no tamanho da tela (#{w} px de largura), " \
                  "como o Exportar 2D.\n\n"
                when :nada
                  "ATENÇÃO: as imagens saíram escuras de todas as formas que tentei. Rode Extensões > RM Cenas > " \
                  "\"Diagnóstico da imagem escura\" e mande o relatório.\n\n"
                else ''
                end
        UI.messagebox("#{arqs.size} #{arqs.size == 1 ? 'imagem salva' : 'imagens salvas'} em:\n#{pasta}\n\n#{aviso}" \
                      "No sistema de Propostas: aba Imagens, \"Trocar imagem\" em cada bloco (ou \"Adicionar imagens\").\n\n" \
                      'Se ainda sair escura: Extensões > RM Cenas > "Diagnóstico da imagem escura".')
      end
    end
  rescue StandardError => e
    UI.messagebox("Não consegui exportar: #{e.message}")
  end

  # o Diagnóstico direto no menu (sem passar pelas escolhas da exportação)
  def diagnostico_menu
    return UI.messagebox('Abra um modelo antes.') unless Sketchup.active_model
    pasta = UI.select_directory(title: 'Pasta vazia para o diagnóstico')
    return unless pasta
    linhas, relatorio = diagnostico(pasta)
    UI.messagebox("RM Cenas #{EXTENSION_VERSION}: diagnóstico pronto.\n\n#{linhas.join("\n")}\n\n" \
                  "Relatório: #{relatorio || 'não consegui gravar (copie esta mensagem)'}\n\n" \
                  'Abra as imagens D1 a D8 e conte quais saíram escuras (ou mande a pasta com o relatório).')
  rescue StandardError => e
    UI.messagebox("RM Cenas #{EXTENSION_VERSION}: o diagnóstico parou: #{e.class}: #{e.message}")
  end

  def ajuda
    UI.messagebox(
      "RM Cenas #{EXTENSION_VERSION}\n\n" \
      "Exporta todas as cenas do modelo em PNG, uma imagem por cena, numeradas na ordem das cenas.\n\n" \
      "  - Qualidade máxima (o padrão): texturas, arestas finas, sombras e sol nas faces, sem céu nem chão, igual em todas as cenas. O sol é o da hora de agora (Janela > Sombras): escolha uma hora em que a fachada fica clara.\n" \
      "  - Largura: 3000 px é o bom para o papel A4.\n" \
      "  - Fundo branco (o padrão): como o papel da proposta. O transparente fica de opção.\n" \
      "  - Imagem escura: a extensão mede a 1ª imagem e, se saiu escura, tenta sem suavizar e no tamanho da tela, e avisa.\n" \
      "  - Ainda escura? \"Diagnóstico da imagem escura\" grava a vista atual de 8 formas (D1 a D8) e um relatório.\n" \
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
    menu.add_item('Diagnóstico da imagem escura…') { diagnostico_menu }
    menu.add_item('Como usar') { ajuda }
    file_loaded(__FILE__)
  end
end
