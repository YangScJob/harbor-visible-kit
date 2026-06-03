import 'package:flutter/material.dart';

import 'package:harbor_visible_kit/app/theme/app_theme.dart';

class WorkflowStepData {
  final IconData icon;
  final String title;
  final String subtitle;

  const WorkflowStepData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class WorkflowSteps extends StatelessWidget {
  final List<WorkflowStepData> steps;
  final int currentStep;
  final Brightness? brightness;

  const WorkflowSteps({
    super.key,
    required this.steps,
    required this.currentStep,
    this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final width = narrow || steps.isEmpty
            ? constraints.maxWidth
            : (constraints.maxWidth - (10 * (steps.length - 1))) / steps.length;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: width,
                child: _WorkflowStep(
                  steps[i],
                  index: i,
                  currentStep: currentStep,
                  brightness: b,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  final WorkflowStepData step;
  final int index;
  final int currentStep;
  final Brightness brightness;

  const _WorkflowStep(
    this.step, {
    required this.index,
    required this.currentStep,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final done = currentStep > index;
    final active = currentStep == index;
    final color = done
        ? AppTheme.suc(brightness)
        : active
        ? AppTheme.upl(brightness)
        : AppTheme.textM(brightness);
    final background = done
        ? AppTheme.sucDim(brightness).withValues(alpha: 0.52)
        : active
        ? AppTheme.uplDim(brightness).withValues(alpha: 0.58)
        : AppTheme.surf(brightness);

    return Semantics(
      container: true,
      label: '${index + 1}. ${step.title}，${step.subtitle}',
      child: AnimatedContainer(
        duration: AppTheme.animNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: active || done
                ? color.withValues(alpha: 0.38)
                : AppTheme.surfBorder(brightness),
          ),
        ),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle_rounded : step.icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: AppTheme.textP(brightness),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textM(brightness),
                      fontSize: 11.5,
                    ),
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
