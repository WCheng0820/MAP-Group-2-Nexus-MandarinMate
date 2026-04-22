import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool isPassword;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int maxLines;
  final int minLines;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.sm),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          obscureText: _obscureText,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          minLines: widget.minLines,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height = AppDimensions.buttonHeight,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = isLoading
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
            ),
          )
        : Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: isOutlined ? AppColors.primaryColor : AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(width ?? double.infinity, height),
          side: BorderSide(color: backgroundColor ?? AppColors.primaryColor),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primaryColor,
        minimumSize: Size(width ?? double.infinity, height),
      ),
      child: child,
    );
  }
}

class RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const RoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: isSelected ? color : AppColors.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppColors.surfaceColor,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.lg),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, size: AppDimensions.iconLarge, color: color),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              description,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.lg),
                child: Icon(
                  Icons.check_circle,
                  color: color,
                  size: AppDimensions.iconLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorSnackBar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
