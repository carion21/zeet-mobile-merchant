// lib/screens/order_details/receipt_screen.dart
//
// Apercu du bon de livraison d'une commande terminee. Recupere le HTML
// genere par le backend (`GET /v1/partner/orders/:id/receipt`) et affiche
// la version textuelle (tags HTML strippes) pour un format lisible mobile.
//
// La version PDF est en follow-up backend (puppeteer / pdfkit). Pour
// l'instant le partner peut copier le contenu pour l'envoyer par email
// ou WhatsApp ; un bouton "Partager" arrivera quand `share_plus` sera
// integre au workspace.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/services/order_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OrderReceiptScreen extends StatefulWidget {
  const OrderReceiptScreen({
    super.key,
    required this.orderId,
    this.orderCode,
  });

  final int orderId;
  final String? orderCode;

  @override
  State<OrderReceiptScreen> createState() => _OrderReceiptScreenState();
}

class _OrderReceiptScreenState extends State<OrderReceiptScreen> {
  String? _html;
  String? _plainText;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String html = await OrderService().fetchReceiptHtml(widget.orderId);
      if (!mounted) return;
      setState(() {
        _html = html;
        _plainText = _stripHtml(html);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Strip basique des tags HTML pour rendu textuel mobile. Conserve les
  /// blocs principaux (h1/h2 → header, p/div → newline). Le HTML brut
  /// reste copiable via "Copier le HTML" pour le partner qui veut l'envoyer
  /// par mail.
  String _stripHtml(String html) {
    String text = html;
    // Header sections en bloc
    text = text.replaceAll(RegExp(r'</?(h1|h2|h3|p|div|tr)[^>]*>'), '\n');
    // Cellules tableau separees par tab
    text = text.replaceAll(RegExp(r'</?(td|th)[^>]*>'), '\t');
    // Drop tous les autres tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    // Decode entites HTML basiques
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    // Compact multiple newlines
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
    return text.trim();
  }

  Future<void> _copyHtml() async {
    if (_html == null) return;
    await Clipboard.setData(ClipboardData(text: _html!));
    if (!mounted) return;
    ZeetHaptics.success();
    AppToast.showSuccess(
      context: context,
      message: 'HTML copie — collez-le dans un mail ou WhatsApp',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String title = widget.orderCode != null
        ? 'Reçu ${widget.orderCode}'
        : 'Reçu commande';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: Text(title),
        actions: <Widget>[
          if (_html != null)
            IconButton(
              tooltip: 'Copier le HTML',
              icon: const Icon(Icons.content_copy_rounded),
              onPressed: _copyHtml,
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.all(20.w),
        child: ZeetErrorState.fromError(_error!, onRetry: _load),
      );
    }
    if (_plainText == null || _plainText!.isEmpty) {
      return ZeetErrorState(
        kind: ZeetErrorKind.notFound,
        title: 'Reçu vide',
        description: 'Le serveur a renvoyé un document vide.',
        onRetry: _load,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: ZeetColors.infoBg,
              borderRadius: BorderRadius.circular(ZeetRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 20.r,
                  color: ZeetColors.infoText,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Aperçu textuel — version PDF en préparation. Vous pouvez copier le HTML pour l\'envoyer par mail.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: ZeetColors.infoText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          SelectableText(
            _plainText!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: const <String>['Menlo', 'Consolas'],
              fontSize: 13.sp,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
