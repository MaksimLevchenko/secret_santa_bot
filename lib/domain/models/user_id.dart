class UserId {
  final int value;
  const UserId(this.value);
  
  @override
  String toString() => value.toString();
  
  @override
  bool operator ==(Object other) => other is UserId && other.value == value;
  
  @override
  int get hashCode => value.hashCode;
}
