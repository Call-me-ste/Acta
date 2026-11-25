import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/calendar/cluster.dart';

/// Il contratto del cap a 2 caselle: come si raggruppa e come si spezza.
void main() {
  test('tre elementi sovrapposti fanno un cluster di tre', () {
    // Esempio del contratto: evento 18-22, evento 20-22, todo 21-22.
    final clusters = clusterDi<String>([
      ('evento 18-22', 18 * 60, 22 * 60),
      ('evento 20-22', 20 * 60, 22 * 60),
      ('todo 21-22', 21 * 60, 22 * 60),
    ]);

    expect(clusters, hasLength(1));
    expect(clusters.single.visibili, ['evento 18-22', 'evento 20-22']);
    expect(clusters.single.nascosti, ['todo 21-22']);
    expect(clusters.single.haBollino, isTrue);
    expect(clusters.single.corsie, 3);
    // Il bollino sta sull'intera finestra del cluster.
    expect(clusters.single.inizio, 18 * 60);
    expect(clusters.single.fine, 22 * 60);
  });

  test('il raggruppamento attraversa i confini: uno che chiude il buco unisce',
      () {
    // A 8-12 copre B e C: benché B e C non si tocchino fra loro, stanno con A.
    final clusters = clusterDi<String>([
      ('c', 10 * 60, 10 * 60 + 30),
      ('a', 8 * 60, 12 * 60),
      ('b', 9 * 60, 9 * 60 + 30),
    ]);

    expect(clusters, hasLength(1));
    expect(clusters.single.visibili, ['a', 'b']);
    expect(clusters.single.nascosti, ['c']);
  });

  test('elementi separati fanno cluster separati', () {
    final clusters = clusterDi<String>([
      ('mattina', 8 * 60, 9 * 60),
      ('pomeriggio', 10 * 60, 11 * 60),
    ]);

    expect(clusters, hasLength(2));
    expect(clusters.every((c) => !c.haBollino), isTrue);
    expect(clusters.every((c) => c.corsie == 1), isTrue);
  });

  test('fine uguale all\'inizio di un altro = due cluster (confine a contatto)',
      () {
    // La regola `!isAfter` di `DayLayout`: chi si tocca non si sovrappone.
    final clusters = clusterDi<String>([
      ('primo', 8 * 60, 9 * 60),
      ('secondo', 9 * 60, 10 * 60),
    ]);

    expect(clusters, hasLength(2));
  });

  test('cluster da due: tutte le caselle, nessun bollino', () {
    final clusters = clusterDi<String>([
      ('a', 9 * 60, 10 * 60),
      ('b', 9 * 60 + 30, 10 * 60 + 30),
    ]);

    expect(clusters.single.visibili, ['a', 'b']);
    expect(clusters.single.nascosti, isEmpty);
    expect(clusters.single.haBollino, isFalse);
    expect(clusters.single.corsie, 2);
  });

  test('il cap tiene le prime 2 per orino di inizio, non per posizione', () {
    final clusters = clusterDi<String>([
      ('tardi', 11 * 60, 13 * 60),
      ('primo', 9 * 60, 12 * 60),
      ('mezzo', 10 * 60, 12 * 60),
    ]);

    expect(clusters.single.visibili, ['primo', 'mezzo']);
    expect(clusters.single.nascosti, ['tardi']);
  });

  test('a parità di inizio vale l\'ordine dato: è stabile', () {
    final clusters = clusterDi<String>([
      ('evento', 9 * 60, 11 * 60),
      ('todo', 9 * 60, 10 * 60),
      ('evento 2', 9 * 60, 10 * 60),
    ]);

    expect(clusters.single.visibili, ['evento', 'todo']);
    expect(clusters.single.nascosti, ['evento 2']);
  });

  test('nessun elemento, nessun cluster', () {
    expect(clusterDi<String>(const []), isEmpty);
    expect(corsieDeiCluster(const <Cluster<String>>[]), 1);
  });

  test('corsieDeiCluster prende la più alta, con minimo 1', () {
    final clusters = clusterDi<String>([
      ('a', 8 * 60, 9 * 60),
      ('b', 8 * 60 + 15, 9 * 60),
      ('c', 8 * 60 + 30, 9 * 60),
      ('solo', 14 * 60, 15 * 60),
    ]);

    expect(corsieDeiCluster(clusters), 3);
    expect(corsieDeiCluster([clusters.last]), 1);
  });
}
