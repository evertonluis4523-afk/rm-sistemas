# ============================================================
#  RM Estruturas Pré-Fabricadas
#  Exportar ML → Controle de PU   (v6 – lógica completa)
#
#  PLACAS : ML = largura horizontal (ext+int por padrão)
#           Casos de placa lado único → editar no sistema
#
#  PILARES: ML = soma das coberturas Z por face
#           Cada face analisada independentemente
#           Vão livre (porta, abertura) excluído por face
#
#  VIGAS  : ML = trecho horizontal coberto por placas adjacentes
#           Segue o mesmo padrão do pilar
#
#  Como usar:
#    Extensões → RM Estruturas PU → Exportar Medição PU
#    No Controle de PU → "Importar" → selecione o JSON
# ============================================================
require 'json'

module RM_ExportarPU

  INCHES_TO_M  = 0.0254
  ADJACENCIA_M = 0.50    # distância máxima (m) para considerar adjacência

  KEYWORDS   = %w[placa pilar viga].freeze
  EXT_ARQ    = %w[.dwg .dxf .obj .dae .fbx .3ds .ifc .kmz .skp
                  .png .jpg .jpeg .bmp .tif .rvt].freeze
  SKIP_NOMES = %w[tesoura telhado escada porta janela vidro parafuso
                  chapa pino puxador fechadura alizar marco folha
                  niraj person people human car tree furniture].freeze

  # ── Classificação ──────────────────────────────────────────

  def self.estrutural?(nome)
    n = nome.downcase
    KEYWORDS.any? { |k| n.include?(k) }
  end

  def self.tipo(nome)
    n = nome.downcase
    return 'Pilar' if n.include?('pilar') || n.include?('coluna') || n.include?('poste')
    return 'Viga'  if n.include?('viga')  || n.include?('baldrame') || n.include?('travessa')
    'Placa'
  end

  def self.ignorar?(nome, ml)
    return true if ml < 0.05 || ml > 300.0
    return true if EXT_ARQ.include?(File.extname(nome.downcase))
    return true if SKIP_NOMES.any? { |k| nome.downcase.start_with?(k) }
    false
  end

  # ── Bounding box em world space ────────────────────────────
  # Retorna [x_min, x_max, y_min, y_max, z_min, z_max] em polegadas
  def self.world_bounds(defn, world_t)
    bb = defn.bounds
    corners = (0..7).map { |i| world_t * bb.corner(i) }
    xs = corners.map(&:x); ys = corners.map(&:y); zs = corners.map(&:z)
    [xs.min, xs.max, ys.min, ys.max, zs.min, zs.max]
  end

  # ── Mesclagem de intervalos ────────────────────────────────
  def self.merge_intervals(ivs)
    sorted = ivs.sort_by { |a, _| a }
    merged = [sorted.first.dup]
    sorted.drop(1).each do |iv|
      if iv[0] <= merged.last[1]
        merged.last[1] = [merged.last[1], iv[1]].max
      else
        merged << iv.dup
      end
    end
    merged
  end

  # ── Coleta recursiva ───────────────────────────────────────
  # Entra em qualquer ComponentInstance não-estrutural (Agrupar#N etc)
  # para encontrar elementos aninhados em qualquer profundidade
  def self.coletar_tudo(entities, pilares, placas, vigas,
                        parent_t = Geom::Transformation.new)
    entities.each do |e|
      case e
      when Sketchup::ComponentInstance
        nome    = e.definition.name.strip
        world_t = parent_t * e.transformation

        if estrutural?(nome)
          t      = tipo(nome)
          bounds = world_bounds(e.definition, world_t)
          rec    = { nome: nome.upcase, tipo: t, bounds: bounds }
          case t
          when 'Pilar' then pilares << rec
          when 'Viga'  then vigas   << rec
          else              placas  << rec
          end
        else
          # Não é estrutural → entra dentro para buscar elementos aninhados
          coletar_tudo(e.definition.entities, pilares, placas, vigas, world_t)
        end

      when Sketchup::Group
        coletar_tudo(e.entities, pilares, placas, vigas,
                     parent_t * e.transformation)
      end
    end
  end

  # ── ML do PILAR — análise por face ────────────────────────
  #
  # Cada face (+X, -X, +Y, -Y) é analisada independentemente.
  # Para cada face: calcula a união dos intervalos Z cobertos
  # pelas placas adjacentes a essa face.
  # ML total = soma das coberturas de todas as faces.
  # (Vão livre = Z não coberto por nenhuma placa = excluído)
  #
  def self.ml_pilar(pilar, placas)
    px0, px1, py0, py1, pz0, pz1 = pilar[:bounds]
    adj  = ADJACENCIA_M / INCHES_TO_M
    pcx  = (px0 + px1) / 2.0
    pcy  = (py0 + py1) / 2.0

    faces = { xp: [], xn: [], yp: [], yn: [] }

    placas.each do |pl|
      plx0, plx1, ply0, ply1, plz0, plz1 = pl[:bounds]

      x_gap = [plx0 - px1, px0 - plx1, 0].max
      y_gap = [ply0 - py1, py0 - ply1, 0].max
      next if x_gap > adj || y_gap > adj

      # Face = direção do centroide da placa em relação ao pilar
      dx = (plx0 + plx1) / 2.0 - pcx
      dy = (ply0 + ply1) / 2.0 - pcy
      face = if dx.abs >= dy.abs
               dx >= 0 ? :xp : :xn
             else
               dy >= 0 ? :yp : :yn
             end

      z0 = [plz0, pz0].max
      z1 = [plz1, pz1].min
      faces[face] << [z0, z1] if z1 > z0
    end

    total_m = 0.0; n_faces = 0
    faces.each do |_, ivs|
      next if ivs.empty?
      n_faces += 1
      total_m += merge_intervals(ivs).sum { |a, b| (b - a) * INCHES_TO_M }
    end

    pilar[:n_faces]  = n_faces
    pilar[:fallback] = (n_faces == 0)

    # Sem placas adjacentes → 0 (não leva PU; quem chama descarta)
    total_m.round(3)
  end

  # ── ML da VIGA ────────────────────────────────────────────
  #
  # A viga só conta a junção no seu LADO INFERIOR (Line C):
  # as placas que terminam ABAIXO da viga e encostam na sua
  # face inferior. Essa junção NÃO é contada pelas placas
  # (placas só contam a junta NA SUA BASE, não no topo).
  #
  # A junção NO TOPO da viga (Line D, onde placas superiores
  # assentam) NÃO é contada pela viga — já é contada pela
  # JUNTA INFERIOR de cada placa acima.
  #
  # Resultado:
  #   Viga de BASE (sem placas abaixo) → ML = 0, não entra no JSON
  #   Viga INTERMEDIÁRIA (placas abaixo) → ML = cobertura horizontal
  #
  def self.ml_viga(viga, placas)
    vx0, vx1, vy0, vy1, vz0, vz1 = viga[:bounds]
    adj     = ADJACENCIA_M / INCHES_TO_M
    vwx     = (vx1 - vx0).abs
    vwy     = (vy1 - vy0).abs
    along_x = vwx >= vwy
    viga_cz = (vz0 + vz1) / 2.0  # centro Z da viga (polegadas)

    covered = []
    placas.each do |pl|
      plx0, plx1, ply0, ply1, plz0, plz1 = pl[:bounds]

      # Adjacência vertical com a viga
      z_gap = [plz0 - vz1, vz0 - plz1, 0].max
      next if z_gap > adj

      # Só conta placas ABAIXO da viga (Line C)
      # Placas ACIMA já contam essa junção como sua própria junta inferior
      pl_cz = (plz0 + plz1) / 2.0
      next if pl_cz >= viga_cz

      if along_x
        y_gap = [ply0 - vy1, vy0 - ply1, 0].max
        next if y_gap > adj
        a0 = [plx0, vx0].max;  a1 = [plx1, vx1].min
        covered << [a0, a1] if a1 > a0
      else
        x_gap = [plx0 - vx1, vx0 - plx1, 0].max
        next if x_gap > adj
        a0 = [ply0, vy0].max;  a1 = [ply1, vy1].min
        covered << [a0, a1] if a1 > a0
      end
    end

    # Sem placas abaixo → viga de base → ML = 0
    # (a junção no topo da viga já é contada pela placa acima)
    viga[:fallback] = covered.empty?
    return 0.0 if covered.empty?

    merge_intervals(covered).sum { |a, b| (b - a) * INCHES_TO_M }.round(3)
  end

  # ── ML da PLACA — extensão horizontal ─────────────────────
  def self.ml_placa(bounds)
    x0, x1, y0, y1 = bounds
    wx = (x1 - x0).abs * INCHES_TO_M
    wy = (y1 - y0).abs * INCHES_TO_M
    [wx, wy].max.round(3)
  end

  # ── Sobreposição entre dois bounding boxes (0.0 a 1.0) ────
  # Retorna a fração do volume da menor bbox que está sobreposta pela outra.
  def self.overlap_ratio(a, b)
    ax0,ax1,ay0,ay1,az0,az1 = a
    bx0,bx1,by0,by1,bz0,bz1 = b
    ox = [[ax1,bx1].min - [ax0,bx0].max, 0].max
    oy = [[ay1,by1].min - [ay0,by0].max, 0].max
    oz = [[az1,bz1].min - [az0,bz0].max, 0].max
    overlap = ox * oy * oz
    vol_a = (ax1-ax0).abs * (ay1-ay0).abs * (az1-az0).abs
    vol_b = (bx1-bx0).abs * (by1-by0).abs * (bz1-bz0).abs
    min_v = [vol_a, vol_b].min
    return 0.0 if min_v < 1e-8
    (overlap / min_v).round(4)
  end

  # ── Ponto de entrada ───────────────────────────────────────
  def self.exportar
    model  = Sketchup.active_model
    pilares = []; placas = []; vigas = []
    coletar_tudo(model.entities, pilares, placas, vigas)

    if pilares.empty? && placas.empty? && vigas.empty?
      UI.messagebox("Nenhum componente estrutural encontrado.\n\n" \
                    "Verifique se os elementos têm 'placa', 'pilar' ou 'viga' no nome.")
      return
    end

    acum = {}

    # ── Pilares ──
    pilares.each do |p|
      ml_total = ml_pilar(p, placas)   # soma das coberturas por face
      n = p[:n_faces].to_i
      # Sem placa encostada não leva PU: o pilar fica fora (regra da RM).
      # Antes entrava pela altura inteira, como "pilar22".
      next if n == 0
      next if ignorar?(p[:nome], ml_total)

      if n >= 2
        # 2+ faces com placa → pilar22 (2 ext + 2 int)
        # ML por face = total / 2  → pilar22 (×4) dá o mesmo resultado que total × 2
        ml   = (ml_total / 2.0).round(3)
        app  = 'pilar22'
      else
        # Só 1 face com placa (lado de porta/abertura) → ext + int
        ml   = ml_total.round(3)
        app  = 'ext_int'
      end

      chave = "#{p[:nome]}|#{ml.round(2)}|#{app}"
      acum[chave] ||= { nome: p[:nome], tipo: 'Pilar', ml: ml, app: app,
                        n_faces: n, fallback: p[:fallback], count: 0, bboxes: [] }
      acum[chave][:count] += 1
      acum[chave][:bboxes] << p[:bounds]
    end

    # ── Placas ──
    placas.each do |r|
      ml    = ml_placa(r[:bounds])
      next if ignorar?(r[:nome], ml)
      chave = "#{r[:nome]}|#{ml.round(2)}"
      acum[chave] ||= { nome: r[:nome], tipo: 'Placa', ml: ml,
                        app: 'ext_int', count: 0, bboxes: [] }
      acum[chave][:count] += 1
      acum[chave][:bboxes] << r[:bounds]
    end

    # ── Vigas ──
    vigas.each do |v|
      ml    = ml_viga(v, placas)
      next if ignorar?(v[:nome], ml)
      chave = "#{v[:nome]}|#{ml.round(2)}"
      acum[chave] ||= { nome: v[:nome], tipo: 'Viga', ml: ml,
                        app: 'ext_int', fallback: v[:fallback],
                        count: 0, bboxes: [] }
      acum[chave][:count] += 1
      acum[chave][:bboxes] << v[:bounds]
    end

    # ── Detecção de duplicidade ────────────────────────────────
    # Compara cada par de instâncias de mesmo tipo no espaço 3D.
    # Se duas bboxes se sobrepõem > 90% do volume da menor → possível duplicata.
    todas_por_tipo = { 'Pilar' => [], 'Placa' => [], 'Viga' => [] }
    acum.each do |(chave, info)|
      info[:bboxes].each { |bb| todas_por_tipo[info[:tipo]] << { chave: chave, bb: bb } }
    end

    avisos_dup = []
    todas_por_tipo.each do |tipo, lista|
      lista.each_with_index do |a, i|
        lista[(i+1)..].each do |b|
          r = overlap_ratio(a[:bb], b[:bb])
          if r >= 0.90
            # Marca ambos os grupos como tendo possível duplicata
            [a[:chave], b[:chave]].each { |ch| acum[ch][:dup] = true if acum[ch] }
            nome_a = acum[a[:chave]] ? acum[a[:chave]][:nome] : a[:chave]
            nome_b = acum[b[:chave]] ? acum[b[:chave]][:nome] : b[:chave]
            unless nome_a == nome_b && acum[a[:chave]]&.dig(:count).to_i > 1
              # Só avisa se são nomes diferentes (mesmo nome no grupo é esperado)
              next if a[:chave] == b[:chave]
            end
            avisos_dup << "  ⚠ #{nome_a} ↔ #{nome_b} (sobreposição #{(r*100).round}%)"
          end
        end
      end
    end
    avisos_dup.uniq!

    # Ordena: Pilares → Placas → Vigas, depois nome
    ordem    = { 'Pilar' => 0, 'Placa' => 1, 'Viga' => 2 }
    ordenado = acum.sort_by { |(_, v)| [ordem[v[:tipo]], v[:nome]] }

    # Modelo ainda sem salvar não tem pasta: pergunta onde gravar.
    if model.path.to_s.empty?
      caminho = UI.savepanel('Salvar medição de PU', '', 'PU_Sem nome.json')
      return if caminho.nil? || caminho.to_s.empty?
    else
      caminho = File.join(File.dirname(model.path), "PU_#{File.basename(model.path, '.skp')}.json")
    end
    nome_arq  = File.basename(caminho)
    pasta     = File.dirname(caminho)
    nome_obra = File.basename(nome_arq, '.json').sub(/\APU_/, '').gsub(/[_\-]+/, ' ').strip

    # JSON pela biblioteca: aspas ou barra no nome não quebram mais o arquivo.
    elementos = ordenado.map do |(_, info)|
      # A aplicação calculada vai para o arquivo. Antes saía "ext_int" para
      # tudo: o pilar com placa em 2+ faces (ml = total/2, "pilar22") ficava
      # com METADE dos metros.
      e = { nome: info[:nome], tipo: info[:tipo], qtd: info[:count], ml: info[:ml].round(3), app: info[:app] || 'ext_int' }
      e[:dup] = true if info[:dup]
      e
    end
    dados = { obra: { nome: nome_obra, cliente: '', metragem: '', endereco: '', data: '' },
              precos: { ext: '2,00', int: '2,00' },
              elementos: elementos, arremates: [], cortes: [] }
    begin
      File.write(caminho, JSON.pretty_generate(dados), encoding: 'UTF-8')
    rescue => e
      UI.messagebox("Erro ao salvar:\n#{e.message}"); return
    end

    # ── Resumo diagnóstico ──
    resumo = ordenado.map do |(_, info)|
      nota = case info[:tipo]
             when 'Pilar'
               " ← #{info[:n_faces]} face(s) com placa"
             when 'Viga'
               info[:fallback] ? ' ⚠ sem placa adj. (comprimento total)' : ' ← coberto por placas'
             else ''
             end
      sprintf("  %-34s %3dx  %6.3f m  [%s]%s",
              info[:nome], info[:count], info[:ml], info[:tipo], nota)
    end.join("\n")

    total = acum.values.sum { |v| v[:count] }
    dup_msg = avisos_dup.empty? ? '' :
      "\n\n⚠ POSSÍVEIS DUPLICATAS (mesmo espaço físico):\n#{avisos_dup.join("\n")}\n" \
      "Verifique esses elementos no modelo SketchUp."

    UI.messagebox(
      "✓ Exportado!\n\n" \
      "Arquivo: #{nome_arq}\nPasta:   #{pasta}\n\n" \
      "#{acum.size} tipo(s) — #{total} peça(s):\n\n" \
      "#{resumo}" \
      "#{dup_msg}\n\n" \
      "Nota: placas lado único → ajuste manualmente no sistema.\n\n" \
      "No Controle de PU → \"Importar\" → selecione o arquivo."
    )
  end

end

RM_ExportarPU.exportar
