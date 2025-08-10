import '../services/content_service.dart';

// Export the ContentService from the wrapper for easy importing
export '../services/content_service.dart' show ContentService;

// Additional wrapper functions can be added here if needed
class ContentServiceWrapper {
  static final ContentService _contentService = ContentService();
  
  static ContentService get instance => _contentService;
}
