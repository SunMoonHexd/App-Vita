import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_app/ui/core/theme/vita_theme.dart';
import 'package:vita_app/ui/core/widgets/vita_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'componentes de estado, cabecera y tarjetas muestran sus opciones',
    (tester) async {
      var cardTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: VitaTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                const VitaHeroHeader(
                  eyebrow: 'Bienvenida',
                  title: 'Adulto mayor',
                  trailing: Icon(Icons.person),
                  child: Text('Conexión activa'),
                ),
                const VitaHeader(
                  eyebrow: 'Buenos días',
                  title: 'VITA',
                  badge: VitaPill(label: 'Verificada'),
                  trailing: Icon(Icons.account_circle),
                ),
                const VitaPill(
                  label: 'Disponible',
                  tone: VitaTone.success,
                  dot: true,
                  icon: Icons.check,
                ),
                const VitaStatTile(
                  icon: Icons.call,
                  label: 'Hoy',
                  value: '2 llamadas',
                  tone: VitaTone.info,
                ),
                VitaCard(
                  tone: VitaTone.warning,
                  onTap: () => cardTapped = true,
                  child: const Text('Aviso importante'),
                ),
                const VitaCard(
                  children: [Text('Elemento uno'), Text('Elemento dos')],
                ),
                const VitaErrorText('Revisa los datos ingresados.'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Adulto mayor'), findsOneWidget);
      expect(find.text('Conexión activa'), findsOneWidget);
      expect(find.text('Buenos días'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('2 llamadas'), findsOneWidget);
      expect(find.text('Elemento uno'), findsOneWidget);
      expect(find.text('Revisa los datos ingresados.'), findsOneWidget);

      await tester.ensureVisible(find.text('Aviso importante'));
      await tester.tap(find.text('Aviso importante'));
      expect(cardTapped, isTrue);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VitaErrorText(null))),
      );
      expect(find.text('Revisa los datos ingresados.'), findsNothing);
    },
  );

  testWidgets('botones VITA y navegación notifican la acción seleccionada', (
    tester,
  ) async {
    var primaryTapped = false;
    var secondaryTapped = false;
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: VitaTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('Prueba')),
          body: Column(
            children: [
              VitaPrimaryButton(
                label: 'Continuar',
                icon: Icons.arrow_forward,
                onPressed: () => primaryTapped = true,
              ),
              VitaSecondaryButton(
                label: 'Volver',
                icon: Icons.arrow_back,
                onPressed: () => secondaryTapped = true,
              ),
            ],
          ),
          bottomNavigationBar: VitaNavBar(
            selectedIndex: 1,
            items: const [
              VitaNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Inicio',
              ),
              VitaNavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Perfil',
              ),
            ],
            onSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.tap(find.text('Volver'));
    await tester.tap(find.text('Inicio'));
    expect(primaryTapped, isTrue);
    expect(secondaryTapped, isTrue);
    expect(selectedIndex, 0);

    await tester.pumpWidget(
      MaterialApp(
        theme: VitaTheme.light,
        home: VitaPage(title: 'Página VITA', child: Text('Contenido')),
      ),
    );
    expect(find.text('Página VITA'), findsOneWidget);
    expect(find.text('Contenido'), findsOneWidget);
  });
}
