import 'package:flutter/material.dart';

// Colors
const kPrimaryColor = Color(0xFFFF2E2E); // Primary red tuned to plan
const kBackgroundColor = Color(0xFF0F0F0F); // Dark background per plan 0E-11
const kCardColor = Color(0xFF2C2C2C); // Darker gray for cards/elements
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
