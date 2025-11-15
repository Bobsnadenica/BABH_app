/// Single source of truth for app configuration structure and defaults.
/// This JSON is used for:
/// 1. Providing default values when S3 is unavailable
/// 2. Parsing S3 config into typed objects
/// 3. Validating S3 config structure
///
/// NO hardcoding elsewhere - all config logic derives from this schema.
const Map<String, dynamic> appPropertiesSchema = {
  'app': {
    'version': '1.0.0',
    'name': 'BABH Дневници',
  },
  'folders': [
    'ЗА ВХОДЯЩ КОНТРОЛ НА ПРИЕТИТЕ ХРАНИ И ОПАКОВЪЧНИТЕ МАТЕРИАЛИ',
    'ЗА ИЗХОДЯЩ КОНТРОЛ НА ПРОИЗВЕДЕНАТА ПРОДУКЦИЯ',
    'ЗА ОТЧИТАНЕ ТЕМПЕРАТУРАТА НА ХЛАДИЛНИТЕ СИСТЕМИ',
    'ЗА ПОДДЪРЖАНЕ ХИГИЕННОТО СЪСТОЯНИЕ НА ОБЕКТА',
    'ЗА ЛИЧНАТА ХИГИЕНА НА ПЕРСОНАЛА',
    'ЗА ИЗВЪРШЕН ИНСТРУКТАЖ И ОБУЧЕНИЕ НА ПЕРСОНАЛА ПО ДОБРИ ПРОИЗВОДСТВЕНИ И ХИГИЕННИ ПРАКТИКИ',
    'ЗА ПРОВЕДЕНИ ДДД МЕРОПРИЯТИЯ /ДЕЗИНСЕКЦИЯ, ДЕРАТИЗАЦИЯ/',
  ],
  'compression': {
    'quality': 85,
    'maxWidth': 1920,
    'maxHeight': 1920,
    'thumbnailQuality': 70,
    'thumbnailWidth': 256,
    'thumbnailHeight': 256,
  },
  'storage': {
    'trashRetentionDays': 30,
  },
};
