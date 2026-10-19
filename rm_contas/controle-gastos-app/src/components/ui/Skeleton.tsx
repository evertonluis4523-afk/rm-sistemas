export function Skeleton({ height = 16, width = '100%', radius }: { height?: number | string; width?: number | string; radius?: number }) {
  return <div className="skeleton" style={{ height, width, borderRadius: radius }} />;
}

export function SkeletonCard() {
  return (
    <div className="card pad stack">
      <Skeleton height={12} width="40%" />
      <Skeleton height={32} width="60%" />
      <Skeleton height={8} width="100%" radius={99} />
    </div>
  );
}
