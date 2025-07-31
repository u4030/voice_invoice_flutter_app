class Invoice {
  final int? id;
  final String invoiceNumber;
  final DateTime date;
  final String dayName; // Added day name field
  final List<InvoiceItem> items;
  final double total;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    required this.dayName, // Added to constructor
    required this.items,
    required this.total,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      date: DateTime.parse(map['date']),
      dayName: map['day_name'], // Added day name
      items: [], // Items will be loaded separately
      total: map['total'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'date': date.toIso8601String(),
      'day_name': dayName, // Added day name
      'total': total,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    DateTime? date,
    String? dayName, // Added to copyWith
    List<InvoiceItem>? items,
    double? total,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      dayName: dayName ?? this.dayName, // Added to copyWith
      items: items ?? this.items,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double calculateTotal() {
    return items.fold(0.0, (sum, item) => sum + item.total);
  }
}

class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int itemNumber; // Added item number
  final String description;
  final double price;
  final double total;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.itemNumber, // Added to constructor
    required this.description,
    required this.price,
    required this.total,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      itemNumber: map['item_number'], // Added item number
      description: map['description'],
      price: map['price'],
      total: map['total'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'item_number': itemNumber, // Added item number
      'description': description,
      'price': price,
      'total': total,
    };
  }

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? itemNumber, // Added to copyWith
    String? description,
    double? price,
    double? total,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      itemNumber: itemNumber ?? this.itemNumber, // Added to copyWith
      description: description ?? this.description,
      price: price ?? this.price,
      total: total ?? this.total,
    );
  }
}