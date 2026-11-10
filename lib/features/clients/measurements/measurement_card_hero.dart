part of 'paris_client_measurements_page.dart';

extension _MeasurementCardHero on _ParisClientMeasurementsPageState {
  // كارت المقاس في القايمة (المختصر). لمسة عليه بتفتح المحرر (measurement_editor.dart)
  Widget _measurementCard(_Measurement item, int index) {
    return Padding(
      key: ValueKey('measurement-${item.id}'),
      padding: const EdgeInsets.only(bottom: 3),
      child: RepaintBoundary(
        child: _cardShell(
          item,
          index,
          zoom: _compactZoom,
          reveal: 0,
          popup: false,
        ),
      ),
    );
  }
}
