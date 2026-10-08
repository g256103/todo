class PointCatalogItem {
  const PointCatalogItem({
    required this.id,
    required this.name,
    required this.points,
  });

  final String id;
  final String name;
  final int points;
}

/// Server-fixed catalog (decision J); ids must match `purchase_points` RPC.
const kPointPurchaseCatalog = <PointCatalogItem>[
  PointCatalogItem(id: 'book_1000', name: '参考書（モック）', points: 1000),
  PointCatalogItem(id: 'material_500', name: '学習教材（モック）', points: 500),
  PointCatalogItem(id: 'cert_2000', name: '資格教材（モック）', points: 2000),
];
