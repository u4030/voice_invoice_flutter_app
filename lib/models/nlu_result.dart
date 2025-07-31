class NluResult {
  final String intent;
  final Map<String, dynamic> slots;

  NluResult(this.intent, [this.slots = const {}]);

  @override
  String toString() {
    return 'Intent: $intent, Slots: $slots';
  }
}
