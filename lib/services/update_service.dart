import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String _githubRepo = 'briwno/app_remedio';
  static const String _apiUrl =
      'https://api.github.com/repos/$_githubRepo/releases/latest';

  /// Verifica se há atualização e mostra dialog se houver.
  static Future<void> verificarAtualizacao(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final versaoAtual = info.version;

      final response = await http
          .get(Uri.parse(_apiUrl), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?)?.replaceFirst('v', '');
      if (tagName == null) return;

      if (!_versaoMaisNova(versaoAtual, tagName)) return;

      // Procura o APK nos assets do release
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null) return;

      final notas = data['body'] as String? ?? '';

      if (!context.mounted) return;

      _mostrarDialogAtualizacao(context, tagName, notas, apkUrl);
    } catch (e) {
      debugPrint('UpdateService: erro ao verificar atualização: $e');
    }
  }

  /// Compara semver: retorna true se remota > atual
  static bool _versaoMaisNova(String atual, String remota) {
    final partesAtual = atual.split('.').map(int.tryParse).toList();
    final partesRemota = remota.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final a = (i < partesAtual.length ? partesAtual[i] : 0) ?? 0;
      final r = (i < partesRemota.length ? partesRemota[i] : 0) ?? 0;
      if (r > a) return true;
      if (r < a) return false;
    }
    return false;
  }

  static void _mostrarDialogAtualizacao(
      BuildContext context, String versao, String notas, String apkUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF44B4A6)),
            SizedBox(width: 10),
            Text('Atualização v$versao'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uma nova versão está disponível!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (notas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Novidades:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(notas, style: TextStyle(color: Colors.grey[700])),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Depois'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _baixarEInstalar(context, apkUrl, versao);
            },
            icon: const Icon(Icons.download),
            label: const Text('Atualizar'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF44B4A6),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _baixarEInstalar(
      BuildContext context, String url, String versao) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Baixando atualização...'),
          ],
        ),
        duration: Duration(minutes: 5),
      ),
    );

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Erro ao baixar a atualização.')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/app_remedio_$versao.apk');
      await file.writeAsBytes(response.bodyBytes);

      messenger.hideCurrentSnackBar();

      final result = await OpenFilex.open(file.path,
          type: 'application/vnd.android.package-archive');

      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o instalador: ${result.message}')),
        );
      }
    } catch (e) {
      debugPrint('UpdateService: erro ao baixar/instalar: $e');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Erro ao baixar a atualização.')),
      );
    }
  }
}
