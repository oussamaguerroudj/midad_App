import 'package:flutter/painting.dart';

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const fab = [
    BoxShadow(color: Color(0x337B1737), blurRadius: 20, offset: Offset(0, 8)),
  ];
}
