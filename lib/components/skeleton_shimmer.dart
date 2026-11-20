import 'package:flutter/material.dart';

/// Controlador y efecto de brillo (shimmer) animado para componentes de esqueleto.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            final width = bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: t, totalWidth: width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  final double totalWidth;

  const _SlidingGradientTransform({
    required this.slidePercent,
    required this.totalWidth,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final tx = -totalWidth + (slidePercent * 2 * totalWidth);
    return Matrix4.translationValues(tx, 0.0, 0.0);
  }
}

/// Primitiva de caja de esqueleto con bordes redondeados
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Primitiva de línea de texto de esqueleto
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(6),
    );
  }
}

/// Primitiva de círculo de esqueleto para avatares y fotos
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Esqueleto que replica con exactitud la tarjeta de doctor en la lista de especialistas
class SkeletonDoctorCard extends StatelessWidget {
  const SkeletonDoctorCard({super.key});

  static Widget list({int count = 4}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const SkeletonDoctorCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(
              width: 76,
              height: 76,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLine(width: 160, height: 16),
                  const SizedBox(height: 8),
                  const SkeletonLine(width: 110, height: 13),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonBox(width: 80, height: 20, borderRadius: BorderRadius.circular(6)),
                      const SizedBox(width: 8),
                      SkeletonBox(width: 90, height: 20, borderRadius: BorderRadius.circular(6)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto completo que replica el perfil público del doctor
class SkeletonDoctorProfile extends StatelessWidget {
  const SkeletonDoctorProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tarjeta principal del médico
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 76, height: 76, borderRadius: BorderRadius.circular(16)),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 180, height: 18),
                            SizedBox(height: 8),
                            SkeletonLine(width: 130, height: 14),
                            SizedBox(height: 8),
                            SkeletonBox(width: 110, height: 22),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SkeletonBox(width: double.infinity, height: 38, borderRadius: BorderRadius.circular(10)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Acerca del especialista
            const SkeletonLine(width: 160, height: 16),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: double.infinity, height: 12),
                  SizedBox(height: 6),
                  SkeletonLine(width: double.infinity, height: 12),
                  SizedBox(height: 6),
                  SkeletonLine(width: 200, height: 12),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Barra semanal de disponibilidad
            const SkeletonLine(width: 190, height: 16),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (_) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Bloques horarios
            const SkeletonSlotsGrid(),
            const SizedBox(height: 16),

            // 5. Sedes
            const SkeletonLine(width: 150, height: 16),
            const SizedBox(height: 10),
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto para la cuadrícula de bloques horarios de disponibilidad
class SkeletonSlotsGrid extends StatelessWidget {
  final int count;
  const SkeletonSlotsGrid({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 2.3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: count,
        itemBuilder: (_, __) => SkeletonBox(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Esqueleto para una cita en la agenda médica o cola de espera
class SkeletonAppointmentItem extends StatelessWidget {
  const SkeletonAppointmentItem({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 50, height: 14),
                SizedBox(height: 4),
                SkeletonLine(width: 40, height: 10),
              ],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 140, height: 15),
                  SizedBox(height: 6),
                  SkeletonLine(width: 190, height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(width: 70, height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Variantes visuales para que el esqueleto tenga correlación real con la pantalla destino.
enum SkeletonPageVariant {
  generic,
  agenda,
  list,
  profile,
}

/// Esqueleto genérico de página completa reutilizable para cualquier pantalla
/// mientras carga datos o resuelve navegación inicial sin mostrar pantallas intermedias.
class SkeletonPageLoader extends StatelessWidget {
  final SkeletonPageVariant variant;
  final int itemCount;
  final bool showHeader;
  final bool showSummaryCards;

  const SkeletonPageLoader({
    super.key,
    this.variant = SkeletonPageVariant.generic,
    this.itemCount = 4,
    this.showHeader = true,
    this.showSummaryCards = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SkeletonShimmer(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: _buildVariantBody(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantBody(BuildContext context) {
    switch (variant) {
      case SkeletonPageVariant.agenda:
        return _buildAgendaSkeleton(context);
      case SkeletonPageVariant.list:
        return _buildListSkeleton();
      case SkeletonPageVariant.profile:
        return _buildProfileSkeleton();
      case SkeletonPageVariant.generic:
        return _buildGenericSkeleton();
    }
  }

  Widget _buildAgendaSkeleton(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra superior de agenda (selector de fecha + acciones)
        Row(
          children: [
            const SkeletonCircle(size: 40),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 170, height: 18),
                SizedBox(height: 6),
                SkeletonLine(width: 110, height: 12),
              ],
            ),
            const Spacer(),
            SkeletonBox(width: isDesktop ? 130 : 90, height: 36, borderRadius: BorderRadius.circular(10)),
            if (isDesktop) ...[
              const SizedBox(width: 10),
              SkeletonBox(width: 110, height: 36, borderRadius: BorderRadius.circular(10)),
            ],
          ],
        ),
        const SizedBox(height: 18),
        // Franja de métricas de la agenda
        Row(
          children: List.generate(
            isDesktop ? 4 : 2,
            (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == (isDesktop ? 3 : 1) ? 0 : 12),
                child: SkeletonBox(height: 74, borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna principal de citas / timeline
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLine(width: 150, height: 15),
                    const SizedBox(height: 12),
                    for (int i = 0; i < itemCount; i++) const SkeletonAppointmentItem(),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // Panel lateral de resumen del paciente / calendario
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    SkeletonBox(width: double.infinity, height: 220, borderRadius: BorderRadius.circular(16)),
                    const SizedBox(height: 14),
                    SkeletonBox(width: double.infinity, height: 150, borderRadius: BorderRadius.circular(16)),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonLine(width: 140, height: 15),
              const SizedBox(height: 12),
              for (int i = 0; i < itemCount; i++) const SkeletonAppointmentItem(),
            ],
          ),
      ],
    );
  }

  Widget _buildListSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonLine(width: 190, height: 22),
        const SizedBox(height: 14),
        // Buscador
        SkeletonBox(width: double.infinity, height: 46, borderRadius: BorderRadius.circular(12)),
        const SizedBox(height: 12),
        // Chips de filtro
        Row(
          children: [
            SkeletonBox(width: 82, height: 30, borderRadius: BorderRadius.circular(16)),
            const SizedBox(width: 8),
            SkeletonBox(width: 96, height: 30, borderRadius: BorderRadius.circular(16)),
            const SizedBox(width: 8),
            SkeletonBox(width: 78, height: 30, borderRadius: BorderRadius.circular(16)),
          ],
        ),
        const SizedBox(height: 18),
        for (int i = 0; i < itemCount; i++)
          SkeletonBox(
            width: double.infinity,
            height: 84,
            borderRadius: BorderRadius.circular(14),
            margin: const EdgeInsets.only(bottom: 12),
          ),
      ],
    );
  }

  Widget _buildProfileSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        const SkeletonCircle(size: 88),
        const SizedBox(height: 14),
        const SkeletonLine(width: 180, height: 20),
        const SizedBox(height: 8),
        const SkeletonLine(width: 130, height: 13),
        const SizedBox(height: 24),
        for (int i = 0; i < 4; i++)
          SkeletonBox(
            width: double.infinity,
            height: 62,
            borderRadius: BorderRadius.circular(14),
            margin: const EdgeInsets.only(bottom: 12),
          ),
      ],
    );
  }

  Widget _buildGenericSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          const Row(
            children: [
              SkeletonCircle(size: 42),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 180, height: 18),
                  SizedBox(height: 8),
                  SkeletonLine(width: 120, height: 12),
                ],
              ),
              Spacer(),
              SkeletonBox(width: 100, height: 36),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (showSummaryCards) ...[
          Row(
            children: [
              Expanded(
                child: SkeletonBox(
                  height: 84,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(
                  height: 84,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(
                  height: 84,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const SkeletonLine(width: 160, height: 15),
        const SizedBox(height: 14),
        for (int i = 0; i < itemCount; i++) ...[
          SkeletonBox(
            width: double.infinity,
            height: 82,
            borderRadius: BorderRadius.circular(14),
            margin: const EdgeInsets.only(bottom: 12),
          ),
        ],
      ],
    );
  }
}

