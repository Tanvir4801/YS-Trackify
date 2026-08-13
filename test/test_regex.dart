void main() {
  const str = "✅ Good work today";
  final clean = str.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  print(clean);
}
