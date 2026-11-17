import 'package:flutter/material.dart';

/// Botón interactivo de alta fidelidad que despliega un spinner de carga animado cuando ejecuta
/// una acción asíncrona, deshabilitando toques duplicados y preservando sus dimensiones exactas.
///
/// Soporta dos variantes visuales:
/// - Relleno sólido (`LoadingButton`)
/// - Bordeado transparente (`LoadingButton.outlined`)
///
/// Permite gestión automática del estado de carga mediante [onAsyncPressed],
/// o control manual externo mediante [isLoading].
class LoadingButton extends StatefulWidget {
  /// Función asíncrona que se ejecuta al presionar el botón.
  /// Activa automáticamente el spinner interno hasta que la operación finaliza.
  final Future<void> Function()? onAsyncPressed;

  /// Callback síncrono estándar (útil si el estado de carga es gestionado externamente).
  final VoidCallback? onPressed;

  /// Bandera explícita de carga. Si se suministra, tiene prioridad sobre el estado interno.
  final bool? isLoading;

  /// Texto principal visible en el botón en estado inactivo.
  final String label;

  /// Texto opcional que acompaña al spinner durante el proceso de carga.
  final String? loadingLabel;

  /// Widget de icono colocado a la izquierda del texto principal.
  final Widget? icon;

  /// Color de fondo del botón (en modo sólido) o contenedor.
  final Color? backgroundColor;

  /// Color del texto e icono.
  final Color? foregroundColor;

  /// Color personalizado del spinner CircularProgressIndicator.
  final Color? spinnerColor;

  /// Altura fija del botón. Por defecto: 46.0 píxeles.
  final double height;

  /// Ancho del botón. Si es nulo, se ajusta al contenido; si es double.infinity, ocupa todo el ancho.
  final double? width;

  /// Radio de curvatura de las esquinas redondeadas.
  final double borderRadius;

  /// Elevación o sombra proyectada del botón.
  final double elevation;

  /// Define si el botón adopta la estética de borde exterior (Outlined).
  final bool isOutlined;

  /// Propiedades de trazo del borde exterior.
  final BorderSide? borderSide;

  /// Estilo tipográfico personalizado para la etiqueta.
  final TextStyle? textStyle;

  /// Relleno interno horizontal y vertical.
  final EdgeInsetsGeometry? padding;

  const LoadingButton({
    super.key,
    this.onAsyncPressed,
    this.onPressed,
    this.isLoading,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.spinnerColor,
    this.height = 46.0,
    this.width,
    this.borderRadius = 12.0,
    this.elevation = 0.5,
    this.isOutlined = false,
    this.borderSide,
    this.textStyle,
    this.padding,
  });

  /// Constructor de conveniencia para botón de estilo bordeado (Outlined)
  const LoadingButton.outlined({
    super.key,
    this.onAsyncPressed,
    this.onPressed,
    this.isLoading,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.backgroundColor = Colors.transparent,
    this.foregroundColor,
    this.spinnerColor,
    this.height = 46.0,
    this.width,
    this.borderRadius = 12.0,
    this.elevation = 0.0,
    this.borderSide,
    this.textStyle,
    this.padding,
  }) : isOutlined = true;

  /// Constructor para botón expandido al 100% del ancho del contenedor padre
  const LoadingButton.fullWidth({
    super.key,
    this.onAsyncPressed,
    this.onPressed,
    this.isLoading,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.spinnerColor,
    this.height = 48.0,
    this.borderRadius = 12.0,
    this.elevation = 0.5,
    this.isOutlined = false,
    this.borderSide,
    this.textStyle,
    this.padding,
  })  : width = double.infinity;

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _internalLoading = false;

  bool get _effectiveLoading => widget.isLoading ?? _internalLoading;

  Future<void> _handlePress() async {
    if (_effectiveLoading) return;

    if (widget.onAsyncPressed != null) {
      setState(() => _internalLoading = true);
      try {
        await widget.onAsyncPressed!();
      } finally {
        if (mounted) setState(() => _internalLoading = false);
      }
    } else if (widget.onPressed != null) {
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.backgroundColor ?? const Color(0xFF0284C7);
    final onPrimary = widget.foregroundColor ??
        (widget.isOutlined ? const Color(0xFF0284C7) : Colors.white);
    final spinColor = widget.spinnerColor ??
        (widget.isOutlined ? const Color(0xFF0284C7) : Colors.white);

    final bool isDisabled =
        (widget.onAsyncPressed == null && widget.onPressed == null) ||
            _effectiveLoading;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      side: widget.isOutlined
          ? (widget.borderSide ?? const BorderSide(color: Color(0xFFBAE6FD), width: 1.2))
          : BorderSide.none,
    );

    final childWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _effectiveLoading
          ? Row(
              key: const ValueKey('loading_state'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(spinColor),
                  ),
                ),
                if (widget.loadingLabel != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.loadingLabel!,
                    style: (widget.textStyle ??
                            theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ))
                        ?.copyWith(color: onPrimary),
                  ),
                ],
              ],
            )
          : Row(
              key: const ValueKey('content_state'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: (widget.textStyle ??
                          theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ))
                      ?.copyWith(color: onPrimary),
                ),
              ],
            ),
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: widget.isOutlined
          ? (widget.backgroundColor ?? Colors.transparent)
          : primaryColor,
      foregroundColor: onPrimary,
      disabledBackgroundColor: widget.isOutlined
          ? Colors.transparent
          : primaryColor.withValues(alpha: 0.65),
      disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
      elevation: widget.isOutlined ? 0.0 : widget.elevation,
      shadowColor: primaryColor.withValues(alpha: 0.3),
      shape: shape,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
    );

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isDisabled ? null : _handlePress,
        child: childWidget,
      ),
    );
  }
}
