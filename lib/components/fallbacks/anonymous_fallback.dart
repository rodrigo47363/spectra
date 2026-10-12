import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:spotube/collections/routes.gr.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/provider/metadata_plugin/core/auth.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';

class AnonymousFallback extends HookConsumerWidget {
  final Widget? child;
  const AnonymousFallback({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final isLoggedIn = ref.watch(metadataPluginAuthenticatedProvider);
    final isAuthenticating = useState(false);
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';

    if (isLoggedIn.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isLoggedIn.asData?.value == true && child != null) return child!;

    Future<void> handleLogin() async {
      isAuthenticating.value = true;
      try {
        final plugin = await ref.read(metadataPluginProvider.future);
        if (plugin != null) {
          await plugin.auth.authenticate();
        } else {
          if (context.mounted) {
            context.navigateTo(const SettingsMetadataProviderRoute());
          }
        }
      } catch (e) {
        if (context.mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) => SurfaceCard(
              child: Text(
                isSpanish
                    ? 'Abre Proveedores en Ajustes para iniciar sesión.'
                    : 'Open Metadata Providers in Settings to log in.',
              ),
            ),
          );
          context.navigateTo(const SettingsMetadataProviderRoute());
        }
      } finally {
        isAuthenticating.value = false;
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SurfaceCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    SpotubeIcons.library,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                OutlineBadge(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      const Icon(SpotubeIcons.info, size: 12),
                      Text(
                        isSpanish
                            ? 'Sincronización Opcional'
                            : 'Optional Cloud Sync',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isSpanish
                      ? 'Tu Biblioteca Personal'
                      : 'Your Personal Library',
                  style: theme.typography.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  isSpanish
                      ? 'Inicia sesión con tu proveedor preferido (como Spotify o ListenBrainz) para sincronizar tus listas guardadas, canciones favoritas y artistas en la nube.'
                      : 'Log in with your preferred metadata provider (such as Spotify or ListenBrainz) to sync your saved playlists, liked tracks, and followed artists.',
                  style: TextStyle(
                    color: theme.colorScheme.mutedForeground,
                    fontSize: 14,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      _BenefitItem(
                        icon: SpotubeIcons.playlist,
                        title: isSpanish
                            ? 'Listas y Guardados'
                            : 'Playlists & Saved Items',
                        description: isSpanish
                            ? 'Accede a tus playlists de la nube directamente aquí.'
                            : 'Access all your remote playlists directly from this tab.',
                      ),
                      const SizedBox(height: 12),
                      _BenefitItem(
                        icon: SpotubeIcons.heart,
                        title: isSpanish
                            ? 'Favoritos Sincronizados'
                            : 'Synced Favorites',
                        description: isSpanish
                            ? 'Sincroniza canciones y artistas favoritos entre dispositivos.'
                            : 'Sync favorite songs and followed artists across devices.',
                      ),
                      const SizedBox(height: 12),
                      _BenefitItem(
                        icon: SpotubeIcons.music,
                        title: isSpanish
                            ? '100% Funcional sin Cuenta'
                            : '100% Functional Without Account',
                        description: isSpanish
                            ? 'Puedes buscar y reproducir cualquier música libremente sin loguearte.'
                            : 'You can search, browse, and stream all music freely without logging in.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Button.primary(
                        leading: isAuthenticating.value
                            ? SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primaryForeground,
                                ),
                              )
                            : const Icon(SpotubeIcons.login, size: 16),
                        onPressed:
                            isAuthenticating.value ? null : () => handleLogin(),
                        child: Text(
                          isAuthenticating.value
                              ? (isSpanish ? 'Conectando...' : 'Connecting...')
                              : (isSpanish
                                  ? 'Conectar Cuenta'
                                  : 'Connect Account'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Button.outline(
                        leading: const Icon(SpotubeIcons.plugin, size: 16),
                        onPressed: () => context.navigateTo(
                          const SettingsMetadataProviderRoute(),
                        ),
                        child: Text(
                          isSpanish
                              ? 'Proveedores y Cuentas'
                              : 'Providers & Accounts',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Button.ghost(
                      leading: const Icon(SpotubeIcons.search, size: 16),
                      onPressed: () => context.navigateTo(const SearchRoute()),
                      child: Text(
                        isSpanish ? 'Explorar' : 'Explore',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.typography.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: theme.colorScheme.mutedForeground,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
