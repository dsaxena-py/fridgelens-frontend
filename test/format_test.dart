import 'package:flutter_test/flutter_test.dart';
import 'package:meallens/widgets/common.dart';

void main() {
  test('amounts read the way people say them', () {
    expect(formatAmount(1, 'piece'), '1 piece');
    expect(formatAmount(2, 'piece'), '2 pieces');
    expect(formatAmount(0.25, 'piece'), '¼ piece');
    expect(formatAmount(1.5, 'cup'), '1½ cups');
    expect(formatAmount(3, 'clove'), '3 cloves');
    expect(formatAmount(200, 'g'), '200 g');
    expect(formatAmount(2, 'tbsp'), '2 tbsp');
    expect(formatAmount(0.33, 'piece'), '⅓ piece');
    expect(formatAmount(1.2, 'ml'), '1.2 ml');
    expect(formatAmount(6, null), '6');
  });
}
