import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:spotube/collections/assets.gen.dart';
import 'package:spotube/collections/env.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/button/back_button.dart';
import 'package:spotube/components/titlebar/titlebar.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/hooks/controllers/use_package_info.dart';
import 'package:auto_route/auto_route.dart';
import 'package:url_launcher/url_launcher_string.dart';

@RoutePage()
class AboutSpotubePage extends HookConsumerWidget {
  static const name = "about";

  const AboutSpotubePage({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showToast(
        context: context,
        location: ToastLocation.topRight,
        builder: (context, overlay) {
          return SurfaceCard(
            child: Basic(
              leading: const Icon(SpotubeIcons.done, color: Colors.green),
              title: Text("$label copiado al portapapeles"),
              subtitle: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          );
        },
      );
    }
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Button.outline(
      leading: Icon(icon, size: 16),
      onPressed: () => launchUrlString(url, mode: LaunchMode.externalApplication),
      child: Text(label),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title).bold(),
                const Gap(4),
                Text(description).small().muted(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoRow({
    required BuildContext context,
    required String coin,
    required String network,
    required String address,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(coin).bold(),
                    const Gap(8),
                    OutlineBadge(child: Text(network).xSmall()),
                  ],
                ),
                const Gap(4),
                Text(
                  address,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ).muted(),
              ],
            ),
          ),
          const Gap(8),
          IconButton.outline(
            icon: const Icon(FeatherIcons.copy, size: 16),
            onPressed: () =>
                _copyToClipboard(context, address, "Dirección $coin"),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label).semiBold().muted(),
          ),
          const Text(": "),
          const Gap(8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ).semiBold(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = usePackageInfo();
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          TitleBar(
            leading: const [BackButton()],
            title: Text(context.l10n.about_spectra),
          )
        ],
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. BRANDING / HERO HEADER
                    Center(
                      child: Column(
                        children: [
                          Assets.branding.spotubeLogoPng.image(
                            height: 120,
                            width: 120,
                          ),
                          const Gap(16),
                          const Text("Spectra").extraBold().x2Large(),
                          const Gap(8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PrimaryBadge(
                                child: Text("v${packageInfo.version}+${packageInfo.buildNumber}"),
                              ),
                              const Gap(8),
                              const SecondaryBadge(
                                child: Text("Zero Telemetry"),
                              ),
                              const Gap(8),
                              const OutlineBadge(
                                child: Text("Cross-Platform"),
                              ),
                            ],
                          ),
                          const Gap(12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 580),
                            child: const Text(
                              "Reproductor y gestor de audio libre, diseñado con enfoque de privacidad por diseño, bajo consumo de recursos y total soberanía sobre los datos del usuario.",
                              textAlign: TextAlign.center,
                            ).muted(),
                          ),
                        ],
                      ),
                    ),

                    const Gap(32),

                    // 2. LEAD DEVELOPER & ARCHITECT CARD
                    Card(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  FeatherIcons.shield,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                              const Gap(16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Rodrigo").bold().large(),
                                    const Text(
                                      "Offensive Security Specialist & Software Architect",
                                    ).semiBold().small().muted(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.muted.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: theme.colorScheme.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(FeatherIcons.terminal, size: 16),
                                const Gap(8),
                                Expanded(
                                  child: const Text(
                                    "\"Impacto real > Teoría. Privacidad y rendimiento de grado operativo.\"",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'monospace',
                                    ),
                                  ).small(),
                                ),
                              ],
                            ),
                          ),
                          const Gap(14),
                          const Text(
                            "Especialista en seguridad ofensiva centrado en penetration testing, operaciones de Red Team, auditorías de red e investigación de vulnerabilidades. Spectra representa la convergencia entre arquitectura de software de ultra-baja latencia y la erradicación total del rastreo de telemetría invasiva.",
                          ).small().muted(),
                          const Gap(16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildSocialButton(
                                icon: SimpleIcons.github,
                                label: "GitHub",
                                url: "https://github.com/rodrigo47363",
                              ),
                              _buildSocialButton(
                                icon: SimpleIcons.linkedin,
                                label: "LinkedIn",
                                url: "https://linkedin.com/in/rodrigo-v-695728215",
                              ),
                              _buildSocialButton(
                                icon: SimpleIcons.youtube,
                                label: "YouTube",
                                url: "https://youtube.com/@Rodrigo-47363",
                              ),
                              _buildSocialButton(
                                icon: SimpleIcons.protonmail,
                                label: "ProtonMail",
                                url: "mailto:rodrigovil@proton.me",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Gap(24),

                    // 3. ARCHITECTURE & PHILOSOPHY
                    const Text("Arquitectura y Principios de Diseño").bold().large(),
                    const Gap(12),
                    _buildFeatureCard(
                      icon: FeatherIcons.lock,
                      iconColor: Colors.emerald,
                      title: "Cero Telemetría & Privacidad Radical",
                      description:
                          "Sin trackers de comportamiento, sin analíticas en segundo plano y sin envío de identificadores remotos. Tu historial, consultas y biblioteca pertenecen exclusivamente a ti.",
                    ),
                    const Gap(10),
                    _buildFeatureCard(
                      icon: FeatherIcons.zap,
                      iconColor: Colors.amber,
                      title: "Motor Nativo libmpv (C++)",
                      description:
                          "Integración directa con libmpv nativo para decodificación eficiente por hardware, búfer optimizado y reproducción de audio sin pérdida de calidad ni latencia.",
                    ),
                    const Gap(10),
                    _buildFeatureCard(
                      icon: FeatherIcons.database,
                      iconColor: Colors.cyan,
                      title: "Local-First & Soberanía de Datos",
                      description:
                          "Persistencia en base de datos local SQLite y almacenamiento de claves cifradas en el dispositivo. Cero dependencia de nubes cerradas para tu configuración.",
                    ),
                    const Gap(10),
                    _buildFeatureCard(
                      icon: FeatherIcons.cpu,
                      iconColor: Colors.purple,
                      title: "Ecosistema Desacoplado BYOMM",
                      description:
                          "Arquitectura extensible 'Bring Your Own Music Metadata' que independiza el núcleo del reproductor de las fuentes externas de información.",
                    ),

                    const Gap(24),

                    // 4. ESPECIFICACIONES TÉCNICAS
                    const Text("Especificaciones de Compilación").bold().large(),
                    const Gap(12),
                    Card(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _buildSpecRow("Edición", "Spectra Multiplatform"),
                          _buildSpecRow("Versión", "v${packageInfo.version}"),
                          _buildSpecRow("Build Number", packageInfo.buildNumber),
                          _buildSpecRow("Canal", Env.releaseChannel.name),
                          _buildSpecRow("Plataformas", "Android • Windows • Linux"),
                          _buildSpecRow("Licencia", "BSD-4-Clause (Open Source)"),
                          _buildSpecRow("Repositorio", "https://github.com/rodrigo47363/spectra"),
                        ],
                      ),
                    ),

                    const Gap(24),

                    // 5. APORTE A LA INVESTIGACIÓN OPERATIVA (CRYPTO SUPPORT)
                    Row(
                      children: [
                        const Icon(SpotubeIcons.heart, color: Colors.pink, size: 20),
                        const Gap(8),
                        const Text("Apoyo a la Investigación Operativa").bold().large(),
                      ],
                    ),
                    const Gap(8),
                    const Text(
                      "Si este desarrollo, los frameworks de auditoría o las herramientas de seguridad han aportado valor a tus operaciones, puedes respaldar el desarrollo continuo y la investigación técnica:",
                    ).small().muted(),
                    const Gap(12),
                    _buildCryptoRow(
                      context: context,
                      coin: "Bitcoin (BTC)",
                      network: "BTC Native",
                      address: "bc1qkzmpd0hry99qms7ef23vsyx9vt34pzzaslpp8y",
                      icon: SimpleIcons.bitcoin,
                      color: Colors.amber,
                    ),
                    const Gap(10),
                    _buildCryptoRow(
                      context: context,
                      coin: "Ethereum (ETH)",
                      network: "ERC-20 / EVM",
                      address: "0xB75bC57C54FCBFF139EBF981A596B019C537d018",
                      icon: SimpleIcons.ethereum,
                      color: Colors.blue,
                    ),
                    const Gap(10),
                    _buildCryptoRow(
                      context: context,
                      coin: "Solana (SOL)",
                      network: "SPL",
                      address: "ELekuGHcmZjhXrtHNqHuu8QmdCZr3oCWtTmu3QUQ5hac",
                      icon: FeatherIcons.zap,
                      color: Colors.purple,
                    ),

                    const Gap(32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
