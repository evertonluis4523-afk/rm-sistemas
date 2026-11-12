# ============================================================
#  RM Estruturas Pré-Fabricadas
#  Exportar Linhas de Aplicação de PU → Viewer 3D
#
#  Gera as coordenadas 3D exatas de cada linha onde o PU
#  será aplicado, para visualização e validação no viewer.
#
#  Como usar:
#    Extensões → RM Estruturas PU → Exportar Linhas PU
#    No Controle de PU: Viewer 3D → Carregar *_linhasPU.json
#
#  O arquivo leva, além das linhas:
#    pecas  -- a caixa de cada peça lida (o 3D mostra o que foi lido)
#    camera -- a vista atual do SketchUp (o 3D abre igual)
# ============================================================
require 'json'
load File.join(File.dirname(__FILE__), 'deteccao_pu.rb')

module RM_LinhasPU

  VERSAO = '1.3.9'

  INCHES_TO_M  = 0.0254
  ADJACENCIA_M = 0.50

  KEYWORDS   = %w[placa pilar viga].freeze
  EXT_ARQ    = %w[.dwg .dxf .obj .dae .skp .png .jpg .rvt].freeze
  SKIP_NOMES = %w[tesoura telhado escada porta janela vidro parafuso
                  chapa pino puxador fechadura alizar marco folha
                  niraj person people human car tree furniture].freeze

  def self.estrutural?(nome)
    n = nome.downcase
    KEYWORDS.any? { |k| n.include?(k) } &&
      !SKIP_NOMES.any? { |k| n.start_with?(k) } &&
      !EXT_ARQ.include?(File.extname(n))
  end

  # Mesma classificação do Exportar Medição PU: os dois arquivos têm de
  # chamar a mesma peça pelo mesmo tipo.
  def self.tipo(nome)
    n = nome.downcase
    return 'Pilar' if n.include?('pilar') || n.include?('coluna') || n.include?('poste')
    return 'Viga'  if n.include?('viga')  || n.include?('baldrame') || n.include?('travessa')
    'Placa'
  end

  def self.world_bounds(defn, world_t)
    bb = defn.bounds
    corners = (0..7).map { |i| world_t * bb.corner(i) }
    xs = corners.map(&:x); ys = corners.map(&:y); zs = corners.map(&:z)
    [xs.min, xs.max, ys.min, ys.max, zs.min, zs.max]
  end

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

  def self.coletar_tudo(entities, pilares, placas, vigas,
                        parent_t = Geom::Transformation.new)
    entities.each do |e|
      case e
      when Sketchup::ComponentInstance, Sketchup::Group
        next if e.get_attribute('RM_Estruturas_PU', 'ignorar', false)
        world_t = parent_t * e.transformation
        defn    = e.respond_to?(:definition) ? e.definition : nil
        # o nome vale na definição (componente) e também na própria peça:
        # um GRUPO chamado "PLACA" (ou a instância renomeada) era ignorado
        nome = [defn && defn.name, e.respond_to?(:name) ? e.name : nil]
               .compact.map { |x| x.to_s.strip }.find { |x| !x.empty? && estrutural?(x) }
        bounds = defn ? world_bounds(defn, world_t) : nil
        if !nome && RM_DeteccaoPU.laje_sem_nome?(e, defn, world_t, bounds)
          nome = 'PLACA DEITADA (AUTOMATICA)'
        end
        if nome && defn
          t      = tipo(nome)
          bounds = world_bounds(e.definition, world_t)
          dx = (bounds[1]-bounds[0]).abs
          dy = (bounds[3]-bounds[2]).abs
          dz = (bounds[5]-bounds[4]).abs
          next if [dx,dy,dz].max < 1.0   # ignora peças tiny
          rec = { nome: nome.upcase, tipo: t, bounds: bounds }
          case t
          when 'Pilar' then pilares << rec
          when 'Viga'  then vigas   << rec
          else              placas  << rec
          end
        else
          coletar_tudo(e.is_a?(Sketchup::Group) ? e.entities : defn.entities, pilares, placas, vigas, world_t)
        end
      end
    end
  end

  # Converte polegadas → metros, 4 casas
  def self.m(v); (v * INCHES_TO_M).round(4); end
  def self.pt(x, y, z); [m(x), m(y), m(z)]; end


  # ── JUNTA DA BASE DA PLACA: só onde ela encontra outra peça ──
  # "Essa linha que o sistema leu sem encontro adjacente com nada além do
  # buraco está errada: se não tem encontro de juntas, considerar a linha de
  # PU só até o final da placa inferior." A linha da base da placa vale nos
  # trechos em que há placa (ou viga) logo abaixo, encostada. Placa no nível
  # mais baixo (sobre o piso/baldrame) leva a base inteira. Placa sem nada
  # encostado embaixo mas com placa mais baixa na mesma parede está por cima
  # de um vão: não leva linha. Sem nenhuma placa embaixo na parede: inteira
  # (apoiada em algo que não foi modelado). Volta [a0,a1] no eixo da placa.
  # ── PLACA DEITADA SOBRE A VIGA (piso de mezanino, laje) ──
  # "Não leu as linhas superiores da viga: tem uma placa apoiada sobre a
  # viga, ali vai PU interno e externo." A placa deitada (mais fina na
  # altura que na planta) não tem junta de base como a de parede: a junta
  # é o TOPO de cada viga em que ela se apoia. Volta [[viga, a0, a1], ...]
  # no eixo da viga.
  def self.deitada?(b)
    (b[5]-b[4]).abs < [(b[1]-b[0]).abs, (b[3]-b[2]).abs].min
  end
  def self.topos_viga(vigas, placas)
    tol = TOL_JUNTA_M / INCHES_TO_M; out = []
    vigas.each do |v|
      vx0,vx1,vy0,vy1,_vz0,vz1 = v[:bounds]; em_x = (vx1-vx0).abs >= (vy1-vy0).abs
      ivs = []
      placas.each do |p|
        b = p[:bounds]
        next unless deitada?(b) && (b[4]-vz1).abs <= tol
        ox = [b[1],vx1].min - [b[0],vx0].max; oy = [b[3],vy1].min - [b[2],vy0].max
        next unless ox > 0 && oy > 0
        ivs << (em_x ? [[b[0],vx0].max, [b[1],vx1].min] : [[b[2],vy0].max, [b[3],vy1].min])
      end
      merge_intervals(ivs).each { |a0, a1| out << [v, a0, a1] } unless ivs.empty?
    end
    out
  end

  # A PAREDE QUE ENCOSTA EMBAIXO DO PISO: o topo da placa de parede que
  # toca a face de baixo da placa deitada também é junta ("aqui também";
  # "em baixo, e nada na parte superior do piso"). Volta [[placa, a0, a1]]
  # no eixo da placa de parede.
  def self.topos_parede(placas)
    tol = TOL_JUNTA_M / INCHES_TO_M; adj = ADJACENCIA_M / INCHES_TO_M; out = []
    deitadas = placas.select { |q| deitada?(q[:bounds]) }
    return out if deitadas.empty?
    placas.each do |p|
      b = p[:bounds]; next if deitada?(b)
      em_x = (b[1]-b[0]).abs >= (b[3]-b[2]).abs
      ivs = []
      deitadas.each do |d|
        q = d[:bounds]
        next unless (q[4] - b[5]).abs <= tol
        g = em_x ? [q[2]-b[3], b[2]-q[3], 0].max : [q[0]-b[1], b[0]-q[1], 0].max
        next if g > adj
        i0, i1 = em_x ? [[q[0], b[0]].max, [q[1], b[1]].min] : [[q[2], b[2]].max, [q[3], b[3]].min]
        ivs << [i0, i1] if i1 > i0
      end
      merge_intervals(ivs).each { |a0, a1| out << [p, a0, a1] } unless ivs.empty?
    end
    out
  end

  # ── PLACA ENTERRADA (contenção abaixo do baldrame) ──
  # "Essas linhas inferiores não têm encontro adjacente com nada, por que
  # está considerando linhas de PU?" A placa que corre ao lado da viga
  # baldrame e desce abaixo dela fica enterrada: a BASE dela (o fundo) não
  # encontra nada e não leva PU, e ela não conta como "a placa mais baixa"
  # da obra. O resto continua: "essa linha [o encontro da placa com o fundo
  # da viga] deveria ter sido lida, era apenas a linha inferior que não" --
  # a face de baixo da viga e as juntas com o pilar seguem valendo. A placa
  # pendurada embaixo de uma viga intermediária só ENCOSTA na viga (topo =
  # fundo da viga): essa continua normal.
  def self.enterrada?(p, vigas)
    tol = TOL_JUNTA_M / INCHES_TO_M; adj = ADJACENCIA_M / INCHES_TO_M
    x0,x1,y0,y1,z0,z1 = p[:bounds]
    return false if deitada?(p[:bounds])
    vigas.any? do |v|
      vx0,vx1,vy0,vy1,vz0,vz1 = v[:bounds]
      gx = [vx0-x1, x0-vx1, 0].max; gy = [vy0-y1, y0-vy1, 0].max
      next false if gx > adj || gy > adj
      z1 > vz0 + tol && z1 < vz1 - tol && z0 < vz0 - tol
    end
  end
  def self.placas_enterradas(placas, vigas)
    placas.select { |p| enterrada?(p, vigas) }
  end

  TOL_JUNTA_M = 0.05
  def self.trechos_base_placa(p, placas, vigas, enterradas = [])
    x0,x1,y0,y1,z0,_z1 = p[:bounds]
    em_x = (x1-x0).abs >= (y1-y0).abs
    a0, a1 = em_x ? [x0, x1] : [y0, y1]
    tol = TOL_JUNTA_M / INCHES_TO_M; adj = ADJACENCIA_M / INCHES_TO_M
    chao = placas.reject { |q| enterradas.any? { |e| e.equal?(q) } }
    base = (chao.empty? ? placas : chao).map { |q| q[:bounds][4] }.min
    return [[a0, a1]] if z0 <= base + tol
    perto = lambda do |b|
      g = em_x ? [b[2]-y1, y0-b[3], 0].max : [b[0]-x1, x0-b[1], 0].max
      g <= adj
    end
    ao_longo = lambda { |b| em_x ? [[b[0], a0].max, [b[1], a1].min] : [[b[2], a0].max, [b[3], a1].min] }
    apoios = []; abaixo = false
    (placas + vigas).each do |q|
      next if q.equal?(p)
      b = q[:bounds]
      next if deitada?(b)   # em cima do piso não leva PU
      next unless perto.call(b)
      i0, i1 = ao_longo.call(b)
      next unless i1 > i0
      if (b[5] - z0).abs <= tol then apoios << [i0, i1]
      elsif b[5] < z0 then abaixo = true
      end
    end
    return merge_intervals(apoios) unless apoios.empty?
    abaixo ? [] : [[a0, a1]]
  end

  # ── Gera linhas de PU em coordenadas reais ────────────────
  def self.gerar_linhas(pilares, placas, vigas, enterradas = [])
    linhas = []; id = 0; adj = ADJACENCIA_M / INCHES_TO_M

    # ── PLACAS: linha horizontal na base (junta inferior) ────
    placas.each do |p|
      next if deitada?(p[:bounds])   # deitada: a junta é o topo da viga (abaixo)
      next if enterradas.any? { |e| e.equal?(p) }   # o fundo da enterrada não encontra nada
      x0,x1,y0,y1,z0,z1 = p[:bounds]
      dx = (x1-x0).abs; dy = (y1-y0).abs
      z_base = z0   # base da placa = onde o PU é aplicado

      # um trecho por encontro de junta embaixo (ver trechos_base_placa)
      trechos_base_placa(p, placas, vigas, enterradas).each do |a0, a1|
        if dx >= dy   # placa estendida em X
          cy = (y0+y1)/2.0
          p1 = pt(a0, cy, z_base); p2 = pt(a1, cy, z_base)
        else           # placa estendida em Y
          cx = (x0+x1)/2.0
          p1 = pt(cx, a0, z_base); p2 = pt(cx, a1, z_base)
        end
        ml = ((a1-a0) * INCHES_TO_M).round(3)
        next if ml < 0.05
        linhas << { id: id+=1, nome: p[:nome], tipo: 'Placa', junta: 'placa_base',
                    pt1: p1, pt2: p2, ml: ml, app: 'ext_int', incluir: true }
      end
    end

    # ── PILARES: segmentos verticais por face com placa ───────
    pilares.each do |pilar|
      px0,px1,py0,py1,pz0,pz1 = pilar[:bounds]
      pcx = (px0+px1)/2.0; pcy = (py0+py1)/2.0

      faces = { xp: [], xn: [], yp: [], yn: [] }
      placas.each do |pl|
        plx0,plx1,ply0,ply1,plz0,plz1 = pl[:bounds]
        x_gap = [plx0-px1, px0-plx1, 0].max
        y_gap = [ply0-py1, py0-ply1, 0].max
        next if x_gap > adj || y_gap > adj

        dx = (plx0+plx1)/2.0 - pcx
        dy = (ply0+ply1)/2.0 - pcy
        face = dx.abs >= dy.abs ? (dx>=0 ? :xp : :xn) : (dy>=0 ? :yp : :yn)

        z0 = [plz0,pz0].max; z1 = [plz1,pz1].min
        faces[face] << [z0,z1] if z1 > z0
      end

      # Sem placa encostada não leva PU: o pilar fica fora (regra da RM).
      next if faces.values.all?(&:empty?)

      faces.each do |face_sym, ivs|
        next if ivs.empty?
        merged = merge_intervals(ivs)

        # Posição no espaço da face do pilar
        case face_sym
        when :xp; fx=px1; fy=pcy
        when :xn; fx=px0; fy=pcy
        when :yp; fx=pcx; fy=py1
        when :yn; fx=pcx; fy=py0
        end

        merged.each do |zs, ze|
          ml = ((ze-zs)*INCHES_TO_M).round(3)
          next if ml < 0.05
          linhas << { id: id+=1,
                      nome: "#{pilar[:nome]} · face #{face_sym}",
                      tipo: 'Pilar', junta: 'pilar_face',
                      pt1: pt(fx, fy, zs),
                      pt2: pt(fx, fy, ze),
                      ml: ml, app: 'ext_int', incluir: true }
        end
      end
    end

    # ── VIGAS: linha na face inferior (Line C) ─────────────
    # Só vigas com placas ABAIXO (intermediárias).
    # Vigas de base não geram linha — já coberta pela placa.
    vigas.each do |viga|
      vx0,vx1,vy0,vy1,vz0,vz1 = viga[:bounds]
      vwx = (vx1-vx0).abs; vwy = (vy1-vy0).abs
      along_x = vwx >= vwy
      viga_cz  = (vz0+vz1)/2.0

      covered = []
      placas.each do |pl|
        plx0,plx1,ply0,ply1,plz0,plz1 = pl[:bounds]
        z_gap = [plz0-vz1, vz0-plz1, 0].max
        next if z_gap > adj
        next if (plz0+plz1)/2.0 >= viga_cz   # placa acima → skip

        if along_x
          y_gap = [ply0-vy1, vy0-ply1, 0].max; next if y_gap > adj
          a0=[plx0,vx0].max; a1=[plx1,vx1].min; covered << [a0,a1] if a1>a0
        else
          x_gap = [plx0-vx1, vx0-plx1, 0].max; next if x_gap > adj
          a0=[ply0,vy0].max; a1=[ply1,vy1].min; covered << [a0,a1] if a1>a0
        end
      end
      next if covered.empty?

      z_line = vz0   # face inferior da viga
      merge_intervals(covered).each do |a0, a1|
        ml = ((a1-a0)*INCHES_TO_M).round(3)
        next if ml < 0.05
        if along_x
          vc = (vy0+vy1)/2.0
          linhas << { id: id+=1, nome: viga[:nome], tipo: 'Viga', junta: 'viga_inferior',
                      pt1: pt(a0,vc,z_line), pt2: pt(a1,vc,z_line),
                      ml: ml, app: 'ext_int', incluir: true }
        else
          vc = (vx0+vx1)/2.0
          linhas << { id: id+=1, nome: viga[:nome], tipo: 'Viga', junta: 'viga_inferior',
                      pt1: pt(vc,a0,z_line), pt2: pt(vc,a1,z_line),
                      ml: ml, app: 'ext_int', incluir: true }
        end
      end
    end

    # ── VIGAS: topo onde uma placa deitada se apoia (Line D) ──
    topos_viga(vigas, placas).each do |viga, a0, a1|
      vx0,vx1,vy0,vy1,_vz0,vz1 = viga[:bounds]
      ml = ((a1-a0)*INCHES_TO_M).round(3)
      next if ml < 0.05
      if (vx1-vx0).abs >= (vy1-vy0).abs
        vc = (vy0+vy1)/2.0; p1 = pt(a0,vc,vz1); p2 = pt(a1,vc,vz1)
      else
        vc = (vx0+vx1)/2.0; p1 = pt(vc,a0,vz1); p2 = pt(vc,a1,vz1)
      end
      # a viga do mezanino leva PU nos 2 lados (ext_int)
      linhas << { id: id+=1, nome: "#{viga[:nome]} · topo", tipo: 'Viga', junta: 'viga_superior',
                  pt1: p1, pt2: p2, ml: ml, app: 'ext_int', incluir: true }
    end

    # ── PAREDE: topo da placa que encosta embaixo do piso ──
    topos_parede(placas).each do |pl, a0, a1|
      x0,x1,y0,y1,_z0,z1 = pl[:bounds]
      ml = ((a1-a0)*INCHES_TO_M).round(3)
      next if ml < 0.05
      if (x1-x0).abs >= (y1-y0).abs
        c = (y0+y1)/2.0; p1 = pt(a0,c,z1); p2 = pt(a1,c,z1)
      else
        c = (x0+x1)/2.0; p1 = pt(c,a0,z1); p2 = pt(c,a1,z1)
      end
      # embaixo da laje o PU vai só na linha interna: 1 lado (int1)
      linhas << { id: id+=1, nome: "#{pl[:nome]} · topo", tipo: 'Laje', junta: 'laje_inferior',
                  pt1: p1, pt2: p2, ml: ml, app: 'int1', incluir: true }
    end

    linhas
  end

  # ── Onde gravar ────────────────────────────────────────────
  # Modelo ainda sem salvar não tem pasta: antes o arquivo ia para um lugar
  # qualquer. Agora pergunta.
  def self.caminho_saida(model, sufixo)
    base = model.path.to_s
    unless base.empty?
      return File.join(File.dirname(base), "#{File.basename(base, '.skp')}#{sufixo}")
    end
    UI.savepanel('Salvar linhas de PU', '', "Sem nome#{sufixo}")
  end

  def self.camera(model)
    c = model.active_view.camera
    v = ->(p) { [m(p.x), m(p.y), m(p.z)] }
    { eye: v.(c.eye), target: v.(c.target), up: [c.up.x, c.up.y, c.up.z].map { |x| x.to_f.round(4) },
      fov: c.fov.to_f.round(2), perspectiva: c.perspective? ? true : false }
  rescue StandardError
    nil
  end

  # ── Ponto de entrada ───────────────────────────────────────
  def self.exportar
    model   = Sketchup.active_model
    pilares = []; placas = []; vigas = []
    coletar_tudo(model.entities, pilares, placas, vigas)
    RM_DeteccaoPU.remover_chao!(pilares, placas)

    enterradas = placas_enterradas(placas, vigas)
    linhas = gerar_linhas(pilares, placas, vigas, enterradas)

    if linhas.empty?
      UI.messagebox("Nenhuma linha de PU encontrada.\n\nVerifique os nomes dos componentes.")
      return
    end

    caminho = caminho_saida(model, '_linhasPU.json')
    return if caminho.nil? || caminho.to_s.empty?
    nome_arq  = File.basename(caminho)
    pasta     = File.dirname(caminho)
    nome_obra = File.basename(nome_arq, '_linhasPU.json').gsub(/[_\-]+/, ' ').strip

    pecas = (pilares + placas + vigas).map do |p|
      b = p[:bounds]
      { nome: p[:nome], tipo: p[:tipo], min: pt(b[0], b[2], b[4]), max: pt(b[1], b[3], b[5]) }
    end

    # JSON montado pela biblioteca, e não colando texto: aspas, barra
    # invertida ou acento no nome de uma peça quebravam o arquivo.
    dados = { obra: nome_obra, versao: VERSAO, gerado: Time.now.strftime('%Y-%m-%d %H:%M'),
              unidade: 'm', camera: camera(model), linhas: linhas, pecas: pecas }

    begin
      File.write(caminho, JSON.pretty_generate(dados), encoding: 'UTF-8')
    rescue => e
      UI.messagebox("Erro ao salvar:\n#{e.message}"); return
    end

    cnt = linhas.group_by { |l| l[:tipo] }.transform_values(&:count)
    ml1 = linhas.sum { |l| l[:ml] }

    UI.messagebox(
      "✓ Exportado!\n\n" \
      "Arquivo: #{nome_arq}\nPasta:   #{pasta}\n\n" \
      "#{linhas.size} linhas de PU:\n" \
      "  Pilares: #{cnt['Pilar']||0} segmentos\n" \
      "  Placas:  #{cnt['Placa']||0} linhas\n" \
      "  Vigas:   #{cnt['Viga']||0} linhas\n\n" \
      "ML total (1 lado): #{sprintf('%.2f', ml1)} m\n" \
      "ML total (ext+int): #{sprintf('%.2f', ml1*2)} m\n" \
      "\n" \
      "No Controle de PU: Viewer 3D → Carregar *_linhasPU.json."
    )
  end

end

RM_LinhasPU.exportar
