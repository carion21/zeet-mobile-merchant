// lib/screens/order_details/widgets/order_code_header.dart
//
// Ligne header : code commande copiable + date formatee. Le bouton code
// est prominent, monospace, tap pour copier dans le presse-papier (gain
// de plusieurs secondes par incident support).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:merchant/core/widgets/order_code_text.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/order_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OrderCodeHeader extends StatelessWidget {
  const OrderCodeHeader({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateFormat dateFormat =
        DateFormat('dd MMM yyyy - HH:mm', 'fr_FR');
    String formattedDate = '';
    if (order.createdAt != null) {
      try {
        formattedDate = dateFormat.format(DateTime.parse(order.createdAt!));
      } catch (_) {
        formattedDate = order.createdAt ?? '';
      }
    }
    final String code = order.code ?? '#${order.id}';

    return Row(
      children: <Widget>[
        Flexible(child: _HeaderCodeButton(code: code)),
        if (formattedDate.isNotEmpty) ...<Widget>[
          SizedBox(width: 12.w),
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 12.sp,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderCodeButton extends StatelessWidget {
  const _HeaderCodeButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Code commande $code, toucher pour copier',
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: () async {
            ZeetHaptics.success();
            await Clipboard.setData(ClipboardData(text: code));
            if (!context.mounted) return;
            AppToast.showSuccess(
              context: context,
              message: 'Code $code copié',
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: OrderCodeText(
                    code: code,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: 0.3,
                      fontFamily: 'monospace',
                      fontFamilyFallback: const <String>['Menlo', 'Consolas'],
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.content_copy_rounded,
                  size: 14.r,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
