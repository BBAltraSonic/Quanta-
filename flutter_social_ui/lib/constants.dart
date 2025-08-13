import 'package:flutter/material.dart';

// Colors
const kPrimaryColor = Color(0xFF1B8989); // Primary teal-ish replacing previous primary
const kBackgroundColor = Color(0xFF002B36); // Dark blue-gray background replacing black
const kCardColor = Color(0xFF073642); // Darker blue-gray for cards/elements based on new theme
const kTextColor = Colors.white; // Colors.white is already a const
const kLightTextColor = Color(0xFFB0B0B0); // Lighter gray for secondary text

// Chat Colors
const kChatOutgoingBubbleColor = Color(0xFFD1DCF7);
const kChatIncomingBubbleColor = Color(0xFFD9F4DF);
const kChatTimeTextColor = Color(0xFFDFDFDF);

// Padding and Margins
const kDefaultPadding = 16.0;
const kDefaultMargin = 16.0;

// Border Radius
const kDefaultBorderRadius = 12.0;
const kChatBubbleRadius = 22.0;

// Chat Bubble Max Width Ratio
const kChatBubbleMaxWidthRatio = 0.72;

// Text Styles (Example - will be refined in main.dart)
const kHeadingTextStyle = TextStyle(
  color: kTextColor,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

const kBodyTextStyle = TextStyle(color: kTextColor, fontSize: 16);

const kCaptionTextStyle = TextStyle(color: kLightTextColor, fontSize: 12);
