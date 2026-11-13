# ============================================================
#  RM Estruturas -- forma real da obra para o 3D do PU
#
#  "Cada pilar, viga, tem detalhes como friso, console... isso tudo aparece
#  no SketchUp, porém o sistema ignora": as linhas e as caixas (pecas)
#  continuam sendo o cálculo; isto aqui é SÓ A VISTA. Cada componente vai
#  com a forma de verdade (triângulos), uma vez por definição, e cada cópia
#  com a posição dela. Cada peça leva o grupo, para o 3D ligar e desligar:
#    concreto   -- pilar, viga, placa, contenção (com friso e consolo)
#    metalica   -- tesoura, terça, treliça
#    esquadrias -- portas, janelas, vidros
#    cobertura  -- telhas, calhas (também pelo material do telhado)
#    outros     -- o resto (o 3D começa com ele oculto)
#  Pessoas, árvores, desenhos importados (.dwg) e cotas ficam de fora.
#  Qualquer erro aqui não impede o arquivo das linhas: ele sai sem a forma.
# ============================================================
module RM_VisualPU

  POL_M   = 0.0254
  TRI_MAX = 600_000     # acima disso o "outros" fica de fora (arquivo leve)

  IGNORAR = /niraj|person|people|human|pessoa|boneco|\btree\b|arvore|árvore|furniture|\.(dwg|dxf|pdf|png|jpe?g)\b|\bcotas?\b|proje[cç][aã]o|rascunho|planta baixa/i

  # nome do componente, do grupo ou da camada (Tag) -> grupo
  POR_NOME = [
    ['esquadrias', /porta|janela|vidro|esquadri|\bmarco|folha de|alizar|dobradi|fechadur|puxador|port[aã]o|batente|basculant|veneziana|caixilho/i],
    ['metalica',   /tesour|ter[cç]a|treli[cç]|banzo|perfil|met[aá]lic|contravent|m[aã]o francesa|tirante|\ba[cç]o\b|estrutura met/i],
    ['cobertura',  /telh|cumeeir|calha|rufo|cobertura|rufos|platiband/i],
    ['concreto',   /placa|pilar|viga|coluna|poste|baldrame|travessa|conten[cç]|muro|sapata|c[aá]lice|bloco|laje|consol/i]
  ].freeze

  # material de pintura -> grupo (para o que não tem nome: "Agrupar#57")
  POR_MATERIAL = [
    ['cobertura',  /roof|telh|corrug|seam|zinc|ondulad/i],
    ['esquadrias', /glass|vidro|translucent|window|janela/i],
    ['metalica',   /metal|alum|steel|a[cç]o\b|galvan|chrome|cromad/i],
    ['concreto',   /concret|cimento/i]
  ].freeze

  def self.tipo_concreto(nome)
    n = nome.to_s.downcase
    return 'Pilar' if n =~ /pilar|coluna|poste/
    return 'Viga'  if n =~ /viga|baldrame|travessa/
    'Placa'
  end

  def self.grupo_por(texto, regras)
    t = texto.to_s
    return nil if t.strip.empty?
    regras.each { |g, re| return g if t =~ re }
    nil
  end

  def self.nomes(e)
    defn = e.respond_to?(:definition) ? e.definition : nil
    [e.respond_to?(:name) ? e.name : nil, defn && defn.name].compact.map { |x| x.to_s.strip }.reject(&:empty?)
  end

  def self.camada(e)
    l = e.respond_to?(:layer) ? e.layer : nil
    l && l.respond_to?(:name) ? l.name.to_s : ''
  end

  def self.visivel?(e)
    return false if e.respond_to?(:hidden?) && e.hidden?
    l = e.respond_to?(:layer) ? e.layer : nil
    return false if l && l.respond_to?(:visible?) && !l.visible?
    true
  end

  def self.coletar(model)
    v = new_estado
    percorre(v, model.entities, nil, nil)
    proprio = parte_propria(v, model.entities, nil)
    v[:inst] << { d: proprio, t: nil, g: nil, k: nil, m: nil } if proprio
    return nil if v[:inst].empty?
    { versao: 1, unidade: 'm', mats: v[:mats], defs: v[:defs], inst: v[:inst], tri: v[:tri], parcial: v[:parcial] }
  end

  def self.new_estado
    { mats: [], mat_idx: {}, defs: [], def_idx: {}, inst: [], tri: 0, parcial: false }
  end

  # percorre a árvore: peça com grupo vai inteira (forma achatada da
  # definição); sem grupo, desce e leva só as faces soltas daquele nível
  def self.percorre(v, ents, t, mat)
    ents.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      next unless visivel?(e)
      defn = e.respond_to?(:definition) ? e.definition : nil
      next unless defn
      ns = nomes(e)
      next if ns.any? { |n| n =~ IGNORAR } || camada(e) =~ IGNORAR
      wt = t ? t * e.transformation : e.transformation
      m  = e.respond_to?(:material) && e.material ? e.material : mat
      ign = e.respond_to?(:get_attribute) && e.get_attribute('RM_Estruturas_PU', 'ignorar', false)
      g = ns.map { |n| grupo_por(n, POR_NOME) }.compact.first || grupo_por(camada(e), POR_NOME)
      g = 'outros' if ign && g == 'concreto'   # o chão marcado para ignorar no PU
      ents_d = e.is_a?(Sketchup::Group) && e.respond_to?(:entities) ? e.entities : defn.entities
      if g
        d = parte_achatada(v, defn, ents_d, g == 'outros')
        v[:inst] << { d: d, t: matriz(wt), g: g, k: g == 'concreto' ? tipo_concreto(ns.first || camada(e)) : nil, m: mat_id(v, m) } if d
      else
        d = parte_propria(v, ents_d, defn)
        v[:inst] << { d: d, t: matriz(wt), g: nil, k: nil, m: mat_id(v, m) } if d
        percorre(v, ents_d, wt, m)
      end
    end
  end

  # forma inteira da definição (com o que tem dentro: o consolo, o friso)
  def self.parte_achatada(v, defn, ents, outros)
    chave = [:a, defn.object_id]
    return v[:def_idx][chave] if v[:def_idx].key?(chave)
    partes = {}
    junta_faces(v, ents, nil, nil, partes, true)
    v[:def_idx][chave] = grava_def(v, partes, outros)
  end

  # só as faces soltas daquele nível (o resto vai pelos filhos)
  def self.parte_propria(v, ents, defn)
    chave = [:p, defn ? defn.object_id : :modelo]
    return v[:def_idx][chave] if v[:def_idx].key?(chave)
    partes = {}
    junta_faces(v, ents, nil, nil, partes, false)
    v[:def_idx][chave] = grava_def(v, partes, true)
  end

  def self.junta_faces(v, ents, t, mat, partes, desce)
    ents.each do |e|
      if e.is_a?(Sketchup::Face)
        next unless visivel?(e) && e.respond_to?(:mesh)
        fm = e.respond_to?(:material) && e.material ? e.material : (e.respond_to?(:back_material) && e.back_material ? e.back_material : mat)
        k = mat_id(v, fm)
        p = (partes[k] ||= { m: k, v: [], i: [] })
        malha = e.mesh(0)
        next unless malha
        base = p[:v].length / 3
        malha.points.each do |pt|
          q = t ? t * pt : pt
          p[:v].push((q.x * POL_M).round(3), (q.y * POL_M).round(3), (q.z * POL_M).round(3))
        end
        malha.polygons.each do |pol|
          ids = pol.map { |i| i.abs - 1 }
          (1...(ids.length - 1)).each { |j| p[:i].push(base + ids[0], base + ids[j], base + ids[j + 1]) }
        end
      elsif desce && (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group))
        next unless visivel?(e)
        next if nomes(e).any? { |n| n =~ IGNORAR }
        defn = e.respond_to?(:definition) ? e.definition : nil
        ents_d = e.is_a?(Sketchup::Group) && e.respond_to?(:entities) ? e.entities : (defn && defn.entities)
        next unless ents_d
        m = e.respond_to?(:material) && e.material ? e.material : mat
        junta_faces(v, ents_d, t ? t * e.transformation : e.transformation, m, partes, true)
      end
    end
  end

  def self.grava_def(v, partes, outros)
    ps = partes.values.reject { |p| p[:i].empty? }
    return nil if ps.empty?
    tri = ps.sum { |p| p[:i].length / 3 }
    if v[:tri] + tri > TRI_MAX && outros
      v[:parcial] = true
      return nil
    end
    v[:tri] += tri
    v[:defs] << { p: ps }
    v[:defs].length - 1
  end

  def self.mat_id(v, m)
    return nil unless m && m.respond_to?(:name)
    return v[:mat_idx][m.object_id] if v[:mat_idx].key?(m.object_id)
    nome = m.respond_to?(:display_name) ? m.display_name.to_s : m.name.to_s
    cor = m.respond_to?(:color) && m.color ? format('#%02x%02x%02x', m.color.red, m.color.green, m.color.blue) : '#cccccc'
    alfa = m.respond_to?(:alpha) ? m.alpha.to_f.round(2) : 1.0
    v[:mats] << { n: nome, c: cor, a: alfa, g: grupo_por(nome, POR_MATERIAL) }
    v[:mat_idx][m.object_id] = v[:mats].length - 1
  end

  # a transformação do SketchUp (16 números, coluna a coluna), com o
  # deslocamento passado de polegadas para metros
  def self.matriz(t)
    a = t.to_a.map(&:to_f)
    [12, 13, 14].each { |i| a[i] *= POL_M }
    a.map { |x| x.round(6) }
  end
end
