import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

void main() {
  test('repairPolishText fixes lossy question-mark text', () {
    expect(
      TextUtils.repairPolishText('Do??czy?e? do czatu'),
      'Dołączyłeś do czatu',
    );
    expect(TextUtils.repairPolishText('Wiadomo??'), 'Wiadomość');
    expect(TextUtils.repairPolishText('U?ytkownik'), 'Użytkownik');
    expect(TextUtils.repairPolishText('Cz?onek grupy'), 'Członek grupy');
  });

  test('repairPolishText keeps valid Polish text untouched', () {
    const value = 'Zażółć gęślą jaźń';
    expect(TextUtils.repairPolishText(value), value);
  });

  test('repairPolishText fixes common mojibake sequences', () {
    expect(TextUtils.repairPolishText('ZaĹ‚Ä…cznik'), 'Załącznik');
    expect(TextUtils.repairPolishText('UÅ¼ytkownik'), 'Użytkownik');
    expect(TextUtils.repairPolishText('Policja'), 'Policja');
  });

  test('unitChatId preserves service channel identifiers', () {
    expect(TextUtils.unitChatId('service_psp'), 'unit_service_psp');
    expect(TextUtils.unitChatId('unit_service_media'), 'unit_service_media');
  });
}
