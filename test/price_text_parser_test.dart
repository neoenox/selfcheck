import 'package:flutter_test/flutter_test.dart';
import 'package:selfcheck_jibun_check/domain/scan_state.dart';
import 'package:selfcheck_jibun_check/infrastructure/price_text_parser.dart';

void main() {
  const region = Rect(left: 1, top: 2, right: 3, bottom: 4);

  test('prefers currency-marked price over bare numbers', () {
    final result = parsePriceText([
      (text: '在庫 12', region: region),
      (text: '税込 ￥1,980円', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 1980);
    expect(result.confidence, 0.90);
  });

  test('accepts a plausible bare price', () {
    final result = parsePriceText([(text: '398', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
    expect(result.confidence, 0.70);
  });

  test('rejects bare numbers embedded in non-price text', () {
    expect(parsePriceText([(text: '在庫 12', region: region)]), isNull);
    expect(parsePriceText([(text: '商品 398', region: region)]), isNull);
  });

  test('prefers the larger OCR region for equally ranked bare prices', () {
    const smallRegion = Rect(left: 0, top: 0, right: 20, bottom: 10);
    const largeRegion = Rect(left: 0, top: 0, right: 80, bottom: 40);

    final result = parsePriceText([
      (text: '398', region: smallRegion),
      (text: '980', region: largeRegion),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 980);
    expect(result.region, largeRegion);
  });

  test('does not reinterpret JAN/EAN-length text as a price', () {
    final result = parsePriceText([(text: '4901234567894', region: region)]);

    expect(result, isNull);
  });

  test('rejects zero and values above 99,999 yen', () {
    expect(parsePriceText([(text: '￥0円', region: region)]), isNull);
    expect(parsePriceText([(text: '￥100,000円', region: region)]), isNull);
  });

  test('prefers product price over a marked per-weight unit price', () {
    final result = parsePriceText([
      (text: '398', region: region),
      (text: '100g当たり ¥198', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });

  test('rejects tax-marked unit price without a product price', () {
    expect(parsePriceText([(text: '100g当たり 税込198円', region: region)]), isNull);
    expect(parsePriceText([(text: '1個当たり（税込）50円', region: region)]), isNull);
  });

  test('rejects slash-form unit price without a product price', () {
    expect(parsePriceText([(text: '¥198/100g', region: region)]), isNull);
    expect(parsePriceText([(text: '￥198／100ml', region: region)]), isNull);
    expect(parsePriceText([(text: '税込198円/100g', region: region)]), isNull);
    expect(parsePriceText([(text: '198円（税込）/100g', region: region)]), isNull);
  });

  test('rejects per-item unit price without a product price', () {
    expect(parsePriceText([(text: '1個当たり 50円', region: region)]), isNull);
    expect(parsePriceText([(text: '1本あたり ￥80', region: region)]), isNull);
  });

  test('keeps a normal price followed by package weight', () {
    final result = parsePriceText([(text: '税込 ¥398 100g', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });

  test('keeps tax-inclusive price when unit price shares one OCR line', () {
    final result = parsePriceText([
      (text: '税込 398円（100g当たり 198円）', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });

  test('keeps product price when unit price is also tax-marked', () {
    final result = parsePriceText([
      (text: '税込398円（100g当たり 税込198円）', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });

  test('keeps product price before unit price in one OCR line', () {
    final result = parsePriceText([
      (text: '398円 / 100g当たり198円', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 398);
  });

  test('prefers tax-inclusive price over a larger tax-exclusive line', () {
    const largeRegion = Rect(left: 0, top: 0, right: 120, bottom: 40);
    const smallRegion = Rect(left: 0, top: 50, right: 70, bottom: 75);

    final result = parsePriceText([
      (text: '本体価格 398円', region: largeRegion),
      (text: '税込 429円', region: smallRegion),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 429);
    expect(result.region, smallRegion);
  });

  test('selects tax-inclusive value when both prices share one OCR line', () {
    final result = parsePriceText([(text: '本体価格398円（税込429円）', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 429);
  });

  test('recognizes a price followed by an inclusive-tax marker', () {
    final result = parsePriceText([(text: '429円（税込）', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 429);
  });

  test('fails closed for an explicitly tax-exclusive price only', () {
    expect(parsePriceText([(text: '税抜 398円', region: region)]), isNull);
    expect(parsePriceText([(text: '本体価格 ￥398', region: region)]), isNull);
    expect(parsePriceText([(text: '税別 398円', region: region)]), isNull);
  });

  test('fails closed for regular and sale prices on one line', () {
    expect(parsePriceText([(text: '通常 398円 特売 298円', region: region)]), isNull);
  });

  test('fails closed for member and regular prices on one line', () {
    expect(parsePriceText([(text: '会員 350円 通常 398円', region: region)]), isNull);
  });

  test('fails closed for contextual prices split across lines', () {
    expect(
      parsePriceText([
        (text: '通常 398円', region: region),
        (text: '特売 298円', region: region),
      ]),
      isNull,
    );
  });

  test('fails closed for SALE marker with multiple prices', () {
    expect(
      parsePriceText([(text: 'SALE 298円 通常 398円', region: region)]),
      isNull,
    );
  });

  test('selects a single sale price without guessing', () {
    final result = parsePriceText([(text: '特売 298円', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 298);
  });

  test('selects a single member price without guessing', () {
    final result = parsePriceText([(text: '会員価格 350円', region: region)]);

    expect(result, isNotNull);
    expect(result!.priceYen, 350);
  });

  test('proceeds when contextual prices agree on one value', () {
    final result = parsePriceText([
      (text: '特売 298円', region: region),
      (text: '298円', region: region),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 298);
  });

  test('ambiguous parses stay null across repeated frames', () {
    for (var i = 0; i < 3; i++) {
      expect(
        parsePriceText([(text: '通常 398円 特売 298円', region: region)]),
        isNull,
      );
    }
  });

  test('tax-inclusive coexistence is not treated as ambiguous', () {
    const largeRegion = Rect(left: 0, top: 0, right: 120, bottom: 40);
    const smallRegion = Rect(left: 0, top: 50, right: 70, bottom: 75);

    final result = parsePriceText([
      (text: '本体価格 398円', region: largeRegion),
      (text: '税込 429円', region: smallRegion),
    ]);

    expect(result, isNotNull);
    expect(result!.priceYen, 429);
  });
}
