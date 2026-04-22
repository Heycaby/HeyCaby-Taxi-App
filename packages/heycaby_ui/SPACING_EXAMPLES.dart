// ignore_for_file: unused_local_variable, prefer_const_constructors, prefer_const_literals_to_create_immutables

/// HeyCaby spacing — practical examples using [HeyCabyColorTokens] and [HeyCabyTypography].
///
/// Copy these patterns into your screens for consistent layouts. No raw [Colors] or ad-hoc font sizes.

import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

HeyCabyThemeData get _demoTheme => kThemes[kRiderDefaultTheme]!;

// ============================================================================
// EXAMPLE 1: Profile Card with Proper Hierarchy
// ============================================================================

class ProfileCardExample extends StatelessWidget {
  const ProfileCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: HeyCabyEdgeInsets.componentAll,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 24, color: colors.text),
              HeyCabyGaps.horizontal,
              Text('Profile', style: typo.headingMedium.copyWith(color: colors.text)),
            ],
          ),
          HeyCabyGaps.verticalMax,
          Text('John Doe', style: typo.bodyLarge.copyWith(color: colors.text)),
          HeyCabyGaps.verticalMin,
          Text(
            'john@example.com',
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 2: Screen Layout with Section Spacing
// ============================================================================

class ScreenLayoutExample extends StatelessWidget {
  const ScreenLayoutExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: HeyCabyEdgeInsets.screenAll,
          child: Column(
            children: [
              const _HeaderSection(),
              HeyCabyGaps.verticalSection,
              const _StatsSection(),
              HeyCabyGaps.verticalSection,
              const _ActionsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: HeyCabyEdgeInsets.componentAll,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.accentL,
            child: Icon(Icons.person, color: colors.accent),
          ),
          HeyCabyGaps.horizontal,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back',
                  style: typo.bodyMedium.copyWith(color: colors.textSoft),
                ),
                HeyCabyGaps.verticalMin,
                Text(
                  'John Doe',
                  style: typo.headingMedium.copyWith(color: colors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Rides', value: '24')),
        SizedBox(width: HeyCabySpacing.element),
        Expanded(child: _StatCard(label: 'Rating', value: '4.8')),
        SizedBox(width: HeyCabySpacing.element),
        Expanded(child: _StatCard(label: 'Saved', value: '€45')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: EdgeInsets.all(HeyCabySpacing.componentSmall),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: typo.displayMedium.copyWith(
              color: colors.text,
              fontSize: 24,
            ),
          ),
          HeyCabyGaps.verticalMin,
          Text(
            label,
            style: typo.bodySmall.copyWith(color: colors.textSoft),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(icon: Icons.directions_car, label: 'Book a Ride'),
        SizedBox(height: HeyCabySpacing.listItem),
        _ActionButton(icon: Icons.history, label: 'Ride History'),
        SizedBox(height: HeyCabySpacing.listItem),
        _ActionButton(icon: Icons.settings, label: 'Settings'),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: HeyCabyEdgeInsets.componentAll,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: colors.text),
          HeyCabyGaps.horizontal,
          Expanded(child: Text(label, style: typo.bodyLarge.copyWith(color: colors.text))),
          Icon(Icons.chevron_right, size: 20, color: colors.textSoft),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 3: Form with Proper Spacing
// ============================================================================

class FormExample extends StatelessWidget {
  const FormExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Padding(
      padding: HeyCabyEdgeInsets.screenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign In', style: typo.headingLarge.copyWith(color: colors.text)),
          HeyCabyGaps.verticalSection,
          TextField(
            style: typo.bodyLarge.copyWith(color: colors.text),
            decoration: InputDecoration(
              contentPadding: HeyCabyEdgeInsets.componentAll,
              labelText: 'Email',
              labelStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: HeyCabySpacing.formField),
          TextField(
            style: typo.bodyLarge.copyWith(color: colors.text),
            obscureText: true,
            decoration: InputDecoration(
              contentPadding: HeyCabyEdgeInsets.componentAll,
              labelText: 'Password',
              labelStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          HeyCabyGaps.verticalSection,
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: HeyCabyEdgeInsets.button,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: colors.accent,
              foregroundColor: colors.text,
            ),
            onPressed: () {},
            child: Text('Sign In', style: typo.labelLarge.copyWith(color: colors.text)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 4: Nested Spacing Hierarchy
// ============================================================================

class NestedHierarchyExample extends StatelessWidget {
  const NestedHierarchyExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: EdgeInsets.all(HeyCabySpacing.level1),
      color: colors.bgAlt,
      child: Container(
        padding: EdgeInsets.all(HeyCabySpacing.level2),
        color: colors.surface,
        child: Container(
          padding: EdgeInsets.all(HeyCabySpacing.level3),
          color: colors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, size: 20, color: colors.accent),
                  SizedBox(width: HeyCabySpacing.level5),
                  Text(
                    'Information',
                    style: typo.titleMedium.copyWith(color: colors.text),
                  ),
                ],
              ),
              SizedBox(height: HeyCabySpacing.level4),
              Text(
                'This demonstrates nested spacing.',
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
              SizedBox(height: HeyCabySpacing.level6),
              Text(
                'Notice how spacing gets tighter as nesting increases.',
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 5: Modal/Bottom Sheet with Proper Spacing
// ============================================================================

class ModalExample extends StatelessWidget {
  const ModalExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: HeyCabyEdgeInsets.modal,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          HeyCabyGaps.verticalComponent,
          Text(
            'Confirm Action',
            style: typo.headingLarge.copyWith(color: colors.text),
          ),
          HeyCabyGaps.verticalMax,
          Text(
            'Are you sure you want to proceed?',
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
          HeyCabyGaps.verticalSection,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: HeyCabyEdgeInsets.button,
                    minimumSize: const Size(0, 48),
                    foregroundColor: colors.text,
                    side: BorderSide(color: colors.border),
                  ),
                  onPressed: () {},
                  child: Text('Cancel', style: typo.labelLarge.copyWith(color: colors.text)),
                ),
              ),
              HeyCabyGaps.horizontal,
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: HeyCabyEdgeInsets.button,
                    minimumSize: const Size(0, 48),
                    backgroundColor: colors.accent,
                    foregroundColor: colors.text,
                  ),
                  onPressed: () {},
                  child: Text('Confirm', style: typo.labelLarge.copyWith(color: colors.text)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 6: List with Proper Item Spacing
// ============================================================================

class ListExample extends StatelessWidget {
  const ListExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: HeyCabyEdgeInsets.screenAll,
      itemCount: 10,
      separatorBuilder: (context, index) => HeyCabyGaps.vertical,
      itemBuilder: (context, index) => _ListItem(index: index),
    );
  }
}

class _ListItem extends StatelessWidget {
  final int index;

  const _ListItem({required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = _demoTheme.colors;
    final typo = _demoTheme.typography;

    return Container(
      padding: HeyCabyEdgeInsets.componentAll,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.accentL,
            child: Text(
              '${index + 1}',
              style: typo.labelLarge.copyWith(color: colors.accent),
            ),
          ),
          HeyCabyGaps.horizontal,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item ${index + 1}',
                  style: typo.titleMedium.copyWith(color: colors.text),
                ),
                HeyCabyGaps.verticalMin,
                Text(
                  'Description',
                  style: typo.bodySmall.copyWith(color: colors.textSoft),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textSoft),
        ],
      ),
    );
  }
}
