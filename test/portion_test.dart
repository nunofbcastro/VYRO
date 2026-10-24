import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/features/nutrition/domain/food_product.dart';
import 'package:vyro/features/nutrition/domain/portion.dart';

FoodProduct _product({
  String? quantity,
  String? servingSize,
  double? servingGrams,
  double? packageGrams,
}) => FoodProduct(
  barcode: '5601234567890',
  name: 'Barra de cereais',
  quantity: quantity,
  servingSize: servingSize,
  servingGrams: servingGrams,
  packageGrams: packageGrams,
  kcalPer100g: 400,
);

PortionOption _option(List<PortionOption> options, PortionKind kind) =>
    options.firstWhere((option) => option.kind == kind);

void main() {
  group('parsePackQuantity', () {
    test('multi-packs give a unit weight and total', () {
      final pack = parsePackQuantity('6 x 25 g')!;
      expect(pack.count, 6);
      expect(pack.unitAmount, 25);
      expect(pack.totalAmount, 150);
      expect(pack.liquid, isFalse);
    });

    test('accepts × and decimals with comma', () {
      final pack = parsePackQuantity('4×12,5g')!;
      expect(pack.unitAmount, 12.5);
      expect(pack.totalAmount, 50);
    });

    test('litres and centilitres become millilitres', () {
      expect(parsePackQuantity('1,5 l')!.totalAmount, 1500);
      expect(parsePackQuantity('33 cl')!.totalAmount, 330);
      expect(parsePackQuantity('33 cl')!.liquid, isTrue);
    });

    test('a stated count splits the pack weight', () {
      final pack = parsePackQuantity('250 g (10 unidades)')!;
      expect(pack.count, 10);
      expect(pack.unitAmount, 25);
    });

    test('unknown text returns null', () {
      expect(parsePackQuantity('caixa familiar'), isNull);
      expect(parsePackQuantity(null), isNull);
    });
  });

  test('serving weight is read from the serving label', () {
    expect(parseServingGrams('1 barra (25 g)'), 25);
    expect(parseServingGrams('30g'), 30);
    expect(parseServingGrams('uma porção'), isNull);
  });

  group('portionOptionsFor', () {
    test('bars: serving, unit and package are offered and converted', () {
      final options = portionOptionsFor(
        _product(quantity: '6 x 25 g', servingSize: '1 barra (25 g)'),
      );
      // Serving == unit weight, so both exist; the package is distinct.
      expect(_option(options, PortionKind.serving).gramsPerUnit, 25);
      expect(_option(options, PortionKind.unit).gramsPerUnit, 25);
      expect(_option(options, PortionKind.package).gramsPerUnit, 150);
      expect(options.last.kind, PortionKind.grams);

      final unit = _option(options, PortionKind.unit);
      expect(gramsFor(unit, 2), 50);
      expect(nutrientForPortion(400, gramsFor(unit, 2)!), 200);
    });

    test('no declared unit leaves a unit option the user must weigh', () {
      final options = portionOptionsFor(_product(quantity: '500 g'));
      final unit = _option(options, PortionKind.unit);
      expect(unit.gramsPerUnit, isNull);
      expect(unit.declared, isFalse);
      expect(gramsFor(unit, 1), isNull);
      expect(gramsFor(unit.withGrams(40), 1.5), 60);
    });

    test('single bar: unit equals the pack, package is not repeated', () {
      // Open Food Facts data for a Snickers bar.
      final options = portionOptionsFor(
        _product(quantity: '50 G', servingGrams: 50, packageGrams: 50),
      );
      expect(_option(options, PortionKind.unit).gramsPerUnit, 50);
      expect(_option(options, PortionKind.unit).declared, isTrue);
      expect(
        options.where((option) => option.kind == PortionKind.package),
        isEmpty,
      );
    });

    test('count in the product name splits the pack', () {
      final options = portionOptionsFor(
        const FoodProduct(
          barcode: '8000500310427',
          name: 'Biscuits Noisettes et Cacao x22 - 304g',
          quantity: '304 g',
          packageGrams: 304,
          servingGrams: 13.8,
        ),
      );
      expect(
        _option(options, PortionKind.unit).gramsPerUnit,
        closeTo(13.82, 0.01),
      );
      expect(_option(options, PortionKind.package).gramsPerUnit, 304);
    });

    test('package equal to an existing portion is not duplicated', () {
      final options = portionOptionsFor(
        _product(quantity: '1 x 45 g', servingGrams: 45),
      );
      expect(
        options.where((option) => option.kind == PortionKind.package),
        isEmpty,
      );
    });

    test('default is the declared serving, otherwise grams', () {
      expect(
        defaultPortion(portionOptionsFor(_product(servingGrams: 30))).kind,
        PortionKind.serving,
      );
      expect(
        defaultPortion(portionOptionsFor(_product(quantity: '500 g'))).kind,
        PortionKind.grams,
      );
    });
  });

  test('formatAmount trims zeros and follows the locale', () {
    expect(formatAmount(2, english: false), '2');
    expect(formatAmount(1.5, english: false), '1,5');
    expect(formatAmount(1.5, english: true), '1.5');
    expect(formatAmount(0.25, english: true), '0.25');
  });

  test('portion kinds round-trip through their stored key', () {
    for (final kind in PortionKind.values) {
      expect(PortionKind.fromKey(kind.key), kind);
    }
    expect(PortionKind.fromKey(null), isNull);
  });
}
