# Reconhecimento compartilhado pelos dois exportadores.
module RM_DeteccaoPU
  def self.laje_sem_nome?(e, defn, world_t, bounds)
    return false unless defn && e.respond_to?(:manifold?) && e.manifold?
    nomes = [defn.name, e.respond_to?(:name) ? e.name : nil].compact.map { |n| n.to_s.strip.downcase }
    # Nomes automáticos do SketchUp não identificam a função da peça.
    return false unless nomes.all? { |n| n.empty? || n =~ /\A(?:group|grupo|agrupar|component|componente|solid group|grupo s[oó]lido)(?:[ #]*\d+)?\z/ }
    entities = e.is_a?(Sketchup::Group) ? e.entities : defn.entities
    # Nunca substituir uma montagem pela caixa que envolve seus filhos.
    return false if entities.any? { |c| c.is_a?(Sketchup::Group) || c.is_a?(Sketchup::ComponentInstance) }
    dx = (bounds[1] - bounds[0]).abs * 0.0254
    dy = (bounds[3] - bounds[2]).abs * 0.0254
    dz = (bounds[5] - bounds[4]).abs * 0.0254
    return false unless dz >= 0.02 && [dx, dy].min >= 0.60 && [dx, dy].min >= dz * 3.0
    # A espessura precisa apontar para Z no modelo, inclusive em grupos aninhados.
    bb = defn.bounds
    dims = [bb.width.abs, bb.height.abs, bb.depth.abs]
    axis = dims.each_with_index.min_by { |v, _i| v }[1]
    v = [Geom::Vector3d.new(1,0,0), Geom::Vector3d.new(0,1,0), Geom::Vector3d.new(0,0,1)][axis].transform(world_t)
    v.length > 0 && v.z.abs / v.length >= 0.995
  end

  # Remover o chão depois da coleta completa: a ordem dos grupos não importa.
  # A referência acompanha os pilares próximos, nunca o Z=0 do arquivo.
  def self.remover_chao!(pilares, placas)
    placas.reject! do |p|
      b = p[:bounds]
      dx = (b[1]-b[0]).abs; dy = (b[3]-b[2]).abs; dz = (b[5]-b[4]).abs
      next false unless dz < [dx, dy].min
      perto = lambda do |q|
        c = q[:bounds]
        gx = [b[0]-c[1], c[0]-b[1], 0].max
        gy = [b[2]-c[3], c[2]-b[3], 0].max
        gx <= 0.50 / 0.0254 && gy <= 0.50 / 0.0254
      end
      # Bases enterradas isoladas não definem o nível do chão.
      # Usar a mediana dos pilares próximos mantém a referência da maioria.
      referencias = pilares.select { |q| perto.call(q) }
      if referencias.empty?
        referencias = placas.select do |q|
          c = q[:bounds]
          (c[5]-c[4]).abs >= [(c[1]-c[0]).abs, (c[3]-c[2]).abs].min && perto.call(q)
        end
        next false if referencias.empty?
        base = referencias.map { |q| q[:bounds][4] }.min
      else
        niveis = referencias.map { |q| q[:bounds][4] }.sort
        meio = niveis.length / 2
        base = niveis.length.odd? ? niveis[meio] : (niveis[meio-1] + niveis[meio]) / 2.0
      end
      # Piso no nível da base (até 30 cm acima); laje elevada permanece.
      b[4] <= base + 0.05 / 0.0254 && b[5] <= base + 0.30 / 0.0254
    end
  end
end
