import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildLinkifiableText(String text, TextStyle baseStyle, TextStyle linkStyle) {
  final RegExp urlRegExp = RegExp(
    r'((https?:\/\/|www\.)[^\s]+)',
    caseSensitive: false,
  );

  final matches = urlRegExp.allMatches(text);
  if (matches.isEmpty) {
    return Text(text, style: baseStyle);
  }

  final List<TextSpan> spans = [];
  int lastIndex = 0;

  for (final match in matches) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: baseStyle));
    }

    final urlString = match.group(0)!;
    final displayUrl = urlString;
    final launchUrlString = urlString.toLowerCase().startsWith('www.')
        ? 'https://$urlString'
        : urlString;

    spans.add(
      TextSpan(
        text: displayUrl,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(launchUrlString);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ),
    );

    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
  }

  return RichText(
    text: TextSpan(children: spans),
  );
}
